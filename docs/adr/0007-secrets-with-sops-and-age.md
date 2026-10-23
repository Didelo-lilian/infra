# 7. Secrets encrypted in the repository with SOPS and age

Date: 2026-10-23 · Status: accepted

## Context

Secrets are set by hand with `gh secret set`. Nothing records what changed or when, nothing is reviewed, and rebuilding the platform means retyping every one. More arrive with each application.

Terraform runs in CI with the workflow's `github.token`, which is read-only: it cannot write GitHub secrets. Pushing them from Terraform would need a GitHub App with write access to secrets, which is a powerful key of its own.

## Decision

Application secrets live in `secrets/*.sops.yaml`, encrypted with [SOPS](https://github.com/getsops/sops) and [age](https://github.com/FiloSottile/age). SOPS keeps the key names readable and encrypts the values, so a diff shows *which* secret changed without showing it.

- **Two age keys**: one on my laptop to edit the files, one for CI. Files are encrypted for both. Both private keys are in my password manager, and the CI key also has an offline copy.
- **CI decrypts, Terraform does not (yet).** The CI private key is the `SOPS_AGE_KEY` secret of the `production` environment, never of `plan`: the dry run has no access to secrets, as it does today. Ansible reads the files with the `community.sops` lookup during the apply and writes what the server needs.
- **Bootstrap secrets stay manual**, because something has to exist before the pipeline can read anything: the OVH keys, the HCP Terraform token, the CI SSH key, `SOPS_AGE_KEY` and the release App key.
- **Terraform pushing secrets to other repositories** (for example a token a scheduled workflow needs) comes later, with its own ADR and its own App.
- **Rotation**: a secret value is changed at its source, edited with `sops`, merged, then rolled out by running the Server workflow with `force`. If the CI key may have leaked, remove it from `.sops.yaml`, run `sops updatekeys`, then `sops rotate`, replace `SOPS_AGE_KEY`, and only then change the secret values themselves, otherwise the old key reads the new ones.
- **Keys stay classic X25519**: age can generate post-quantum keys, but SOPS support for them is not confirmed.

## Consequences

- The repository is public, so the ciphertext is public forever. If a private key ever leaks, every value ever committed must be treated as leaked and changed at its source: rotating the key is not enough.
- One manual secret (the CI age key) replaces one per application secret.
- Losing both private keys is painful, not fatal: every secret can be reissued at its source.
- A value decrypted at run time is not masked by GitHub, and the run summary is public. Nothing decrypted is ever printed, and tasks that handle a secret set `no_log: true`.
- Ephemeral self-hosted runners fit: the key exists only in the job's environment, after approval, and disappears with the container. They must never take jobs from pull requests of a public repository.
