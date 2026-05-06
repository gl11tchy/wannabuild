#!/usr/bin/env bats
#
# Cross-host routing parity.
#
# CLAUDE.md and AGENTS.md treat Codex and Claude Code as co-primary, with
# Cursor and Factory as supported hosts. Today the runtime classifies
# prompts host-independently — this test pins that invariant so a future
# refactor can't silently introduce per-host divergence.
#
# For each canonical phase prompt, all four hosts must return:
#   - the expected route (e.g., "wb-plan" for planning prompts)
#   - the same route value as every other host
#
# If this test fails, the orchestrator's "co-primary" claim has broken —
# users on different hosts would experience different behavior for the
# same natural-language input.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

HOSTS=(claude-code codex cursor factory)

setup_file() {
  cargo build --quiet --manifest-path "$REPO_ROOT/Cargo.toml" --bin wb-runtime
  export WB_RUNTIME_BIN="$REPO_ROOT/target/debug/wb-runtime"
}

route_for() {
  local host="$1" prompt="$2" project="$3"
  "$WB_RUNTIME_BIN" adapter route --project "$project" --host "$host" --prompt "$prompt" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["route"])'
}

assert_parity() {
  local prompt="$1" expected="$2" project="$3"
  local first_route=""
  for host in "${HOSTS[@]}"; do
    local actual
    actual="$(route_for "$host" "$prompt" "$project")"
    if [[ -z "$first_route" ]]; then
      first_route="$actual"
    fi
    if [[ "$actual" != "$expected" ]]; then
      echo "expected '$expected' from $host for prompt '$prompt', got '$actual'" >&2
      return 1
    fi
    if [[ "$actual" != "$first_route" ]]; then
      echo "host divergence: $host returned '$actual', earlier hosts returned '$first_route'" >&2
      return 1
    fi
  done
}

@test "host parity: broad feature prompts route to wannabuild on every host" {
  project="$(setup_tmpdir)/proj"
  make_target_repo "$project" >/dev/null
  "$WB_RUNTIME_BIN" init --project "$project" >/dev/null
  assert_parity "I want to add Stripe billing to my SaaS" "wannabuild" "$project"
  assert_parity "let's build a settings page" "wannabuild" "$project"
}

@test "host parity: planning prompts route to wb-plan on every host" {
  project="$(setup_tmpdir)/proj"
  make_target_repo "$project" >/dev/null
  "$WB_RUNTIME_BIN" init --project "$project" >/dev/null
  assert_parity "plan this" "wb-plan" "$project"
  assert_parity "design the architecture" "wb-plan" "$project"
}

@test "host parity: implementation prompts route to wb-build on every host" {
  project="$(setup_tmpdir)/proj"
  make_target_repo "$project" >/dev/null
  "$WB_RUNTIME_BIN" init --project "$project" >/dev/null
  assert_parity "implement the next planned slice" "wb-build" "$project"
}

@test "host parity: debug prompts route to wb-debug on every host" {
  project="$(setup_tmpdir)/proj"
  make_target_repo "$project" >/dev/null
  "$WB_RUNTIME_BIN" init --project "$project" >/dev/null
  assert_parity "debug the failing test" "wb-debug" "$project"
  assert_parity "this regression is killing us" "wb-debug" "$project"
}

@test "host parity: review prompts route to wb-review on every host" {
  project="$(setup_tmpdir)/proj"
  make_target_repo "$project" >/dev/null
  "$WB_RUNTIME_BIN" init --project "$project" >/dev/null
  assert_parity "review this change" "wb-review" "$project"
}

@test "host parity: QA prompts route to wb-qa on every host" {
  project="$(setup_tmpdir)/proj"
  make_target_repo "$project" >/dev/null
  "$WB_RUNTIME_BIN" init --project "$project" >/dev/null
  assert_parity "run QA against acceptance criteria" "wb-qa" "$project"
}

@test "host parity: ship prompts route to wb-ship on every host" {
  project="$(setup_tmpdir)/proj"
  make_target_repo "$project" >/dev/null
  "$WB_RUNTIME_BIN" init --project "$project" >/dev/null
  assert_parity "create a PR" "wb-ship" "$project"
  assert_parity "ship it" "wb-ship" "$project"
}
