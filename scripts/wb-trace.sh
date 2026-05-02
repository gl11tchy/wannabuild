#!/usr/bin/env bash
# wb-trace.sh — minimal OTLP-style span emitter for shell scripts.
#
# Usage (sourced):
#   source scripts/wb-trace.sh
#   sid=$(wb_trace_start "lint")
#   ... do work ...
#   wb_trace_end "$sid"     # or just `wb_trace_end` to pop the top span
#
# When `OTEL_EXPORTER_OTLP_ENDPOINT` is set, each ended span is POSTed to
# `${OTEL_EXPORTER_OTLP_ENDPOINT%/}/v1/traces` as a minimal valid OTLP/HTTP JSON
# payload (3s timeout, 1 retry, failures are warnings only).
#
# When the endpoint is not set, spans are emitted to stderr in a `# TRACE …`
# format that preserves nesting via `parent_span_id`.
#
# Self-test:
#   bash scripts/wb-trace.sh --self-test
# runs a parent span containing two child spans and verifies parent/child
# nesting in the emitted lines.

set -euo pipefail

# ---- minimal logging fallback ---------------------------------------------
__wb_trace_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${__wb_trace_dir}/wb-log.sh" ]]; then
  # shellcheck source=/dev/null
  source "${__wb_trace_dir}/wb-log.sh" || true
fi
if ! declare -F wb_log_warn >/dev/null 2>&1; then
  wb_log_warn() { printf '[warn] %s\n' "$*" >&2; }
fi

# ---- state ----------------------------------------------------------------
#
# Span state lives in two files in TMPDIR (or /tmp), keyed by PID, so that
# wb_trace_start can be called via command substitution `sid=$(wb_trace_start …)`
# without losing state across the subshell boundary.
#
#   stack file:  one span_id per line (last line = top of stack)
#   state file:  rows of "span_id|trace_id|parent_id|name|start_ns"

__WB_TRACE_TMPDIR="${TMPDIR:-/tmp}"
__WB_TRACE_STACK_FILE="${__WB_TRACE_TMPDIR%/}/wb-trace-stack-$$"
__WB_TRACE_STATE_FILE="${__WB_TRACE_TMPDIR%/}/wb-trace-state-$$"
__WB_TRACE_DISABLED=0
# Tolerate read-only / nonexistent TMPDIR: if we can't create the state files,
# disable tracing rather than failing under `set -euo pipefail`. Callers will
# still source us cleanly; wb_trace_start / wb_trace_end short-circuit.
if ! { : >"${__WB_TRACE_STACK_FILE}"; } 2>/dev/null \
   || ! { : >"${__WB_TRACE_STATE_FILE}"; } 2>/dev/null; then
  __WB_TRACE_DISABLED=1
  wb_log_warn "wb-trace: TMPDIR (${__WB_TRACE_TMPDIR}) not writable; tracing disabled"
else
  trap 'rm -f "${__WB_TRACE_STACK_FILE}" "${__WB_TRACE_STATE_FILE}"' EXIT
fi

__wb_trace_now_ns() {
  if date +%N >/dev/null 2>&1 && [[ "$(date +%N)" != "N" ]]; then
    local s ns
    s="$(date +%s)"
    ns="$(date +%N)"
    printf '%s%s\n' "${s}" "${ns}"
  else
    # Fallback for systems without %N (e.g., BSD date on macOS): seconds * 1e9.
    printf '%s000000000\n' "$(date +%s)"
  fi
}

__wb_trace_rand_hex() {
  # Generates N hex chars from /dev/urandom; portable across macOS and Linux.
  local n="$1"
  local bytes=$(( (n + 1) / 2 ))
  if command -v xxd >/dev/null 2>&1; then
    head -c "${bytes}" /dev/urandom | xxd -p -c 256 | head -c "${n}"
  elif command -v od >/dev/null 2>&1; then
    od -An -tx1 -N "${bytes}" /dev/urandom | tr -d ' \n' | head -c "${n}"
  else
    # Last-resort pseudo-random.
    awk -v n="${n}" 'BEGIN{srand(); s=""; while(length(s)<n){ s=s sprintf("%02x", int(rand()*256))}; print substr(s,1,n)}'
  fi
}

__wb_trace_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

__wb_trace_scrub() {
  # Pipe stdin through wb_log_scrub if available, otherwise pass through.
  if declare -F wb_log_scrub >/dev/null 2>&1; then
    wb_log_scrub
  else
    cat
  fi
}

