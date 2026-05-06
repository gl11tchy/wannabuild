#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/validate-wannabuild-dry-runs.sh [repo_root]

Validates the host-neutral daily-use trust harness:
- Claude Code and Codex invocation contract
- dry-run scenario coverage and fixture expectations
- golden path demo artifacts
- summary gate blocking behavior for failed review/QA evidence

Exit code 0 = valid, non-zero = trust contract violation.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
ROOT="$(cd "$ROOT" && pwd)"
DRY_RUN_DIR="$ROOT/skills/build/dry-runs"
MANIFEST="$DRY_RUN_DIR/daily-use-trust-scenarios.json"
GOLDEN_ROOT="$ROOT/docs/golden-path-demo"
ARTIFACT_VALIDATOR="$ROOT/scripts/validate-wannabuild-artifacts.sh"
GATE_CHECK="$ROOT/scripts/wannabuild-gate-check.sh"
status=0

pass() {
  printf 'PASS  %s\n' "$1"
}

fail() {
  printf 'FAIL  %s\n' "$1"
  status=1
}

require_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    pass "${path#$ROOT/}"
  else
    fail "${path#$ROOT/}"
  fi
}

run_expect_success() {
  local label="$1"
  shift
  local output
  if output="$("$@" 2>&1)"; then
    pass "$label"
  else
    fail "$label"
    printf '%s\n' "$output"
  fi
}

run_expect_failure() {
  local label="$1"
  shift
  local output
  if output="$("$@" 2>&1)"; then
    fail "$label"
    printf 'Expected failure but command passed.\n'
  else
    pass "$label"
  fi
}

require_file "$MANIFEST"
require_file "$ARTIFACT_VALIDATOR"
require_file "$GATE_CHECK"

if ! command -v python3 >/dev/null 2>&1; then
  fail "python3 available for dry-run validation"
else
  pass "python3 available for dry-run validation"
fi

if [[ $status -eq 0 ]]; then
  if python3 - "$MANIFEST" "$DRY_RUN_DIR" <<'PY'; then
import json
from pathlib import Path
import sys

manifest_path = Path(sys.argv[1])
dry_run_dir = Path(sys.argv[2])
errors = []

def err(message):
    errors.append(message)

def load_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        err(f"{path.name}: invalid JSON ({exc})")
        return None

def get_value(payload, dotted):
    current = payload
    for part in dotted.split("."):
        if isinstance(current, dict) and part in current:
            current = current[part]
        else:
            return None
    return current

manifest = load_json(manifest_path)
if manifest is None:
    raise SystemExit(1)

expected_hosts = {
    "claude_code": {"start": "/wannabuild", "intro": "/using-wannabuild"},
    "codex": {"start": "$wannabuild", "intro": "$using-wannabuild"},
}
if manifest.get("schema_version") != 1:
    err("schema_version must be 1")
if manifest.get("host_invocations") != expected_hosts:
    err("host_invocations must preserve /wannabuild, /using-wannabuild, $wannabuild, and $using-wannabuild")

required = {
    "no-task-invocation",
    "exploratory-discovery-invocation",
    "wb-discover-entrypoint-full-loop",
    "vague-acknowledgment-no-phase-skip",
    "runtime-plan-gate",
    "implementation-workspace-selection",
    "resume",
    "research-gate",
    "implementation-selection",
    "review-failure",
    "qa-failure",
    "summary-completion",
}
declared_required = set(manifest.get("required_scenarios", []))
if declared_required != required:
    err("required_scenarios must exactly match the daily-use trust scenario set")

scenarios = manifest.get("scenarios")
if not isinstance(scenarios, list):
    err("scenarios must be a list")
    scenarios = []

