#!/usr/bin/env bash
# Runs the real scripts/deploy-app against a throwaway stack of two replicas behind a throwaway Traefik, with a local
# registry whose `main` tag moves like the real one (ADR 0019): a good image, an image that crashes, one that never
# gets healthy, one that crashes after the soak has begun, one whose second replica fails, and a single replica.
# 20 long-lived requests are open before each deploy and 20 more once the canary takes traffic: the survivors are the
# connections a deploy or a rollback did not cut. Needs Docker, curl and nothing else; takes a few minutes.
set -euo pipefail
cd "$(dirname "$0")/../.."

tmp=$(mktemp -d)
export DEPLOY_STACKS_DIR=$tmp/stacks STATE_DIR=$tmp/state REPLICAS=2 START_PERIOD=0s DEPLOY_HEALTH_TIMEOUT=15
mkdir -p "$DEPLOY_STACKS_DIR/ds" "$STATE_DIR"
chmod 777 "$STATE_DIR"
cp tests/deploy-app/compose.yaml "$DEPLOY_STACKS_DIR/ds/"
compose="docker compose -f $DEPLOY_STACKS_DIR/ds/compose.yaml"
traefik=$(docker compose -f stacks/traefik/compose.yaml config --images | grep '^traefik:')
failures=0

teardown() {
  pkill -f 'Host: deploytest.localhost' 2>/dev/null || true
  $compose down --volumes --remove-orphans >/dev/null 2>&1 || true
  docker rm -f deploytest-registry deploytest-traefik >/dev/null 2>&1 || true
  docker network rm deploytest-edge >/dev/null 2>&1 || true
}
cleanup() { teardown; rm -rf "$tmp"; }
trap cleanup EXIT
teardown

docker network create deploytest-edge >/dev/null
docker run -d --name deploytest-registry -p 127.0.0.1:5055:5000 registry:2 >/dev/null
docker run -d --name deploytest-traefik --network deploytest-edge -p 127.0.0.1:18080:80 \
  -v /var/run/docker.sock:/var/run/docker.sock "$traefik" --providers.docker=true \
  --providers.docker.exposedbydefault=false --providers.docker.network=deploytest-edge \
  --entrypoints.web.address=:80 >/dev/null

