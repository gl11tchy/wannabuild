#!/usr/bin/env bats
#
# Integration smoke test for scripts/install-codex-skill.sh.
#
# Runs the Codex installer against a synthetic CODEX_HOME and verifies the
# documented .codex/INSTALL.md skill surface, runtime install, legacy ship
# absence, and second-run idempotence.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

INSTALL_SCRIPT="${REPO_ROOT}/scripts/install-codex-skill.sh"
CODEX_SKILLS=(
  wannabuild
  using-wannabuild
  wb-build
  wb-debug
  wb-discover
  wb-plan
  wb-qa
  wb-review
  wb-ship
)

run_install() {
  local home="$1"
  WANNABUILD_HOST_HOME="$home" CODEX_HOME="$home/.codex" bash "$INSTALL_SCRIPT"
}

assert_skill_symlink() {
  local skills_dir="$1"
  local skill="$2"
  local dest="$skills_dir/$skill"

  [ -L "$dest" ]
  [ -f "$dest/SKILL.md" ]
  [ "$(readlink "$dest")" = "$REPO_ROOT/skills/$skill" ]
}

assert_codex_layout() {
  local home="$1"
  local skills_dir="$home/.codex/skills"
  local runtime_dir="$home/.codex/bin"
  local skill

  for skill in "${CODEX_SKILLS[@]}"; do
    assert_skill_symlink "$skills_dir" "$skill"
  done

  [ -d "$skills_dir" ]
  [ ! -e "$skills_dir/ship" ]

  if [[ -x "$runtime_dir/wb-runtime" ]]; then
    :
  else
    [ -x "$runtime_dir/wb-runtime.exe" ]
  fi
}

@test "install-codex-skill: installs documented skills, runtime, and is idempotent" {
  fake_home="$(setup_tmpdir)/host"
  mkdir -p "$fake_home"

  run run_install "$fake_home"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installed Codex skills:"* ]]
  [[ "$output" == *"Installed Codex runtime:"* ]]
  [[ "$output" == *"Verified Codex skills target:"* ]]
  [[ "$output" == *"Verified Codex runtime target:"* ]]
  [[ "$output" == *"Restart Codex, then type a natural feature request."* ]]
  [[ "$output" == *"Explicit shortcut remains available: \$wannabuild"* ]]
  assert_codex_layout "$fake_home"

  run run_install "$fake_home"
  [ "$status" -eq 0 ]
  assert_codex_layout "$fake_home"
}
