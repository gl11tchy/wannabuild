#!/usr/bin/env bats
#
# Integration test: run the doctor against a full copy of the repo.
# Ensures that the documented "all surfaces present" exit-0 path is real and
# that removing any one required surface flips the doctor to failure.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

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

@test "doctor_full_repo: exits 0 against a fresh copy of the working tree" {
  copy="$(_copy_repo)"
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  if [[ "$status" -ne 0 ]]; then
    echo "$output" >&2
  fi
  [ "$status" -eq 0 ]
  [[ "$output" == *"Repo surfaces ready"* ]]
}

@test "doctor_full_repo: removing skills/build/SKILL.md flips exit to 1 and prints FAIL" {
  copy="$(_copy_repo)"
  rm -f "$copy/skills/build/SKILL.md"
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL  skills/build/SKILL.md"* ]]
  [[ "$output" == *"missing"* ]] || [[ "$output" == *"Missing"* ]]
}

@test "doctor_full_repo: removing AGENTS.md flips exit to 1 and prints FAIL" {
  copy="$(_copy_repo)"
  rm -f "$copy/AGENTS.md"
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL  AGENTS.md"* ]]
}
