#!/usr/bin/env bash
# Checks the athlete-panel stack as it is deployed (ADR 0023), on a throwaway Traefik with a fixed address like the real
# one. First the real stack with its real images (database, migrations, web app, worker, Caddy, backup): everything
# healthy, the client address the app sees, the cookie, no secret in `docker inspect`, a first backup that authenticates
# and a restore into a throwaway database. Then Caddy alone in front of a stub that echoes its headers: a client cannot
# choose the address Caddy tells the app, and the login is limited per address.
# Needs Docker, curl and openssl; pulls an 870 MB image; takes about three minutes (more under emulation on an ARM laptop).
set -euo pipefail
cd "$(dirname "$0")/../.."

export CONFIG_HASH=test SECRETS_HASH=test
tmp=$(mktemp -d)
export TEST_DIR=$tmp
base=stacks/athlete-panel/compose.yaml
traefik=$(docker compose -f stacks/traefik/compose.yaml config --images 2>/dev/null | grep '^traefik:')
subnet=$(sed -n 's/^[[:space:]]*- subnet: //p' stacks/traefik/compose.yaml)
traefik_ip=$(sed -n 's/^[[:space:]]*ipv4_address: //p' stacks/traefik/compose.yaml)
failures=0
reply=$(mktemp)

compose() { docker compose -p aptest -f "$base" "$@"; }
real() { compose -f tests/athlete-panel/real.yaml "$@"; }
stub() { compose -f tests/athlete-panel/stub.yaml "$@"; }

