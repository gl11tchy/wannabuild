#!/usr/bin/env bats
#
# End-to-end runtime flow coverage for gates, transitions, tasks, and adapters.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

setup_file() {
  cargo build --quiet --manifest-path "$REPO_ROOT/Cargo.toml" --bin wb-runtime
  export WB_RUNTIME_BIN="$REPO_ROOT/target/debug/wb-runtime"
}

setup() {
  TARGET="$(setup_tmpdir)/proj"
  make_target_repo "$TARGET" >/dev/null
}

write_all_review_verdicts() {
  local status_kind="${1:-PASS}"
  for agent in wb-security-reviewer wb-performance-reviewer \
               wb-architecture-reviewer wb-testing-reviewer \
               wb-integration-tester wb-code-simplifier; do
    cat >"$TARGET/.wannabuild/review/${agent}-iter-1.json" <<JSON
{"agent":"${agent}","status":"${status_kind}","summary":"fixture","issues":[]}
JSON
  done
}

@test "runtime_flow: no concrete task blocks planning" {
  run "$WB_RUNTIME_BIN" transition --project "$TARGET" --to plan
  [ "$status" -ne 0 ]
  [[ "$output" == *"Concrete task gate failed"* ]]
  assert_file_contains "$TARGET/.wannabuild/events.jsonl" '"type":"transition_denied"'
}

@test "runtime_flow: plan incomplete blocks implementation and plan complete allows it" {
  write_spec "$TARGET" requirements.md "requirements\n"
  run "$WB_RUNTIME_BIN" transition --project "$TARGET" --to plan
  [ "$status" -eq 0 ]

  run "$WB_RUNTIME_BIN" transition --project "$TARGET" --to plan --status complete
  [ "$status" -ne 0 ]
  [[ "$output" == *"Plan completion denied"* ]]

  run "$WB_RUNTIME_BIN" transition --project "$TARGET" --to implement
  [ "$status" -ne 0 ]
  [[ "$output" == *"Plan gate failed"* ]]

  write_spec "$TARGET" design.md "design\n"
  write_spec "$TARGET" tasks.md "tasks\n"
  run "$WB_RUNTIME_BIN" transition --project "$TARGET" --to implement
  [ "$status" -eq 0 ]
  assert_file_contains "$TARGET/.wannabuild/state.json" '"public_stage": "implement"'
}

@test "runtime_flow: task checkpoint resume and safe claim semantics" {
  cat >"$TARGET/.wannabuild/spec/tasks.md" <<'TASKS'
# Tasks

## Task T-001: First

- Phase: implement
- Dependencies: none
- Acceptance criteria:
  - First complete.

## Task T-002: Second

- Phase: implement
- Dependencies: T-001
- Acceptance criteria:
  - Second ready after first.
TASKS

  run "$WB_RUNTIME_BIN" tasks import --project "$TARGET" --from "$TARGET/.wannabuild/spec/tasks.md"
  [ "$status" -eq 0 ]

  run "$WB_RUNTIME_BIN" tasks claim --project "$TARGET" --task T-001 --owner owner-a
  [ "$status" -ne 0 ]
  [[ "$output" == *"Plan gate failed"* ]]

  write_spec "$TARGET" design.md "design\n"

  run "$WB_RUNTIME_BIN" tasks claim --project "$TARGET" --task T-002 --owner owner-a
  [ "$status" -ne 0 ]
  [[ "$output" == *"dependencies are not complete"* ]]

  run "$WB_RUNTIME_BIN" tasks complete --project "$TARGET" --task T-002
  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot be completed from status pending"* ]]

  run "$WB_RUNTIME_BIN" tasks next --project "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"next_task: T-001"* ]]
  assert_file_contains "$TARGET/.wannabuild/decisions.md" "Scheduler Decision"
  assert_file_contains "$TARGET/.wannabuild/decisions.md" "- scheduler: single-owner"
  assert_file_contains "$TARGET/.wannabuild/decisions.md" "- next_task: T-001 First"

  run "$WB_RUNTIME_BIN" tasks claim --project "$TARGET" --task T-001 --owner owner-a
  [ "$status" -eq 0 ]

  run "$WB_RUNTIME_BIN" tasks claim --project "$TARGET" --task T-001 --owner owner-b
  [ "$status" -ne 0 ]
  [[ "$output" == *"already claimed"* ]]

  run "$WB_RUNTIME_BIN" tasks complete --project "$TARGET" --task T-001
  [ "$status" -ne 0 ]
  [[ "$output" == *"requires --checkpoint"* ]]

  write_checkpoint "$TARGET" 1 1
  run "$WB_RUNTIME_BIN" tasks complete --project "$TARGET" --task T-001 --checkpoint "$TARGET/.wannabuild/checkpoints/task-1-step-1.md"
  [ "$status" -eq 0 ]
  assert_file_contains "$TARGET/.wannabuild/tasks.json" '"checkpoint_path"'
  assert_file_contains "$TARGET/.wannabuild/events.jsonl" '"type":"checkpoint_written"'

  run "$WB_RUNTIME_BIN" tasks next --project "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"next_task: T-002"* ]]
}

