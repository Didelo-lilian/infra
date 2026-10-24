# 17. A plugin catalog outage is accepted

Date: 2026-10-24 · Status: accepted

## Context

The edge asks the CrowdSec bouncer, a Traefik plugin, about every request ([ADR 0011](0011-the-traefik-bouncer-fails-open.md)). Traefik downloads the plugin from its catalog (`plugins.traefik.io`) when it starts. ADR 0011 said the plugin volume makes a restart independent of the catalog and that Traefik does not start without the plugin. Both were wrong.

Measured on a throwaway Traefik v3.7.16 with the real flags and middleware files, and the catalog pointed at a closed port:

- The downloader asks the catalog at every start, even with the archive in the volume; the cache only saves bandwidth.
- When the call fails, Traefik stays up. It logs "Plugins are disabled because an error has occurred", the middleware that uses the plugin becomes invalid, and every router on `websecure` answers 404.
- Nothing restarts it. The sites come back at the next start with the catalog reachable.

How often that can happen: the catalog needs to be down **and** Traefik needs to start during that time (a deployment, or the 04:00 reboot when an update asks for it). A quick search of the entries of [Traefik's status page](https://status.traefik.io) found two short incidents on the plugins, about an hour in December 2024 and a Cloudflare outage in November 2025. That is a quick look, not a count, and the entries could not be opened at the source.

## Decision

Keep the catalog. A catalog outage during a start is accepted.

- **What was tried**: the plugin source copied into the repository and loaded with `experimental.localPlugins` from a read-only mount. It worked: with the catalog down the current setup answered 404, the local plugin answered 200, and a banned address still got its 403. It lives on the branch `74-traefik-plugin-from-disk` (PR #78, closed without merging).
- **Why not**: about 200 KB of third-party code in the request path of every site, bumped by hand (Dependabot does not read plugin versions), so a fix upstream waits for us; plus exceptions in gitleaks (a test key in the plugin's manifest) and in SonarCloud (the copied code fails the duplication gate). For two or three sites that is more upkeep than the risk is worth.
- **Detection**: every probed site fails at once, so `SiteDown` fires for all of them. The Traefik logs say "Plugins are disabled".
- **Runbook**: check that the catalog answers (`curl -sI https://plugins.traefik.io`), then restart the Traefik container. The sites are back with the bouncer. Nothing is lost: certificates and the key are in volumes and files.
- **Reconsider** (issue #74) when a start actually hits an outage, when the catalog turns unreliable (several incidents within a few months), or when the plugin ships a fix we cannot wait for during an outage.

## Consequences

- A start during a catalog outage takes every site down until someone restarts Traefik; the 04:00 reboot makes it possible at night, so the alert may be the first sign.
- The volume stays: the container is read-only and the download needs a writable place.
- Nothing new to maintain: the plugin keeps being bumped by hand in the static configuration.
