#!/usr/bin/env bats
#
# Unit tests for the Claude Code natural-language autorouter hook.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

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

@test "hook: planned implementation request routes to build toolbox" {
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
