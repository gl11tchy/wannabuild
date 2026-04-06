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

Stages:
  discover
  control_mode_decision
  research_decision
  research
  plan
  implementation_decision
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

python3 - "$command" "$project_root" "$state_file" "${3:-}" "${4:-}" <<'PY'
import json
from pathlib import Path
import sys
from datetime import datetime, timezone

command, project_root, state_file, arg1, arg2 = sys.argv[1:]
stages = {
    "discover",
    "control_mode_decision",
    "research_decision",
    "research",
    "plan",
    "implementation_decision",
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
