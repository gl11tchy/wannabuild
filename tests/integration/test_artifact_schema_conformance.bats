#!/usr/bin/env bats
#
# Integration test: every fixture that claims to be a minimally-valid
# artifact passes the validator, and a corresponding mutation flips it to
# invalid.
#
# This is a behavioral conformance check: the validator's accept/reject
# behavior is the contract for the schemas in skills/internal/build/schemas/.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

setup() {
  TARGET="$(setup_tmpdir)/proj"
  make_target_repo "$TARGET" >/dev/null
}

@test "schema_conformance: state-requirements fixture is accepted" {
  make_state_json "$TARGET" requirements
  run_script validate-wannabuild-artifacts.sh "$TARGET"
  [ "$status" -eq 0 ]
}

@test "schema_conformance: state-design fixture is accepted (with requirements.md)" {
  make_state_json "$TARGET" design
  write_spec "$TARGET" requirements.md
  run_script validate-wannabuild-artifacts.sh "$TARGET" design
  [ "$status" -eq 0 ]
}

@test "schema_conformance: state-tasks fixture is accepted (with requirements.md and design.md)" {
  make_state_json "$TARGET" tasks
  write_spec "$TARGET" requirements.md
  write_spec "$TARGET" design.md
  run_script validate-wannabuild-artifacts.sh "$TARGET" tasks
  [ "$status" -eq 0 ]
}

@test "schema_conformance: state-implement fixture is accepted (with requirements.md and tasks.md)" {
  make_state_json "$TARGET" implement
  write_spec "$TARGET" requirements.md
  write_spec "$TARGET" tasks.md
  run_script validate-wannabuild-artifacts.sh "$TARGET" implement
  [ "$status" -eq 0 ]
}

@test "schema_conformance: invalid state fixture is rejected" {
  mkdir -p "$TARGET/.wannabuild"
  cp "$FIXTURES_DIR/state-invalid-missing-id.json" "$TARGET/.wannabuild/state.json"
  run_script validate-wannabuild-artifacts.sh "$TARGET"
  [ "$status" -ne 0 ]
}

@test "schema_conformance: loop-state-pass fixture is accepted alongside implement state" {
  make_state_json "$TARGET" implement
  make_loop_state "$TARGET" pass
  run_script validate-wannabuild-artifacts.sh "$TARGET"
  [ "$status" -eq 0 ]
}

@test "schema_conformance: mutating loop-state fixture to a bad enum value is rejected" {
  make_state_json "$TARGET" implement
  make_loop_state "$TARGET" pass
  python3 - "$TARGET/.wannabuild/loop-state.json" <<'PY'
import json,sys
p = sys.argv[1]
d = json.load(open(p))
d["status"] = "totally-bogus"
open(p, "w").write(json.dumps(d))
PY
  run_script validate-wannabuild-artifacts.sh "$TARGET"
  [ "$status" -ne 0 ]
}

@test "schema_conformance: review verdict fixture is accepted as part of review dir" {
  make_state_json "$TARGET" implement
  cp "$FIXTURES_DIR/review-verdict-valid.json" "$TARGET/.wannabuild/review/wb-security-reviewer-iter-1.json"
  run_script validate-wannabuild-artifacts.sh "$TARGET"
  [ "$status" -eq 0 ]
}

@test "schema_conformance: review verdict mutated to invalid status is rejected" {
  make_state_json "$TARGET" implement
  cp "$FIXTURES_DIR/review-verdict-valid.json" "$TARGET/.wannabuild/review/wb-security-reviewer-iter-1.json"
  python3 - "$TARGET/.wannabuild/review/wb-security-reviewer-iter-1.json" <<'PY'
import json,sys
p = sys.argv[1]
d = json.load(open(p))
d["status"] = "MAYBE"
open(p, "w").write(json.dumps(d))
PY
  run_script validate-wannabuild-artifacts.sh "$TARGET"
  [ "$status" -ne 0 ]
}

@test "schema_conformance: checkpoint missing required field is rejected" {
  make_state_json "$TARGET" implement
  mkdir -p "$TARGET/.wannabuild/checkpoints"
  # Missing "Verify:" required field.
  cat > "$TARGET/.wannabuild/checkpoints/task-T-bad-step-1.md" <<'EOF'
Task: T-bad
Step: 1
Changed Files: src/foo.py
Result: PASS
Next: continue
EOF
  run_script validate-wannabuild-artifacts.sh "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Verify:"* ]]
}
