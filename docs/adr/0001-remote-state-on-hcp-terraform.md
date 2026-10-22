# 1. Remote state on HCP Terraform, local execution

Date: 2026-10-22 · Status: accepted

## Context

The state holds secrets in clear text, so it can't live in git. I want a remote, locked and versioned state without paying for anything but the VPS, and I don't want cloud credentials to leave my machine or the CI.

## Decision

Store the state in an HCP Terraform workspace on the free tier, with **local execution**: HCP only keeps the state and the lock, `plan` and `apply` run on my machine or in GitHub Actions.

## Consequences

- Free up to 500 managed resources, far above what this platform needs.
- OVH and GitHub credentials stay in the environment of whoever runs Terraform.
- An HCP token is needed in CI to read and lock the state.
- Alternatives left aside: an S3 bucket (paid object storage), OpenTofu with client-side state encryption in git (switching tool for one feature).
