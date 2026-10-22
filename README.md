# infra

My personal production platform: one VPS, everything as code, every project deployed to production from CI.

> **Status:** getting started — weekend 1 of the [roadmap](https://github.com/orgs/Didelo-lilian/projects/1).

## What it will run

| Layer | Choice |
|---|---|
| Server | OVHcloud VPS, configured and hardened by an Ansible playbook |
| DNS | `didelo.fr` zone fully managed by Terraform |
| Edge | Traefik v3, HTTPS everywhere, wildcard certificate, WAF and anti-bot |
| Observability | Prometheus, Grafana, one uptime probe per project, public status page |
| CI/CD | Pull requests on GitHub-hosted runners, deploys from `main` on ephemeral self-hosted runners |
| Secrets | SOPS + age, pushed to GitHub by Terraform |

Every choice gets a short decision record in [`docs/adr/`](docs/adr/) as it is made.

## Run it

Requirements: Terraform ≥ 1.14, Ansible with ansible-lint, Docker, gitleaks, the GitHub CLI, an HCP Terraform workspace in local execution mode and scoped OVH API credentials.

```bash
make check         # same checks as CI: fmt, validate, tflint, ansible-lint, gitleaks
make plan          # preview changes to the real infrastructure
make apply         # apply them, after confirmation
make server-diff   # preview the server configuration (dry run)
make server        # apply it
```

Changes reach production through CI, not from a laptop: once a change to `terraform/` is merged to `main`, the **Terraform** workflow plans it and shows the plan in the run summary, then the apply waits for a manual approval in the protected `production` environment ([ADR 0002](docs/adr/0002-apply-from-ci-with-approval.md)).

`make plan` and `make apply` remain for local previews and emergencies. They read `TF_CLOUD_ORGANIZATION`, `TF_WORKSPACE` and the OVH credentials from an env file kept outside the repo (override its path with `ENV=`), and the GitHub token from `gh auth token`. Nothing secret is committed.

### The server

[`ansible/site.yml`](ansible/site.yml) describes the whole server ([ADR 0003](docs/adr/0003-server-configuration-with-ansible.md)):
- key-only SSH, no root login;
- Docker from Ubuntu's packages, with log rotation;
- a `deploy` user;
- a firewall that only lets SSH, HTTP and HTTPS in;
- automatic security updates, with a reboot at 04:00 UTC when one needs it.

It is idempotent: a second run changes nothing. It reaches the server through an SSH alias `didelo-vps` defined in `~/.ssh/config` (host, user `ubuntu`, key).

## How I built this

Built incrementally, one weekend at a time, with [Claude Code](https://claude.com/claude-code) as a pair: I write the issues and decisions, review every change and keep the history honest.

## License

[MIT](LICENSE)
