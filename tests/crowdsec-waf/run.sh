#!/usr/bin/env bash
# Checks which methods the WAF of play.didelo.fr lets through (ADR 0013): the real CrowdSec stack (collections,
# acquisition, in-band CRS config) behind the real bouncer middleware of Traefik, with a stub in place of the game.
# First without the hook of crs-inband.yaml, to see the rule block PUT and DELETE, then with it. Then the requests of
# athlete.didelo.fr (ADR 0023): its app only uses GET and POST, so it has no exemption, and what it posts must pass.
# Needs Docker, curl and nothing else; takes about a minute.
set -euo pipefail
cd "$(dirname "$0")/../.."

tmp=$(mktemp -d)
compose="docker compose -p waftest -f $tmp/crowdsec/compose.yaml -f $tmp/crowdsec/override.yaml"
traefik=$(docker compose -f stacks/traefik/compose.yaml config --images | grep '^traefik:')
plugin=()
while IFS= read -r flag; do plugin+=("$flag"); done < <(sed -n 's/^ *- \(--experimental\.plugins\.bouncer\.[^ ]*\)$/\1/p' stacks/traefik/compose.yaml)
export ADM_GID=0 CONFIG_HASH=test
failures=0
reply=$(mktemp)

teardown() {
  rm -f "$reply"
  $compose down --volumes --remove-orphans >/dev/null 2>&1 || true
  docker rm -f waftraefik wafstub >/dev/null 2>&1 || true
  docker network rm waftest-crowdsec >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap teardown EXIT
teardown
mkdir -p "$tmp"

grep -q '^pre_eval:' stacks/crowdsec/appsec/crs-inband.yaml || { echo "FAIL crs-inband.yaml has no pre_eval hook" >&2; exit 1; }

# A copy, so that the bouncer key and the empty log directory it mounts stay out of the repository.
cp -R stacks/crowdsec "$tmp/crowdsec"
mkdir -p "$tmp/traefik/logs" "$tmp/dynamic"
touch "$tmp/traefik/logs/access.log"
key=$(openssl rand -hex 16)
echo "BOUNCER_KEY_test=$key" > "$tmp/crowdsec/bouncer.env"
printf '%s' "$key" > "$tmp/key"
cat > "$tmp/crowdsec/override.yaml" <<'YAML'
services:
  crowdsec:
    ports: !override []
networks:
  crowdsec:
    name: waftest-crowdsec
YAML
cp stacks/traefik/dynamic/crowdsec.yml tests/crowdsec-waf/routes.yml "$tmp/dynamic/"
# Without the hook (it is the last key of the file): what the CRS does on its own.
sed '/^pre_eval:/,$d' stacks/crowdsec/appsec/crs-inband.yaml > "$tmp/crowdsec/appsec/crs-inband.yaml"

docker network create waftest-crowdsec >/dev/null
$compose up -d --quiet-pull >/dev/null 2>&1
docker run -d --name wafstub --network waftest-crowdsec traefik/whoami:v1.11 >/dev/null
docker run -d --name waftraefik --network waftest-crowdsec -p 127.0.0.1:18083:80 \
  -v "$tmp/dynamic:/dynamic:ro" -v "$tmp/key:/run/secrets/crowdsec_bouncer_key:ro" "$traefik" \
  --global.checkNewVersion=false --entryPoints.web.address=:80 --providers.file.directory=/dynamic "${plugin[@]}" >/dev/null

# The status and whether the stub answered (whoami says its hostname).
call() { # method path [curl options...]
  local method=$1 path=$2
  shift 2
  curl -s -m 5 -o "$reply" -w '%{http_code}' --path-as-is -X "$method" -H "Host: ${host:-play.didelo.fr}" "$@" "http://127.0.0.1:18083$path"
}
expect() { # description, method, path, status [curl options...]
  local description=$1 status
  status=$(call "$2" "$3" "${@:5}")
  if [[ "$status" == "$4" ]] && { [[ "$4" != 200 ]] || grep -q '^Hostname:' "$reply"; }; then
    echo "ok   $description"
  else
    echo "FAIL $description: got $status, wanted $4"
    failures=$((failures + 1))
  fi
}
# AppSec fails open, so a 200 proves nothing until a request it must block is blocked.
wait_for_waf() {
  for _ in $(seq 120); do
    [[ "$(call GET /.env)" == 403 ]] && return
    sleep 1
  done
  echo "FAIL the WAF never blocked /.env" >&2
  docker logs waftest-crowdsec-1 2>&1 | tail -20 >&2
  exit 1
}

wait_for_waf
echo "-- without the hook"
expect "a GET passes" GET /api/me 200
expect "a POST passes" POST /api/me 200
expect "a PUT under /api/ is blocked by the CRS" PUT /api/me 403
expect "a DELETE under /api/ is blocked by the CRS" DELETE /api/auth/account 403

cp stacks/crowdsec/appsec/crs-inband.yaml "$tmp/crowdsec/appsec/crs-inband.yaml"
$compose restart crowdsec >/dev/null 2>&1
wait_for_waf
echo "-- with the hook"
expect "a PUT /api/me passes" PUT /api/me 200 -H 'Content-Type: application/json' -d '{"name":"ana"}'
expect "a pseudo with a quote passes" PUT /api/me 200 -H 'Content-Type: application/json' -d "{\"name\":\"O'Brien\"}"
expect "another PUT under /api/ passes" PUT /api/other 200
expect "a DELETE /api/me passes" DELETE /api/me 200
expect "a DELETE /api/auth/account passes" DELETE /api/auth/account 200
expect "a GET still passes" GET /api/me 200
expect "an OPTIONS still passes" OPTIONS /api/me 200

expect "a PATCH under /api/ stays blocked" PATCH /api/me 403
expect "a PUT on / stays blocked" PUT / 403
expect "a DELETE on / stays blocked" DELETE / 403
expect "a PUT on /ws stays blocked" PUT /ws 403
expect "a DELETE on /ws stays blocked" DELETE /ws 403
expect "a PUT on /api alone stays blocked" PUT /api 403
expect "a PUT on /apix stays blocked" PUT /apix 403
expect "a PUT out of /api/ stays blocked" PUT /api/../actuator/health 403
expect "an encoded PUT out of /api/ stays blocked" PUT '/api/%2e%2e/actuator/health' 403
host=other.didelo.fr expect "a PUT under /api/ on another host stays blocked" PUT /api/me 403

expect "a SQL injection in the query of a GET stays blocked" GET "/api/me?q=1'%20OR%20'1'='1" 403
expect "a SQL injection in the query of a PUT stays blocked" PUT "/api/me?q=1'%20OR%20'1'='1" 403
expect "a SQL injection in the body of a PUT stays blocked" PUT /api/me 403 -H 'Content-Type: application/json' -d "{\"name\":\"x' OR '1'='1\"}"
expect "a script in the body of a PUT stays blocked" PUT /api/me 403 -H 'Content-Type: application/json' -d '{"name":"<script>alert(1)</script>"}'
expect "a SQL injection in the query of a DELETE stays blocked" DELETE "/api/auth/account?id=1'%20OR%20'1'='1" 403
expect "an exposed file stays blocked" GET /.env 403

echo "-- athlete.didelo.fr: GET and POST only, no exemption"
export host=athlete.didelo.fr
json=(-H 'Content-Type: application/json')
expect "a page passes" GET /login 200
expect "the health check passes" GET /api/health 200
expect "the login passes" POST /api/auth/login 200 "${json[@]}" -d '{"password":"correct horse battery staple 9!"}'
expect "a Garmin key passes" POST /api/plugins/garmin/configure 200 "${json[@]}" \
  -d '{"key":"11111111-1111-4111-8111-111111111111","idempotencyKey":"22222222-2222-4222-8222-222222222222"}'
# Free text, as an athlete writes it: quotes, brackets, semicolons, comparison signs, slashes, SQL words.
expect "a workout with a title and notes passes" POST /api/plugins/training/mutate 200 "${json[@]}" -d '{"commands":[{"type":"workout.create","values":{"title":"Tempo 3 x 10'"'"' @ threshold (RPE 7) / 2'"'"' rest","notes":"Legs felt heavy; knee OK - did not skip the drills. Drop to Z2 if HR > 150 or pace < 5:00/km. Select a flat route, union with the club run on Sunday."}}]}'
expect "a note with double quotes and an ampersand passes" POST /api/plugins/training/mutate 200 "${json[@]}" -d '{"commands":[{"type":"workout.update","values":{"notes":"Coach said \"easy day\" & recovery; 6 x 100 m strides (walk back)."}}]}'
expect "a note with a script tag stays blocked" POST /api/plugins/training/mutate 403 "${json[@]}" -d '{"commands":[{"values":{"notes":"<script>alert(1)</script>"}}]}'
expect "a SQL injection in a note stays blocked" POST /api/plugins/training/mutate 403 "${json[@]}" -d '{"commands":[{"values":{"notes":"x'"'"' OR '"'"'1'"'"'='"'"'1"}}]}'
expect "a PUT stays blocked: the app does not use it" PUT /api/workspace 403
expect "a PATCH stays blocked: the app does not use it" PATCH /api/workspace 403
expect "a DELETE stays blocked: the app does not use it" DELETE /api/workspace 403
unset host

if [[ $failures -gt 0 ]]; then
  echo "$failures check(s) failed" >&2
  exit 1
fi
echo "all checks passed"
