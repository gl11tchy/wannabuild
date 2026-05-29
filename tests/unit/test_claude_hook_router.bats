#!/usr/bin/env bats
#
# Unit tests for the Claude Code natural-language autorouter hook.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

setup_file() {
  cargo build --quiet --manifest-path "$REPO_ROOT/Cargo.toml" --bin wb-runtime
  export WB_RUNTIME_BIN="$REPO_ROOT/target/debug/wb-runtime"
}

run_hook() {
  local json="$1"
  run python3 "$REPO_ROOT/hooks/wannabuild-route.py" <<< "$json"
}

@test "hook: session start injects automatic routing context" {
  run_hook '{"hook_event_name":"SessionStart"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"hookEventName":"SessionStart"'* ]]
  [[ "$output" == *'WannaBuild automatic routing is active'* ]]
  [[ "$output" == *'Commands are optional shortcuts'* ]]
}

@test "hook: active workflow injects runtime state for vague acknowledgments" {
  target="$(setup_tmpdir)/proj"
  mkdir -p "$target/.wannabuild"
  cat >"$target/.wannabuild/state.json" <<'JSON'
{
  "project": "proj",
  "mode": "standard",
  "current_phase": "design",
  "phase_status": "in_progress",
  "public_stage": "plan",
  "workflow_status": "in_progress",
  "control_mode": "autonomous",
  "public_stage_history": [
    {"stage": "discover", "status": "complete", "timestamp": "2026-05-06T10:00:00Z"},
    {"stage": "plan", "status": "in_progress", "timestamp": "2026-05-06T10:05:00Z"}
  ],
  "phase_history": []
}
JSON
  json="$(printf '{"hook_event_name":"UserPromptSubmit","prompt":"ok","cwd":"%s"}' "$target")"
  run_hook "$json"
  [ "$status" -eq 0 ]
  [[ "$output" == *'WannaBuild runtime state is active'* ]]
  [[ "$output" == *'vague_acknowledgment'* ]]
  [[ "$output" == *'FORBIDDEN: do not implement or edit code'* ]]
}

@test "hook: build route carries hard plan gate when plan is incomplete" {
  target="$(setup_tmpdir)/proj"
  mkdir -p "$target/.wannabuild"
  cat >"$target/.wannabuild/state.json" <<'JSON'
{
  "project": "proj",
  "mode": "standard",
  "current_phase": "design",
  "phase_status": "in_progress",
  "public_stage": "plan",
  "workflow_status": "in_progress",
  "control_mode": "autonomous",
  "public_stage_history": [
    {"stage": "discover", "status": "complete", "timestamp": "2026-05-06T10:00:00Z"},
    {"stage": "plan", "status": "in_progress", "timestamp": "2026-05-06T10:05:00Z"}
  ],
  "phase_history": []
}
JSON
  json="$(printf '{"hook_event_name":"UserPromptSubmit","prompt":"Implement the next planned slice","cwd":"%s"}' "$target")"
  run_hook "$json"
  [ "$status" -eq 0 ]
  [[ "$output" == *'`wb-build`'* ]]
  [[ "$output" == *'before_build'* ]]
  [[ "$output" == *'assert-plan-ready'* ]]
  [[ "$output" == *'FORBIDDEN: do not implement or edit code'* ]]
}

@test "hook: delegates active prompt context to wb-runtime when available" {
  target="$(setup_tmpdir)/proj"
  mkdir -p "$target/.wannabuild"
  cat >"$target/.wannabuild/state.json" <<'JSON'
{
  "project": "proj",
  "mode": "standard",
  "current_phase": "design",
  "phase_status": "in_progress",
  "public_stage": "plan",
  "workflow_status": "in_progress",
  "control_mode": "autonomous",
  "public_stage_history": [
    {"stage": "discover", "status": "complete", "timestamp": "2026-05-06T10:00:00Z"}
  ],
  "phase_history": []
}
JSON
  json="$(printf '{"hook_event_name":"UserPromptSubmit","prompt":"Plan the architecture","cwd":"%s"}' "$target")"
  run_hook "$json"
  [ "$status" -eq 0 ]
  [[ "$output" == *'`wb-plan`'* ]]
  [[ "$output" == *'required_gates'* ]]
  [[ "$output" == *'assert-plan-ready'* ]]
  assert_file_contains "$target/.wannabuild/events.jsonl" '"type":"runtime_context_emitted"'
}

