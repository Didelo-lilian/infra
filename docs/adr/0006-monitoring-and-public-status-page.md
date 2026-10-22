# 6. Monitoring with Prometheus, and a public read-only status page

Date: 2026-10-23 · Status: accepted

## Context

The platform is live, but nobody would know if it stopped. I want alerts when something breaks, history to look at, and a status page worth showing.

## Decision

Prometheus, a blackbox exporter, node-exporter, Alertmanager and Grafana, all in `stacks/monitoring`, deployed by the same pipeline as the rest ([ADR 0005](0005-apply-the-server-configuration-from-ci.md)).

- **Probes go through the public URL**, so they exercise DNS, Traefik and the certificate like a visitor, and give availability, latency and days left on the certificate. Traefik renews 30 days before expiry, so under 14 days left means renewal is failing.
- **Grafana is a public, read-only status page** at `status.didelo.fr`: anonymous viewers, no login form, basic auth off, no initial admin user. Datasource and dashboard are provisioned from files and not editable in the UI: a change is a pull request. There is no admin surface to attack because there is no admin.
- **Alerts go by email**, through a Gmail SMTP relay with an app password in the `production` environment secrets. A transactional mail service would need SPF and DKIM for `didelo.fr`, which would undo the mail lock-down of the DNS zone: it still sends nothing. The recipient is the `ALERT_EMAIL` repository variable.
- **An outside probe**: a scheduled GitHub Actions workflow requests the site every 15 minutes. A server that is down cannot tell anyone, and a failed run emails me without any secret or third-party service.
- Containers restart when a mounted config changes, through a `CONFIG_HASH` label that Ansible computes: Compose does not notice a bind-mounted file changing.

## Consequences

- Anyone can read the dashboard and, through Grafana's query API, any metric Prometheus holds. They contain no secrets, but host names and resource use are public.
- The dry run has no SMTP secret, so a rotated password does not show in the diff: run the Server workflow by hand with `force`.
- The password file is readable by group `nobody` only, and Ansible tasks that handle it set `no_log`, because the run summary is public.
- No per-container metrics yet (no cAdvisor) and no per-interface network metrics: node-exporter does not run on the host network. Blackbox covers each public service.
- Scheduled workflows are paused after 60 days without activity on a public repository.
