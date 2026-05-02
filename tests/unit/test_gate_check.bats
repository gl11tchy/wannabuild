#!/usr/bin/env bats
#
# Unit tests for scripts/wannabuild-gate-check.sh

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

setup() {
  TARGET="$(setup_tmpdir)/proj"
  make_target_repo "$TARGET" >/dev/null
}

@test "gate_check: prints usage and exits non-zero with no args" {
  run_script wannabuild-gate-check.sh
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "gate_check: rejects unknown gate name" {
  run_script wannabuild-gate-check.sh "$TARGET" totally-bogus-gate
  [ "$status" -ne 0 ]
}

@test "gate_check: review gate fails when review dir is missing" {
  rm -rf "$TARGET/.wannabuild/review"
  run_script wannabuild-gate-check.sh "$TARGET" review
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing review directory"* ]]
}

@test "gate_check: review gate fails when review dir is empty" {
  run_script wannabuild-gate-check.sh "$TARGET" review
  [ "$status" -ne 0 ]
  [[ "$output" == *"No review verdict files"* ]]
}

@test "gate_check: review gate fails when required reviewer is missing" {
  # Only one verdict — missing the others required by default.
  write_review_verdict "$TARGET" wb-security-reviewer pass
  run_script wannabuild-gate-check.sh "$TARGET" review
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing required review verdicts"* ]]
}

@test "gate_check: review gate passes when all default reviewers pass" {
  for agent in wb-security-reviewer wb-performance-reviewer \
               wb-architecture-reviewer wb-testing-reviewer \
               wb-integration-tester wb-code-simplifier; do
    write_review_verdict "$TARGET" "$agent" pass
  done
  run_script wannabuild-gate-check.sh "$TARGET" review
  [ "$status" -eq 0 ]
  [[ "$output" == *"Gate OK: review"* ]]
}

@test "gate_check: review gate fails when any reviewer FAILs" {
  for agent in wb-security-reviewer wb-performance-reviewer \
               wb-architecture-reviewer wb-testing-reviewer \
               wb-integration-tester wb-code-simplifier; do
    write_review_verdict "$TARGET" "$agent" pass
  done
  # Overwrite one to FAIL.
  write_review_verdict "$TARGET" wb-security-reviewer fail
  run_script wannabuild-gate-check.sh "$TARGET" review
  [ "$status" -ne 0 ]
  [[ "$output" == *"Non-passing review verdicts"* ]]
}

@test "gate_check: qa gate fails when qa-summary is missing" {
  run_script wannabuild-gate-check.sh "$TARGET" qa
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing QA summary"* ]]
}

@test "gate_check: qa gate passes when qa-summary exists" {
  mkdir -p "$TARGET/.wannabuild/outputs"
  printf '# QA summary\n' > "$TARGET/.wannabuild/outputs/qa-summary.md"
  run_script wannabuild-gate-check.sh "$TARGET" qa
  [ "$status" -eq 0 ]
  [[ "$output" == *"Gate OK: qa"* ]]
}

@test "gate_check: summary gate requires both review and qa to pass" {
  for agent in wb-security-reviewer wb-performance-reviewer \
               wb-architecture-reviewer wb-testing-reviewer \
               wb-integration-tester wb-code-simplifier; do
    write_review_verdict "$TARGET" "$agent" pass
  done
  mkdir -p "$TARGET/.wannabuild/outputs"
  printf '# QA summary\n' > "$TARGET/.wannabuild/outputs/qa-summary.md"
  run_script wannabuild-gate-check.sh "$TARGET" summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"Gate OK: summary"* ]]
}
