#!/usr/bin/env bash
# tests/test_helper.bash
#
# Common helpers for the WannaBuild Bats test suite.
#
# Loaded by every .bats file via:
#     load "${BATS_TEST_DIRNAME}/../test_helper.bash"   # for files in unit/ or integration/
#     load "${BATS_TEST_DIRNAME}/test_helper.bash"      # for files in tests/ root
#
# Conventions:
#   * Each test gets its own $BATS_TEST_TMPDIR (Bats provides this).
#   * Helpers never read or write outside that tmpdir or the repo's `tests/` tree.
#   * No network, no time-based assertions, no $HOME mutation outside tmp homes.

# REPO_ROOT: absolute path to the repo root (one level above tests/).
# Resolved once on first load.
if [[ -z "${REPO_ROOT:-}" ]]; then
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME:-$(dirname "${BASH_SOURCE[0]}")}/.." 2>/dev/null && pwd)"
  # In integration/unit subdirs, BATS_TEST_DIRNAME is one deeper, so try again.
  if [[ ! -f "$REPO_ROOT/AGENTS.md" ]]; then
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME:-$(dirname "${BASH_SOURCE[0]}")}/../.." 2>/dev/null && pwd)"
  fi
  export REPO_ROOT
fi

# SCRIPTS_DIR: absolute path to the scripts under test.
export SCRIPTS_DIR="${REPO_ROOT}/scripts"

# FIXTURES_DIR: absolute path to JSON/text fixtures.
export FIXTURES_DIR="${REPO_ROOT}/tests/fixtures"

# setup_tmpdir
#   Ensures $BATS_TEST_TMPDIR exists and echoes its path. Each Bats test
#   already gets a unique tmpdir; this just guarantees it's created and
#   gives callers a friendly name.
setup_tmpdir() {
  : "${BATS_TEST_TMPDIR:?BATS_TEST_TMPDIR must be set by Bats}"
  mkdir -p "$BATS_TEST_TMPDIR"
  printf '%s\n' "$BATS_TEST_TMPDIR"
}

# make_target_repo <dir>
#   Creates a minimal target project layout at <dir> with the .wannabuild/
#   skeleton expected by the validator. Caller chooses what to populate next.
#   <dir> may be relative; it will be resolved to an absolute path.
make_target_repo() {
  local target="$1"
  mkdir -p "$target/.wannabuild/spec"
  mkdir -p "$target/.wannabuild/outputs"
  mkdir -p "$target/.wannabuild/checkpoints"
  mkdir -p "$target/.wannabuild/review"
  ( cd "$target" && pwd )
}

# make_state_json <target_dir> <phase>
#   Copies the matching fixture into <target_dir>/.wannabuild/state.json.
#   <phase>: requirements | design | tasks | implement
make_state_json() {
  local target="$1" phase="$2"
  local src="${FIXTURES_DIR}/state-${phase}.json"
  if [[ ! -f "$src" ]]; then
    echo "make_state_json: no fixture for phase '$phase' at $src" >&2
    return 1
  fi
  mkdir -p "$target/.wannabuild"
  cp "$src" "$target/.wannabuild/state.json"
}

# make_loop_state <target_dir> <pass|fail>
#   Copies a loop-state fixture into the target.
make_loop_state() {
  local target="$1" kind="$2"
  local src="${FIXTURES_DIR}/loop-state-${kind}.json"
  [[ -f "$src" ]] || { echo "make_loop_state: missing fixture $src" >&2; return 1; }
  mkdir -p "$target/.wannabuild"
  cp "$src" "$target/.wannabuild/loop-state.json"
}

# write_spec <target_dir> <name> [content]
#   Writes a minimal spec file (requirements.md/design.md/tasks.md) so phase
#   transition checks are satisfied. Defaults to a single-line body.
write_spec() {
  local target="$1" name="$2" content="${3:-# ${2%.md}\n\nfixture\n}"
  mkdir -p "$target/.wannabuild/spec"
  printf '%b' "$content" > "$target/.wannabuild/spec/$name"
}

# assert_file_exists <path>
assert_file_exists() {
  if [[ ! -e "$1" ]]; then
    echo "assert_file_exists: missing path: $1" >&2
    return 1
  fi
}

# assert_file_contains <path> <substring>
assert_file_contains() {
  local path="$1" needle="$2"
  if [[ ! -f "$path" ]]; then
    echo "assert_file_contains: file does not exist: $path" >&2
    return 1
  fi
  if ! grep -F -q -- "$needle" "$path"; then
    echo "assert_file_contains: '$needle' not found in $path" >&2
    echo "----- file content -----" >&2
    cat "$path" >&2
    echo "------------------------" >&2
    return 1
  fi
}

# refute_file_contains <path> <substring>
refute_file_contains() {
  local path="$1" needle="$2"
  if [[ -f "$path" ]] && grep -F -q -- "$needle" "$path"; then
    echo "refute_file_contains: '$needle' unexpectedly found in $path" >&2
    return 1
  fi
}

