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

@test "session: assert-plan-ready fails closed when runtime is unavailable" {
  fake_repo="$(setup_tmpdir)/fake-repo"
  fake_home="$(setup_tmpdir)/empty-home"
  mkdir -p "$fake_repo/scripts"
  cp "$SCRIPTS_DIR/wannabuild-session.sh" "$fake_repo/scripts/wannabuild-session.sh"

  set +e
  actual_output="$(env -u WB_RUNTIME_BIN -u CODEX_HOME HOME="$fake_home" PATH="/usr/bin:/bin" \
    bash "$fake_repo/scripts/wannabuild-session.sh" assert-plan-ready "$TARGET" 2>&1)"
  actual_status=$?
  set -e

  [ "$actual_status" -eq 127 ]
  [[ "$actual_output" == *"Runtime unavailable: wb-runtime is required to evaluate the plan gate."* ]]
}

@test "session: assert-plan-ready finds Codex-installed runtime outside PATH" {
  fake_repo="$(setup_tmpdir)/fake-repo"
  codex_home="$(setup_tmpdir)/codex-home"
  mkdir -p "$fake_repo/scripts" "$codex_home/bin"
  cp "$SCRIPTS_DIR/wannabuild-session.sh" "$fake_repo/scripts/wannabuild-session.sh"
  cat >"$codex_home/bin/wb-runtime" <<'SH'
#!/usr/bin/env bash
echo "Plan gate OK: codex-runtime-bin"
SH
  chmod +x "$codex_home/bin/wb-runtime"

  run env -u WB_RUNTIME_BIN CODEX_HOME="$codex_home" PATH="/usr/bin:/bin" \
    bash "$fake_repo/scripts/wannabuild-session.sh" assert-plan-ready "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"codex-runtime-bin"* ]]
}

@test "session: assert-plan-ready passes with plan artifacts" {
  mkdir -p "$TARGET/.wannabuild/spec"
  printf 'design\n' >"$TARGET/.wannabuild/spec/design.md"
  printf 'tasks\n' >"$TARGET/.wannabuild/spec/tasks.md"
  run_script wannabuild-session.sh assert-plan-ready "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Plan gate OK"* ]]
}

@test "session: assert-plan-ready rejects completed plan marker without real evidence" {
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
  [ "$status" -ne 0 ]
  [[ "$output" == *"Plan gate failed"* ]]
}

@test "session: assert-plan-ready passes with completed design and tasks phase history" {
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
    {"stage": "discover", "status": "complete", "timestamp": "2026-05-06T10:00:00Z"}
  ],
  "phase_history": [
    {"phase": "design", "status": "complete", "timestamp": "2026-05-06T10:03:00Z"},
    {"phase": "tasks", "status": "complete", "timestamp": "2026-05-06T10:05:00Z"}
  ]
}
JSON
  run_script wannabuild-session.sh assert-plan-ready "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"phase_history.design+tasks"* ]]
}

@test "session: show fails before init" {
  run_script wannabuild-session.sh show "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"state.json not found"* ]]
}