seen = set()
for scenario in scenarios:
    if not isinstance(scenario, dict):
        err("scenario entries must be objects")
        continue
    sid = scenario.get("id")
    if not isinstance(sid, str) or not sid:
        err("scenario missing non-empty id")
        continue
    if sid in seen:
        err(f"duplicate scenario id: {sid}")
    seen.add(sid)
    if not scenario.get("description"):
        err(f"{sid}: missing description")
    fixture = scenario.get("fixture")
    payload = None
    if fixture:
        fixture_path = dry_run_dir / fixture
        if not fixture_path.is_file():
            err(f"{sid}: missing fixture {fixture}")
        else:
            payload = load_json(fixture_path)
    for contract in [scenario, payload if isinstance(payload, dict) else None]:
        if isinstance(contract, dict) and "expected_banner" in contract:
            err(f"{sid}: must not require a visible machine banner")

    if sid == "no-task-invocation":
        no_task_contract = payload if isinstance(payload, dict) else scenario
        if no_task_contract.get("prompt_has_concrete_task") is not False:
            err("no-task-invocation must explicitly model a missing concrete task")
        if no_task_contract.get("next_prompt") != "Tell me what you want to build or change.":
            err("no-task-invocation next prompt changed")
        forbidden = set(no_task_contract.get("must_not", []))
        for item in {"inspect_repo", "infer_git_diff", "plan", "implement"}:
            if item not in forbidden:
                err(f"no-task-invocation must forbid {item}")

    if sid == "exploratory-discovery-invocation":
        discovery_contract = payload if isinstance(payload, dict) else scenario
        if discovery_contract.get("prompt_has_concrete_task") is not True:
            err("exploratory-discovery-invocation must be concrete enough to start Discover")
        if discovery_contract.get("prompt_kind") != "exploratory_build_intent":
            err("exploratory-discovery-invocation prompt_kind must be exploratory_build_intent")
        if discovery_contract.get("expected_skill") != "wannabuild":
            err("exploratory-discovery-invocation must use the full wannabuild skill")
        if discovery_contract.get("expected_loop") != "full":
            err("exploratory-discovery-invocation must continue through the full loop after Discover")
        if discovery_contract.get("expected_public_step") != "discover":
            err("exploratory-discovery-invocation must route to Discover")
        if discovery_contract.get("expected_next_action") != "start_discovery_interview":
            err("exploratory-discovery-invocation must start the discovery interview")
        forbidden = set(discovery_contract.get("must_not", []))
        for item in {"no_task_fallback", "ask_user_to_invoke_skill", "plan_before_discovery", "implement_before_plan"}:
            if item not in forbidden:
                err(f"exploratory-discovery-invocation must forbid {item}")
        examples = discovery_contract.get("prompt_examples", [])
        if not isinstance(examples, list) or not examples:
            err("exploratory-discovery-invocation must include prompt_examples")
        else:
            joined = " ".join(str(item).lower() for item in examples)
            for phrase in ["work on this", "brainstorm", "what should we add"]:
                if phrase not in joined:
                    err(f"exploratory-discovery-invocation examples must cover {phrase!r}")

    if sid == "wb-discover-entrypoint-full-loop":
        entry_contract = payload if isinstance(payload, dict) else scenario
        if entry_contract.get("prompt_has_concrete_task") is not True:
            err("wb-discover-entrypoint-full-loop must model a concrete change request")
        if entry_contract.get("invoked_skill") != "wb-discover":
            err("wb-discover-entrypoint-full-loop must model wb-discover as the invoked entrypoint")
        if entry_contract.get("expected_loop") != "full":
            err("wb-discover-entrypoint-full-loop must continue the full loop")
        if entry_contract.get("expected_public_step") != "discover":
            err("wb-discover-entrypoint-full-loop must start at Discover")
        if entry_contract.get("expected_next_action") != "produce_requirements_then_plan":
            err("wb-discover-entrypoint-full-loop must transition from requirements to planning")
        progression = entry_contract.get("expected_phase_progression", [])
        for stage in ["discover", "plan", "implement", "review", "qa", "ship", "summary"]:
            if stage not in progression:
                err(f"wb-discover-entrypoint-full-loop must include {stage!r} in expected_phase_progression")
        forbidden = set(entry_contract.get("must_not", []))
        for item in {"stop_after_discovery", "ask_user_to_invoke_wb_plan", "ask_user_to_invoke_wb_build", "generic_codex_implementation", "implement_before_plan"}:
            if item not in forbidden:
                err(f"wb-discover-entrypoint-full-loop must forbid {item}")

    if sid == "vague-acknowledgment-no-phase-skip":
        ack_contract = payload if isinstance(payload, dict) else scenario
        if ack_contract.get("active_workflow") is not True:
            err("vague-acknowledgment-no-phase-skip must model an active workflow")
        if ack_contract.get("workflow_status") != "in_progress":
            err("vague-acknowledgment-no-phase-skip must keep workflow_status in_progress")
        if ack_contract.get("expected_next_action") != "continue_current_phase":
            err("vague-acknowledgment-no-phase-skip must continue the current phase")
        if ack_contract.get("phase_limit_requires_explicit_user_text") is not True:
            err("vague-acknowledgment-no-phase-skip must require explicit text for phase limits")
        examples = ack_contract.get("prompt_examples", [])
        joined = " ".join(str(item).lower() for item in examples)
        for phrase in ["ok", "uh ok"]:
            if phrase not in joined:
                err(f"vague-acknowledgment-no-phase-skip examples must cover {phrase!r}")
        forbidden = set(ack_contract.get("must_not", []))
        for item in {"treat_as_approval_to_skip_plan", "start_implementation_without_plan", "stop_workflow", "ask_user_to_invoke_next_phase"}:
            if item not in forbidden:
                err(f"vague-acknowledgment-no-phase-skip must forbid {item}")

    if sid == "runtime-plan-gate":
        gate_contract = payload if isinstance(payload, dict) else scenario
        if gate_contract.get("active_workflow") is not True:
            err("runtime-plan-gate must model an active workflow")
        if gate_contract.get("workflow_status") != "in_progress":
            err("runtime-plan-gate must keep workflow_status in_progress")
        if gate_contract.get("public_stage") != "plan":
            err("runtime-plan-gate must model the plan stage")
        if gate_contract.get("expected_runtime_context") is not True:
            err("runtime-plan-gate must require runtime context injection")
        if gate_contract.get("expected_next_action") != "complete_plan_before_implementation":
            err("runtime-plan-gate must require Plan completion before implementation")
        if gate_contract.get("required_gate_command") != "scripts/wannabuild-session.sh assert-plan-ready <project_root>":
            err("runtime-plan-gate must require the assert-plan-ready gate command")
        forbidden = set(gate_contract.get("must_not", []))
        for item in {"implement_before_plan", "edit_code_before_plan_gate", "treat_vague_ack_as_approval", "generic_codex_implementation"}:
            if item not in forbidden:
                err(f"runtime-plan-gate must forbid {item}")

    workspace_fixture = scenario.get("workspace_fixture")
    if workspace_fixture:
        workspace_path = dry_run_dir / workspace_fixture
        workspace = load_json(workspace_path) if workspace_path.is_file() else None
        if workspace is None:
            err(f"{sid}: missing workspace fixture {workspace_fixture}")
        else:
            branch_name = workspace.get("branch_name", "")
            prefixes = tuple(scenario.get("branch_prefixes", []))
            if not prefixes:
                err(f"{sid}: workspace scenario must declare accepted branch_prefixes")
            elif not isinstance(branch_name, str) or not branch_name.startswith(prefixes):
                err(f"{sid}: workspace branch {branch_name!r} does not use an accepted host branch prefix")
            for key in ["workspace_id", "source_repo", "source_branch", "workspace_path", "branch_name", "dirty_snapshot"]:
                if key not in workspace:
                    err(f"{sid}: workspace fixture missing {key}")
            source_repo = workspace.get("source_repo")
            isolated_path = workspace.get("workspace_path")
            if not isinstance(source_repo, str) or not source_repo:
                err(f"{sid}: workspace source_repo must be a non-empty string")
            if not isinstance(isolated_path, str) or not isolated_path:
                err(f"{sid}: workspace workspace_path must be a non-empty string")
            elif "/.codex/worktrees/" not in isolated_path:
                err(f"{sid}: workspace_path must live under a .codex/worktrees root")
            if isinstance(source_repo, str) and isinstance(isolated_path, str) and source_repo == isolated_path:
                err(f"{sid}: workspace_path must differ from source_repo")
            if not isinstance(workspace.get("dirty_snapshot"), bool):
                err(f"{sid}: workspace dirty_snapshot must be boolean")

    if payload is not None:
        for key, expected in scenario.get("expect", {}).items():
            actual = get_value(payload, key)
            if actual != expected:
                err(f"{sid}: expected {key}={expected!r}, got {actual!r}")
        history = scenario.get("required_public_history", [])
        if history:
            records = payload.get("public_stage_history", [])
            stages = {item.get("stage") for item in records if isinstance(item, dict)}
            for stage in history:
                if stage not in stages:
                    err(f"{sid}: missing public_stage_history stage {stage!r}")
        public_stage_expect = scenario.get("latest_public_stage_expect", {})
        if public_stage_expect:
            records = payload.get("public_stage_history", [])
            if not isinstance(records, list) or not records:
                err(f"{sid}: missing public_stage_history records")
            else:
                stage = public_stage_expect.get("stage")
                candidates = [item for item in records if isinstance(item, dict) and (not stage or item.get("stage") == stage)]
                if not candidates:
                    err(f"{sid}: missing public_stage_history record for {stage!r}")
                else:
                    latest_record = candidates[-1]
                    for key, expected in public_stage_expect.items():
                        actual = latest_record.get(key)
                        if actual != expected:
                            err(f"{sid}: expected latest public stage {key}={expected!r}, got {actual!r}")
        latest_expect = scenario.get("latest_iteration_expect", {})
        if latest_expect:
            iterations = payload.get("iterations")
            if not isinstance(iterations, list) or not iterations:
                err(f"{sid}: missing loop iterations")
            else:
                latest = max(iterations, key=lambda item: item.get("iteration", 0))
                for key, expected in latest_expect.items():
                    actual = get_value(latest, key)
                    if actual != expected:
                        err(f"{sid}: expected latest iteration {key}={expected!r}, got {actual!r}")

