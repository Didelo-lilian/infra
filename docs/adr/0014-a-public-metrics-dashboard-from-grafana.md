# 14. A public metrics dashboard from Grafana

Date: 2026-10-24 · Status: accepted

## Context

The status page ([ADR 0006](0006-monitoring-and-public-status-page.md)) says whether the site is up. It does not show how loaded the server is, which is what a visitor looking at the platform may want to see. Grafana already has the data, but the admin Grafana must stay private: anonymous access to all of it would let anyone run their own PromQL against Prometheus.

## Decision

`https://metrics.didelo.fr` serves **one public dashboard** ([`public.json`](../../stacks/monitoring/grafana/dashboards/public.json)), through Grafana's public dashboards feature: it only runs the queries stored in the dashboard's panels.

- **What is public**: the status of each URL, uptime over 30 days, days left on the certificate, response time, and CPU and memory as global percentages. All of it is already visible to a visitor, or is global load. Container names, per-container figures, disk and server uptime stay private: they would tell an attacker what runs here and when the server reboots.
- **Traefik routes only what the page needs**, from labels on the Grafana container: `/public/` (front-end assets), `/public-dashboards/<token>`, `/api/public/dashboards/<token>` (the dashboard and its panel queries) and `/api/login/ping` and `/apis/dashboard.grafana.app/` (two calls the page makes at load: without them it shows an error toast). `/` redirects to the dashboard. Everything else, login, admin and the rest of the API included, is a 404 from Traefik and never reaches Grafana.
- **Its own network**: Grafana joins a `metrics` network shared with Traefik only, not `edge`, so the other containers cannot reach its admin API.
- **Created by Ansible**: Grafana cannot provision a public dashboard from a file. After the stacks start, Ansible waits for the dashboard to be provisioned, then creates its public link through the API on `127.0.0.1:3000` if it does not exist, with a fixed token. That needs an admin user, so the initial admin is no longer disabled: its password comes from SOPS (`GRAFANA_ADMIN_PASSWORD`) and only Ansible uses it. The login form stays disabled and the API is not routed by Traefik.
- The token is the dashboard's link and is public by nature: it is in the repository and in every URL. It limits the router to this one dashboard, it is not a secret.
- The CrowdSec bouncer, the rate limit and the security headers apply, as they are set on the `websecure` entry point.

## Consequences

- Checked on a throwaway stack with the real files and Traefik: the dashboard renders through the router; `/login`, `/api/datasources`, `/api/ds/query`, `/api/search`, `/api/user`, `/metrics` and `/explore` answer 404; a panel that is not in the dashboard answers 404; a query sent in the body of a panel's request is ignored, the stored one runs. Running the Ansible tasks twice creates the link once.
- The page made calls that fail behind the router and fill the browser console: a Grafana Live WebSocket retried in a loop, the settings of four bundled apps (Explore Logs, Traces, Metrics, Profiles) and its front-end timings posted to `/api/frontend-metrics`. Live and the four apps are switched off (`GF_LIVE_MAX_CONNECTIONS=0`, `GF_PLUGINS_DISABLE_PLUGINS`), nothing here uses them. The timings go to a router that points at Traefik's `ping@internal` (200, enabled on the private `metrics` entry point), so they never reach Grafana. A page load now has no failed request and no console error.
- A page load is about 60 requests: the burst of the rate limit (100) covers it, the average does not apply.
- Anyone can read the numbers of the six panels, nothing else: the time range is fixed, the viewer cannot change it.
- This **does not replace the external status page**: it runs on the server it shows, so it goes down with it. The status page stays the answer to "is it up?".
- A link that already exists with another token is kept. Changing the token means deleting the public dashboard in Grafana first.
- Grafana's basic auth is on again, with the admin only reachable on localhost (the tunnel). A rotation of the password needs the workflow run with `force`, like the SMTP password.
