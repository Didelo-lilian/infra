# 5. Apply the server configuration from CI

Date: 2026-10-23 · Status: accepted

## Context

The Ansible playbook ran from my laptop. That has the problems [ADR 0002](0002-apply-from-ci-with-approval.md) solved for Terraform: no trace of who applied what, a dependency on one machine and its key, and nothing stops a run of unmerged code.

## Decision

The same pipeline as Terraform. On every push to `main` that touches `ansible/` or `stacks/`, the **Server** workflow:

1. runs `ansible-playbook --check --diff` in the `plan` environment and publishes the output in the run summary;
2. if the recap shows changes, waits in `production` until I approve, then runs the playbook.

- CI connects as a dedicated `ci` user, with its own ed25519 key. The private key exists only in the two environments' secrets. The public key is in the repo and Ansible keeps it as the user's only authorized key.
- The server's host key is pinned in `ansible/known_hosts`, so CI refuses to talk to anything else answering on `didelo.fr`, even if DNS were hijacked.
- `make server-bootstrap` runs only the tasks tagged `ci`, once per fresh server: CI cannot create its own access.

## Consequences

- Every deploy is tied to a merged commit, a dry run and an approval.
- The `ci` user has passwordless sudo, which Ansible needs: the key is as powerful as root. Revoking it means deleting the secret and removing `ci.pub`.
- `--diff` prints file contents in a public run summary: any task that ever handles a secret must set `no_log: true`.
- Ansible and its collections are pinned (`requirements.txt`, `requirements.yml`) so CI and my laptop run the same versions. Dependabot bumps the pip pin.
