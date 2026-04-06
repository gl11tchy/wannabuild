#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
Usage:
  scripts/validate-wannabuild-artifacts.sh <project_root> [target_phase]

Arguments:
  <project_root>   Root path of the target project containing .wannabuild/.
  [target_phase]   Optional transition target: requirements, design, tasks,
                   implement, review, ship, document.

Exit code 0 = valid, non-zero = contract violation.
USAGE
  exit 0
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "ERROR: expected 1-2 args. Use --help for usage."
  exit 1
fi

PROJECT_ROOT="$1"
TARGET_PHASE="${2:-}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

STATE_FILE="$PROJECT_ROOT/.wannabuild/state.json"
LOOP_FILE="$PROJECT_ROOT/.wannabuild/loop-state.json"
CHECKPOINT_DIR="$PROJECT_ROOT/.wannabuild/checkpoints"
REVIEW_DIR="$PROJECT_ROOT/.wannabuild/review"

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required for artifact validation."
  exit 3
fi

python3 - "$STATE_FILE" "$LOOP_FILE" "$CHECKPOINT_DIR" "$REVIEW_DIR" "$TARGET_PHASE" <<'PY'
import json
import re
from pathlib import Path
import sys

state_path, loop_path, checkpoint_path, review_path, target_phase = sys.argv[1:]
errors = []
warnings = []


def record_error(msg):
    errors.append(msg)


def record_warning(msg):
    warnings.append(msg)


def must_exist(path, label):
    if not Path(path).is_file():
        record_error(f"Missing required file: {label} ({path})")
        return False
    return True


def load_json(path, label, optional=False):
    if not Path(path).is_file():
        if optional:
            return None
        record_error(f"Missing required file: {label} ({path})")
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as exc:
        record_error(f"Invalid JSON in {label} ({path}): {exc}")
        return None


def ensure_iso8601(value, label):
    if not isinstance(value, str) or not re.match(r"^\d{4}-\d{2}-\d{2}T", value):
        record_error(f"{label} must be ISO-8601 string: got {value!r}")


def validate_state(state):
    if state is None:
        return
    if not isinstance(state, dict):
        record_error(f"state.json must be an object: got {type(state).__name__}")
        return
    required = [
        "project",
        "current_phase",
        "phase_status",
        "control_mode",
        "artifacts",
        "started_at",
        "updated_at",
        "phase_history",
    ]
    for key in required:
        if key not in state:
            record_error(f"state.json missing required key: {key}")
    if not isinstance(state.get("project"), str) or not state.get("project"):
        record_error("state.json.project must be a non-empty string")
    if state.get("mode") not in {None, "standard"}:
        record_error(f"state.json.mode invalid: {state.get('mode')!r}")
    if state.get("current_phase") not in {None, ""}:
        if not isinstance(state.get("current_phase"), str) or not state.get("current_phase"):
            record_error("state.json.current_phase must be a non-empty string")
    if state.get("control_mode") not in {"guided", "autonomous"}:
        record_error(f"state.json.control_mode invalid: {state.get('control_mode')!r}")
    if state.get("phase_status") not in {"pending", "in_progress", "complete"}:
        record_error(f"state.json.phase_status invalid: {state.get('phase_status')!r}")
    artifacts = state.get("artifacts")
    if not isinstance(artifacts, dict):
        record_error("state.json.artifacts must be an object")
    else:
        for k, v in artifacts.items():
            if not isinstance(k, str) or not k:
                record_error("state.json.artifacts keys must be strings")
            if not isinstance(v, str) or not v:
                record_error(f"state.json.artifacts[{k!r}] must be a non-empty string path")
    ensure_iso8601(state.get("started_at"), "state.json.started_at")
    ensure_iso8601(state.get("updated_at"), "state.json.updated_at")
    history = state.get("phase_history")
    if not isinstance(history, list):
        record_error("state.json.phase_history must be an array")
    else:
        for i, item in enumerate(history):
            if not isinstance(item, dict):
                record_error(f"state.json.phase_history[{i}] must be an object")
                continue
            for key in ["phase", "status", "timestamp"]:
                if key not in item:
                    record_error(f"state.json.phase_history[{i}] missing key: {key}")
            if item.get("phase") is not None and (
                not isinstance(item.get("phase"), str) or not item.get("phase")
            ):
                record_error(
                    f"state.json.phase_history[{i}].phase must be non-empty string"
                )
            if item.get("status") not in {"pending", "in_progress", "complete"}:
                record_error(
                    f"state.json.phase_history[{i}].status invalid: {item.get('status')!r}"
                )
            ensure_iso8601(item.get("timestamp"), f"state.json.phase_history[{i}].timestamp")


