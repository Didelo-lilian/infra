# 9. Deploy app updates without an approval

Date: 2026-10-23 · Status: accepted

## Context

The **Server** workflow applies the whole server configuration: firewall, Traefik, monitoring, secrets. Its approval in `production` guards that. [ADR 0008](0008-serve-a-static-site-from-another-repository.md) made every merge to `design-system` start that workflow, so a new Storybook image waited for the same click as a firewall change. A new image of an app that already runs changes no configuration and should deploy continuously.

## Decision

- A **Deploy app** workflow (`workflow_dispatch`, input `stack`) restarts one stack on its latest image. It runs in its own `apps` environment, which has no required reviewer.
- It connects as `deploy` with its own ed25519 key. In `authorized_keys` the key is `restrict,command="/usr/local/bin/deploy-app"`: whatever it asks for, the server runs that script, which accepts only a stack from a fixed list (today `ds`) and runs `docker compose up -d --pull always --wait` on the copy of its Compose file that Ansible installed. It cannot open a shell, forward a port or change what the stack runs.
- The private key is a secret of the `apps` environment only, which is restricted to the `main` branch: a pull request cannot read it.
- `design-system` starts **Deploy app** instead of **Server**. Anything that changes `stacks/`, `ansible/` or `terraform/` keeps the dry run and the approval in `production`.
- A new stack is not deployable by this path until it is added to the list in `site.yml` and to the workflow's choices: that takes a pull request and an approved Server run.

## Consequences

- A merge to `design-system` reaches https://ds.didelo.fr without a click; the workflow fails if the new container is not healthy within 60 seconds.
- The `deploy` user is in the `docker` group, which is root-equivalent: the safety rests on the forced command, so the script must stay a fixed list, never a pattern.
- The App token that starts the workflow can also start **Server**, but that one still waits for approval.
- A bad image is rolled back by pinning a previous `sha-…` tag in the Compose file through a pull request.
- When the self-hosted runner pool exists, the deployment can run on the server itself and this workflow goes away.