teardown() {
  rm -f "$reply"
  real --profile tools down --volumes --remove-orphans >/dev/null 2>&1 || true
  stub down --volumes --remove-orphans >/dev/null 2>&1 || true
  docker rm -f aptest-traefik aptest-client-12 aptest-client-13 >/dev/null 2>&1 || true
  docker network rm aptest-edge >/dev/null 2>&1 || true
  # The files belong to the user 10010: a container removes them.
  docker run --rm -v "$tmp:/t" alpine rm -rf /t/secrets /t/backups >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap teardown EXIT
teardown
mkdir -p "$tmp"

check() { # description, condition (0 = pass)
  if [[ "$2" == 0 ]]; then
    echo "ok   $1"
  else
    echo "FAIL $1"
    failures=$((failures + 1))
  fi
}
ok() { "$@" >/dev/null 2>&1 && echo 0 || echo 1; }

# Caddy trusts one address, Traefik's: the two files must say the same.
trusted=$(sed -n 's/^[[:space:]]*trusted_proxies static //p' stacks/athlete-panel/caddy/Caddyfile)
check "Caddy trusts the fixed address of Traefik and nothing else" "$([[ "$trusted" == "$traefik_ip/32" ]] && echo 0 || echo 1)"

# Secrets as Ansible writes them: owned by 10010, the backup key readable by its owner only.
mkdir -p "$tmp/secrets" "$tmp/backups"
app_password=$(openssl rand -hex 32)
admin_password=$(openssl rand -hex 32)
printf '%s' "$admin_password" > "$tmp/secrets/admin_db_password"
printf '%s' "$app_password" > "$tmp/secrets/app_db_password"
printf '%s' "$(openssl rand -base64 32)" > "$tmp/secrets/encryption_key"
printf '%s' "$(openssl rand -base64 32)" > "$tmp/secrets/backup_key"
docker run --rm -v "$tmp:/t" alpine sh -c 'chown -R 10010:10010 /t/secrets /t/backups &&
  chmod 440 /t/secrets/admin_db_password /t/secrets/app_db_password /t/secrets/encryption_key &&
  chmod 400 /t/secrets/backup_key && chmod 700 /t/backups'

docker pull -q curlimages/curl:8.11.1 >/dev/null
docker network create --subnet "$subnet" aptest-edge >/dev/null
docker run -d --name aptest-traefik --network aptest-edge --ip "$traefik_ip" -p 127.0.0.1:18090:80 \
  -v /var/run/docker.sock:/var/run/docker.sock "$traefik" --providers.docker=true \
  --providers.docker.exposedbydefault=false --providers.docker.network=aptest-edge \
  --entrypoints.web.address=:80 >/dev/null

# Two clients that live as long as the run, each with an address of its own: a `docker run --ip` right after the
# removal of the previous container with that address can fail on the address still being held.
for address in 172.30.45.12 172.30.45.13; do
  docker run -d --name "aptest-client-${address##*.}" --network aptest-edge --ip "$address" --entrypoint sleep \
    curlimages/curl:8.11.1 3600 >/dev/null
done
from() { # address, curl options...
  local address=$1
  shift
  docker exec "aptest-client-${address##*.}" curl -s -m 20 "$@"
}
# curl speaks plain HTTP when it is given no scheme: the test's own Docker network, nothing leaves the machine.
edge=$traefik_ip
host=(-H 'Host: athlete.didelo.fr')
# Traefik applies what it sees every two seconds at most, and routes to a container once it is healthy: five seconds of
# 200 in a row is the route of the container that runs now, not a stale one left by the container that just went.
routed() { # path
  local streak=0
  for _ in $(seq 120); do
    if [[ "$(from 172.30.45.12 -o /dev/null -w '%{http_code}' "${host[@]}" "$edge$1")" == 200 ]]; then streak=$((streak + 1)); else streak=0; fi
    [[ $streak -ge 5 ]] && return 0
    sleep 1
  done
  return 1
}
healthy() { # service, seconds
  for _ in $(seq "$2"); do
    [[ "$(docker inspect -f '{{.State.Health.Status}}' "$(real ps -q "$1")" 2>/dev/null)" == healthy ]] && return 0
    sleep 1
  done
  return 1
}

echo "-- the real stack"
real up -d --quiet-pull --wait db >/dev/null 2>&1
check "the migrations run as the user 10010, read-only, from the secret files" "$(ok real --profile tools run --rm --no-deps migrate)"
real up -d --quiet-pull web worker backup caddy >/dev/null 2>&1
for service in db web worker backup caddy; do
  check "$service is healthy" "$(ok healthy "$service" 300)"
done

routed /api/health || true
body=$(from 172.30.45.12 "${host[@]}" "$edge/api/health")
check "the health route answers through Traefik and Caddy" "$([[ "$body" == '{"status":"ready"}' ]] && echo 0 || echo 1)"

headers=$(from 172.30.45.12 -I "${host[@]}" "$edge/login" | tr -d '\r')
csp=$(sed -n 's/^[Cc]ontent-[Ss]ecurity-[Pp]olicy: //p' <<<"$headers")
check "the page carries the policy of the app" "$([[ "$csp" == *"script-src 'self' 'unsafe-inline'"* && "$csp" == *"frame-ancestors 'none'"* ]] && echo 0 || echo 1)"
check "the page does not say that Caddy served it" "$(grep -qi '^via:' <<<"$headers" && echo 1 || echo 0)"

# The owner of this throwaway database has a password of the test's own.
owner_password="Test-$(openssl rand -hex 12)-Aa1!"
check "the owner bootstraps from the standard input" \
  "$(printf '%s' "$owner_password" | ok real --profile tools run --rm --no-deps -T migrate sh /opt/athlete/env.sh admin pnpm run owner bootstrap --password-stdin)"

# The attempt counter of the app is keyed on the address it was told: here the sixth byte of the client's, whatever
# the client put in the two headers.
login() { # address password
  from "$1" -o /dev/null -D - -X POST "${host[@]}" -H 'Origin: https://athlete.didelo.fr' -H 'Content-Type: application/json' \
    -H 'X-Forwarded-For: 6.6.6.6' -H 'X-Athlete-Panel-Client-IP: 7.7.7.7' -d "{\"password\":\"$2\"}" "$edge/api/auth/login"
}
login 172.30.45.12 "not-the-password" > "$reply"
check "a wrong password is refused" "$(grep -q '^HTTP/1.1 401' "$reply" && echo 0 || echo 1)"
expected="client:$(printf '%s' 172.30.45.12 | openssl dgst -sha256 | sed 's/^.* //')"
seen=$(real exec -T db psql -U athlete_panel -d athlete_panel -At -c 'select key from host.login_attempts' | tr -d '\r')
check "the app counts the attempt on the real address of the client" "$([[ "$seen" == "$expected" ]] && echo 0 || echo 1)"
login 172.30.45.12 "$owner_password" | tr -d '\r' > "$reply"
check "the right password opens a session" "$(grep -q '^HTTP/1.1 200' "$reply" && echo 0 || echo 1)"
check "the session cookie is Secure and HttpOnly" "$(grep -i '^set-cookie:' "$reply" | grep -qi 'secure' && grep -i '^set-cookie:' "$reply" | grep -qi 'httponly' && echo 0 || echo 1)"

leaks=0
for service in db web worker backup caddy; do
  inspected=$(docker inspect "$(real ps -q "$service")")
  for secret in "$app_password" "$admin_password" "$owner_password"; do
    [[ "$inspected" != *"$secret"* ]] || leaks=$((leaks + 1))
  done
done
check "no password is in the output of docker inspect" "$([[ $leaks == 0 ]] && echo 0 || echo 1)"
check "the web app has no capability and a read-only file system" \
  "$([[ "$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}} {{.HostConfig.CapDrop}}' "$(real ps -q web)")" == 'true [ALL]' ]] && echo 0 || echo 1)"

# The directory belongs to the user 10010 and is 0700: from the host, only a container sees into it.
archives() { real exec -T backup find /backups -maxdepth 1 -name '*.fgr' | grep -q .; }
for _ in $(seq 120); do
  archives && break
  sleep 1
