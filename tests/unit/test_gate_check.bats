#!/usr/bin/env bats
#
# Unit tests for scripts/wannabuild-gate-check.sh

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

setup_file() {
  cargo build --quiet --manifest-path "$REPO_ROOT/Cargo.toml" --bin wb-runtime
  export WB_RUNTIME_BIN="$REPO_ROOT/target/debug/wb-runtime"
}

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

@test "gate_check: fails clearly when runtime is unavailable" {
  fake_repo="$(setup_tmpdir)/fake-repo"
  fake_home="$(setup_tmpdir)/empty-home"
  mkdir -p "$fake_repo/scripts"
  cp "$SCRIPTS_DIR/wannabuild-gate-check.sh" "$fake_repo/scripts/wannabuild-gate-check.sh"

  set +e
  actual_output="$(env -u WB_RUNTIME_BIN -u CODEX_HOME HOME="$fake_home" PATH="/usr/bin:/bin" \
    bash "$fake_repo/scripts/wannabuild-gate-check.sh" "$TARGET" review 2>&1)"
  actual_status=$?
  set -e

  [ "$actual_status" -eq 127 ]
  [[ "$actual_output" == *"Runtime unavailable: wb-runtime is required to evaluate the 'review' gate."* ]]
}

@test "gate_check: finds Codex-installed runtime outside PATH" {
  fake_repo="$(setup_tmpdir)/fake-repo"
  codex_home="$(setup_tmpdir)/codex-home"
  mkdir -p "$fake_repo/scripts" "$codex_home/bin"
  cp "$SCRIPTS_DIR/wannabuild-gate-check.sh" "$fake_repo/scripts/wannabuild-gate-check.sh"
  cat >"$codex_home/bin/wb-runtime" <<'SH'
#!/usr/bin/env bash
echo "Review gate OK: codex-runtime-bin"
SH
  chmod +x "$codex_home/bin/wb-runtime"

  set +e
  actual_output="$(env -u WB_RUNTIME_BIN CODEX_HOME="$codex_home" PATH="/usr/bin:/bin" \
    bash "$fake_repo/scripts/wannabuild-gate-check.sh" "$TARGET" review 2>&1)"
  actual_status=$?
  set -e

  [ "$actual_status" -eq 0 ]
  [[ "$actual_output" == *"codex-runtime-bin"* ]]
}

@test "gate_check: review gate fails when review dir is missing" {
  rmdir "$TARGET/.wannabuild/review"
  run_script wannabuild-gate-check.sh "$TARGET" review
  [ "$status" -ne 0 ]
  # With no loop-state and no review dir, the gate reports the missing required reviewers.
  [[ "$output" == *"Missing required review verdicts"* ]]
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
  [[ "$output" == *"Review gate OK"* ]]
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

@test "gate_check: review gate ignores superseded historical failures" {
  for agent in wb-security-reviewer wb-performance-reviewer \
               wb-architecture-reviewer wb-testing-reviewer \
               wb-integration-tester wb-code-simplifier; do
    cat >"$TARGET/.wannabuild/review/${agent}-iter-1.json" <<JSON
{"agent":"${agent}","status":"FAIL","summary":"old","issues":[]}
JSON
    cat >"$TARGET/.wannabuild/review/${agent}-iter-2.json" <<JSON
{"agent":"${agent}","status":"PASS","summary":"fixed","issues":[]}
JSON
  done

  run_script wannabuild-gate-check.sh "$TARGET" review
  [ "$status" -eq 0 ]
  [[ "$output" == *"Review gate OK"* ]]
}

@test "gate_check: qa gate fails when qa-summary is missing" {
  run_script wannabuild-gate-check.sh "$TARGET" qa
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing QA summary"* ]]
}

@test "gate_check: qa gate fails when qa-summary lacks positive evidence" {
  mkdir -p "$TARGET/.wannabuild/outputs"
  printf '# QA summary\n' > "$TARGET/.wannabuild/outputs/qa-summary.md"
  run_script wannabuild-gate-check.sh "$TARGET" qa
  [ "$status" -ne 0 ]
  [[ "$output" == *"lacks positive PASS evidence"* ]]
}

@test "gate_check: qa gate passes with structured pass coverage" {
  mkdir -p "$TARGET/.wannabuild/outputs"
  {
    printf '# QA summary\n\n'
    printf 'status: PASS\n'
    printf 'acceptance_coverage: covered\n'
    printf 'integration_coverage: covered\n'
  } > "$TARGET/.wannabuild/outputs/qa-summary.md"
  cat > "$TARGET/.wannabuild/review/wb-integration-tester-iter-1.json" <<'JSON'
{"agent":"wb-integration-tester","status":"PASS","summary":"ok","issues":[],"hard_gate":true,"test_execution":{"total":4,"passed":4,"failed":0,"errored":0,"duration_ms":80},"coverage_map":[{"criterion":"acceptance","status":"covered"}]}
JSON
  run_script wannabuild-gate-check.sh "$TARGET" qa
  [ "$status" -eq 0 ]
  [[ "$output" == *"Qa gate OK"* ]]
}

@test "gate_check: qa gate rejects latest failed QA event" {
  mkdir -p "$TARGET/.wannabuild/outputs"
  printf '# QA summary\n' > "$TARGET/.wannabuild/outputs/qa-summary.md"
  cat > "$TARGET/.wannabuild/events.jsonl" <<'JSONL'
{"id":"1","timestamp":"2026-05-06T10:00:00Z","type":"qa_passed","payload":{}}
{"id":"2","timestamp":"2026-05-06T10:01:00Z","type":"qa_failed","payload":{"reason":"integration failed"}}
JSONL
  run_script wannabuild-gate-check.sh "$TARGET" qa
  [ "$status" -ne 0 ]
  [[ "$output" == *"latest QA event is qa_failed"* ]]
}

@test "gate_check: qa gate rejects latest passed QA event without structured evidence" {
  mkdir -p "$TARGET/.wannabuild/outputs"
  printf '# QA summary\n' > "$TARGET/.wannabuild/outputs/qa-summary.md"
  cat > "$TARGET/.wannabuild/events.jsonl" <<'JSONL'
{"id":"1","timestamp":"2026-05-06T10:00:00Z","type":"qa_failed","payload":{"reason":"integration failed"}}
{"id":"2","timestamp":"2026-05-06T10:01:00Z","type":"qa_passed","payload":{}}
JSONL
  run_script wannabuild-gate-check.sh "$TARGET" qa
  [ "$status" -ne 0 ]
  [[ "$output" == *"lacks positive PASS evidence"* ]]
}

@test "gate_check: summary gate requires both review and qa to pass" {
  for agent in wb-security-reviewer wb-performance-reviewer \
               wb-architecture-reviewer wb-testing-reviewer \
               wb-integration-tester wb-code-simplifier; do
    write_review_verdict "$TARGET" "$agent" pass
  done
  mkdir -p "$TARGET/.wannabuild/outputs"
  {
    printf '# QA summary\n\n'
    printf 'status: PASS\n'
    printf 'acceptance_coverage: covered\n'
    printf 'integration_coverage: covered\n'
  } > "$TARGET/.wannabuild/outputs/qa-summary.md"
  run_script wannabuild-gate-check.sh "$TARGET" summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"Summary gate OK"* ]]
}
