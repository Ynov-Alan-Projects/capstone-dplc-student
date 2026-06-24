#!/usr/bin/env bash
# Hammer /api/compute to trigger CPU-based HPA scale-out. Requires `hey`.
# Usage: HOST=worldcup.<IP>.nip.io ./loadtest.sh
set -euo pipefail
HOST="${HOST:?set HOST=worldcup.<IP>.nip.io}"
SCHEME="${SCHEME:-https}"
hey -z 120s -c 50 "${SCHEME}://${HOST}/api/compute"