__wb_trace_attrs_json() {
  # Stable attribute set for every span. The assembled JSON is piped through
  # wb_log_scrub so secrets that ended up in WB_RUN_ID, hostname, or script
  # paths are redacted before they reach the OTLP endpoint.
  local script="${BASH_SOURCE[1]:-${0}}"
  local hostname; hostname="$(hostname 2>/dev/null || printf 'unknown')"
  local run_id="${WB_RUN_ID:-}"
  printf '[{"key":"hostname","value":{"stringValue":"%s"}},{"key":"script","value":{"stringValue":"%s"}},{"key":"wb.run_id","value":{"stringValue":"%s"}}]' \
    "$(__wb_trace_json_escape "${hostname}")" \
    "$(__wb_trace_json_escape "${script}")" \
    "$(__wb_trace_json_escape "${run_id}")" \
    | __wb_trace_scrub
}

__wb_trace_post() {
  local payload="$1"
  if [[ -z "${OTEL_EXPORTER_OTLP_ENDPOINT:-}" ]]; then
    return 0
  fi
  if ! command -v curl >/dev/null 2>&1; then
    wb_log_warn "wb-trace: curl not available; skipping export"
    return 0
  fi
  local url="${OTEL_EXPORTER_OTLP_ENDPOINT%/}/v1/traces"
  local hdrs=(-H "Content-Type: application/json")
  if [[ -n "${OTEL_EXPORTER_OTLP_HEADERS:-}" ]]; then
    # Headers are formatted "k1=v1,k2=v2" per OTel convention.
    local IFS=','
    for h in ${OTEL_EXPORTER_OTLP_HEADERS}; do
      local k="${h%%=*}" v="${h#*=}"
      hdrs+=(-H "${k}: ${v}")
    done
  fi
  if ! curl -fsS -X POST --max-time 3 --retry 1 \
        "${hdrs[@]}" -d "${payload}" "${url}" \
        >/dev/null 2>&1; then
    wb_log_warn "wb-trace: OTLP export to ${url} failed (non-fatal)"
  fi
  return 0
}

# ---- public API -----------------------------------------------------------

wb_trace_start() {
  # wb_trace_start <span_name>  — echoes the new span_id.
  if [[ "${__WB_TRACE_DISABLED:-0}" -eq 1 ]]; then
    return 0
  fi
  local name="${1:-span}"
  local span_id; span_id="$(__wb_trace_rand_hex 16)"
  local trace_id parent_id=""
  if [[ -s "${__WB_TRACE_STACK_FILE}" ]]; then
    parent_id="$(tail -n 1 "${__WB_TRACE_STACK_FILE}")"
    trace_id="$(awk -F'|' -v sid="${parent_id}" '$1==sid {print $2; exit}' "${__WB_TRACE_STATE_FILE}")"
    if [[ -z "${trace_id}" ]]; then
      trace_id="$(__wb_trace_rand_hex 32)"
    fi
  else
    trace_id="$(__wb_trace_rand_hex 32)"
  fi
  local start_ns; start_ns="$(__wb_trace_now_ns)"
  printf '%s|%s|%s|%s|%s\n' "${span_id}" "${trace_id}" "${parent_id}" "${name}" "${start_ns}" \
    >>"${__WB_TRACE_STATE_FILE}"
  printf '%s\n' "${span_id}" >>"${__WB_TRACE_STACK_FILE}"
  printf '%s\n' "${span_id}"
}

