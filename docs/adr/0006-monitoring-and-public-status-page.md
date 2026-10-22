# 6. Monitoring with Prometheus, and a status page outside the server

Date: 2026-10-23 · Status: accepted

## Context

The platform is live, but nobody would know if it stopped. I want alerts when something breaks, history to look at, and a status page worth showing.

## Decision

Prometheus, a blackbox exporter, node-exporter, Alertmanager and Grafana, all in `stacks/monitoring`, deployed by the same pipeline as the rest ([ADR 0005](0005-apply-the-server-configuration-from-ci.md)).

- **Probes go through the public URL**, so they exercise DNS, Traefik and the certificate like a visitor, and give availability, latency and days left on the certificate. Traefik renews 30 days before expiry, so under 14 days left means renewal is failing.
- **Grafana is private**: reachable through an SSH tunnel only, with datasource and dashboard provisioned from files and not editable in the UI, so a change is a pull request. It is my detailed view (CPU, latency, history), not a public page.
- **The public status page lives outside the server.** A page hosted on the machine it watches goes down with it, which is when it is needed. The [status repository](https://github.com/Didelo-lilian/status) probes the site from GitHub every 15 minutes and publishes a static page with GitHub Pages at `status.didelo.fr`, through a CNAME managed by Terraform.
- **Alerts go by email**, through a Gmail SMTP relay with an app password in the `production` environment secrets. A transactional mail service would need SPF and DKIM for `didelo.fr`, which would undo the mail lock-down of the DNS zone: it still sends nothing. The recipient is the `ALERT_EMAIL` repository variable.
- Containers restart when a mounted config changes, through a `CONFIG_HASH` label that Ansible computes: Compose does not notice a bind-mounted file changing.

## Consequences

- Two views to keep consistent: Prometheus probes from inside the server, the status repository from outside. A disagreement is itself a signal (for example a firewall or DNS problem).
- A CNAME to GitHub Pages must only be created after the custom domain is set on the Pages site, or anyone could claim `status.didelo.fr` first.
- The dry run has no SMTP secret, so a rotated password does not show in the diff: run the Server workflow by hand with `force`.
- The password file is readable by group `nobody` only, and Ansible tasks that handle it set `no_log`, because the run summary is public.
- No per-container metrics yet (no cAdvisor) and no per-interface network metrics: node-exporter does not run on the host network. Blackbox covers each public service.
