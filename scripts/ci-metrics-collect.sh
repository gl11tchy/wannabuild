#!/usr/bin/env bash
# ci-metrics-collect.sh — emit a single CI job-completion event.
#
# Designed to be the LAST step (or an `if: always()` step) of every CI job.
# The workflow is responsible for setting:
#   JOB_START_EPOCH_MS   start time in milliseconds (from a step earlier in the job)
#   JOB_STATUS           success | failure | cancelled | skipped
#
# Standard GitHub Actions vars used:
#   GITHUB_JOB, GITHUB_RUN_ID, GITHUB_REPOSITORY, GITHUB_REF, GITHUB_SHA, GITHUB_WORKFLOW
#
# Always exits 0 — CI must never fail because metrics emission failed.

set -uo pipefail

__here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${__here}/wb-metrics.sh" || true

now_ms() {
  if date +%N >/dev/null 2>&1 && [[ "$(date +%N)" != "N" ]]; then
    local s ns
    s="$(date +%s)"
    ns="$(date +%N)"
    printf '%s\n' "$(( s * 1000 + 10#${ns:0:9} / 1000000 ))"
  else
    printf '%s000\n' "$(date +%s)"
  fi
}

job="${GITHUB_JOB:-unknown}"
run_id="${GITHUB_RUN_ID:-0}"
repo="${GITHUB_REPOSITORY:-unknown}"
ref="${GITHUB_REF:-unknown}"
sha="${GITHUB_SHA:-unknown}"
workflow="${GITHUB_WORKFLOW:-unknown}"
result="${JOB_STATUS:-unknown}"

end_ms="$(now_ms)"
start_ms="${JOB_START_EPOCH_MS:-${end_ms}}"
duration_ms=$(( end_ms - start_ms ))
if [[ ${duration_ms} -lt 0 ]]; then duration_ms=0; fi

if declare -F wb_metric_event >/dev/null 2>&1; then
  wb_metric_event ci_job_complete \
    "name=${job}" \
    "workflow=${workflow}" \
    "run_id=${run_id}" \
    "repo=${repo}" \
    "ref=${ref}" \
    "sha=${sha}" \
    "result=${result}" \
    "duration_ms=${duration_ms}" \
    || true
else
  # Fallback if wb-metrics.sh failed to source.
  printf '# METRIC kind=event name=ci_job_complete name=%s workflow=%s run_id=%s repo=%s ref=%s sha=%s result=%s duration_ms=%s\n' \
    "${job}" "${workflow}" "${run_id}" "${repo}" "${ref}" "${sha}" "${result}" "${duration_ms}" >&2
fi

exit 0
