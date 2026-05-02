#!/usr/bin/env bats
#
# Unit tests for scripts/validate-wannabuild-artifacts.sh
# Exercises CLI parsing, missing/invalid state detection, and per-phase
# transition checks. Each test is hermetic and uses $BATS_TEST_TMPDIR.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

setup() {
  TARGET="$(setup_tmpdir)/proj"
  make_target_repo "$TARGET" >/dev/null
}

@test "validate_artifacts: --help prints usage and exits 0" {
  run_script validate-wannabuild-artifacts.sh --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"<project_root>"* ]]
}

@test "validate_artifacts: exits non-zero with no args" {
  run_script validate-wannabuild-artifacts.sh
  [ "$status" -ne 0 ]
  [[ "$output" == *"expected 1-2 args"* ]]
}

@test "validate_artifacts: exits non-zero with too many args" {
  run_script validate-wannabuild-artifacts.sh "$TARGET" requirements extra
  [ "$status" -ne 0 ]
  [[ "$output" == *"expected 1-2 args"* ]]
}

@test "validate_artifacts: fails on nonexistent target dir" {
  run_script validate-wannabuild-artifacts.sh "${BATS_TEST_TMPDIR}/does-not-exist"
  [ "$status" -ne 0 ]
}

@test "validate_artifacts: rejects unknown phase argument" {
  make_state_json "$TARGET" requirements
  run_script validate-wannabuild-artifacts.sh "$TARGET" totally-bogus-phase
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown target phase"* ]] || [[ "$output" == *"target phase"* ]]
}

@test "validate_artifacts: accepts every documented valid phase name" {
  make_state_json "$TARGET" requirements
  for phase in requirements design tasks implement review ship document; do
    # Provide spec files as needed for downstream phases.
    write_spec "$TARGET" requirements.md
    write_spec "$TARGET" design.md
    write_spec "$TARGET" tasks.md
    # ship/document need an approved loop-state.
    if [[ "$phase" == "ship" || "$phase" == "document" ]]; then
      make_loop_state "$TARGET" pass
    fi
    run_script validate-wannabuild-artifacts.sh "$TARGET" "$phase"
    if [[ "$status" -ne 0 ]]; then
      echo "phase=$phase status=$status output=$output" >&2
      return 1
    fi
  done
}

@test "validate_artifacts: happy path target with state.json validates with exit 0" {
  make_state_json "$TARGET" requirements
  run_script validate-wannabuild-artifacts.sh "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Validation passed"* ]]
}

@test "validate_artifacts: rejects target missing state.json" {
  # No state.json was written.
  run_script validate-wannabuild-artifacts.sh "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing required file"* ]]
  [[ "$output" == *"state.json"* ]]
}

@test "validate_artifacts: rejects invalid JSON in state.json" {
  mkdir -p "$TARGET/.wannabuild"
  printf 'not json {{{' > "$TARGET/.wannabuild/state.json"
  run_script validate-wannabuild-artifacts.sh "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid JSON"* ]]
}

@test "validate_artifacts: rejects state.json missing required fields" {
  mkdir -p "$TARGET/.wannabuild"
  cp "${FIXTURES_DIR}/state-invalid-missing-id.json" "$TARGET/.wannabuild/state.json"
  run_script validate-wannabuild-artifacts.sh "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing required key: project"* ]]
}

@test "validate_artifacts: rejects design transition without requirements.md" {
  make_state_json "$TARGET" design
  # No requirements.md written.
  run_script validate-wannabuild-artifacts.sh "$TARGET" design
  [ "$status" -ne 0 ]
  [[ "$output" == *"requirements.md"* ]]
}

@test "validate_artifacts: validates loop-state with approved status" {
  make_state_json "$TARGET" implement
  make_loop_state "$TARGET" pass
  run_script validate-wannabuild-artifacts.sh "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Validation passed"* ]]
}

@test "validate_artifacts: rejects loop-state with bad status enum" {
  make_state_json "$TARGET" implement
  mkdir -p "$TARGET/.wannabuild"
  cat > "$TARGET/.wannabuild/loop-state.json" <<'EOF'
{
  "current_iteration": 0,
  "max_iterations": 1,
  "base_reviewer_count": 1,
  "status": "totally-bogus",
  "iterations": []
}
EOF
  run_script validate-wannabuild-artifacts.sh "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"loop-state.json.status invalid"* ]]
}

@test "validate_artifacts: ship transition blocked when loop-state is not approved" {
  make_state_json "$TARGET" implement
  write_spec "$TARGET" requirements.md
  write_spec "$TARGET" tasks.md
  make_loop_state "$TARGET" fail
  run_script validate-wannabuild-artifacts.sh "$TARGET" ship
  [ "$status" -ne 0 ]
  [[ "$output" == *"ship/document"* ]]
}
