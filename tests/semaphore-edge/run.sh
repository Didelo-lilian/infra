#!/usr/bin/env bash
# Checks what Traefik sends where on play.didelo.fr (ADR 0022): the real labels of stacks/semaphore/compose.yaml on a
# throwaway Traefik, with stubs that say their name in place of the backend and the front. /ws and /api/ go to the
# backend, PUT /api/me is limited and capped, everything else, path tricks included, stays with the front.
# Needs Docker, curl and nothing else; takes about a minute.
set -euo pipefail
cd "$(dirname "$0")/../.."

export PASSWORD_HASH=test
compose="docker compose -p edgetest -f stacks/semaphore/compose.yaml -f tests/semaphore-edge/compose.yaml"
traefik=$(docker compose -f stacks/traefik/compose.yaml config --images | grep '^traefik:')
failures=0
reply=$(mktemp)

teardown() {
  rm -f "$reply"
  $compose down --remove-orphans >/dev/null 2>&1 || true
  docker rm -f edgetest-traefik >/dev/null 2>&1 || true
  docker network rm edgetest-edge >/dev/null 2>&1 || true
}
trap teardown EXIT
teardown

docker pull -q curlimages/curl:8.11.1 >/dev/null
docker network create edgetest-edge >/dev/null
docker run -d --name edgetest-traefik --network edgetest-edge -p 127.0.0.1:18082:80 \
  -v /var/run/docker.sock:/var/run/docker.sock "$traefik" --providers.docker=true \
  --providers.docker.exposedbydefault=false --providers.docker.network=edgetest-edge \
  --entrypoints.web.address=:80 >/dev/null
$compose up -d --quiet-pull >/dev/null 2>&1

# The status and, for the stubs, which of them answered (whoami says its hostname as text, and as JSON on /api).
call() { # method path [curl options...]
  local method=$1 path=$2
  shift 2
  curl -s -m 5 -o "$reply" -w '%{http_code}' --path-as-is -X "$method" -H 'Host: play.didelo.fr' "$@" "http://127.0.0.1:18082$path"
}
who() { sed -nE 's/^Hostname: (.*)$/\1/p; s/.*"hostname":"([^"]*)".*/\1/p' "$reply"; }
expect() { # description, method, path, status, who [curl options...]
  local description=$1 status
  status=$(call "$2" "$3" "${@:6}")
  if [[ "$status" == "$4" && ( -z "$5" || "$(who)" == "$5" ) ]]; then
    echo "ok   $description"
  else
    echo "FAIL $description: got $status $(who), wanted $4 ${5:-}"
    failures=$((failures + 1))
  fi
}

for _ in $(seq 60); do
  [[ "$(call GET /api/me)" == 200 && "$(call GET /)" == 200 ]] && break
  sleep 0.5
done

expect "the front serves the page" GET / 200 front
expect "the backend serves /api/me" GET /api/me 200 backend
expect "the backend serves what is under /api/" GET /api/auth/github 200 backend
expect "the backend serves /ws" GET /ws 200 backend
expect "/api alone stays with the front" GET /api 200 front
expect "/apix stays with the front" GET /apix 200 front
expect "the actuator stays unreachable" GET /actuator/health 200 front
expect "a path out of /api/ stays with the front" GET /api/../actuator/health 200 front
expect "an encoded path out of /api/ stays with the front" GET '/api/%2e%2e/actuator/health' 200 front
expect "/ws/x stays with the front" GET /ws/x 200 front
expect "DELETE /api/me is not limited" DELETE /api/me 200 backend
expect "another PUT under /api is not limited" PUT /api/other 200 backend

body='{"name":"ana"}'
big="{\"name\":\"$(head -c 2000 /dev/zero | tr '\0' x)\"}"
expect "a PUT /api/me of a pseudo reaches the backend" PUT /api/me 200 backend -d "$body"
expect "a PUT /api/me over 1 KiB is refused" PUT /api/me 413 "" -d "$big"

# The bucket holds 30 (burst), the two PUTs above took 2, and it refills one a minute: 28 more go through, then 429.
sent=0
while [[ "$(call PUT /api/me -d "$body")" == 200 ]]; do sent=$((sent + 1)); [[ $sent -lt 60 ]] || break; done
if [[ $sent -ge 27 && $sent -le 29 ]]; then
  echo "ok   PUT /api/me is refused with 429 once the burst is spent ($((sent + 2)) went through)"
else
  echo "FAIL PUT /api/me: $sent more went through after the first two, wanted about 28 and then 429"
  failures=$((failures + 1))
fi
expect "GET /api/me is not limited by it" GET /api/me 200 backend
# Another source address, another bucket: the limit counts per client IP, not per host.
other=$(docker run --rm --network edgetest-edge curlimages/curl:8.11.1 -s -o /dev/null -w '%{http_code}' -X PUT \
  -H 'Host: play.didelo.fr' -d "$body" http://edgetest-traefik/api/me)
if [[ "$other" == 200 ]]; then
  echo "ok   another address has its own bucket"
else
  echo "FAIL another address got $other, wanted 200"
  failures=$((failures + 1))
fi

if [[ $failures -gt 0 ]]; then
  echo "$failures check(s) failed" >&2
  exit 1
fi
echo "all checks passed"
