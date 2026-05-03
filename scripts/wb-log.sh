#!/usr/bin/env bash
# wb-log.sh — WannaBuild structured logging library with built-in secret scrubbing.
#
# Usage (sourced):
#   . "$(dirname -- "${BASH_SOURCE[0]}")/wb-log.sh"
#   wb_log_info  "starting phase $phase"
#   wb_log_warn  "config missing: $key"
#   wb_log_error "validator failed for $artifact"
#   wb_log_debug "internal state: $blob"
#
# Environment variables:
#   WB_LOG_LEVEL  - debug | info | warn | error  (default: info)
#   WB_LOG_FORMAT - text | json                  (default: text)
#
# Contract for sourcing:
#   - This file is set+e safe: it does not enable `set -e`, `set -u`, or
#     `set -o pipefail`. Sourcing it must not change the host script's
#     shell options, traps, or working directory.
#   - All functions are pure stdout writers. They do not exit, do not
#     mutate global state beyond the WB_LOG_* env contract, and do not
#     return non-zero except for `--self-test`.
#   - All functions scrub their arguments through `wb_log_scrub` before
#     emitting output. Callers should not assume their literal text is
#     printed; sensitive-looking patterns will be redacted.
#
# Standalone mode:
#   bash scripts/wb-log.sh --self-test   # runs the redaction test suite
#
# Portability: the redaction implementation uses POSIX-friendly `sed -E`
# constructs that work on both macOS BSD sed and GNU sed. LANG=C is forced
# during scrubbing to keep character classes deterministic.

# ---------------------------------------------------------------------------
# Internal: redaction
# ---------------------------------------------------------------------------

# wb_log_scrub: read text from stdin, emit scrubbed text to stdout.
# Patterns redacted:
#   - generic key/value: token|secret|password|api_key|api-key|bearer
#   - GitHub tokens (ghp_/gho_/ghu_/ghs_/ghr_)
#   - AWS access keys (AKIA prefix)
#   - JWTs (eyJ. ... . ...)
#   - Bearer auth headers
#   - Email addresses
#   - Generic high-entropy strings (32+ chars in [A-Za-z0-9+/=_-])
# Git SHAs (exactly 40 hex chars) are preserved via a split/restore pre-pass.
wb_log_scrub() {
  LANG=C sed -E \
    -e 's/([0-9a-f]{8})([0-9a-f]{8})([0-9a-f]{8})([0-9a-f]{8})([0-9a-f]{8})/\1~\2~\3~\4~\5/g' \
    -e 's/([Tt][Oo][Kk][Ee][Nn]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Aa][Pp][Ii][_-]?[Kk][Ee][Yy]|[Bb][Ee][Aa][Rr][Ee][Rr])[[:space:]]*[:=][[:space:]]*[^[:space:]]+/\1: <redacted>/g' \
    -e 's/gh[pousr]_[A-Za-z0-9]{20,}/<github-token-redacted>/g' \
    -e 's/AKIA[0-9A-Z]{16}/<aws-access-key-redacted>/g' \
    -e 's/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/<jwt-redacted>/g' \
    -e 's/Bearer [A-Za-z0-9._-]+/Bearer <redacted>/g' \
    -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/<email-redacted>/g' \
    -e 's@[A-Za-z0-9+/=_-]{32,}@<high-entropy-redacted>@g' \
    -e 's/([0-9a-f]{8})~([0-9a-f]{8})~([0-9a-f]{8})~([0-9a-f]{8})~([0-9a-f]{8})/\1\2\3\4\5/g'
}

# ---------------------------------------------------------------------------
# Internal: level gating
# ---------------------------------------------------------------------------

_wb_log_level_value() {
  case "${1:-info}" in
    debug) printf '10\n' ;;
    info) printf '20\n' ;;
    warn) printf '30\n' ;;
    error) printf '40\n' ;;
    *) printf '20\n' ;;
  esac
}

_wb_log_should_emit() {
  local msg_level="$1"
  local cur="${WB_LOG_LEVEL:-info}"
  local cur_v msg_v
  cur_v=$(_wb_log_level_value "$cur")
  msg_v=$(_wb_log_level_value "$msg_level")
  [ "$msg_v" -ge "$cur_v" ]
}

# ---------------------------------------------------------------------------
# Internal: JSON emission
# ---------------------------------------------------------------------------

_wb_log_json_escape() {
  # Escape backslashes, double-quotes, tabs, carriage returns, and newlines.
  # Reads stdin, writes stdout.
  LANG=C sed \
    -e 's/\\/\\\\/g' \
    -e 's/"/\\"/g' \
    -e $'s/\t/\\\\t/g' \
    -e $'s/\r/\\\\r/g' \
    | awk 'BEGIN{first=1} {if(!first)printf("\\n"); printf("%s",$0); first=0}'
}

