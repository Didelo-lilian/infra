#!/bin/sh
# Restores the newest backup into a database that exists for the length of the run, checks what came back, then drops
# it. The live database is never touched. Run it through the `restore-test` service (docs/runbooks/athlete-panel.md).
set -eu
db=restore_test
# shellcheck disable=SC2012 # the app names the archives itself: letters, digits, dashes, dots
archive=$(ls -1t /backups/*.fgr | head -n 1)
[ -n "$archive" ] || { echo "no backup in /backups" >&2; exit 1; }

# The URL of the admin role names the live database; the same one with another name is the throwaway.
admin=$DATABASE_URL
scratch=${admin%/*}/$db
cleanup() { psql --no-psqlrc -q "$admin" -c "DROP DATABASE IF EXISTS $db" >/dev/null; rm -rf /tmp/restored; }
trap cleanup EXIT
psql --no-psqlrc -q "$admin" -c "DROP DATABASE IF EXISTS $db" -c "CREATE DATABASE $db"

echo "archive: $(basename "$archive")"
pnpm exec tsx scripts/verify-backup.ts "$archive"
ADMIN_DATABASE_URL=$scratch pnpm exec tsx scripts/restore.ts "$archive" --confirm-replace --source-dir /tmp/restored
tables=$(psql --no-psqlrc -At "$scratch" -c "select count(*) from information_schema.tables where table_schema = 'host'")
migrations=$(psql --no-psqlrc -At "$scratch" -c "select count(*) from host.migrations")
echo "restored: $tables tables in schema host, $migrations migrations recorded"
[ "$tables" -gt 0 ] && [ "$migrations" -gt 0 ]
echo "restore test passed"
