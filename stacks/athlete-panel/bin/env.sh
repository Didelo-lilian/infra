#!/bin/sh
# Builds the environment of the app from its secret files, then runs the command: no password or key is in the Compose
# file, in `docker inspect` or on a command line (the same idea as the Redis password in stacks/redis).
# Usage: env.sh runtime|admin command...   `runtime` is the role that owns the data, `admin` the one that migrates.
set -eu
secrets=/run/secrets
mode=$1
shift
ENCRYPTION_KEY=$(cat "$secrets/encryption_key")
export ENCRYPTION_KEY
case $mode in
  runtime)
    DATABASE_URL="postgresql://athlete_panel_app:$(cat "$secrets/app_db_password")@db:5432/athlete_panel"
    ;;
  admin)
    DATABASE_URL="postgresql://athlete_panel:$(cat "$secrets/admin_db_password")@db:5432/athlete_panel"
    APP_DATABASE_PASSWORD=$(cat "$secrets/app_db_password")
    APP_DATABASE_ROLE=athlete_panel_app
    export APP_DATABASE_PASSWORD APP_DATABASE_ROLE
    ;;
  *)
    echo "usage: env.sh runtime|admin command..." >&2
    exit 1
    ;;
esac
export DATABASE_URL
exec "$@"