coverage = seen & required
missing = sorted(required - coverage)
if missing:
    err("missing required scenario coverage: " + ", ".join(missing))

if errors:
    print("Daily-use trust dry-run validation failed:")
    for message in errors:
        print(f" - {message}")
    raise SystemExit(1)

print(f"Validated {len(scenarios)} daily-use trust scenario(s).")
PY
    pass "dry-run scenario manifest"
  else
    fail "dry-run scenario manifest"
  fi
fi

if [[ -d "$GOLDEN_ROOT" ]]; then
  run_expect_success "golden path artifact validation" "$ARTIFACT_VALIDATOR" "$GOLDEN_ROOT" document
  run_expect_success "golden path summary gate" "$GATE_CHECK" "$GOLDEN_ROOT" summary
else
  fail "docs/golden-path-demo/"
fi

if [[ $status -eq 0 ]]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  cp -R "$GOLDEN_ROOT/.wannabuild" "$tmp/.wannabuild"
  rm -f "$tmp/.wannabuild/outputs/qa-summary.md"
  run_expect_failure "summary gate blocks missing QA summary" "$GATE_CHECK" "$tmp" summary

  rm -rf "$tmp/.wannabuild"
  mkdir -p "$tmp/.wannabuild/review" "$tmp/.wannabuild/outputs"
  cp "$DRY_RUN_DIR/review-failure-loop.json" "$tmp/.wannabuild/loop-state.json"
  printf 'QA completed, but review remains blocked.\n' >"$tmp/.wannabuild/outputs/qa-summary.md"
  python3 - "$tmp/.wannabuild/loop-state.json" "$tmp/.wannabuild/review" <<'PY'