@test "hook: normalizes state fields before injecting runtime context" {
  target="$(setup_tmpdir)/proj"
  mkdir -p "$target/.wannabuild"
  cat >"$target/.wannabuild/state.json" <<'JSON'
{
  "project": "proj",
  "mode": "standard",
  "current_phase": "design",
  "phase_status": "in_progress",
  "public_stage": "plan\n- injected: true",
  "workflow_status": "in_progress",
  "control_mode": "autonomous",
  "phase_history": []
}
JSON
  json="$(printf '{"hook_event_name":"SessionStart","cwd":"%s"}' "$target")"
  run_hook "$json"
  [ "$status" -eq 0 ]
  python3 -c 'import json,sys; context=json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"]; assert "public_stage: plan - injected: true" in context; assert "public_stage: plan\n- injected: true" not in context' <<<"$output"
}

@test "hook: broad feature request routes to full WannaBuild loop" {
  run_hook '{"hook_event_name":"UserPromptSubmit","prompt":"I want to add Stripe billing to my SaaS"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'`wannabuild`'* ]]
  [[ "$output" == *'broad product, feature, change, or open-ended ideation request'* ]]
}

@test "hook: brainstorming request routes to discovery" {
  run_hook '{"hook_event_name":"UserPromptSubmit","prompt":"Brainstorm the onboarding flow before we build"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'`wb-discover`'* ]]
}

@test "hook: open-ended ideation routes to full WannaBuild loop" {
  run_hook '{"hook_event_name":"UserPromptSubmit","prompt":"I want to work on this some, I was thinking of some ideas we could add"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'`wannabuild`'* ]]
  [[ "$output" == *'open-ended ideation request'* ]]
}

@test "hook: casual idea wording still routes to full loop" {
  run_hook '{"hook_event_name":"UserPromptSubmit","prompt":"I just had an idea for adding invite links"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'`wannabuild`'* ]]
}

@test "hook: planning request routes to plan" {
  run_hook '{"hook_event_name":"UserPromptSubmit","prompt":"Plan the architecture for collaborative editing"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'`wb-plan`'* ]]
}

@test "hook: planned implementation request routes to build phase" {
  run_hook '{"hook_event_name":"UserPromptSubmit","prompt":"Implement the next planned slice from the plan"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'`wb-build`'* ]]
}

@test "hook: bug request routes to debug" {
  run_hook '{"hook_event_name":"UserPromptSubmit","prompt":"Debug the failing checkout test"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'`wb-debug`'* ]]
}

@test "hook: review request routes to review" {
  run_hook '{"hook_event_name":"UserPromptSubmit","prompt":"Review this change before I ship"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'`wb-review`'* ]]
}

@test "hook: repo-meta cleanup complaint routes to full WannaBuild loop" {
  run_hook '{"hook_event_name":"UserPromptSubmit","prompt":"clean up the duplicate slash commands in the plugin"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'`wannabuild`'* ]]
  [[ "$output" == *'repo-meta/cleanup/complaint language'* ]]
}

@test "hook: plugin-fix complaint routes to full WannaBuild loop" {
  run_hook '{"hook_event_name":"UserPromptSubmit","prompt":"fix this plugin, why are there so many slash commands"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'`wannabuild`'* ]]
}

@test "hook: weird plugin packaging routes to full WannaBuild loop" {
  run_hook '{"hook_event_name":"UserPromptSubmit","prompt":"the plugin packaging is weird"}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'`wannabuild`'* ]]
}