@test "runtime_flow: tasks block records blocker and checkpoint paths stay confined" {
  cat >"$TARGET/.wannabuild/spec/tasks.md" <<'TASKS'
# Tasks

## Task T-001: First

- Phase: implement
- Dependencies: none
- Acceptance criteria:
  - First complete.
TASKS

  run "$WB_RUNTIME_BIN" tasks import --project "$TARGET" --from "$TARGET/.wannabuild/spec/tasks.md"
  [ "$status" -eq 0 ]
  write_spec "$TARGET" design.md "design\n"

  run "$WB_RUNTIME_BIN" tasks claim --project "$TARGET" --task T-001 --owner owner-a
  [ "$status" -eq 0 ]

  printf 'outside\n' >"$TARGET/checkpoint.md"
  run "$WB_RUNTIME_BIN" tasks complete --project "$TARGET" --task T-001 --checkpoint "$TARGET/checkpoint.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Checkpoint path must be inside"* ]]

  run "$WB_RUNTIME_BIN" tasks block --project "$TARGET" --task T-001 --reason "waiting on API"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"status": "blocked"'* ]]
  [[ "$output" == *'"blocked_reason": "waiting on API"'* ]]
  assert_file_contains "$TARGET/.wannabuild/events.jsonl" '"type":"task_blocked"'
}

@test "runtime_flow: review and QA evidence gate summary readiness" {
  mkdir -p "$TARGET/.wannabuild/outputs"
  {
    printf '# QA summary\n\n'
    printf 'status: PASS\n'
    printf 'acceptance_coverage: covered\n'
    printf 'integration_coverage: covered\n'
  } >"$TARGET/.wannabuild/outputs/qa-summary.md"

  run "$WB_RUNTIME_BIN" assert-summary-ready --project "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Review gate failed"* ]]

  write_all_review_verdicts FAIL
  run "$WB_RUNTIME_BIN" assert-summary-ready --project "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Non-passing review verdicts"* ]]

  write_all_review_verdicts PASS
  rm "$TARGET/.wannabuild/outputs/qa-summary.md"
  run "$WB_RUNTIME_BIN" assert-summary-ready --project "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"QA gate failed"* ]]

  printf '# QA summary\n\nstatus: failed\n' >"$TARGET/.wannabuild/outputs/qa-summary.md"
  run "$WB_RUNTIME_BIN" assert-qa-ready --project "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"QA summary marks status as failed"* ]]

  printf '# QA summary\n' >"$TARGET/.wannabuild/outputs/qa-summary.md"
  run "$WB_RUNTIME_BIN" assert-qa-ready --project "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"lacks positive PASS evidence"* ]]

  run "$WB_RUNTIME_BIN" event append --project "$TARGET" --type qa_failed --json '{"reason":"integration failed"}'
  [ "$status" -eq 0 ]
  run "$WB_RUNTIME_BIN" assert-qa-ready --project "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"latest QA event is qa_failed"* ]]

  run "$WB_RUNTIME_BIN" event append --project "$TARGET" --type qa_passed
  [ "$status" -eq 0 ]
  run "$WB_RUNTIME_BIN" assert-qa-ready --project "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"lacks positive PASS evidence"* ]]

  {
    printf '# QA summary\n\n'
    printf 'status: PASS\n'
    printf 'acceptance_coverage: covered\n'
    printf 'integration_coverage: covered\n'
  } >"$TARGET/.wannabuild/outputs/qa-summary.md"
  run "$WB_RUNTIME_BIN" assert-summary-ready --project "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Summary gate OK"* ]]
}

