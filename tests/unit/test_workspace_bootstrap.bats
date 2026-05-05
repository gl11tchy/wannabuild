#!/usr/bin/env bats
#
# Unit tests for scripts/wannabuild-workspace.sh
#
# The script creates a Codex-managed worktree directory:
#   <repo>/.codex/worktrees/<repo_name>/<workspace_id>/
# We point it at a tmp git repo so we never touch real $HOME or this repo's
# parent directory.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

setup() {
  WORKDIR="$(setup_tmpdir)/work"
  mkdir -p "$WORKDIR/repo"
  cd "$WORKDIR/repo"
  git init -q --initial-branch=main . >/dev/null 2>&1 || git init -q . >/dev/null
  git config user.email "test@example.invalid"
  git config user.name "Test"
  printf 'fixture\n' > README.md
  git add README.md
  git commit -q -m "init" >/dev/null
}

@test "workspace: --help prints usage and exits 0" {
  run bash "$SCRIPTS_DIR/wannabuild-workspace.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"isolated WannaBuild git worktree"* ]]
}

@test "workspace: rejects unknown argument" {
  run bash "$SCRIPTS_DIR/wannabuild-workspace.sh" --not-a-real-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown argument"* ]]
}

@test "workspace: errors helpfully outside a git work tree" {
  cd "$WORKDIR"  # parent of repo, not a git work tree
  run bash "$SCRIPTS_DIR/wannabuild-workspace.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not inside a git work tree"* ]]
}

@test "workspace: bootstraps a worktree with expected layout" {
  cd "$WORKDIR/repo"
  run bash "$SCRIPTS_DIR/wannabuild-workspace.sh" --label feature
  [ "$status" -eq 0 ]
  [[ "$output" == *"WannaBuild workspace created"* ]]
  [[ "$output" == *"workspace_id:"* ]]
  [[ "$output" == *"branch_name: wannabuild/"* ]]

  # Parse workspace_path from output.
  ws_path="$(printf '%s\n' "$output" | awk '/^workspace_path:/{print $2}')"
  [ -n "$ws_path" ]
  [[ "$ws_path" == *"/.codex/worktrees/repo/"* ]]
  [ -d "$ws_path" ]
  [ -f "$ws_path/.wannabuild/workspace.json" ]
  grep -q '"workspace_id"' "$ws_path/.wannabuild/workspace.json"
  grep -q '"dirty_snapshot": false' "$ws_path/.wannabuild/workspace.json"
  [ ! -e "$WORKDIR/.wannabuild-workspaces" ]
  [[ "$(git status --porcelain)" == "" ]]
  grep -Fxq '.codex/worktrees/' "$(git rev-parse --git-path info/exclude)"
}

@test "workspace: --json produces a single JSON line" {
  cd "$WORKDIR/repo"
  run bash "$SCRIPTS_DIR/wannabuild-workspace.sh" --label run --json
  [ "$status" -eq 0 ]
  json_line="$(printf '%s\n' "$output" | grep -E '^\{.*\}$' | head -n1)"
  [ -n "$json_line" ]
  printf '%s\n' "$json_line" | python3 -c 'import json,sys; json.loads(sys.stdin.read())'
}

@test "workspace: idempotency — invoking twice creates two distinct workspaces, no errors" {
  cd "$WORKDIR/repo"
  run bash "$SCRIPTS_DIR/wannabuild-workspace.sh" --label first
  [ "$status" -eq 0 ]
  ws1="$(printf '%s\n' "$output" | awk '/^workspace_path:/{print $2}')"

  run bash "$SCRIPTS_DIR/wannabuild-workspace.sh" --label second
  [ "$status" -eq 0 ]
  ws2="$(printf '%s\n' "$output" | awk '/^workspace_path:/{print $2}')"

  [ "$ws1" != "$ws2" ]
  [ -d "$ws1" ]
  [ -d "$ws2" ]
}

@test "workspace: dirty tree is snapshotted into worktree (dirty_snapshot=true)" {
  cd "$WORKDIR/repo"
  printf 'unstaged change\n' > UNCOMMITTED.txt
  run bash "$SCRIPTS_DIR/wannabuild-workspace.sh" --label dirty
  [ "$status" -eq 0 ]
  ws_path="$(printf '%s\n' "$output" | awk '/^workspace_path:/{print $2}')"
  grep -q '"dirty_snapshot": true' "$ws_path/.wannabuild/workspace.json"
  [ -f "$ws_path/UNCOMMITTED.txt" ]
}
