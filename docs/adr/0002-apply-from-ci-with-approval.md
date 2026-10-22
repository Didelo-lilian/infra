# 2. Apply from CI after a manual approval

Date: 2026-10-23 · Status: accepted

## Context

Applying from a laptop works but leaves no trace of who applied what, depends on local tools and credentials, and makes it easy to apply code that was never merged.

## Decision

`main` is the only source of what runs in production. On every push to `main` that touches `terraform/`, a GitHub Actions workflow:

1. runs `terraform plan` in the `plan` environment and publishes it in the run summary;
2. if there are changes, waits in the `production` environment until I approve the deployment, then runs `terraform apply`.

Both environments only accept deployments from `main`, and they hold the credentials (OVH API keys, a dedicated HCP Terraform team token), so a workflow on another branch can't read them.

## Consequences

- Every apply is tied to a merged commit, a plan and an approval, all visible in the Actions history.
- The apply job plans again before applying. Runs are serialized, so it applies the plan that was reviewed unless the infrastructure changed outside Terraform in between.
- The plan is public in the run summary: sensitive values must be marked `sensitive` so Terraform masks them.
- `make apply` stays available locally for emergencies.
