#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/wannabuild-gate-check.sh <project_root> <gate>

Gates:
  review   - require review verdict JSON files including integration tester
  qa       - require positive QA pass evidence
  summary  - require review and qa gates to be satisfied
USAGE
}

if [[ $# -ne 2 ]]; then
  usage >&2
  exit 1
fi

project_root="$(cd "$1" && pwd)"
gate="$2"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"

runtime_command_for_gate() {
  case "$1" in
    review) printf 'assert-review-ready\n' ;;
    qa) printf 'assert-qa-ready\n' ;;
    summary) printf 'assert-summary-ready\n' ;;
    *) return 1 ;;
  esac
}

runtime_unavailable() {
  echo "Runtime unavailable: wb-runtime is required to evaluate the '$gate' gate." >&2
  echo "Install wb-runtime, build $repo_root/target/debug/wb-runtime, or run with cargo available." >&2
}

run_runtime_gate() {
  local runtime_command="$1"
  local runtime_bin

  if [[ -n "${WB_RUNTIME_BIN:-}" ]]; then
    if [[ ! -x "$WB_RUNTIME_BIN" ]]; then
      echo "Runtime unavailable: WB_RUNTIME_BIN is not executable: $WB_RUNTIME_BIN" >&2
      return 127
    fi
    "$WB_RUNTIME_BIN" "$runtime_command" --project "$project_root"
    return
  fi

  if runtime_bin="$(command -v wb-runtime 2>/dev/null)"; then
    "$runtime_bin" "$runtime_command" --project "$project_root"
    return
  fi

  if [[ -x "$repo_root/target/debug/wb-runtime" ]]; then
    "$repo_root/target/debug/wb-runtime" "$runtime_command" --project "$project_root"
    return
  fi

  if command -v cargo >/dev/null 2>&1 && [[ -f "$repo_root/Cargo.toml" ]]; then
    cargo run --quiet --manifest-path "$repo_root/Cargo.toml" --bin wb-runtime -- "$runtime_command" --project "$project_root"
    return
  fi

  runtime_unavailable
  return 127
}

case "$gate" in
  review | qa | summary) ;;
  *)
    usage >&2
    exit 1
    ;;
esac

runtime_command="$(runtime_command_for_gate "$gate")"
run_runtime_gate "$runtime_command"
