# 3. Server configuration with Ansible

Date: 2026-10-23 · Status: accepted

## Context

The VPS was hardened by hand (SSH keys only, no root login). It still needs Docker, a firewall and automatic updates, and it must be possible to rebuild it, or change it, without remembering a list of commands.

Options considered:
- a shell script: no dependency, but every step has to check by hand whether it already ran;
- cloud-init: only runs on first boot, so applying it to the current server means reinstalling it;
- Ansible: declarative and idempotent by design, re-runnable at any time.

## Decision

An Ansible playbook, [`ansible/site.yml`](../../ansible/site.yml), describes the server. `make server-diff` previews the changes (`--check --diff`), `make server` applies them, and CI lints the playbook with ansible-lint.

- Docker comes from Ubuntu's own packages (`docker.io`, `docker-compose-v2`), not Docker's repository: no third-party repository, and security fixes arrive with unattended-upgrades.
- The firewall (ufw) only allows SSH, HTTP and HTTPS. Docker writes its own iptables rules and bypasses ufw, so only the reverse proxy will publish ports.
- Unattended-upgrades reboots the server at 04:00 UTC when an update needs it.

## Consequences

- The server can be rebuilt from a fresh Ubuntu image with one command, and a second run changes nothing.
- It runs from my laptop for now. Running it from CI would need an SSH key in the `production` environment, which can come later.
- The `deploy` user is in the `docker` group, which is equivalent to root on this host: it must never get a password or a key with more reach than deploys need.
