#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/wannabuild-gate-check.sh <project_root> <gate>

Gates:
  review       - require review verdict JSON files including integration tester
  qa           - require positive QA pass evidence
  summary      - require review and qa gates to be satisfied
  acquisition  - reject any blocked/failed state with no logged acquisition attempt
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
    acquisition) printf 'assert-acquisition-attempted\n' ;;
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

  # Prefer the binary built from this checkout: the script and the runtime it
  # dispatches to must agree on gate semantics. An older binary installed on
  # PATH or under ~/.codex/bin must not silently weaken the gates. Within the
  # checkout, prefer target/debug — the profile the installer, session helper,
  # and test suite build and refresh — over a target/release that is only built
  # by hand and may lag behind the current source.
  for runtime_bin in \
    "$repo_root/target/debug/wb-runtime" \
    "$repo_root/target/debug/wb-runtime.exe" \
    "$repo_root/target/release/wb-runtime" \
    "$repo_root/target/release/wb-runtime.exe"; do
    if [[ -x "$runtime_bin" ]]; then
      "$runtime_bin" "$runtime_command" --project "$project_root"
      return
    fi
  done

  if runtime_bin="$(command -v wb-runtime 2>/dev/null)"; then
    "$runtime_bin" "$runtime_command" --project "$project_root"
    return
  fi

  if runtime_bin="$(codex_runtime_bin)"; then
    "$runtime_bin" "$runtime_command" --project "$project_root"
    return
  fi

  if command -v cargo >/dev/null 2>&1 && [[ -f "$repo_root/Cargo.toml" ]]; then
    cargo run --quiet --manifest-path "$repo_root/Cargo.toml" --bin wb-runtime -- "$runtime_command" --project "$project_root"
    return
  fi

  runtime_unavailable
  return 127
}

codex_runtime_bin() {
  local codex_bin=""
  if [[ -n "${CODEX_HOME:-}" ]]; then
    codex_bin="$CODEX_HOME/bin"
  elif [[ -n "${HOME:-}" ]]; then
    codex_bin="$HOME/.codex/bin"
  fi

  if [[ -n "$codex_bin" && -x "$codex_bin/wb-runtime" ]]; then
    printf '%s\n' "$codex_bin/wb-runtime"
  elif [[ -n "$codex_bin" && -x "$codex_bin/wb-runtime.exe" ]]; then
    printf '%s\n' "$codex_bin/wb-runtime.exe"
  else
    return 1
  fi
}

case "$gate" in
  review | qa | summary | acquisition) ;;
  *)
    usage >&2
    exit 1
    ;;
esac

runtime_command="$(runtime_command_for_gate "$gate")"
run_runtime_gate "$runtime_command"
