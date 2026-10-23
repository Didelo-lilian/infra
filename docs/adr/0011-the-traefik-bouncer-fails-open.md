# 11. The Traefik bouncer fails open

Date: 2026-10-24 · Status: accepted

## Context

CrowdSec now decides which IPs are hostile ([ADR 0010](0010-crowdsec-reads-the-edge-logs.md)) but nothing acts on it. Traefik is the only way in for web traffic, so it is the place to refuse a banned IP, before any backend sees it.

## Decision

The **CrowdSec bouncer plugin** for Traefik runs as a global middleware on `websecure`, ahead of the security headers. A banned IP gets a 403.

- **Stream mode**: every minute the plugin pulls the banned IPs into a local cache, so a request is checked in memory and never waits for CrowdSec. A ban or a lifted ban takes up to a minute to apply.
- **Fail open**: `updateMaxFailure: -1` and `streamStartupBlock: false`. The plugin blocks everything by default when CrowdSec is down or still starting, which would turn a crashed security container into an outage of every site. If CrowdSec stops, Traefik keeps the last list it has and keeps serving; if Traefik restarts while CrowdSec is down, nothing is blocked until CrowdSec is back.
- **Key**: a random value in the SOPS file. Ansible writes it to a file that Traefik reads (`crowdsecLapiKeyFile`, so it is in no label or command line) and to an env file that CrowdSec uses to register the bouncer at startup. Nothing is registered by hand.
- **Network**: the `crowdsec` network is created by the Traefik stack, like `edge`, and CrowdSec joins it. The API (8080) is reachable from there only.
- **Plugin cache**: Traefik downloads the plugin when it starts and does not start without it. A volume keeps it, so a restart does not depend on the plugin catalog being reachable.
- **Version**: the plugin is pinned to `v1.8.1` in the static configuration and bumped by hand.

## Consequences

- Checked on a throwaway stack with the real flags and middleware file: 200 before a decision, 403 about a minute after `cscli decisions add`, 200 again after `delete`, the ban still applies when CrowdSec is stopped, and a Traefik restarted without CrowdSec answers 200.
- A false positive locks the owner of the IP out of every site until the decision is deleted (`cscli decisions delete --ip …`, one minute to apply). SSH is not affected: it is not behind Traefik.
- Rotating the key is not visible in the dry run, and Traefik reads it when its configuration loads: run the workflow by hand with `force`.
- The first deployment recreates Traefik, which drops its connections for a few seconds.
- WebSocket upgrades go through the same check, once, when the connection opens.
