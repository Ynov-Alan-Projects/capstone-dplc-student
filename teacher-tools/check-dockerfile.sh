#!/usr/bin/env bash
# check-dockerfile.sh — scores a Dockerfile against 5 containerization best practices.
# Contract (from app/tests/dockerfile-check.property.test.js):
#   1. last FROM image is a pinned slim/alpine tag (node:<N>-(alpine|slim)), not node:latest
#   2. a non-root USER instruction is present
#   3. multi-stage build (>= 2 FROM instructions)
#   4. a .dockerignore exists alongside the Dockerfile
#   5. optimal layer order: first `COPY *package*` < first `RUN npm install|npm ci` < last `COPY . .`
# Usage: check-dockerfile.sh <path-to-Dockerfile>
# Output: "<score>/5 checks passed". Exit 0 iff 5/5.
set -uo pipefail

DOCKERFILE="${1:?usage: check-dockerfile.sh <Dockerfile>}"
DIR="$(cd "$(dirname "$DOCKERFILE")" && pwd)"
score=0

# Check 1: last FROM uses a pinned slim/alpine image (not node:latest)
last_from_image="$(grep -iE '^FROM ' "$DOCKERFILE" | tail -n1 | awk '{print $2}')"
if [[ "$last_from_image" != "node:latest" ]] && [[ "$last_from_image" =~ node:[0-9]+.*-(alpine|slim) ]]; then
  score=$((score + 1))
fi

# Check 2: a non-root USER instruction is present
user_name="$(grep -iE '^USER ' "$DOCKERFILE" | tail -n1 | awk '{print $2}')"
if [[ -n "$user_name" && "$user_name" != "root" && "$user_name" != "0" ]]; then
  score=$((score + 1))
fi

# Check 3: multi-stage build (>= 2 FROM)
from_count="$(grep -icE '^FROM ' "$DOCKERFILE")"
if [[ "$from_count" -ge 2 ]]; then
  score=$((score + 1))
fi

# Check 4: .dockerignore alongside the Dockerfile
if [[ -f "$DIR/.dockerignore" ]]; then
  score=$((score + 1))
fi

# Check 5: optimal layer order (global, across all stages)
copy_pkg_line="$(grep -nE 'COPY .*package' "$DOCKERFILE" | head -n1 | cut -d: -f1)"
run_npm_line="$(grep -nE 'RUN .*(npm install|npm ci)' "$DOCKERFILE" | head -n1 | cut -d: -f1)"
copy_all_line="$(grep -nE '^COPY \. \.' "$DOCKERFILE" | tail -n1 | cut -d: -f1)"
if [[ -n "$copy_pkg_line" && -n "$run_npm_line" && -n "$copy_all_line" ]] \
   && (( copy_pkg_line < run_npm_line )) && (( run_npm_line < copy_all_line )); then
  score=$((score + 1))
fi

echo "${score}/5 checks passed"
[[ "$score" -eq 5 ]] && exit 0 || exit 1
