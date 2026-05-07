#!/usr/bin/env bats
#
# Unit tests for scripts/install-codex-skill.sh.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

setup() {
  TARGET="$(setup_tmpdir)/skills"
  RUNTIME_DIR="$(setup_tmpdir)/bin"
  HOST_HOME="$(setup_tmpdir)/home"
}

@test "install_codex: installs skills and wb-runtime" {
  run env WANNABUILD_HOST_HOME="$HOST_HOME" \
    CODEX_SKILLS_DIR="$TARGET" \
    CODEX_RUNTIME_DIR="$RUNTIME_DIR" \
    bash "$SCRIPTS_DIR/install-codex-skill.sh"

  [ "$status" -eq 0 ]
  [ -f "$TARGET/wannabuild/SKILL.md" ]
  [ -f "$TARGET/wb-build/SKILL.md" ]
  if [[ -x "$RUNTIME_DIR/wb-runtime" ]]; then
    :
  else
    [ -x "$RUNTIME_DIR/wb-runtime.exe" ]
  fi
  [[ "$output" == *"Installed Codex runtime:"* ]]
}
