#!/usr/bin/env bash
# check-complexity.sh — enforce cyclomatic complexity budget on shell scripts.
#
# Thresholds (mirror .lizardrc):
#   CCN per function : 10
#   NLOC per function: 80
#   arguments        : 5

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

CCN_THRESHOLD=10
LENGTH_THRESHOLD=80
ARG_THRESHOLD=5

if ! command -v lizard >/dev/null 2>&1; then
  echo "lizard not installed; install with 'pipx install lizard' or 'pip install lizard'" >&2
  exit 127
fi

echo "==> lizard -l shell --CCN ${CCN_THRESHOLD} --length ${LENGTH_THRESHOLD} --arguments ${ARG_THRESHOLD} scripts/"
lizard \
  -l shell \
  --CCN "${CCN_THRESHOLD}" \
  --length "${LENGTH_THRESHOLD}" \
  --arguments "${ARG_THRESHOLD}" \
  scripts/
