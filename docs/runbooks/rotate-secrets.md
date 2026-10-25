# Rotating secrets and age keys

How secrets are stored is in [ADR 0007](../adr/0007-secrets-with-sops-and-age.md). The commands below were rehearsed with throwaway keys and dummy values: after `updatekeys` and `rotate`, the removed key no longer decrypts the file, while a copy made *before* the rotation (which is what the public git history keeps) stays readable by it.

Run everything from a checkout of `infra`. `sops` finds the laptop key in its default location; the CI key is only used by the Server workflow.

## Change the value of a secret

1. Create the new value at its source (for the SMTP password: a new app password in the Google account).
2. Edit the file and set `SMTP_PASSWORD`: `sops secrets/production.sops.yaml` (`SOPS_EDITOR=nano` is set in my shell).
3. Open a pull request and merge it. The dry run cannot see a rotated secret, so run the **Server** workflow by hand with `force` and approve it.
4. Check in the run log that the secret's task prints nothing but `changed`, then revoke the old value at its source.

## Add a secret

Add the key to `secrets/production.sops.yaml`, read it in Ansible with the `community.sops.sops` lookup, and give the task that writes it `no_log: true`. If its value is used in a shell step of the workflow, register it with `::add-mask::` first, as the Server workflow does for the SMTP password.

## Rotate the Redis password

There is no provider to revoke it at: generate the new value with `openssl rand -hex 32` and set `REDIS_PASSWORD` as in "Change the value of a secret". The **Server** run with `force` rewrites the file and Ansible restarts Redis (the `Restart Redis` handler shows as `changed`); the rooms stay in its append-only file. Whatever else holds the old password (the semaphore stack, once it reads it, [ADR 0018](../adr/0018-redis-for-the-games-rooms.md)) must restart with the new one, and every game in progress ends: rotate when nobody is playing.

## Rotate the CI key (planned, no suspicion)

Do it in two merges so the CI can always decrypt:

1. `age-keygen -o /tmp/ci-new.key`. Keep the public key it prints, put the private file in the password manager, then delete it from `/tmp` (`rm -P`).
2. Add the new public key to `.sops.yaml` next to the old one. Run `sops updatekeys -y secrets/production.sops.yaml`, then merge.
3. Set the new private key as the `SOPS_AGE_KEY` secret of the `production` environment: `gh secret set SOPS_AGE_KEY --env production --repo Didelo-lilian/infra < /tmp/ci-new.key`. Run **Server** with `force` to prove it works.
4. Remove the old public key from `.sops.yaml`, run `sops updatekeys -y` then `sops rotate -i secrets/production.sops.yaml`, and merge.

The laptop key is rotated the same way, except there is no GitHub secret to replace: the new key goes in `~/Library/Application Support/sops/age/keys.txt` and the password manager.

## A private key leaked, or may have

The repository is public, so every version of the file ever committed is readable with that key. Rotating the key is not enough: the secrets themselves must change. Do it in this order, because changing the values first would hand the new ones to the leaked key:

1. Generate a new key (step 1 above). Replace the leaked public key in `.sops.yaml`.
2. `sops updatekeys -y secrets/production.sops.yaml`, then `sops rotate -i secrets/production.sops.yaml`.
3. If it is the CI key, replace the `SOPS_AGE_KEY` secret now. Until the pull request is merged and the secret replaced, deploys fail on decryption: they do not do anything unsafe.
4. Merge, then change **every** value in the file at its source and re-encrypt them (see "Change the value of a secret").
5. If the key was on a lost or stolen laptop, also review the bootstrap secrets below.

## A private key is lost

With one key left, nothing is lost: add a new recipient and re-encrypt as in the planned rotation. With both lost, the file cannot be read again. Every secret can be reissued at its source: create new values, create a new file with new keys (`sops` encrypts for the recipients in `.sops.yaml`), and set `SOPS_AGE_KEY`.

## Secrets that stay manual

They are needed before the pipeline can run, so they live only in GitHub (set with `gh secret set`) and in the provider that issued them:

| Secret | Where | Rotate by |
|---|---|---|
| `OVH_APPLICATION_KEY`, `OVH_APPLICATION_SECRET`, `OVH_CONSUMER_KEY` | `plan` and `production` | new OVH API credentials, same names |
| `TF_API_TOKEN` | `plan` and `production` | new HCP Terraform team token (it expires after a year) |
| `SSH_PRIVATE_KEY` | `plan` and `production` | new key, update `ansible/ci.pub`, run `make server-bootstrap` |
| `SOPS_AGE_KEY` | `production` | the planned rotation above |
| `RELEASE_APP_PRIVATE_KEY` | repository | new key on the GitHub App |

## Yearly review

When the HCP token expires, rotate the CI age key and check that both private keys are still in the password manager, with an offline copy of the CI one.
