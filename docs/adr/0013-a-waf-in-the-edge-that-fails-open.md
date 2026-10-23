# 13. A WAF at the edge that fails open

Date: 2026-10-24 · Status: accepted

## Context

The edge refuses banned addresses ([ADR 0011](0011-the-traefik-bouncer-fails-open.md)) and limits what one address can ask for. Neither looks at what a request contains: a SQL injection, a path traversal or an exploit for a known CVE comes from an address that has done nothing wrong yet. The apps that take input (the game's WebSockets, forms) are coming.

## Decision

**CrowdSec AppSec**, in the CrowdSec container, is the WAF. The Traefik bouncer sends it every request and blocks the ones it matches with a 403.

- **Rules**: the virtual-patching collection (rules written for known CVEs and exposed files, `/.env` for instance) and the **OWASP Core Rule Set**.
- **CRS in-band**: the hub ships the CRS out-of-band, which only raises alerts. A small config of ours ([`stacks/crowdsec/appsec/crs-inband.yaml`](../../stacks/crowdsec/appsec/crs-inband.yaml)) runs the same rules in-band, so the anomaly score decides before the backend sees the request. Paranoia level 1, the CRS default.
- **Fail open**: `crowdsecAppsecFailureBlock`, `crowdsecAppsecUnreachableBlock` and `crowdsecAppsecUnreadableBodyBlock` are `false`. The plugin blocks on all three by default, which would make a WAF error an outage of every site. A body over 1 MiB is not buffered for inspection: the sites serve static files and the game's messages are small.
- **Memory**: CrowdSec used about 42 MiB before. On a throwaway stack with the real files and the 205 rules it uses about 70 MiB; the limit goes from 256 to 384 MiB to leave room for the community blocklist and for traffic.
- AppSec listens on port 7422 of the `crowdsec` network, never published. The bouncer's key is the same as for the decisions.

## Consequences

- Checked on a throwaway stack with the real files: a SQL injection, a path traversal, an XSS, a Log4Shell header and `/.env` get 403 and appear as alerts (`anomaly score block: sql_injection`, `lfi`, `vpatch-env-access`…); a normal GET, a form POST and a page with query parameters pass. With CrowdSec stopped, the same attacks get 200.
- Every request now waits for AppSec's answer before it reaches the backend (a few milliseconds, one extra hop on the private network). If it hangs, the plugin's 10 s timeout applies, then the request passes.
- A false positive is a 403 for a legitimate request. The way out is in the config file: find the rule in `cscli alerts inspect`, then turn it off for one path with a `pre_eval` hook, as the commented example shows. Until then the address is not banned: a WAF block is an alert, not a decision.
- CrowdSec's own scenarios can still turn repeated WAF alerts into a ban, which the Traefik bouncer then applies.
- The virtual-patching rules update with the hub, when CrowdSec restarts; the version of the collections is not pinned.