import json
from pathlib import Path
import sys

loop = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
review_dir = Path(sys.argv[2])
latest = max(loop["iterations"], key=lambda item: item.get("iteration", 0))
for reviewer, verdict in latest["verdicts"].items():
    path = review_dir / f"{reviewer}-iter-{latest['iteration']}.json"
    path.write_text(json.dumps(verdict, indent=2) + "\n", encoding="utf-8")
PY
  run_expect_failure "summary gate blocks failed reviewer verdict" "$GATE_CHECK" "$tmp" summary

  rm -rf "$tmp/.wannabuild"
  mkdir -p "$tmp/.wannabuild/review" "$tmp/.wannabuild/outputs"
  cp "$DRY_RUN_DIR/qa-failure-remediation-loop.json" "$tmp/.wannabuild/loop-state.json"
  printf 'QA attempted; integration hard gate remains failing.\n' >"$tmp/.wannabuild/outputs/qa-summary.md"
  python3 - "$tmp/.wannabuild/loop-state.json" "$tmp/.wannabuild/review/wb-integration-tester-iter-2.json" <<'PY'
import json
from pathlib import Path
import sys

loop = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
latest = max(loop["iterations"], key=lambda item: item.get("iteration", 0))
verdict = latest["verdicts"]["wb-integration-tester"]
Path(sys.argv[2]).write_text(json.dumps(verdict, indent=2) + "\n", encoding="utf-8")
PY
  run_expect_failure "summary gate blocks failed integration verdict" "$GATE_CHECK" "$tmp" summary
fi

if [[ $status -eq 0 ]]; then
  echo "Daily-use trust dry runs passed."
else
  echo "Daily-use trust dry runs failed."
fi

exit "$status"
