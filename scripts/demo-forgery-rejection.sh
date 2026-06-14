#!/usr/bin/env bash
#
# demo-forgery-rejection.sh — the reproducible "try to cheat it" demo behind the
# README cast. A lazy agent skips the tests and hands the QA gate a
# perfect-looking, 100%-passing integration verdict it never actually ran; the
# runtime refuses it because no signed, runtime-recorded evidence backs the
# claim.
#
# Standalone-runnable (CI smoke): the gate's EXPECTED non-zero exit is the
# success condition — mirroring run_expect_failure in
# scripts/validate-wannabuild-dry-runs.sh. This script exits 0 only when the
# forgery is rejected with the expected message, non-zero otherwise.
#
#   WB_RUNTIME_BIN=path/to/wb-runtime scripts/demo-forgery-rejection.sh
#
# WB_EVIDENCE_MODE is deliberately scrubbed: fixture mode short-circuits evidence
# verification and would make the forgery PASS, destroying the demo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WB_RUNTIME_BIN="${WB_RUNTIME_BIN:-${REPO_ROOT}/target/debug/wb-runtime}"

if [ ! -x "${WB_RUNTIME_BIN}" ]; then
  echo "demo-forgery-rejection: wb-runtime binary not found or not executable:" >&2
  echo "  ${WB_RUNTIME_BIN}" >&2
  echo "Build it first:  cargo build -p wb-runtime" >&2
  echo "or point WB_RUNTIME_BIN at an installed wb-runtime." >&2
  exit 2
fi

DEMO="$(mktemp -d)"
DEMO="$(cd "${DEMO}" && pwd -P)"
# Isolate HOME so nothing touches the real ~/.wannabuild during the demo.
export HOME="${DEMO}"
cleanup() { rm -rf "${DEMO}"; }
trap cleanup EXIT

if [ -t 1 ]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  CYAN=$'\033[36m'
  RESET=$'\033[0m'
else
  BOLD=''
  DIM=''
  RED=''
  GREEN=''
  CYAN=''
  RESET=''
fi

beat() {
  if [ -t 1 ]; then sleep "${DEMO_BEAT:-0.7}"; fi
}
say() { printf '%s\n' "$*"; }
prompt() { printf '%s$ %s%s\n' "${CYAN}" "$*" "${RESET}"; }

cd "${DEMO}"

say "${BOLD}WannaBuild — your agent can't mark its own homework.${RESET}"
say "${DIM}Spec-driven builds with ship gates that are programs, not prose.${RESET}"
say ""
beat

prompt "wb-runtime init --project ."
env -u WB_EVIDENCE_MODE "${WB_RUNTIME_BIN}" init --project . >/dev/null
printf '{"integration_test_command":"true"}' >.wannabuild/config.json
mkdir -p .wannabuild/review .wannabuild/outputs
say "${DIM}initialized · at QA${RESET}"
say ""
beat

say "A lazy agent skips the tests and writes a perfect-looking verdict:"
prompt "cat > .wannabuild/review/wb-integration-tester-iter-1.json"
cat >.wannabuild/review/wb-integration-tester-iter-1.json <<'JSON'
{"agent":"wb-integration-tester","status":"PASS","hard_gate":true,"summary":"all green","issues":[],
 "test_execution":{"total":100,"passed":100,"failed":0,"errored":0,"duration_ms":5000},
 "coverage_map":[{"criterion":"login works","status":"covered"}]}
JSON
printf '# QA\n\nstatus: PASS\nacceptance: covered\nintegration: covered\n' >.wannabuild/outputs/qa-summary.md
say "${GREEN}  status: PASS · 100/100 passed · every criterion covered${RESET}"
say "${DIM}  …exactly what you'd get instead of a real test run.${RESET}"
say ""
beat

say "Now ask the gate to bless it:"
prompt "wb-runtime assert-qa-ready --project ."
set +e
output="$(env -u WB_EVIDENCE_MODE "${WB_RUNTIME_BIN}" assert-qa-ready --project . 2>&1)"
status=$?
set -e
# Trim the temp-dir prefix so the cast shows the project-relative path the README
# documents; the integrity check below still matches against the raw message.
say "${RED}${output//${DEMO}\//}${RESET}"
say ""
beat

if [ "${status}" -ne 0 ] && printf '%s' "${output}" | grep -q "no runtime-recorded execution evidence"; then
  say "${GREEN}✓ Forgery rejected.${RESET} The only path to green is the runtime running"
  say "  your tests itself and signing the result — a hand-written verdict can't pass."
  exit 0
fi

say "${RED}✗ Unexpected: the gate did not reject the forged verdict (exit ${status}).${RESET}"
exit 1
