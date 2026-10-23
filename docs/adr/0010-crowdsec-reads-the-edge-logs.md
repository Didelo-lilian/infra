# 10. CrowdSec reads the edge logs

Date: 2026-10-23 · Status: accepted

## Context

The edge is hardened (HTTPS, headers, key-only SSH) but blind: nothing notices a scanner probing for `.env` files or a bot guessing SSH users, and the server's own `auth.log` already fills with them. Before the apps that take input (the game's WebSockets, forms) go online, the platform needs to see hostile traffic and later act on it.

## Decision

**CrowdSec**, in `stacks/crowdsec`, reads two logs and decides which IPs are hostile. This step only observes: acting on the decisions is [infra#48](https://github.com/Didelo-lilian/infra/issues/48) (Traefik) and [infra#49](https://github.com/Didelo-lilian/infra/issues/49) (host firewall), so a wrong decision cannot lock anything out yet.

- **Traefik access log**, JSON, in `/srv/stacks/traefik/logs/access.log` on the host. Headers are dropped except the user agent, which CrowdSec's scenarios look at. Traefik does not rotate its logs: logrotate does it daily, with `copytruncate`, three files kept and a 50 MB cap at rotation.
- **`/var/log/auth.log`** for sshd, through a read-only mount of `/var/log`: rsyslog replaces the file when it rotates it, and a mount of the file alone would keep following the old one. It belongs to group `adm`, and with every capability dropped being root is not enough to read it, so the container gets `group_add` with the host's `adm` gid, read by Ansible like the docker one.
- Collections: `crowdsecurity/traefik` and `crowdsecurity/sshd`. The `whitelists` parser, installed by default, exempts private and loopback addresses.
- The container is hardened like the monitoring ones (`cap_drop: ALL`, `no-new-privileges`, 256 MB limit) and publishes no port. Its API stays on a private network for the bouncers.
- CrowdSec also registers with its central API and receives the community blocklist.

## Consequences

- Checked on a throwaway stack with the real Traefik flags and acquisition file: 41 of 41 access-log lines parsed, 40 requests to unknown paths raised `http-probing` and `http-crawl-non_statics` with a ban decision, and failed-login lines for sshd raised `ssh-bf` and `ssh-slow-bf`.
- No IP is allowlisted by hand. My own address changes, and the address ranges of GitHub Actions are huge: allowlisting them would exempt anyone who can run a workflow. A deployment logs in once with a key, and a successful login never counts as a failure, so CI is not banned.
- A burst of 404s that a legitimate crawler or a broken front produces would also raise an alert. That is why nothing acts on the decisions yet; the false-positive plan arrives with the bouncer.
- The access log is the only place a visitor's IP is written on the server. It is kept for a few days and not published.
- Traefik is recreated when this is deployed, which drops its connections for a few seconds.