_wb_log_emit() {
  local level="$1"
  shift
  if ! _wb_log_should_emit "$level"; then
    return 0
  fi
  local raw="$*"
  local scrubbed
  scrubbed=$(printf '%s' "$raw" | wb_log_scrub)
  local fmt="${WB_LOG_FORMAT:-text}"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
  if [ "$fmt" = "json" ]; then
    local esc
    esc=$(printf '%s' "$scrubbed" | _wb_log_json_escape)
    printf '{"ts":"%s","level":"%s","msg":"%s"}\n' "$ts" "$level" "$esc"
  else
    printf '[%s] %s %s\n' "$ts" "$level" "$scrubbed"
  fi
}

# ---------------------------------------------------------------------------
# Public: log functions
# ---------------------------------------------------------------------------

wb_log_debug() { _wb_log_emit debug "$@" >&2; }
wb_log_info() { _wb_log_emit info "$@" >&2; }
wb_log_warn() { _wb_log_emit warn "$@" >&2; }
wb_log_error() { _wb_log_emit error "$@" >&2; }

# ---------------------------------------------------------------------------
# Self-test (only runs when executed, not when sourced)
# ---------------------------------------------------------------------------

_wb_log_self_test() {
  local fail=0
  local input expected got name

  _check() {
    name="$1"
    input="$2"
    expected="$3"
    got=$(printf '%s' "$input" | wb_log_scrub)
    if printf '%s' "$got" | grep -Fq -- "$expected"; then
      printf 'PASS  %s\n' "$name"
    else
      printf 'FAIL  %s\n      input:    %s\n      expected: %s\n      got:      %s\n' \
        "$name" "$input" "$expected" "$got"
      fail=$((fail + 1))
    fi
  }

  _refute() {
    name="$1"
    input="$2"
    forbidden="$3"
    got=$(printf '%s' "$input" | wb_log_scrub)
    if printf '%s' "$got" | grep -Fq -- "$forbidden"; then
      printf 'FAIL  %s\n      forbidden substring leaked: %s\n      got: %s\n' \
        "$name" "$forbidden" "$got"
      fail=$((fail + 1))
    else
      printf 'PASS  %s\n' "$name"
    fi
  }

  _check "keyword token=value (lowercase)" \
    "token: hunter2value" \
    "<redacted>"
  _check "keyword Token: case-insensitive" \
    "Token: hunter2value" \
    "<redacted>"
  _check "keyword password=value" \
    "password=hunter2value" \
    "<redacted>"
  _check "keyword api_key" \
    "api_key=alphabravocharlie" \
    "<redacted>"
  _check "keyword api-key" \
    "api-key=alphabravocharlie" \
    "<redacted>"
  local _ghp_test_token
  _ghp_test_token="ghp"'_'"$(printf 'a%.0s' {1..36})"
  _check "github token ghp_" \
    "$_ghp_test_token" \
    "<github-token-redacted>"
  _check "aws access key AKIA" \
    "AKIAIOSFODNN7EXAMPLE" \
    "<aws-access-key-redacted>"
  local _jwt_test_token
  _jwt_test_token="ey$(printf 'J%.0s' {1..40}).ey$(printf 'J%.0s' {1..40}).ey$(printf 'J%.0s' {1..40})"
  _check "jwt three-part" \
    "$_jwt_test_token" \
    "<jwt-redacted>"
  _check "bearer header" \
    "Authorization: Bearer abc-def_123" \
    "Bearer <redacted>"
  _check "email" \
    "alice@example.com filed a ticket" \
    "<email-redacted>"
  _check "high entropy 32+" \
    "value=abcdefghijklmnopqrstuvwxyz0123456789ABCDEF" \
    "<high-entropy-redacted>"

  # Git SHA preservation (40 lowercase hex)
  local sha="1234567890abcdef1234567890abcdef12345678"
  _check "git sha preserved" \
    "merge $sha into main" \
    "$sha"
  _refute "git sha not redacted as high-entropy" \
    "merge $sha into main" \
    "<high-entropy-redacted>"

  # Negative: short non-secret should pass through
  _refute "short token-like word not redacted" \
    "the build token system uses something short" \
    "<redacted>"

  if [ "$fail" -eq 0 ]; then
    printf '\nwb-log.sh self-test: ALL PASSED\n'
    return 0
  fi
  printf '\nwb-log.sh self-test: %d FAILURE(S)\n' "$fail" >&2
  return 1
}

# Detect whether we are being executed directly vs sourced.
# When sourced, BASH_SOURCE[0] != $0.
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  case "${1:-}" in
    --self-test)
      _wb_log_self_test
      exit $?
      ;;
    -h | --help)
      sed -n '2,40p' "$0"
      exit 0
      ;;
    "")
      printf 'wb-log.sh is a sourced library; pass --self-test or --help.\n' >&2
      exit 2
      ;;
    *)
      printf 'wb-log.sh: unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
fi
