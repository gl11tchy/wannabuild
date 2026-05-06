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