def validate_loop_state(loop_state):
    if loop_state is None:
        return
    if not isinstance(loop_state, dict):
        record_error(f"loop-state.json must be an object: got {type(loop_state).__name__}")
        return
    required = [
        "current_iteration",
        "max_iterations",
        "base_reviewer_count",
        "status",
        "iterations",
    ]
    for key in required:
        if key not in loop_state:
            record_error(f"loop-state.json missing required key: {key}")
    if loop_state.get("mode") not in {None, "standard"}:
        record_error(f"loop-state.json.mode invalid: {loop_state.get('mode')!r}")
    for int_key in ["current_iteration", "max_iterations", "base_reviewer_count"]:
        value = loop_state.get(int_key)
        if not isinstance(value, int) or value < 0:
            record_error(f"loop-state.json.{int_key} must be an integer >= 0")
    if loop_state.get("status") not in {"in_progress", "approved", "escalated", "blocked"}:
        record_error(f"loop-state.json.status invalid: {loop_state.get('status')!r}")
    guardrails = loop_state.get("guardrails", {})
    if guardrails is not None and not isinstance(guardrails, dict):
        record_error("loop-state.json.guardrails must be an object if set")
    iterations = loop_state.get("iterations")
    if not isinstance(iterations, list):
        record_error("loop-state.json.iterations must be an array")
        return
    for i, item in enumerate(iterations):
        if not isinstance(item, dict):
            record_error(f"loop-state.json.iterations[{i}] must be an object")
            continue
        for key in ["iteration", "timestamp", "active_reviewers", "verdicts", "pass_count", "fail_count"]:
            if key not in item:
                record_error(f"loop-state.json.iterations[{i}] missing key: {key}")
        if not isinstance(item.get("iteration"), int) or item.get("iteration") < 0:
            record_error(
                f"loop-state.json.iterations[{i}].iteration must be an integer >= 0"
            )
        ensure_iso8601(item.get("timestamp"), f"loop-state.json.iterations[{i}].timestamp")
        if not isinstance(item.get("active_reviewers"), list):
            record_error(f"loop-state.json.iterations[{i}].active_reviewers must be a list")
        verdicts = item.get("verdicts")
        if not isinstance(verdicts, dict):
            record_error(f"loop-state.json.iterations[{i}].verdicts must be an object")
        else:
            for reviewer, verdict in verdicts.items():
                validate_verdict_file({**verdict, "agent": reviewer}, source=f"loop-state.json.iterations[{i}].verdicts[{reviewer}]")
        for key in ["pass_count", "fail_count"]:
            value = item.get(key)
            if not isinstance(value, int) or value < 0:
                record_error(f"loop-state.json.iterations[{i}].{key} must be an integer >= 0")
        if "routing_reason" in item:
            if item["routing_reason"] not in {
                "base_set",
                "impacted",
                "fallback",
                "fast_track_fallback",
                "ambiguous_impact",
            }:
                record_error(
                    f"loop-state.json.iterations[{i}].routing_reason invalid: {item.get('routing_reason')!r}"
                )


def validate_verdict_file(verdict, source):
    if not isinstance(verdict, dict):
        record_error(f"{source} must be an object")
        return
    for key in ["agent", "status", "summary", "issues"]:
        if key not in verdict:
            record_error(f"{source} missing required key: {key}")
    agent = verdict.get("agent")
    status = verdict.get("status")
    if not isinstance(agent, str) or not agent:
        record_error(f"{source}.agent must be a non-empty string")
    if status not in {"PASS", "FAIL"}:
        record_error(f"{source}.status must be PASS or FAIL: {status!r}")
    if not isinstance(verdict.get("summary"), str) or not verdict.get("summary"):
        record_error(f"{source}.summary must be a non-empty string")
    issues = verdict.get("issues")
    if not isinstance(issues, list):
        record_error(f"{source}.issues must be a list")
    else:
        for idx, issue in enumerate(issues):
            if not isinstance(issue, dict):
                record_error(f"{source}.issues[{idx}] must be an object")
                continue
            for key in ["severity", "issue", "recommendation"]:
                if key not in issue:
                    record_error(f"{source}.issues[{idx}] missing key: {key}")
            severity = issue.get("severity")
            if severity not in {"critical", "high", "medium", "low"}:
                record_error(
                    f"{source}.issues[{idx}].severity invalid: {severity!r}"
                )
            if "file" in issue and not isinstance(issue["file"], str):
                record_error(f"{source}.issues[{idx}].file must be string")
            if "line" in issue and (not isinstance(issue["line"], int) or issue["line"] < 0):
                record_error(f"{source}.issues[{idx}].line must be an integer >= 0")
            if not isinstance(issue.get("issue"), str) or not issue.get("issue"):
                record_error(f"{source}.issues[{idx}].issue must be a non-empty string")
            if not isinstance(issue.get("recommendation"), str) or not issue.get("recommendation"):
                record_error(f"{source}.issues[{idx}].recommendation must be a non-empty string")
    if verdict.get("agent") in {"wb-integration-tester", "wb-integration-tester-spark"}:
        if verdict.get("hard_gate") is not True:
            record_error(f"{source}.hard_gate must be true for integration tester verdicts")
        test_execution = verdict.get("test_execution")
        if not isinstance(test_execution, dict):
            record_error(f"{source}.test_execution must be an object")
        else:
            for key in ["total", "passed", "failed", "errored", "duration_ms"]:
                if not isinstance(test_execution.get(key), int) or test_execution.get(key) < 0:
                    record_error(
                        f"{source}.test_execution.{key} must be an integer >= 0"
                    )
        if not isinstance(verdict.get("coverage_map"), list) or not verdict["coverage_map"]:
            record_error(f"{source}.coverage_map must be a non-empty list")


