#!/usr/bin/env bats
#
# Cold-install smoke test for the Claude Code plugin install script.
#
# Runs install-claude-skill.sh against a synthetic CLAUDE_HOME under
# $BATS_TEST_TMPDIR and verifies the resulting layout is what Claude
# Code's plugin loader would actually consume:
#
#   - plugin cache symlink resolves into the repo
#   - hooks/hooks.json is reachable AND in the unwrapped shape
#   - plugin manifest is reachable
#   - known_marketplaces.json, installed_plugins.json, settings.json
#     register and enable the plugin
#   - second run is idempotent

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

INSTALL_SCRIPT="${REPO_ROOT}/scripts/install-claude-skill.sh"

run_install() {
  local home="$1"
  WANNABUILD_HOST_HOME="$home" CLAUDE_HOME="$home/.claude" bash "$INSTALL_SCRIPT"
}

@test "install-claude-skill: writes a plugin cache pointing at the repo" {
  fake_home="$(setup_tmpdir)/host"
  mkdir -p "$fake_home"

  run run_install "$fake_home"
  [ "$status" -eq 0 ]

  cache="$fake_home/.claude/plugins/cache/gl11tchy/wannabuild/local"
  [ -e "$cache" ]
  [ -e "$cache/.claude-plugin/plugin.json" ]
  [ -e "$cache/hooks/hooks.json" ]
}

@test "install-claude-skill: exposes public wb-ship skill but not legacy ship skill" {
  fake_home="$(setup_tmpdir)/host"
  mkdir -p "$fake_home"

  run run_install "$fake_home"
  [ "$status" -eq 0 ]

  cache="$fake_home/.claude/plugins/cache/gl11tchy/wannabuild/local"
  [ -e "$cache/skills/wb-ship/SKILL.md" ]
  [ ! -e "$cache/skills/ship/SKILL.md" ]
}

@test "install-claude-skill: installed hooks.json is the unwrapped event-map shape" {
  fake_home="$(setup_tmpdir)/host"
  mkdir -p "$fake_home"

  run_install "$fake_home" >/dev/null

  hooks="$fake_home/.claude/plugins/cache/gl11tchy/wannabuild/local/hooks/hooks.json"
  run python3 -c "
import json,sys
d=json.load(open('$hooks'))
assert 'hooks' not in d, 'hooks.json is double-wrapped under a hooks key'
assert isinstance(d.get('SessionStart'),list), 'SessionStart not an array'
assert isinstance(d.get('UserPromptSubmit'),list), 'UserPromptSubmit not an array'
"
  [ "$status" -eq 0 ]
}

@test "install-claude-skill: registers namespace, plugin, and settings entry" {
  fake_home="$(setup_tmpdir)/host"
  mkdir -p "$fake_home"

  run_install "$fake_home" >/dev/null

  km="$fake_home/.claude/plugins/known_marketplaces.json"
  installed="$fake_home/.claude/plugins/installed_plugins.json"
  settings="$fake_home/.claude/settings.json"

  [ -f "$km" ] && [ -f "$installed" ] && [ -f "$settings" ]

  run python3 -c "
import json
km=json.load(open('$km'))
assert 'gl11tchy' in km, 'namespace missing from known_marketplaces'
inst=json.load(open('$installed'))
assert 'wannabuild@gl11tchy' in inst.get('plugins',{}), 'plugin missing from installed_plugins'
s=json.load(open('$settings'))
assert s.get('enabledPlugins',{}).get('wannabuild@gl11tchy') is True, 'plugin not enabled in settings'
"
  [ "$status" -eq 0 ]
}

@test "install-claude-skill: second run is idempotent" {
  fake_home="$(setup_tmpdir)/host"
  mkdir -p "$fake_home"

  run run_install "$fake_home"
  [ "$status" -eq 0 ]

  run run_install "$fake_home"
  [ "$status" -eq 0 ]

  cache="$fake_home/.claude/plugins/cache/gl11tchy/wannabuild/local"
  [ -e "$cache/hooks/hooks.json" ]
}