# assert_command_succeeds <cmd...>
#   Runs cmd; fails if non-zero exit. Captures stdout+stderr in $output.
assert_command_succeeds() {
  run "$@"
  if [[ "$status" -ne 0 ]]; then
    echo "assert_command_succeeds: command failed (status=$status): $*" >&2
    echo "----- output -----" >&2
    echo "$output" >&2
    echo "------------------" >&2
    return 1
  fi
}

# assert_command_fails <cmd...>
#   Runs cmd; fails if exit zero. Captures stdout+stderr in $output.
assert_command_fails() {
  run "$@"
  if [[ "$status" -eq 0 ]]; then
    echo "assert_command_fails: command unexpectedly succeeded: $*" >&2
    echo "----- output -----" >&2
    echo "$output" >&2
    echo "------------------" >&2
    return 1
  fi
}

# run_script <script_name> [args...]
#   Invokes a script from $SCRIPTS_DIR as a child process so its set -e and
#   exit codes are observable via Bats' $status / $output. The script is
#   executed (not sourced) to keep test isolation strict.
run_script() {
  local name="$1"; shift
  local path="${SCRIPTS_DIR}/${name}"
  if [[ ! -x "$path" ]]; then
    echo "run_script: not executable or missing: $path" >&2
    return 127
  fi
  run bash "$path" "$@"
}

# with_clean_env <cmd...>
#   Runs cmd with a sanitized environment to prevent leakage from the host
#   shell into the script under test. PATH is preserved. HOME is redirected
#   to a per-test tmp home so install scripts don't touch the real $HOME.
with_clean_env() {
  : "${BATS_TEST_TMPDIR:?BATS_TEST_TMPDIR required}"
  local fake_home="${BATS_TEST_TMPDIR}/home"
  mkdir -p "$fake_home"
  local -a env_args=(
    "PATH=$PATH"
    "HOME=$fake_home"
    "LANG=${LANG:-C.UTF-8}"
    "LC_ALL=${LC_ALL:-C.UTF-8}"
    "BATS_TEST_TMPDIR=$BATS_TEST_TMPDIR"
  )
  # Preserve explicit runtime override; fake HOME can make rustup shims unusable.
  if [[ -n "${WB_RUNTIME_BIN:-}" ]]; then
    env_args+=("WB_RUNTIME_BIN=$WB_RUNTIME_BIN")
  fi
  env -i "${env_args[@]}" "$@"
}

# write_review_verdict <target_dir> <agent> [pass|fail]
#   Writes a minimally-valid review verdict file under .wannabuild/review/.
write_review_verdict() {
  local target="$1" agent="$2" status_kind="${3:-pass}"
  local status="PASS"
  [[ "$status_kind" == "fail" ]] && status="FAIL"
  mkdir -p "$target/.wannabuild/review"
  local file="$target/.wannabuild/review/${agent}-iter-1.json"
  if [[ "$agent" == "wb-integration-tester" ]]; then
    cat > "$file" <<EOF
{
  "agent": "$agent",
  "status": "$status",
  "summary": "fixture summary",
  "issues": [],
  "hard_gate": true,
  "test_execution": {
    "total": 1,
    "passed": 1,
    "failed": 0,
    "errored": 0,
    "duration_ms": 5
  },
  "coverage_map": [
    {"criterion": "AC-1", "status": "covered"}
  ]
}
EOF
  else
    cat > "$file" <<EOF
{
  "agent": "$agent",
  "status": "$status",
  "summary": "fixture summary",
  "issues": []
}
EOF
  fi
}

# write_integration_config <target_dir> [command]
#   Writes .wannabuild/config.json with the integration_test_command the
#   evidence recorder executes. Defaults to `true` for an instant green run.
write_integration_config() {
  local target="$1" command="${2:-true}"
  mkdir -p "$target/.wannabuild"
  printf '{"integration_test_command": "%s"}\n' "$command" > "$target/.wannabuild/config.json"
}

# record_integration_evidence <target_dir> [iteration]
#   Produces the runtime-recorded, HMAC-signed execution evidence the review
#   and QA gates require behind a wb-integration-tester PASS verdict, by
#   running the real recorder (wb-runtime record-test-evidence). The signing
#   key is confined to the per-test tmpdir via WB_EVIDENCE_KEY_FILE so the
#   host's real evidence key is never read or written.
record_integration_evidence() {
  local target="$1" iteration="${2:-1}"
  : "${WB_RUNTIME_BIN:?WB_RUNTIME_BIN must be set (built in setup_file)}"
  export WB_EVIDENCE_KEY_FILE="${WB_EVIDENCE_KEY_FILE:-$BATS_TEST_TMPDIR/evidence.key}"
  "$WB_RUNTIME_BIN" record-test-evidence --project "$target" --iteration "$iteration" >/dev/null
}

# write_checkpoint <target_dir> <task> <step>
#   Writes a minimally-valid checkpoint markdown file.
write_checkpoint() {
  local target="$1" task="$2" step="$3"
  mkdir -p "$target/.wannabuild/checkpoints"
  cat > "$target/.wannabuild/checkpoints/task-${task}-step-${step}.md" <<EOF
Task: ${task}
Step: ${step}
Changed Files: src/foo.py
Verify: bash -n
Result: PASS
Next: continue
EOF
}