def validate_checkpoint_file(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            head = [next(f, "") for _ in range(40)]
    except FileNotFoundError:
        record_error(f"Checkpoint file missing while validating: {path}")
        return
    text = "".join(head)
    required = [
        "Task:",
        "Step:",
        "Changed Files:",
        "Verify:",
        "Result:",
        "Next:",
    ]
    for field in required:
        if re.search(rf"^\s*{re.escape(field)}", text, re.MULTILINE) is None:
            record_error(f"{path} missing checkpoint field: {field}")


def validate_checkpoints():
    cp_dir = Path(checkpoint_path)
    if not cp_dir.is_dir():
        record_warning(f"Checkpoint directory missing: {cp_dir}")
        return
    files = sorted(cp_dir.glob("task-*-step-*.md"))
    if not files:
        record_warning("No checkpoint files found in checkpoint directory")
        return
    for file_path in files:
        validate_checkpoint_file(file_path)


def validate_review_outputs(loop_state):
    review_dir = Path(review_path)
    if not review_dir.is_dir():
        record_warning(f"Review directory missing: {review_dir}")
        return
    review_files = sorted(review_dir.glob("*.json"))
    if not review_files:
        return
    for file_path in review_files:
        payload = load_json(str(file_path), str(file_path), optional=False)
        if payload is None:
            continue
        validate_verdict_file(payload, f"{file_path}")

    if loop_state and isinstance(loop_state, dict):
        iterations = loop_state.get("iterations")
        if isinstance(iterations, list) and iterations:
            latest = sorted(iterations, key=lambda x: x.get("iteration", 0))[-1]
            active = latest.get("active_reviewers", [])
            if isinstance(active, list) and active:
                seen = {Path(p).name for p in map(str, review_files)}
                for reviewer in active:
                    if not isinstance(reviewer, str):
                        continue
                    expected = f"{reviewer}-iter-{latest.get('iteration')}.json"
                    if expected not in seen:
                        record_warning(
                            f"Expected review verdict missing for {expected} (latest iteration active reviewer: {reviewer})"
                        )


def validate_transition(state):
    if not target_phase:
        return
    if target_phase not in {
        "requirements",
        "design",
        "tasks",
        "implement",
        "review",
        "ship",
        "document",
    }:
        record_error(f"Unknown target phase for validation: {target_phase!r}")
        return
    if state is None or not isinstance(state, dict):
        return
    spec_dir = Path(state_path).resolve().parent.parent / ".wannabuild" / "spec"
    phase_required_specs = {
        "requirements": [],
        "design": ["requirements.md"],
        "tasks": ["requirements.md", "design.md"],
        "implement": ["requirements.md", "tasks.md"],
        "review": ["requirements.md", "tasks.md"],
        "ship": ["requirements.md", "tasks.md"],
        "document": ["requirements.md", "tasks.md"],
    }
    mode = state.get("mode", "standard")
    specs = phase_required_specs.get(target_phase, [])
    for spec in specs:
        must_exist(str(spec_dir / spec), f"{spec}")
    if target_phase in {"implement", "review"}:
        if not any(Path(checkpoint_path).glob("task-*-step-*.md")):
            record_warning("No checkpoint files found; review routing and resume continuity may be inaccurate")
        if target_phase == "review":
            loop_state = load_json(loop_path, "loop-state.json", optional=True)
            if loop_state is None:
                record_warning("No loop-state.json available before entering review")
    if target_phase in {"ship", "document"}:
        loop_state = load_json(loop_path, "loop-state.json", optional=True)
        if loop_state is None:
            record_error("No loop-state.json before ship/document; review loop context is required before ship/document")
        else:
            status = loop_state.get("status")
            if status and status != "approved":
                record_error(
                    f"loop-state.json status is {status!r}; ship/document transition should only run after approved review"
                )
state = load_json(state_path, "state.json")
validate_state(state)
loop_state = load_json(loop_path, "loop-state.json", optional=True)
validate_loop_state(loop_state)
validate_checkpoints()
validate_review_outputs(loop_state)
validate_transition(state)

print("WannaBuild artifact validation report")
for warning in warnings:
    print(f"WARN: {warning}")
if errors:
    print("ERRORS:")
    for msg in errors:
        print(f" - {msg}")
    print(f"Validation failed: {len(errors)} error(s)")
    sys.exit(2)
print("Validation passed.")
print(f"Warnings: {len(warnings)}")
sys.exit(0)
PY
