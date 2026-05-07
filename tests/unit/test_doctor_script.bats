#!/usr/bin/env bats
#
# Unit tests for scripts/wannabuild-doctor.sh
# The doctor script walks $ROOT (one level above the script). To test the
# "missing required file" path safely we copy the repo into $BATS_TEST_TMPDIR,
# remove a single required surface in the copy, and run the copied script.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

setup_file() {
  cargo build --quiet --manifest-path "$REPO_ROOT/Cargo.toml" --bin wb-runtime
  export WB_RUNTIME_BIN="$REPO_ROOT/target/debug/wb-runtime"
}

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

@test "doctor: FAILs when a required phase skill is removed" {
  copy="$(_copy_repo)"
  rm -f "$copy/skills/wb-build/SKILL.md"
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  skills/wb-build/SKILL.md"* ]]
}

@test "doctor: FAILs when legacy ship skill is present in top-level Claude surface" {
  copy="$(_copy_repo)"
  mkdir -p "$copy/skills/ship"
  printf '# Legacy Ship Skill\n' > "$copy/skills/ship/SKILL.md"
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  legacy ship skill must stay out of top-level Claude-discoverable skills"* ]]
}

@test "doctor: FAILs when a required phase command is removed" {
  copy="$(_copy_repo)"
  rm -f "$copy/commands/wb-build.md"
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  commands/wb-build.md"* ]]
}

@test "doctor: FAILs when required phase docs are removed" {
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

@test "doctor: FAILs when Claude command reintroduces start banner output" {
  copy="$(_copy_repo)"
  printf '\n[WB-START] WannaBuild STARTED | intent=build | mode=standard\n' >> "$copy/commands/wannabuild.md"
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  Claude command avoids start banner output"* ]]
}

@test "doctor: FAILs when skill-first handoff guard is removed" {
  copy="$(_copy_repo)"
  python3 - "$copy/AGENTS.md" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text(path.read_text().replace("Do not tell the user to invoke a slash command", "Command-first guard removed"))
PY
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  Operator contract prevents command-first handoff"* ]]
}

@test "doctor: FAILs when a phase skill omits bootstrap behavior" {
  copy="$(_copy_repo)"
  python3 - "$copy/skills/wb-build/SKILL.md" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text(path.read_text().replace("Phase Bootstrap", "Bootstrap omitted"))
PY
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  Phase skill wb-build defines bootstrap behavior"* ]]
}

@test "doctor: FAILs when a phase skill display label regresses" {
  copy="$(_copy_repo)"
  python3 - "$copy/skills/wb-build/agents/openai.yaml" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text(path.read_text().replace("WannaBuild: Build", "WB Build"))
PY
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  Skill UI metadata exposes WannaBuild: Build"* ]]
}

@test "doctor: FAILs when a phase skill omits UI display metadata" {
  copy="$(_copy_repo)"
  rm -f "$copy/skills/wb-ship/agents/openai.yaml"
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  skills/wb-ship/agents/openai.yaml"* ]]
}

@test "doctor: FAILs when a phase command stops routing to its skill" {
  copy="$(_copy_repo)"
  python3 - "$copy/commands/wb-build.md" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text(path.read_text().replace("Use the `wb-build` skill", "Route omitted"))
PY
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  Phase command /wb-build routes to skill"* ]]
}

@test "doctor: FAILs when Codex manual install omits a phase skill" {
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

@test "doctor: FAILs when wb-review no-target default is removed" {
  copy="$(_copy_repo)"
  python3 - "$copy/skills/wb-review/SKILL.md" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text(path.read_text().replace("current checkout changes as the review target by default", "ask for the actual goal first"))
PY
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL  wb-review defaults to current checkout changes when target is omitted"* ]]
}

@test "doctor: WARNs when Codex skill symlink is absent in fake HOME" {
  copy="$(_copy_repo)"
  # with_clean_env redirects HOME to an empty tmp dir, so install symlinks
  # will not exist and the doctor must emit WARN lines.
  run with_clean_env bash "$copy/scripts/wannabuild-doctor.sh"
  [[ "$output" == *"WARN"* ]]
  [[ "$output" == *".codex/skills/wannabuild"* ]]
}

@test "doctor: WARNs when Codex phase skill symlink is absent in fake HOME" {
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
