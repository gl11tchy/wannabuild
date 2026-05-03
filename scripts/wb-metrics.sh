#!/usr/bin/env bash
# wb-metrics.sh — structured metric emission for WannaBuild scripts and CI.
#
# Emits metrics in a `key=value` format prefixed with `# METRIC ` to stderr so
# they're easy to grep out of CI logs. When `$WB_METRICS_ENDPOINT` is set, also
# POSTs the metric as JSON to that endpoint.
#
# Usage (sourced):
#   source scripts/wb-metrics.sh
#   wb_metric_counter cache_hit 1
#   wb_metric_gauge   queue_depth 42
#   wb_metric_timing  job_duration_ms 1523
#   wb_metric_event   ci_job_complete name=lint duration_ms=4321 result=success
#
# Self-test:
#   bash scripts/wb-metrics.sh --self-test
#
# Failures to POST never fail the script — they emit a warning via wb_log_warn
# (or a fallback message) and continue.

set -euo pipefail

# ---- minimal logging fallback ---------------------------------------------
# Prefer scripts/wb-log.sh (created by Batch E). Fall back to stderr echoes if
# it isn't available (e.g., during self-test in isolation).
__wb_metrics_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${__wb_metrics_dir}/wb-log.sh" ]]; then
  # shellcheck source=/dev/null
  source "${__wb_metrics_dir}/wb-log.sh" || true
fi
if ! declare -F wb_log_warn >/dev/null 2>&1; then
  wb_log_warn() { printf '[warn] %s\n' "$*" >&2; }
fi
if ! declare -F wb_log_info >/dev/null 2>&1; then
  wb_log_info() { printf '[info] %s\n' "$*" >&2; }
fi

# ---- helpers --------------------------------------------------------------

__wb_metrics_now_ms() {
  # Portable millisecond timestamp.
  if date +%N >/dev/null 2>&1 && [[ "$(date +%N)" != "N" ]]; then
    local s ns
    s="$(date +%s)"
    ns="$(date +%N)"
    # ns may have leading zeros — strip with 10# prefix.
    printf '%s\n' "$((s * 1000 + 10#${ns:0:9} / 1000000))"
  else
    # macOS (BSD date) lacks %N; fall back to seconds * 1000.
    printf '%s000\n' "$(date +%s)"
  fi
}

__wb_metrics_json_escape() {
  # Minimal JSON string escape for the limited set of chars we emit.
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

__wb_metrics_post() {
  local payload="$1"
  if [[ -z "${WB_METRICS_ENDPOINT:-}" ]]; then
    return 0
  fi
  if ! command -v curl >/dev/null 2>&1; then
    wb_log_warn "wb-metrics: curl not available; skipping POST"
    return 0
  fi
  local hdrs=(-H "Content-Type: application/json")
  if [[ -n "${WB_METRICS_TOKEN:-}" ]]; then
    hdrs+=(-H "Authorization: Bearer ${WB_METRICS_TOKEN}")
  fi
  # 3s timeout, 1 retry on failure.
  if ! curl -fsS -X POST --max-time 3 --retry 1 \
    "${hdrs[@]}" -d "$payload" "${WB_METRICS_ENDPOINT}" \
    >/dev/null 2>&1; then
    wb_log_warn "wb-metrics: POST to ${WB_METRICS_ENDPOINT} failed (non-fatal)"
  fi
  return 0
}

__wb_metrics_emit() {
  local kind="$1"
  shift
  local name="$1"
  shift
  local ts
  ts="$(__wb_metrics_now_ms)"
  # KV stderr line for log post-processors.
  local kv_line="# METRIC kind=${kind} name=${name} ts_ms=${ts}"
  local json_attrs=""
  local arg
  for arg in "$@"; do
    kv_line+=" ${arg}"
    local k="${arg%%=*}" v="${arg#*=}"
    json_attrs+=",\"$(__wb_metrics_json_escape "$k")\":\"$(__wb_metrics_json_escape "$v")\""
  done
  printf '%s\n' "${kv_line}" >&2
  local json
  json="{\"kind\":\"${kind}\",\"name\":\"$(__wb_metrics_json_escape "$name")\",\"ts_ms\":${ts}${json_attrs}}"
  __wb_metrics_post "${json}"
}

# ---- public API -----------------------------------------------------------

wb_metric_counter() {
  # wb_metric_counter <name> <value>
  local name="$1" value="${2:-1}"
  __wb_metrics_emit counter "${name}" "value=${value}"
}

wb_metric_gauge() {
  # wb_metric_gauge <name> <value>
  local name="$1" value="$2"
  __wb_metrics_emit gauge "${name}" "value=${value}"
}

wb_metric_timing() {
  # wb_metric_timing <name> <ms>
  local name="$1" ms="$2"
  __wb_metrics_emit timing "${name}" "ms=${ms}"
}

wb_metric_event() {
  # wb_metric_event <name> <key=value...>
  local name="$1"
  shift
  __wb_metrics_emit event "${name}" "$@"
}

# ---- self-test ------------------------------------------------------------

__wb_metrics_self_test() {
  local errors=0
  # Capture stderr of each call into a tmp file.
  local tmp
  tmp="$(mktemp -t wb-metrics-selftest.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -f '${tmp}'" EXIT

  {
    wb_metric_counter selftest_counter 1
    wb_metric_gauge selftest_gauge 17
    wb_metric_timing selftest_timing_ms 250
    wb_metric_event selftest_event foo=bar baz=qux
  } 2>"$tmp"

  # Use regex needles that allow `ts_ms=N` between the name and the value attrs.
  local needle
  for needle in \
    'kind=counter name=selftest_counter .*value=1' \
    'kind=gauge name=selftest_gauge .*value=17' \
    'kind=timing name=selftest_timing_ms .*ms=250' \
    'kind=event name=selftest_event .*foo=bar baz=qux'; do
    if ! grep -Eq "${needle}" "$tmp"; then
      printf 'self-test: missing line matching: %s\n' "${needle}" >&2
      errors=$((errors + 1))
    fi
  done

  if [[ ${errors} -ne 0 ]]; then
    printf '\n--- captured output ---\n' >&2
    cat "$tmp" >&2
    printf 'wb-metrics self-test FAILED with %d errors\n' "${errors}" >&2
    return 1
  fi

  printf 'OK\n'
  return 0
}

# ---- entrypoint -----------------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    --self-test) __wb_metrics_self_test ;;
    -h | --help | "")
      sed -n '2,18p' "${BASH_SOURCE[0]}"
      ;;
    *)
      printf 'unknown arg: %s\n' "${1}" >&2
      exit 2
      ;;
  esac
fi
