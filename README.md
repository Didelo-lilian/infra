# infra

My personal production platform: one VPS, everything as code, every project deployed to production from CI.

> **Status:** getting started — weekend 1 of the [roadmap](https://github.com/orgs/Didelo-lilian/projects/1).

## What it will run

| Layer | Choice |
|---|---|
| Server | OVHcloud VPS, provisioned and hardened from code |
| DNS | `didelo.fr` zone fully managed by Terraform |
| Edge | Traefik v3, HTTPS everywhere, wildcard certificate, WAF and anti-bot |
| Observability | Prometheus, Grafana, one uptime probe per project, public status page |
| CI/CD | Pull requests on GitHub-hosted runners, deploys from `main` on ephemeral self-hosted runners |
| Secrets | SOPS + age, pushed to GitHub by Terraform |

Every choice gets a short decision record in [`docs/adr/`](docs/adr/) as it is made.

## Run it

Requirements: Terraform ≥ 1.14, Docker, gitleaks, the GitHub CLI, an HCP Terraform workspace in local execution mode and scoped OVH API credentials.

```bash
make check   # same checks as CI: fmt, validate, tflint, gitleaks
make plan    # preview changes to the real infrastructure
make apply   # apply them, after confirmation
```

`plan` and `apply` read `TF_CLOUD_ORGANIZATION`, `TF_WORKSPACE` and the OVH credentials from an env file kept outside the repo (`~/.config/didelo/ovh-terraform.env`, override with `ENV=`), and the GitHub token from `gh auth token`. Nothing secret is committed.

## How I built this

Built incrementally, one weekend at a time, with [Claude Code](https://claude.com/claude-code) as a pair: I write the issues and decisions, review every change and keep the history honest.

## License

[MIT](LICENSE)
