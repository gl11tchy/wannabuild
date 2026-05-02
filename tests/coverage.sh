#!/usr/bin/env bash
# tests/coverage.sh — collect line coverage for shell scripts using kcov.
#
# Behavior:
#   * If kcov is not on PATH, prints install instructions and exits 0 with a
#     "skipped" message so CI can be conditional.
#   * If kcov is present, runs the full suite under kcov, parses the summary,
#     and enforces COVERAGE_THRESHOLD (default 60) on line coverage.
#       - >= threshold: prints PASS, exits 0.
#       - <  threshold: prints FAIL with the percentage, exits 1.
#
# Environment:
#   COVERAGE_THRESHOLD   Minimum line-coverage percent (default 60).
#   COVERAGE_OUT         Output directory (default tests/coverage-out).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="${REPO_ROOT}/tests"
THRESHOLD="${COVERAGE_THRESHOLD:-60}"
OUT_DIR="${COVERAGE_OUT:-${TESTS_DIR}/coverage-out}"

if ! command -v kcov >/dev/null 2>&1; then
  cat <<'MSG'
kcov is not installed; coverage collection skipped.

To install kcov:
  macOS:    brew install kcov
  Debian:   sudo apt-get install kcov
  From src: https://github.com/SimonKagstrom/kcov

Re-run `bash tests/coverage.sh` once kcov is on PATH.
MSG
  exit 0
fi

mkdir -p "$OUT_DIR"
echo "Running test suite under kcov..."
kcov --include-pattern="${REPO_ROOT}/scripts/" \
     --exclude-pattern="${REPO_ROOT}/tests/" \
     "$OUT_DIR" \
     bash "${TESTS_DIR}/run.sh"

# kcov emits coverage.json in the output directory's index dir.
SUMMARY="$(find "$OUT_DIR" -name 'coverage.json' -type f -print -quit || true)"
if [[ -z "$SUMMARY" ]]; then
  echo "FAIL: kcov ran but produced no coverage.json"
  exit 1
fi

PCT="$(python3 - "$SUMMARY" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
# kcov coverage.json shape: {"percent_covered": "62.5", ...}
val = d.get("percent_covered") or d.get("percentage") or "0"
try:
    print(float(str(val).strip().rstrip("%")))
except Exception:
    print(0.0)
PY
)"

echo "Line coverage: ${PCT}%  (threshold: ${THRESHOLD}%)"

# Compare via python to avoid bc dependency.
python3 -c "import sys; sys.exit(0 if float('${PCT}') >= float('${THRESHOLD}') else 1)" \
  && { echo "PASS: coverage at or above threshold"; exit 0; } \
  || { echo "FAIL: coverage ${PCT}% below threshold ${THRESHOLD}%"; exit 1; }
