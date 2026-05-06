#!/usr/bin/env bats
#
# Unit tests for scripts/wannabuild-session.sh
# Exercises the basic init/show/set-stage/set-control-mode/assert-stage flow.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

setup() {
  TARGET="$(setup_tmpdir)/proj"
  mkdir -p "$TARGET"
}

@test "session: prints usage when called with no args" {
  run_script wannabuild-session.sh
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "session: init creates state.json with required defaults" {
  run_script wannabuild-session.sh init "$TARGET"
  [ "$status" -eq 0 ]
  [ -f "$TARGET/.wannabuild/state.json" ]
  assert_file_contains "$TARGET/.wannabuild/state.json" '"public_stage": "discover"'
  assert_file_contains "$TARGET/.wannabuild/state.json" '"control_mode": "autonomous"'
  assert_file_contains "$TARGET/.wannabuild/state.json" '"workflow_status": "in_progress"'
}

@test "session: show after init prints the persisted state JSON" {
  run_script wannabuild-session.sh init "$TARGET"
  [ "$status" -eq 0 ]
  run_script wannabuild-session.sh show "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"public_stage"'* ]]
  [[ "$output" == *'"discover"'* ]]
}

@test "session: set-stage rejects unknown stage" {
  run_script wannabuild-session.sh init "$TARGET"
  [ "$status" -eq 0 ]
  run_script wannabuild-session.sh set-stage "$TARGET" totally-bogus-stage in_progress
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown stage"* ]]
}

@test "session: set-stage advances the public stage and appends history" {
  run_script wannabuild-session.sh init "$TARGET"
  run_script wannabuild-session.sh set-stage "$TARGET" plan in_progress
  [ "$status" -eq 0 ]
  assert_file_contains "$TARGET/.wannabuild/state.json" '"public_stage": "plan"'
  # History should contain both stages.
  assert_file_contains "$TARGET/.wannabuild/state.json" '"stage": "discover"'
  assert_file_contains "$TARGET/.wannabuild/state.json" '"stage": "plan"'
}

@test "session: set-control-mode rejects unknown mode" {
  run_script wannabuild-session.sh init "$TARGET"
  run_script wannabuild-session.sh set-control-mode "$TARGET" sneaky-mode
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown control mode"* ]]
}

@test "session: set-control-mode autonomous updates state" {
  run_script wannabuild-session.sh init "$TARGET"
  run_script wannabuild-session.sh set-control-mode "$TARGET" autonomous
  [ "$status" -eq 0 ]
  assert_file_contains "$TARGET/.wannabuild/state.json" '"control_mode": "autonomous"'
}

@test "session: assert-stage succeeds on match, fails on mismatch" {
  run_script wannabuild-session.sh init "$TARGET"
  run_script wannabuild-session.sh assert-stage "$TARGET" discover
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stage OK: discover"* ]]

  run_script wannabuild-session.sh assert-stage "$TARGET" plan
  [ "$status" -ne 0 ]
}

@test "session: assert-plan-ready fails before plan is complete" {
  run_script wannabuild-session.sh init "$TARGET"
  run_script wannabuild-session.sh assert-plan-ready "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Plan gate failed"* ]]
}

@test "session: assert-plan-ready passes with plan artifacts" {
  mkdir -p "$TARGET/.wannabuild/spec"
  printf 'design\n' >"$TARGET/.wannabuild/spec/design.md"
  printf 'tasks\n' >"$TARGET/.wannabuild/spec/tasks.md"
  run_script wannabuild-session.sh assert-plan-ready "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Plan gate OK"* ]]
}

@test "session: assert-plan-ready passes with completed plan marker" {
  mkdir -p "$TARGET/.wannabuild"
  cat >"$TARGET/.wannabuild/state.json" <<'JSON'
{
  "project": "proj",
  "mode": "standard",
  "current_phase": "implement",
  "phase_status": "in_progress",
  "public_stage": "implement",
  "workflow_status": "in_progress",
  "control_mode": "autonomous",
  "public_stage_history": [
    {"stage": "discover", "status": "complete", "timestamp": "2026-05-06T10:00:00Z"},
    {"stage": "plan", "status": "complete", "timestamp": "2026-05-06T10:05:00Z"}
  ],
  "phase_history": []
}
JSON
  run_script wannabuild-session.sh assert-plan-ready "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"public_stage_history.plan"* ]]
}

@test "session: show fails before init" {
  run_script wannabuild-session.sh show "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"state.json not found"* ]]
}
