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

Requirements: Terraform ≥ 1.14, an HCP Terraform workspace in local execution mode, scoped OVH API credentials.

```bash
export TF_CLOUD_ORGANIZATION=<organization> TF_WORKSPACE=infra
export OVH_APPLICATION_KEY=… OVH_APPLICATION_SECRET=… OVH_CONSUMER_KEY=… GITHUB_TOKEN=…
cd terraform
terraform init
terraform plan
```

Credentials are read from the environment only and are never committed.

## How I built this

Built incrementally, one weekend at a time, with [Claude Code](https://claude.com/claude-code) as a pair: I write the issues and decisions, review every change and keep the history honest.

## License

[MIT](LICENSE)
