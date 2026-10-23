# 12. Ban SSH attackers at the host firewall

Date: 2026-10-24 · Status: accepted

## Context

The Traefik bouncer ([ADR 0011](0011-the-traefik-bouncer-fails-open.md)) only sees HTTP. sshd is on the host and already receives brute-force attempts all day: CrowdSec detects them ([ADR 0010](0010-crowdsec-reads-the-edge-logs.md)) but nothing stops the attacker from trying again.

## Decision

The **CrowdSec firewall bouncer** runs on the host as a systemd service, installed and configured by Ansible, in nftables mode.

- **Binary**: the GitHub release (`v0.0.36`, the latest stable) pinned by SHA-256 in `ansible/site.yml`, unpacked under `/opt/…-<version>`. No third-party apt repository, as for Docker and the other packages; an upgrade is a version and checksum bump.
- **API**: CrowdSec publishes its API on `127.0.0.1:8080` only, so the host can reach it and nothing else can. The bouncer has its own key (`CROWDSEC_FIREWALL_BOUNCER_KEY` in the SOPS file), registered at CrowdSec startup like the Traefik one.
- **Input hook only**: the bouncer drops packets in its own nftables table, before ufw's rules, but only on the `input` hook, which is the host itself, so SSH. Ports 80 and 443 are published by Docker, whose traffic goes through `forward`: they stay with the Traefik bouncer, which can answer a 403 where a firewall can only drop.
- **Local detections only** (`origins: [crowdsec, cscli]`): the ~15,000 addresses of the community blocklist are refused by Traefik but do not lose SSH. A blocklisted address can be a GitHub-hosted runner, and CI deploys through SSH. This replaces an allowlist: the ranges of GitHub Actions are too wide to exempt (ADR 0010), and a successful key login never counts as a failure, so CI is not banned by what CrowdSec detects here.
- **Fail open**: stopping the service removes its table, and a CrowdSec that is down leaves the last list in place without blocking anything new. Nothing here can lock the server by itself.

## Consequences

- Checked on a throwaway Linux stack with the real binary and configuration: a connection to port 22 is accepted, then dropped within the 10 s update interval after `cscli decisions add` for the client's address, and accepted again after `delete`. With `origins` reduced to `crowdsec`, a decision created by hand is ignored, which shows the filter applies.
- A ban lasts as long as the scenario says (4 hours by default) and then lifts by itself.
- **If I lock myself out**: connect from another network (a phone hotspot is enough, only my address is banned), or from the OVH console, then `docker exec crowdsec-crowdsec-1 cscli decisions delete --ip <address>`. As a last resort, `systemctl stop crowdsec-firewall-bouncer` empties the table.
- Rotating the key is not visible in the dry run, and the service must restart: run the workflow by hand with `force`.
- Closing a hole by the firewall is not a replacement for key-only SSH, which stays: the bouncer only reduces the noise and the attempts.
