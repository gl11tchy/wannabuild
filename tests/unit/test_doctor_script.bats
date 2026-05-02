#!/usr/bin/env bats
#
# Unit tests for scripts/wannabuild-doctor.sh
# The doctor script walks $ROOT (one level above the script). To test the
# "missing required file" path safely we copy the repo into $BATS_TEST_TMPDIR,
# remove a single required surface in the copy, and run the copied script.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

# Make a shallow clone of the repo into a tmp location and echo the path.
# Excludes potentially large dirs we don't need for the doctor's checks.
_copy_repo() {
  local dest="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$dest"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --quiet \
      --exclude '.git' \
      --exclude '.worktrees' \
      --exclude 'tests/.bats' \
      --exclude 'tests/.bats-libs' \
      --exclude 'tests/results' \
      "$REPO_ROOT/" "$dest/" >/dev/null
  else
    ( cd "$REPO_ROOT" && tar --exclude '.git' --exclude '.worktrees' \
                              --exclude 'tests/.bats' --exclude 'tests/.bats-libs' \
                              --exclude 'tests/results' -cf - . ) | \
      ( cd "$dest" && tar -xf - )
  fi
  printf '%s\n' "$dest"
}

@test "doctor: prints WannaBuild Doctor banner" {
  copy="$(_copy_repo)"
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [[ "$output" == *"WannaBuild Doctor"* ]]
}

@test "doctor: PASSes for an unmodified repo copy and exits 0" {
  copy="$(_copy_repo)"
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  if [[ "$status" -ne 0 ]]; then
    echo "$output" >&2
  fi
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS  README.md"* ]]
  [[ "$output" == *"PASS  AGENTS.md"* ]]
}

@test "doctor: FAILs and exits non-zero when a required surface is removed" {
  copy="$(_copy_repo)"
  rm -f "$copy/AGENTS.md"
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  AGENTS.md"* ]]
  [[ "$output" == *"missing"* ]] || [[ "$output" == *"Missing"* ]]
}

@test "doctor: WARNs when Codex skill symlink is absent in fake HOME" {
  copy="$(_copy_repo)"
  # with_clean_env redirects HOME to an empty tmp dir, so install symlinks
  # will not exist and the doctor must emit WARN lines.
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [[ "$output" == *"WARN"* ]]
  [[ "$output" == *".codex/skills/wannabuild"* ]]
}

@test "doctor: WARNs when Claude install link target is absent in fake HOME" {
  copy="$(_copy_repo)"
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [[ "$output" == *"WARN"* ]]
  [[ "$output" == *".claude/plugins/cache/gl11tchy/wannabuild/local"* ]] || \
    [[ "$output" == *".claude/plugins/cache"* ]]
}