# Pushing moves the registry's tag, not the server's: the tag of this Docker, the server's, is put back where it was.
publish() { # mode version
  local kept
  kept=$(docker image inspect -f '{{.Id}}' localhost:5055/deploytest:main 2>/dev/null || true)
  docker build -q --build-arg "MODE=$1" --build-arg "VERSION=$2" -t localhost:5055/deploytest:main tests/deploy-app >/dev/null
  docker push -q localhost:5055/deploytest:main >/dev/null
  if [ -n "$kept" ]; then docker tag "$kept" localhost:5055/deploytest:main; else docker rmi localhost:5055/deploytest:main >/dev/null; fi
}
ids() { $compose ps -q ds | sort | tr '\n' ' '; }
version_of() { docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$1" | sed -n 's/^VERSION=//p'; }
served() { curl -fsS -m 2 -H 'Host: deploytest.localhost' http://127.0.0.1:18080/ 2>/dev/null || true; }
wait_served() {
  for _ in $(seq 60); do
    [ "$(served)" != "$1" ] || return 0
    sleep 0.5
  done
  echo "version $1 is not served through Traefik"
  exit 1
}
open_clients() { # prints the pids of 20 requests that stay open
  for _ in $(seq 20); do
    curl -sN -H 'Host: deploytest.localhost' http://127.0.0.1:18080/stream >/dev/null 2>&1 &
    echo -n "$! "
  done
}
alive() { local n=0 p; for p in $1; do ! kill -0 "$p" 2>/dev/null || n=$((n + 1)); done; echo "$n"; }
check() { # description, then a command that must succeed
  local description=$1
  shift
  if "$@"; then echo "  ok    $description"; else echo "  FAIL  $description"; failures=$((failures + 1)); fi
}

# scenario <name> <replicas> <mode of the new image> <soak> [wait for the canary: yes]
scenario() {
  local name=$1 replicas=$2 mode=$3 soak=$4 canary=${5:-}
  echo "== $name"
  $compose down --volumes --remove-orphans >/dev/null 2>&1 || true
  rm -f "$STATE_DIR"/*
  export REPLICAS=$replicas
  publish good 1
  $compose up -d --wait >/dev/null 2>&1
  wait_served 1
  # Traefik applies the changes it sees at most every two seconds: both replicas must be in before the connections.
  sleep 3
  before=$(ids)
  first=$(open_clients)
  sleep 1
  publish "$mode" 2
  local start=$SECONDS
  SSH_ORIGINAL_COMMAND="ds $soak" scripts/deploy-app >"$tmp/log" 2>&1 &
  local deploy=$!
  second=
  if [ -n "$canary" ]; then
    until grep -q watching "$tmp/log" || ! kill -0 "$deploy" 2>/dev/null; do sleep 0.2; done
    sleep 3
    second=$(open_clients)
    # The tag moves again while the soak runs: the replicas still to come must get the image the canary got.
    [ -z "${MOVE_TAG:-}" ] || publish good 3
  fi
  rc=0
  wait "$deploy" || rc=$?
  elapsed=$((SECONDS - start))
  sleep 2
  after=$(ids)
  sed 's/^/  | /' "$tmp/log"
  echo "  exit $rc after ${elapsed}s, version served: $(served), replicas: $(echo "$after" | wc -w | tr -d ' ')"
  echo "  connections still open: $(alive "$first")/20 of the first batch${second:+, $(alive "$second")/20 of the second}"
}

all_on() { local c; for c in $after; do [ "$(version_of "$c")" = "$1" ] || return 1; done; }
untouched() { [ "$after" = "$before" ]; }
kept_one() { local c; for c in $before; do case " $after " in *" $c "*) return 0 ;; esac; done; return 1; }
fast() { [ "$rc" = 0 ] && [ "$elapsed" -lt 20 ]; }

MOVE_TAG=1 scenario "good image, and the tag moves again during the soak" 2 good 8 canary
check "exits 0" [ "$rc" = 0 ]
check "two replicas, both on the image the canary got" all_on 2
check "the new version is served" [ "$(served)" = 2 ]

scenario "image that crashes" 2 crash 5
check "exits 1" [ "$rc" = 1 ]
check "the replicas are the same containers" untouched
check "the old version is served" [ "$(served)" = 1 ]
check "no connection was cut" [ "$(alive "$first")" = 20 ]

scenario "image that never gets healthy" 2 unhealthy 5
check "exits 1" [ "$rc" = 1 ]
check "the replicas are the same containers" untouched
check "no connection was cut" [ "$(alive "$first")" = 20 ]

START_PERIOD=60s DEPLOY_HEALTH_TIMEOUT=6 scenario "image still not healthy when the time is up" 2 unhealthy 5
check "exits 1 once the time is up" [ "$rc" = 1 ]
check "the replicas are the same containers" untouched
check "the old version is served" [ "$(served)" = 1 ]

scenario "image that crashes after the soak has begun" 2 late-crash 15 canary
check "exits 1" [ "$rc" = 1 ]
check "the replicas are the same containers" untouched
check "the old version is served" [ "$(served)" = 1 ]
check "no connection of the first batch was cut" [ "$(alive "$first")" = 20 ]

scenario "second replica fails after a good canary" 2 second-fails 8 canary
check "exits 1" [ "$rc" = 1 ]
check "two replicas, both on the old image" all_on 1
check "one of the old containers was never touched" kept_one
check "the old version is served" [ "$(served)" = 1 ]

scenario "one replica, good image" 1 good 30
check "exits 0 without waiting for a soak" fast
check "the new version is served" [ "$(served)" = 2 ]

scenario "one replica, image that crashes" 1 crash 30
check "exits 1" [ "$rc" = 1 ]
check "the replica is the same container" untouched
check "the connection was not cut" [ "$(alive "$first")" = 20 ]

echo "== arguments"
for bad in "" "nginx" "ds;id" "ds 1000" "ds -1" "ds 5 6" "../ds"; do
  rc=0
  SSH_ORIGINAL_COMMAND=$bad scripts/deploy-app >/dev/null 2>&1 || rc=$?
  check "refuses '$bad'" [ "$rc" = 1 ]
done

[ "$failures" = 0 ] || { echo "$failures check(s) failed"; exit 1; }
echo "all checks passed"
