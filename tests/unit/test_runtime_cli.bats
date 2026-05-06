#!/usr/bin/env bats
#
# Unit tests for the wb-runtime CLI and shell compatibility wrapper.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

setup_file() {
  cargo build --quiet --manifest-path "$REPO_ROOT/Cargo.toml" --bin wb-runtime
  export WB_RUNTIME_BIN="$REPO_ROOT/target/debug/wb-runtime"
}

setup() {
  TARGET="$(setup_tmpdir)/proj"
  mkdir -p "$TARGET"
}

@test "runtime_cli: help exposes command groups" {
  run "$WB_RUNTIME_BIN" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"status"* ]]
  [[ "$output" == *"assert-plan-ready"* ]]
  [[ "$output" == *"event"* ]]
  [[ "$output" == *"tasks"* ]]
  [[ "$output" == *"adapter"* ]]
}

@test "runtime_cli: plan gate fails before plan evidence exists" {
  run "$WB_RUNTIME_BIN" assert-plan-ready --project "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Plan gate failed"* ]]
}

@test "runtime_cli: plan complete transition cannot create its own gate evidence" {
  mkdir -p "$TARGET/.wannabuild/spec"
  printf 'requirements\n' >"$TARGET/.wannabuild/spec/requirements.md"

  run "$WB_RUNTIME_BIN" transition --project "$TARGET" --to plan --status complete
  [ "$status" -ne 0 ]
  [[ "$output" == *"Plan completion denied"* ]]

  run "$WB_RUNTIME_BIN" assert-plan-ready --project "$TARGET"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Plan gate failed"* ]]
}

@test "runtime_cli: context emits JSON next action and required gate" {
  run "$WB_RUNTIME_BIN" init --project "$TARGET"
  [ "$status" -eq 0 ]

  run "$WB_RUNTIME_BIN" context --project "$TARGET" --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"runtime_active": true'* ]]
  [[ "$output" == *'"allowed_next_action"'* ]]
  [[ "$output" == *'"assert-plan-ready"'* ]]
}

@test "runtime_cli: session helper delegates plan gate to runtime when binary is on PATH" {
  mkdir -p "$TARGET/.wannabuild/spec"
  printf 'design\n' >"$TARGET/.wannabuild/spec/design.md"
  printf 'tasks\n' >"$TARGET/.wannabuild/spec/tasks.md"

  PATH="$REPO_ROOT/target/debug:$PATH" run_script wannabuild-session.sh assert-plan-ready "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Plan gate OK"* ]]
  assert_file_exists "$TARGET/.wannabuild/events.jsonl"
}

@test "runtime_cli: adapter route classifies prompt intents" {
  run "$WB_RUNTIME_BIN" adapter route --project "$TARGET" --host codex --prompt "Implement the next planned slice"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"route": "wb-build"'* ]]

  run "$WB_RUNTIME_BIN" adapter route --project "$TARGET" --host shell --prompt "ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"route": "continue-current-phase"'* ]]
  [[ "$output" == *'"vague_acknowledgment": true'* ]]
}

@test "runtime_cli: event replay reports count and last event id" {
  run "$WB_RUNTIME_BIN" event append --project "$TARGET" --type gate_checked --json '{"gate":"plan"}'
  [ "$status" -eq 0 ]

  run "$WB_RUNTIME_BIN" event replay --project "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"events_replayed": 1'* ]]
  [[ "$output" == *'"last_event_id":'* ]]
}

@test "runtime_cli: event append and list redact sensitive payload values" {
  run "$WB_RUNTIME_BIN" event append --project "$TARGET" --type runtime_context_emitted --json '{"token":"raw-token","message":"password=hunter2","nested":{"api_key":"raw-key","safe":"ok","items":["token=raw-nested","AKIAIOSFODNN7EXAMPLE"]}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"raw-token"* ]]
  [[ "$output" != *"raw-key"* ]]
  [[ "$output" != *"hunter2"* ]]
  [[ "$output" != *"raw-nested"* ]]
  [[ "$output" != *"AKIAIOSFODNN7EXAMPLE"* ]]

  run "$WB_RUNTIME_BIN" event list --project "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED]"* ]]
  [[ "$output" != *"raw-token"* ]]
  [[ "$output" != *"raw-key"* ]]
  [[ "$output" != *"hunter2"* ]]
  [[ "$output" != *"raw-nested"* ]]
  [[ "$output" != *"AKIAIOSFODNN7EXAMPLE"* ]]
}

@test "runtime_cli: status is read-only when state is missing" {
  run "$WB_RUNTIME_BIN" status --project "$TARGET"
  [ "$status" -eq 0 ]
  [[ ! -f "$TARGET/.wannabuild/state.json" ]]
}

@test "runtime_cli: context and adapter route are read-only when state is missing" {
  run "$WB_RUNTIME_BIN" context --project "$TARGET" --format json
  [ "$status" -eq 0 ]
  [[ ! -e "$TARGET/.wannabuild" ]]

  run "$WB_RUNTIME_BIN" adapter context --project "$TARGET" --host claude-code --event SessionStart
  [ "$status" -eq 0 ]
  [[ ! -e "$TARGET/.wannabuild" ]]

  run "$WB_RUNTIME_BIN" adapter route --project "$TARGET" --host codex --prompt "Plan this"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"route": "wb-plan"'* ]]
  [[ ! -e "$TARGET/.wannabuild" ]]
}

@test "runtime_cli: resume persists durable state and event evidence" {
  run "$WB_RUNTIME_BIN" init --project "$TARGET"
  [ "$status" -eq 0 ]

  run "$WB_RUNTIME_BIN" pause --project "$TARGET" --reason "operator requested pause"
  [ "$status" -eq 0 ]

  run "$WB_RUNTIME_BIN" resume --project "$TARGET"
  [ "$status" -eq 0 ]

  assert_file_contains "$TARGET/.wannabuild/state.json" '"workflow_status": "in_progress"'
  assert_file_contains "$TARGET/.wannabuild/state.json" '"phase_status": "in_progress"'
  assert_file_contains "$TARGET/.wannabuild/state.json" '"pause_reason": null'
  assert_file_contains "$TARGET/.wannabuild/events.jsonl" '"type":"workflow_resumed"'
}

@test "runtime_cli: adapter route covers direct phase intents for all hosts" {
  for host in claude-code codex cursor; do
    run "$WB_RUNTIME_BIN" adapter route --project "$TARGET" --host "$host" --prompt "Brainstorming-only: talk through onboarding"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"route": "wb-discover"'* ]]

    run "$WB_RUNTIME_BIN" adapter route --project "$TARGET" --host "$host" --prompt "Plan the architecture"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"route": "wb-plan"'* ]]

    run "$WB_RUNTIME_BIN" adapter route --project "$TARGET" --host "$host" --prompt "Implement the next planned slice"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"route": "wb-build"'* ]]

    run "$WB_RUNTIME_BIN" adapter route --project "$TARGET" --host "$host" --prompt "ok"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"route": "continue-current-phase"'* ]]
    [[ "$output" == *'"vague_acknowledgment": true'* ]]
  done
}

@test "runtime_cli: adapter route includes canonical router parity terms" {
  run "$WB_RUNTIME_BIN" adapter route --project "$TARGET" --host codex --prompt "Did we cover the requirements?"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"route": "wb-qa"'* ]]

  run "$WB_RUNTIME_BIN" adapter route --project "$TARGET" --host codex --prompt "Talk through requirements-only"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"route": "wb-discover"'* ]]
}