@test "runtime_flow: adapter context is equivalent across hosts" {
  run "$WB_RUNTIME_BIN" init --project "$TARGET"
  [ "$status" -eq 0 ]

  run "$WB_RUNTIME_BIN" adapter context --project "$TARGET" --host claude-code --event SessionStart
  [ "$status" -eq 0 ]
  claude_action="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["allowed_next_action"])' <<<"$output")"
  claude_required="$(python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)["required_gates"]))' <<<"$output")"
  claude_forbidden="$(python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)["forbidden_actions"]))' <<<"$output")"
  claude_pause="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["pause_required"])' <<<"$output")"

  run "$WB_RUNTIME_BIN" adapter context --project "$TARGET" --host codex --event bootstrap
  [ "$status" -eq 0 ]
  codex_action="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["allowed_next_action"])' <<<"$output")"
  codex_required="$(python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)["required_gates"]))' <<<"$output")"
  codex_forbidden="$(python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)["forbidden_actions"]))' <<<"$output")"
  codex_pause="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["pause_required"])' <<<"$output")"

  [ "$claude_action" = "$codex_action" ]

  run "$WB_RUNTIME_BIN" adapter context --project "$TARGET" --host cursor --event bootstrap
  [ "$status" -eq 0 ]
  cursor_action="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["allowed_next_action"])' <<<"$output")"
  cursor_required="$(python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)["required_gates"]))' <<<"$output")"
  cursor_forbidden="$(python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)["forbidden_actions"]))' <<<"$output")"
  cursor_pause="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["pause_required"])' <<<"$output")"

  [ "$claude_action" = "$cursor_action" ]
  [ "$claude_required" = "$cursor_required" ]
  [ "$claude_forbidden" = "$cursor_forbidden" ]
  [ "$claude_pause" = "$cursor_pause" ]
  [ "$codex_required" = "$cursor_required" ]
  [ "$codex_forbidden" = "$cursor_forbidden" ]
  [ "$codex_pause" = "$cursor_pause" ]
  [[ "$cursor_required" == *"assert-plan-ready"* ]]

  # Factory is a fourth supported host. The runtime treats it via the
  # wildcard branch of normalize_host(); this assertion pins that the
  # context computed for it stays identical to the explicitly-named hosts
  # so a future refactor can't quietly diverge.
  run "$WB_RUNTIME_BIN" adapter context --project "$TARGET" --host factory --event bootstrap
  [ "$status" -eq 0 ]
  factory_action="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["allowed_next_action"])' <<<"$output")"
  factory_required="$(python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)["required_gates"]))' <<<"$output")"
  factory_forbidden="$(python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)["forbidden_actions"]))' <<<"$output")"
  factory_pause="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["pause_required"])' <<<"$output")"

  [ "$claude_action" = "$factory_action" ]
  [ "$claude_required" = "$factory_required" ]
  [ "$claude_forbidden" = "$factory_forbidden" ]
  [ "$claude_pause" = "$factory_pause" ]

  run "$WB_RUNTIME_BIN" adapter route --project "$TARGET" --host cursor --prompt "I want to add billing"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"route": "wannabuild"'* ]]
}
