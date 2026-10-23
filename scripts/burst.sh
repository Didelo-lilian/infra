#!/usr/bin/env bash
# Sends a burst of requests from this machine and counts the answers by status: past the rate limit, 429 shows up.
# Usage: scripts/burst.sh [url] [requests] [parallel]   (the limits are in stacks/traefik/dynamic/limits.yml)
set -euo pipefail
url=${1:-https://hello.didelo.fr/}
requests=${2:-300}
parallel=${3:-20}

seq "$requests" | xargs -P "$parallel" -I{} curl -s -o /dev/null -w '%{http_code}\n' "$url" | sort | uniq -c