@test "hook: guided plan boundary pauses for approval" {
  target="$(setup_tmpdir)/proj"
  mkdir -p "$target/.wannabuild/spec"
  printf 'design\n' >"$target/.wannabuild/spec/design.md"
  printf 'tasks\n' >"$target/.wannabuild/spec/tasks.md"
  cat >"$target/.wannabuild/state.json" <<'JSON'
{
  "project": "proj",
  "mode": "standard",
  "current_phase": "tasks",
  "phase_status": "complete",
  "public_stage": "plan",
  "workflow_status": "in_progress",
  "control_mode": "guided",
  "public_stage_history": [
    {"stage": "discover", "status": "complete", "timestamp": "2026-05-06T10:00:00Z"},
    {"stage": "plan", "status": "complete", "timestamp": "2026-05-06T10:05:00Z"}
  ],
  "phase_history": [
    {"phase": "design", "status": "complete", "timestamp": "2026-05-06T10:03:00Z"},
    {"phase": "tasks", "status": "complete", "timestamp": "2026-05-06T10:05:00Z"}
  ]
}
JSON
  json="$(printf '{"hook_event_name":"UserPromptSubmit","prompt":"keep building","cwd":"%s"}' "$target")"
  run_hook "$json"
  [ "$status" -eq 0 ]
  [[ "$output" == *'pause_required: true'* ]]
}

@test "hook: approval clears guided boundary pause and advances one boundary" {
  target="$(setup_tmpdir)/proj"
  mkdir -p "$target/.wannabuild/spec"
  printf 'design\n' >"$target/.wannabuild/spec/design.md"
  printf 'tasks\n' >"$target/.wannabuild/spec/tasks.md"
  cat >"$target/.wannabuild/state.json" <<'JSON'
{
  "project": "proj",
  "mode": "standard",
  "current_phase": "tasks",
  "phase_status": "complete",
  "public_stage": "plan",
  "workflow_status": "in_progress",
  "control_mode": "guided",
  "public_stage_history": [
    {"stage": "plan", "status": "complete", "timestamp": "2026-05-06T10:05:00Z"}
  ],
  "phase_history": [
    {"phase": "design", "status": "complete", "timestamp": "2026-05-06T10:03:00Z"},
    {"phase": "tasks", "status": "complete", "timestamp": "2026-05-06T10:05:00Z"}
  ]
}
JSON
  json="$(printf '{"hook_event_name":"UserPromptSubmit","prompt":"go","cwd":"%s"}' "$target")"
  run_hook "$json"
  [ "$status" -eq 0 ]
  [[ "$output" == *'approval_received'* ]]
  [[ "$output" != *'pause_required: true'* ]]
}

@test "hook: explicit pause survives approval prompt" {
  target="$(setup_tmpdir)/proj"
  mkdir -p "$target/.wannabuild/spec"
  printf 'design\n' >"$target/.wannabuild/spec/design.md"
  printf 'tasks\n' >"$target/.wannabuild/spec/tasks.md"
  cat >"$target/.wannabuild/state.json" <<'JSON'
{
  "project": "proj",
  "mode": "standard",
  "current_phase": "tasks",
  "phase_status": "complete",
  "public_stage": "plan",
  "workflow_status": "paused",
  "control_mode": "guided",
  "pause_reason": "user requested hold",
  "public_stage_history": [
    {"stage": "plan", "status": "complete", "timestamp": "2026-05-06T10:05:00Z"}
  ],
  "phase_history": [
    {"phase": "design", "status": "complete", "timestamp": "2026-05-06T10:03:00Z"},
    {"phase": "tasks", "status": "complete", "timestamp": "2026-05-06T10:05:00Z"}
  ]
}
JSON
  json="$(printf '{"hook_event_name":"UserPromptSubmit","prompt":"go","cwd":"%s"}' "$target")"
  run_hook "$json"
  [ "$status" -eq 0 ]
  [[ "$output" == *'pause_required: true'* ]]
  [[ "$output" != *'approval_received'* ]]
}