wb_trace_end() {
  # wb_trace_end [<span_id>]  — pops the top span (or the named one).
  if [[ "${__WB_TRACE_DISABLED:-0}" -eq 1 ]]; then
    return 0
  fi
  local span_id="${1:-}"
  if [[ -z "${span_id}" ]]; then
    if [[ ! -s "${__WB_TRACE_STACK_FILE}" ]]; then
      wb_log_warn "wb-trace: end called with empty stack"
      return 0
    fi
    span_id="$(tail -n 1 "${__WB_TRACE_STACK_FILE}")"
  fi
  local row
  row="$(awk -F'|' -v sid="${span_id}" '$1==sid {print; exit}' "${__WB_TRACE_STATE_FILE}")"
  if [[ -z "${row}" ]]; then
    wb_log_warn "wb-trace: unknown span_id ${span_id}"
    return 0
  fi
  local trace_id parent_id name start_ns
  trace_id="$(printf '%s' "${row}" | awk -F'|' '{print $2}')"
  parent_id="$(printf '%s' "${row}" | awk -F'|' '{print $3}')"
  name="$(printf '%s' "${row}" | awk -F'|' '{print $4}')"
  start_ns="$(printf '%s' "${row}" | awk -F'|' '{print $5}')"
  local end_ns; end_ns="$(__wb_trace_now_ns)"

  # Remove span_id from stack and state files (in place).
  local tmp
  tmp="$(mktemp -t wb-trace.XXXXXX)"
  grep -v "^${span_id}\$" "${__WB_TRACE_STACK_FILE}" >"${tmp}" || true
  mv "${tmp}" "${__WB_TRACE_STACK_FILE}"
  tmp="$(mktemp -t wb-trace.XXXXXX)"
  grep -v "^${span_id}|" "${__WB_TRACE_STATE_FILE}" >"${tmp}" || true
  mv "${tmp}" "${__WB_TRACE_STATE_FILE}"

  # Stderr line for log preservation.
  printf '# TRACE service.name=%s trace_id=%s span_id=%s parent_span_id=%s name=%s start_time_unix_nano=%s end_time_unix_nano=%s\n' \
    "${OTEL_SERVICE_NAME:-wannabuild}" "${trace_id}" "${span_id}" "${parent_id}" "${name}" "${start_ns}" "${end_ns}" >&2

  # OTLP export. Both the attributes object and the final payload run through
  # wb_log_scrub so anything secret-looking in WB_RUN_ID, hostname, the script
  # path, or the span name is redacted before it leaves the host.
  local attrs; attrs="$(__wb_trace_attrs_json)"
  local payload
  payload="$(printf '{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"%s"}}]},"scopeSpans":[{"scope":{"name":"wb-trace.sh"},"spans":[{"traceId":"%s","spanId":"%s","parentSpanId":"%s","name":"%s","kind":1,"startTimeUnixNano":"%s","endTimeUnixNano":"%s","attributes":%s}]}]}]}' \
    "$(__wb_trace_json_escape "${OTEL_SERVICE_NAME:-wannabuild}")" \
    "${trace_id}" "${span_id}" "${parent_id}" \
    "$(__wb_trace_json_escape "${name}")" \
    "${start_ns}" "${end_ns}" \
    "${attrs}" \
    | __wb_trace_scrub)"
  __wb_trace_post "${payload}"
  return 0
}

# ---- self-test ------------------------------------------------------------

__wb_trace_self_test() {
  local tmp; tmp="$(mktemp -t wb-trace-selftest.XXXXXX)"
  # shellcheck disable=SC2064
  trap "rm -f '${tmp}' '${__WB_TRACE_STACK_FILE}' '${__WB_TRACE_STATE_FILE}'" EXIT

  local parent c1 c2
  {
    parent="$(wb_trace_start parent_op)"
    c1="$(wb_trace_start child_op_1)"
    wb_trace_end "$c1"
    c2="$(wb_trace_start child_op_2)"
    wb_trace_end "$c2"
    wb_trace_end "$parent"
  } 2>"$tmp"

  # Check that we got 3 TRACE lines.
  local count
  count="$(grep -c '^# TRACE ' "$tmp" || true)"
  if [[ "${count}" -ne 3 ]]; then
    printf 'self-test: expected 3 TRACE lines, got %s\n' "${count}" >&2
    cat "$tmp" >&2
    return 1
  fi

  # Children must reference parent's span_id as parent_span_id.
  if ! grep -q "span_id=${c1} parent_span_id=${parent} " "$tmp"; then
    printf 'self-test: child_op_1 nesting incorrect\n' >&2
    cat "$tmp" >&2
    return 1
  fi
  if ! grep -q "span_id=${c2} parent_span_id=${parent} " "$tmp"; then
    printf 'self-test: child_op_2 nesting incorrect\n' >&2
    cat "$tmp" >&2
    return 1
  fi
  # Parent has empty parent_span_id.
  if ! grep -q "span_id=${parent} parent_span_id= " "$tmp"; then
    printf 'self-test: parent_op should have empty parent_span_id\n' >&2
    cat "$tmp" >&2
    return 1
  fi

  printf 'OK\n'
  return 0
}

# ---- entrypoint -----------------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    --self-test) __wb_trace_self_test ;;
    -h|--help|"")
      sed -n '2,18p' "${BASH_SOURCE[0]}"
      ;;
    *)
      printf 'unknown arg: %s\n' "${1}" >&2
      exit 2
      ;;
  esac
fi
