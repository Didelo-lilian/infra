# Running athlete-panel

What runs and why is in [ADR 0023](../adr/0023-athlete-panel-behind-the-edge.md). The stack lives in `/srv/stacks/athlete-panel` on the server, behind Traefik at `https://athlete.didelo.fr`; the **Server** workflow deploys it, with the migrations before the app. Every command below runs on the server, from that folder, unless it says it runs on the laptop.

```bash
cd /srv/stacks/athlete-panel
```

## First start: set the owner password

The app has one owner and no way to sign up. Until the owner exists nothing can log in, and the password is **not** in this repository, in SOPS or in any log: it is chosen once, at a prompt, by the owner.

Pick a password of 12 to 256 characters and run:

```bash
sudo docker compose --profile tools run --rm --no-deps migrate sh -c '
  trap "stty echo" EXIT
  stty -echo
  printf "Owner password: "; read -r password; printf "\n"
  printf "%s" "$password" | sh /opt/athlete/env.sh admin pnpm run owner bootstrap --password-stdin'
```

The prompt shows nothing while you type. The password goes from the shell's variable to the standard input of the command: it is on no command line and in no environment. The command fails with `owner_exists` when an owner is already there, and changes nothing.

Forgot it? The same command with `recover` instead of `bootstrap` sets a new one. It also ends every session and revokes every grant of the agent API, so the agent has to be granted access again.

Then open `https://athlete.didelo.fr`, sign in, and connect Garmin in the app: its key is sent to the app and encrypted with `ENCRYPTION_KEY` there.

## Keep the two keys somewhere else

A backup cannot bring back `ENCRYPTION_KEY` (the Garmin key has to be entered again without it) and nothing opens the archives without the backup key. Put both in the password manager, from the laptop, in a checkout of `infra`, without printing them:

```bash
sops -d --extract '["ATHLETE_ENCRYPTION_KEY"]' secrets/production.sops.yaml | pbcopy
sops -d --extract '["ATHLETE_BACKUP_KEY"]' secrets/production.sops.yaml | pbcopy
```

Paste each into its own entry, then clear the clipboard. The backups sit on the server's own disk until [#94](https://github.com/Didelo-lilian/infra/issues/94) copies them away: these two keys and the SOPS file are what outlive the server.

## Is it healthy?

```bash
sudo docker compose ps
```

`db`, `web`, `worker`, `backup` and `caddy` read `healthy`. `worker` and `backup` failing here is **not** alerted yet ([#112](https://github.com/Didelo-lilian/infra/issues/112)), so look now and then. Prometheus does alert when the site's `/api/health` stops answering, and when fewer than five of the stack's containers run.

```bash
sudo docker compose logs --since 1h worker backup
```

## Backups

The `backup` service takes one when it starts and one a day at 03:00 UTC, keeps seven daily and four weekly, and is unhealthy once the newest is more than 26 hours old.

```bash
sudo ls -lt /var/backups/athlete-panel
```

To take one now (before an update, say), restart the service and wait for a new `.fgr`:

```bash
sudo docker compose restart backup
```

Check the newest archive restores, into a database that lives for the length of the run (the live one is never touched):

```bash
sudo docker compose --profile tools run --rm --no-deps restore-test
```

It prints the archive's name and `restore test passed`. Do it after the first backup, after each update of the app and now and then.

A restore **onto the live database** is not scripted: it replaces the data. Stop `web`, `worker` and `backup`, read `scripts/restore.ts` of the release that runs, and run the same restore as `restore-test.sh` with the live database as target and the app's `--confirm-replace`. The keys must be the ones the archive was made with.

## Update the app

Dependabot opens a pull request that bumps the tag **and** the digest of `ghcr.io/bidulelabs/athlete-panel` in `stacks/athlete-panel/compose.yaml`. An update runs migrations on the owner's data, so:

1. Read the release notes of the new version, and its migrations.
2. Take a backup (above) and check it restores with `restore-test`.
3. Merge, then approve the **Server** run. Ansible starts the database, runs the migration service on the new image, then recreates the app, the worker and the backup service. The old web app and worker serve until then, so a migration that is not backward compatible may fail a request or two.
4. `docker compose ps`, then the site, then `restore-test` again.

The database image (PostgreSQL 17) only takes minor and patch updates: a new major cannot read the old data directory, and Dependabot ignores it.

## Rotate a secret

Values are changed in `secrets/production.sops.yaml` as in [rotate-secrets](rotate-secrets.md): edit, pull request, merge, then run **Server** by hand **with `force`** and approve it, because the dry run cannot see a rotated secret. Generate the passwords with `openssl rand -hex 32` (hexadecimal only: the app requires it).

- **`ATHLETE_APP_DB_PASSWORD`** (the runtime role of the web app, the worker and the backups): nothing else to do. The migration service runs `ALTER ROLE` with the new value before the app restarts.
- **`ATHLETE_ADMIN_DB_PASSWORD`** (the administrator, used by the migrations and the restore test only): PostgreSQL keeps the old one until it is told otherwise, and the migration service would fail on it. Change it in the database **before** the `force` run, from the laptop, so that the value is on no command line:

  ```bash
  printf "ALTER ROLE athlete_panel PASSWORD '%s';\n" "$(sops -d --extract '["ATHLETE_ADMIN_DB_PASSWORD"]' secrets/production.sops.yaml)" |
    ssh didelo-vps 'cd /srv/stacks/athlete-panel && sudo docker compose exec -T db psql -q -U athlete_panel -d athlete_panel'
  ```

  The running app is not affected: it holds the runtime role's password, not this one.
- **`ATHLETE_ENCRYPTION_KEY`**: the app has no re-encryption, and a new key cannot read what the old one encrypted. Rotating it means entering the Garmin key again in the app. Do it only if the key leaked, and update the copy in the password manager.
- **`ATHLETE_BACKUP_KEY`**: archives made from then on use the new key; the older ones need the old key, which stays in the password manager until they have aged out (four weeks). `restore-test` takes the newest archive, so it keeps working.

## Things worth knowing

- **Visitors on IPv6 share one address** for the login limit, at the edge and in the app ([#113](https://github.com/Didelo-lilian/infra/issues/113)): a burst of failed logins from IPv6 locks every IPv6 visitor out for a while, the owner included. Waiting, or reaching the site over IPv4, is enough.
- **The first apply recreates Traefik** (the new `athlete-edge` network): every site is down for a few seconds.
- **A secret changed by hand on the server is overwritten** by the next **Server** run: the files in `secrets/` belong to Ansible.
