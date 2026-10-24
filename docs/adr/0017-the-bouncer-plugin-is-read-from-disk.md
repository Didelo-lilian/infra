# 17. The bouncer plugin is read from disk

Date: 2026-10-24 · Status: accepted

## Context

The edge asks the CrowdSec bouncer, a Traefik plugin, about every request ([ADR 0011](0011-the-traefik-bouncer-fails-open.md)). The plugin was downloaded from Traefik's plugin catalog (`plugins.traefik.io`) at startup, with a volume meant to make a restart independent of the catalog.

It does not. In Traefik v3.7.16 the downloader calls the catalog at every start, even with the archive in the volume (it sends the cached file's hash and only saves bandwidth when the answer is "not modified"). When the call fails Traefik stays up, logs "Plugins are disabled because an error has occurred", and the middleware that uses the plugin becomes invalid: every router on the entry point is dropped and every site answers 404. The container runs, so nothing restarts it. The server reboots at 04:00 when an update needs it, and a reboot is a start.

Measured on a throwaway Traefik v3.7.16 with the real middleware files and `plugins.traefik.io` pointed at a closed port: the old configuration answered 404, the new one 200.

## Decision

- **The plugin source is in the repository** (`stacks/traefik/plugins-local`), at tag v1.8.1, commit `f9c85b1472d618e9188a025c9b2308d0b27e5321`, with its Apache-2.0 licence and the two small libraries it vendors. It is about 200 KB: only what Traefik's interpreter reads (the Go sources, `go.mod`, `vendor/`, `.traefik.yml`), not the tests, examples or CI files.
- **Traefik loads it as a local plugin** (`experimental.localPlugins`), from a read-only mount. The static configuration and the middleware keep the plugin's name, `bouncer`. The `plugins` volume is gone.
- **Provenance is in [`UPSTREAM.md`](../../stacks/traefik/plugins-local/UPSTREAM.md)**: where the files come from, which commit, which files were left out, and how to bump.

## Consequences

- Checked on a throwaway Traefik with the catalog unreachable and a read-only container, as in production: a request goes through the plugin and is answered. With a fake CrowdSec API banning one address, that address gets a 403 and another gets a 200, so it is the plugin that runs, not a bypass.
- Starting Traefik needs no outside service for the plugin any more. What remains at a start is Docker's image, already on the disk.
- A bump is manual: fetch the new tag, copy the files, run the check of `UPSTREAM.md`. Nothing updates the plugin on its own, as before: Dependabot does not read plugin versions.
- Third-party code now sits in the repository. Its tag is annotated, its commit is recorded, and the diff of a bump shows exactly what changes.
- On the server the old `traefik_plugins` volume stays unused; it can be removed by hand (`docker volume rm traefik_plugins`).
