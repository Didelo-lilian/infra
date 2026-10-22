# 4. Traefik with per-host certificates from the TLS challenge

Date: 2026-10-23 · Status: accepted

## Context

Every project gets its own sub-domain of `didelo.fr`, served over HTTPS by one reverse proxy on the VPS. The certificates must renew without anyone thinking about it.

Let's Encrypt offers two ways to prove control of a name here:
- **DNS-01**: the proxy writes a TXT record through the OVH API. It is the only way to get a wildcard `*.didelo.fr`, but an OVH key able to rewrite the zone has to live on the server;
- **TLS-ALPN-01**: Let's Encrypt connects to port 443 and the proxy answers with a special certificate. No credentials are needed, but each name gets its own certificate.

## Decision

Traefik v3 with the TLS-ALPN-01 challenge, one certificate per host, renewed by Traefik 30 days before expiry.

- No secret on the server can change DNS: a compromised server cannot redirect the domain.
- The usual argument for a wildcard, keeping sub-domain names out of Certificate Transparency logs, does not apply: every project here is public.
- HTTP redirects to HTTPS. HSTS lasts a year and covers sub-domains, without `preload`, which is hard to undo.
- Traefik reaches Docker through a socket proxy that only allows reading containers and events, on an internal network. The dashboard is off.

## Consequences

- A new sub-domain only needs container labels: its certificate is issued on the first request.
- Let's Encrypt limits new certificates to 50 a week for the domain, far above what this platform needs.
- A sub-domain that must stay private would need DNS-01 and a scoped OVH key, to decide then.
