#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/wannabuild-session.sh <command> <project_root> [args]

Commands:
  init <project_root>
  set-stage <project_root> <stage> <status>
  set-control-mode <project_root> <guided|autonomous>
  show <project_root>
  assert-stage <project_root> <stage>
  assert-workflow-active <project_root>
  assert-discovery-ready <project_root>
  assert-plan-ready <project_root>

Stages:
  discover
  research
  plan
  implement
  review
  qa
  summary
USAGE
}

if [[ $# -lt 2 ]]; then
  usage >&2
  exit 1
fi

command="$1"
project_root="$(cd "$2" && pwd)"
state_file="$project_root/.wannabuild/state.json"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"

runtime_command() {
  local runtime_subcommand="$1"
  local runtime_bin
  if [[ -n "${WB_RUNTIME_BIN:-}" ]]; then
    if [[ ! -x "$WB_RUNTIME_BIN" ]]; then
      echo "Runtime unavailable: WB_RUNTIME_BIN is not executable: $WB_RUNTIME_BIN" >&2
      return 127
    fi
    run_runtime_command "$WB_RUNTIME_BIN" "$runtime_subcommand"
    return $?
  fi

  if [[ -x "$repo_root/target/debug/wb-runtime" ]]; then
    run_runtime_command "$repo_root/target/debug/wb-runtime" "$runtime_subcommand"
    return $?
  fi

  if [[ -x "$repo_root/target/debug/wb-runtime.exe" ]]; then
    run_runtime_command "$repo_root/target/debug/wb-runtime.exe" "$runtime_subcommand"
    return $?
  fi

  if command -v cargo >/dev/null 2>&1 && [[ -f "$repo_root/Cargo.toml" ]]; then
    run_runtime_command cargo run --quiet --manifest-path "$repo_root/Cargo.toml" --bin wb-runtime -- "$runtime_subcommand"
    return $?
  fi

  if runtime_bin="$(command -v wb-runtime 2>/dev/null)"; then
    run_runtime_command "$runtime_bin" "$runtime_subcommand"
    return $?
  fi

  if runtime_bin="$(codex_runtime_bin)"; then
    run_runtime_command "$runtime_bin" "$runtime_subcommand"
    return $?
  fi

  echo "Runtime unavailable: wb-runtime is required to run $runtime_subcommand." >&2
  echo "Install wb-runtime, build $repo_root/target/debug/wb-runtime, or run with cargo available." >&2
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

run_runtime_command() {
  local output status
  set +e
  output="$("$@" --project "$project_root" 2>&1)"
  status=$?
  set -e
  if [[ $status -eq 0 ]]; then
    printf '%s\n' "$output"
  else
    printf '%s\n' "$output" >&2
  fi
  return "$status"
}

if [[ "$command" == "init" || "$command" == "assert-plan-ready" || "$command" == "assert-workflow-active" || "$command" == "assert-discovery-ready" ]]; then
  runtime_status=0
  runtime_command "$command" || runtime_status=$?
  if [[ $runtime_status -eq 0 ]]; then
    exit 0
  fi
  exit "$runtime_status"
fi

python3 - "$command" "$project_root" "$state_file" "${3:-}" "${4:-}" <<'PY'
import json
from pathlib import Path
import sys
from datetime import datetime, timezone

command, project_root, state_file, arg1, arg2 = sys.argv[1:]
stages = {
    "discover",
    "research",
    "plan",
    "implement",
    "review",
    "qa",
    "summary",
}

def now():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

state_path = Path(state_file)
project_name = Path(project_root).name

def load_state():
    if not state_path.exists():
        return None
    return json.loads(state_path.read_text(encoding="utf-8"))

def write_state(state):
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")

if command == "init":
    ts = now()
    state = {
        "project": project_name,
        "mode": "standard",
        "current_phase": "requirements",
        "phase_status": "pending",
        "public_stage": "discover",
        "control_mode": "guided",
        "workflow_status": "in_progress",
        "started_at": ts,
        "updated_at": ts,
        "artifacts": {},
        "phase_history": [],
        "public_stage_history": [
            {"stage": "discover", "status": "in_progress", "timestamp": ts}
        ],
    }
    write_state(state)
    print(f"Initialized WannaBuild session at {state_path}")
elif command == "set-stage":
    stage = arg1
    status = arg2 or "in_progress"
    if stage not in stages:
        raise SystemExit(f"Unknown stage: {stage}")
    state = load_state()
    if state is None:
        raise SystemExit("state.json not found; run init first")
    ts = now()
    state["public_stage"] = stage
    state["workflow_status"] = status
    state["updated_at"] = ts
    history = state.setdefault("public_stage_history", [])
    history.append({"stage": stage, "status": status, "timestamp": ts})
    write_state(state)
    print(f"Set public stage to {stage} ({status})")
elif command == "set-control-mode":
    mode = arg1
    if mode not in {"guided", "autonomous"}:
        raise SystemExit(f"Unknown control mode: {mode}")
    state = load_state()
    if state is None:
        raise SystemExit("state.json not found; run init first")
    ts = now()
    state["control_mode"] = mode
    state["updated_at"] = ts
    write_state(state)
    print(f"Set control mode to {mode}")
elif command == "show":
    state = load_state()
    if state is None:
        raise SystemExit("state.json not found")
    print(json.dumps(state, indent=2))
elif command == "assert-stage":
    expected = arg1
    state = load_state()
    if state is None:
        raise SystemExit("state.json not found")
    actual = state.get("public_stage")
    if actual != expected:
        raise SystemExit(f"Expected stage {expected!r}, got {actual!r}")
    print(f"Stage OK: {actual}")
else:
    raise SystemExit(f"Unknown command: {command}")
PY
