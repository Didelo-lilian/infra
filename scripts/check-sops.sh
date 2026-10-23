#!/usr/bin/env bash
# Fails if anything in secrets/ is not a SOPS-encrypted YAML: the repository is public, so a plaintext value would leak for good.
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -d secrets ]] || exit 0
status=0
while IFS= read -r file; do
  case "$file" in
    secrets/*.sops.yaml) ;;
    *) echo "secrets/: only *.sops.yaml files are allowed: $file"; status=1; continue ;;
  esac
  grep -q '^sops:' "$file" && grep -q '^    mac: ENC\[' "$file" || { echo "$file: missing SOPS metadata, is it encrypted?"; status=1; continue; }
  # Every value above the metadata must be an ENC[...] blob.
  awk -v f="$file" '/^sops:/ { exit } /(: +|^ *- +)[^ #]/ && !/ENC\[/ { print f ":" FNR ": value is not encrypted"; bad = 1 } END { exit bad }' "$file" || status=1
done < <(find secrets -type f | sort)
exit "$status"
