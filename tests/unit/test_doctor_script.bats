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

@test "doctor: FAILs when a required toolbox skill is removed" {
  copy="$(_copy_repo)"
  rm -f "$copy/skills/wb-build/SKILL.md"
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  skills/wb-build/SKILL.md"* ]]
}

@test "doctor: FAILs when a required toolbox command is removed" {
  copy="$(_copy_repo)"
  rm -f "$copy/commands/wb-build.md"
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  commands/wb-build.md"* ]]
}

@test "doctor: FAILs when required toolbox docs are removed" {
  copy="$(_copy_repo)"
  python3 - "$copy/README.md" <<'PY'
from pathlib import Path
path = Path(__import__("sys").argv[1])
path.write_text(path.read_text().replace("/wb-build", "/removed-build"))
PY
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  README docs expose /wb-build"* ]]
}

@test "doctor: FAILs when Claude command reintroduces direct banner output" {
  copy="$(_copy_repo)"
  printf '\n[WB-START] WannaBuild STARTED | intent=build | mode=standard\n' >> "$copy/commands/wannabuild.md"
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  Claude command leaves start banner to skill"* ]]
}

@test "doctor: FAILs when a toolbox skill omits bootstrap behavior" {
  copy="$(_copy_repo)"
  python3 - "$copy/skills/wb-build/SKILL.md" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text(path.read_text().replace("Toolbox Bootstrap", "Bootstrap omitted"))
PY
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  Toolbox skill wb-build defines bootstrap behavior"* ]]
}

@test "doctor: FAILs when a toolbox command stops routing to its skill" {
  copy="$(_copy_repo)"
  python3 - "$copy/commands/wb-build.md" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text(path.read_text().replace("Use the `wb-build` skill", "Route omitted"))
PY
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  Toolbox command /wb-build routes to skill"* ]]
}

@test "doctor: FAILs when Codex manual install omits a toolbox skill" {
  copy="$(_copy_repo)"
  python3 - "$copy/.codex/INSTALL.md" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text(path.read_text().replace("wb-build", "removed-build"))
PY
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  Codex manual install includes wb-build"* ]]
}

@test "doctor: WARNs when Codex skill symlink is absent in fake HOME" {
  copy="$(_copy_repo)"
  # with_clean_env redirects HOME to an empty tmp dir, so install symlinks
  # will not exist and the doctor must emit WARN lines.
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [[ "$output" == *"WARN"* ]]
  [[ "$output" == *".codex/skills/wannabuild"* ]]
}

@test "doctor: WARNs when Codex toolbox skill symlink is absent in fake HOME" {
  copy="$(_copy_repo)"
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [[ "$output" == *"WARN"* ]]
  [[ "$output" == *".codex/skills/wb-build"* ]]
}

@test "doctor: WARNs when Claude install link target is absent in fake HOME" {
  copy="$(_copy_repo)"
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [[ "$output" == *"WARN"* ]]
  [[ "$output" == *".claude/plugins/cache/gl11tchy/wannabuild/local"* ]] || \
    [[ "$output" == *".claude/plugins/cache"* ]]
}