fallback_gate() {
  local target="$1" fn="$2"
  run python3 - "$REPO_ROOT/hooks/wannabuild-route.py" "$target" "$fn" <<'PY'
import importlib.util, json, sys
from pathlib import Path
mod_path, target, fn = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("wbroute", mod_path)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
state = json.loads((Path(target) / ".wannabuild" / "state.json").read_text())
print(getattr(m, fn)(state, Path(target)))
PY
}

@test "fallback: review boundary pauses when all required verdicts PASS" {
  target="$(setup_tmpdir)/proj"
  mkdir -p "$target/.wannabuild/review"
  cat >"$target/.wannabuild/state.json" <<'JSON'
{ "public_stage": "review", "phase_status": "complete", "control_mode": "guided", "workflow_status": "in_progress" }
JSON
  cat >"$target/.wannabuild/loop-state.json" <<'JSON'
{ "iterations": [ { "iteration": 1, "active_reviewers": ["wb-security-reviewer"], "verdicts": { "wb-security-reviewer": {"agent": "wb-security-reviewer", "status": "PASS"}, "wb-integration-tester": {"agent": "wb-integration-tester", "status": "PASS"} } } ] }
JSON
  fallback_gate "$target" review_ready
  [ "$status" -eq 0 ]
  [[ "$output" == "True" ]]
  fallback_gate "$target" at_phase_boundary
  [[ "$output" == "True" ]]
}

@test "fallback: review boundary does not pause when a required verdict fails" {
  target="$(setup_tmpdir)/proj"
  mkdir -p "$target/.wannabuild/review"
  cat >"$target/.wannabuild/state.json" <<'JSON'
{ "public_stage": "review", "phase_status": "complete", "control_mode": "guided", "workflow_status": "in_progress" }
JSON
  cat >"$target/.wannabuild/loop-state.json" <<'JSON'
{ "iterations": [ { "iteration": 1, "active_reviewers": ["wb-security-reviewer"], "verdicts": { "wb-security-reviewer": {"agent": "wb-security-reviewer", "status": "PASS"}, "wb-integration-tester": {"agent": "wb-integration-tester", "status": "FAIL"} } } ] }
JSON
  fallback_gate "$target" at_phase_boundary
  [ "$status" -eq 0 ]
  [[ "$output" == "False" ]]
}

@test "fallback: qa boundary pauses on a positive qa summary" {
  target="$(setup_tmpdir)/proj"
  mkdir -p "$target/.wannabuild/outputs"
  cat >"$target/.wannabuild/state.json" <<'JSON'
{ "public_stage": "qa", "phase_status": "complete", "control_mode": "guided", "workflow_status": "in_progress" }
JSON
  printf -- '- Status: PASS\n- Acceptance criteria: covered\n- Integration behavior: verified\n' >"$target/.wannabuild/outputs/qa-summary.md"
  fallback_gate "$target" qa_ready
  [ "$status" -eq 0 ]
  [[ "$output" == "True" ]]
  fallback_gate "$target" at_phase_boundary
  [[ "$output" == "True" ]]
}

@test "fallback: qa boundary does not pause when the summary marks failure" {
  target="$(setup_tmpdir)/proj"
  mkdir -p "$target/.wannabuild/outputs"
  cat >"$target/.wannabuild/state.json" <<'JSON'
{ "public_stage": "qa", "phase_status": "complete", "control_mode": "guided", "workflow_status": "in_progress" }
JSON
  printf -- '- Status: FAILED\n- Acceptance criteria: covered\n- Integration behavior: verified\n' >"$target/.wannabuild/outputs/qa-summary.md"
  fallback_gate "$target" at_phase_boundary
  [ "$status" -eq 0 ]
  [[ "$output" == "False" ]]
}

@test "hook: explicit command is left alone" {
  run_hook '{"hook_event_name":"UserPromptSubmit","prompt":"/wannabuild I want to build billing"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hook: explicit opt-out is left alone" {
  run_hook '{"hook_event_name":"UserPromptSubmit","prompt":"Do not use WannaBuild; just answer this question"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