done
check "the first backup is written" "$(ok archives)"
restore=$(real --profile tools run --rm --no-deps -T restore-test 2>&1 || true)
check "the backup authenticates and restores into a throwaway database" "$([[ "$restore" == *"restore test passed"* ]] && echo 0 || echo 1)"
[[ "$restore" == *"restore test passed"* ]] || echo "$restore" | tail -15
check "the throwaway database is gone" \
  "$([[ "$(real exec -T db psql -U athlete_panel -d athlete_panel -At -c "select count(*) from pg_database where datname = 'restore_test'" | tr -d '\r')" == 0 ]] && echo 0 || echo 1)"

real --profile tools down --volumes --remove-orphans >/dev/null 2>&1

echo "-- Caddy and the edge in front of a stub"
stub up -d --wait --quiet-pull --no-deps web caddy >/dev/null 2>&1
routed / || true
caddy_ip=$(docker inspect -f '{{(index .NetworkSettings.Networks "aptest-edge").IPAddress}}' "$(stub ps -q caddy)")
check "Caddy has the fixed address of the compose file, next to Traefik's" \
  "$([[ "$caddy_ip" == "$(sed -n 's/^[[:space:]]*ipv4_address: //p' "$base")" ]] && echo 0 || echo 1)"
told() { tr '[:upper:]' '[:lower:]' | sed -n 's/^x-athlete-panel-client-ip: //p' | tr -d '\r'; } # what the stub received

told_through_edge=$(from 172.30.45.12 "${host[@]}" "$edge/" | told)
check "through Traefik the app is told the address of the client" "$([[ "$told_through_edge" == 172.30.45.12 ]] && echo 0 || echo 1)"
told_through_edge=$(from 172.30.45.12 "${host[@]}" -H 'X-Forwarded-For: 6.6.6.6, 8.8.8.8' -H 'X-Athlete-Panel-Client-IP: 7.7.7.7' "$edge/" | told)
check "a client cannot choose it with either header, through Traefik" "$([[ "$told_through_edge" == 172.30.45.12 ]] && echo 0 || echo 1)"
told_direct=$(from 172.30.45.13 -H 'X-Forwarded-For: 6.6.6.6' -H 'X-Athlete-Panel-Client-IP: 7.7.7.7' "$caddy_ip:8080/" | told)
check "a client that reaches Caddy without Traefik cannot choose it either" "$([[ "$told_direct" == 172.30.45.13 ]] && echo 0 || echo 1)"
other_told=$(from 172.30.45.13 "${host[@]}" "$edge/" | told)
check "another address is told its own" "$([[ "$other_told" == 172.30.45.13 ]] && echo 0 || echo 1)"

# The bucket of the login holds 10 (burst) and refills one every two minutes: the ones after the tenth get a 429.
statuses=$(docker exec aptest-client-12 sh -c '
  for _ in $(seq 16); do
    curl -s -m 20 -o /dev/null -w "%{http_code}\n" -X POST -H "Host: athlete.didelo.fr" -d "{\"password\":\"x\"}" "$0/api/auth/login"
  done' "$edge")
passed=$(grep -c '^200$' <<<"$statuses" || true)
refused=$(grep -c '^429$' <<<"$statuses" || true)
check "the login is refused with 429 once its burst is spent ($passed passed, $refused refused)" \
  "$([[ $passed -ge 9 && $passed -le 11 && $((passed + refused)) == 16 ]] && echo 0 || echo 1)"
check "the rest of the app is not limited by it" \
  "$([[ "$(from 172.30.45.12 -o /dev/null -w '%{http_code}' "${host[@]}" "$edge/api/health")" == 200 ]] && echo 0 || echo 1)"
check "another address has its own login bucket" \
  "$([[ "$(from 172.30.45.13 -o /dev/null -w '%{http_code}' -X POST "${host[@]}" -d '{"password":"x"}' "$edge/api/auth/login")" == 200 ]] && echo 0 || echo 1)"
big=$(head -c 5000 /dev/zero | tr '\0' x)
check "a login body over 4 KiB is refused" \
  "$([[ "$(from 172.30.45.13 -o /dev/null -w '%{http_code}' -X POST "${host[@]}" -d "{\"password\":\"$big\"}" "$edge/api/auth/login")" == 413 ]] && echo 0 || echo 1)"

if [[ $failures -gt 0 ]]; then
  echo "-- what was running, and what the edge answers" >&2
  docker ps -a --filter name=aptest --format '{{.Names}} {{.Status}}' >&2
  docker logs --tail 20 aptest-traefik >&2 2>&1 || true
  from 172.30.45.12 -i "${host[@]}" "$edge/" 2>&1 | head -15 >&2 || true
  echo "$failures check(s) failed" >&2
  exit 1
fi
echo "all checks passed"
