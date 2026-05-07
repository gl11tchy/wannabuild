#!/usr/bin/env bats
#
# Cold-install smoke test for the Factory Droid plugin install script.
#
# Runs install-factory-plugin.sh against a synthetic FACTORY_HOME under
# $BATS_TEST_TMPDIR and verifies the resulting layout is what Droid consumes:
#
#   - plugin cache symlink resolves into the Factory adapter
#   - command, hook, and skill files are reachable through the cache
#   - the adapter payload has no nested symlinks
#   - known_marketplaces.json and installed_plugins.json register the plugin
#   - generated wb-* droids are installed
#   - second run is idempotent

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

INSTALL_SCRIPT="${REPO_ROOT}/scripts/install-factory-plugin.sh"

run_install() {
  local home="$1"
  WANNABUILD_HOST_HOME="$home" FACTORY_HOME="$home/.factory" bash "$INSTALL_SCRIPT"
}

@test "install-factory-plugin: writes a plugin cache pointing at the Factory adapter" {
  fake_home="$(setup_tmpdir)/host"
  mkdir -p "$fake_home"

  run run_install "$fake_home"
  [ "$status" -eq 0 ]

  cache="$fake_home/.factory/plugins/cache/wannabuild/wannabuild/local"
  [ -e "$cache" ]
  [ -e "$cache/.factory-plugin/plugin.json" ]
  [ -e "$cache/commands/wannabuild.md" ]
  [ -e "$cache/hooks/hooks.json" ]
  [ -e "$cache/hooks/wannabuild-route.py" ]
  [ -e "$cache/skills/wannabuild/SKILL.md" ]
}

@test "install-factory-plugin: adapter payload has no nested symlinks" {
  fake_home="$(setup_tmpdir)/host"
  mkdir -p "$fake_home"

  run_install "$fake_home" >/dev/null

  cache="$fake_home/.factory/plugins/cache/wannabuild/wannabuild/local"
  run bash -c 'find -H "$1" -mindepth 1 -type l -print -quit' _ "$cache"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "install-factory-plugin: registers marketplace and plugin" {
  fake_home="$(setup_tmpdir)/host"
  mkdir -p "$fake_home"

  run_install "$fake_home" >/dev/null

  km="$fake_home/.factory/plugins/known_marketplaces.json"
  installed="$fake_home/.factory/plugins/installed_plugins.json"

  [ -f "$km" ] && [ -f "$installed" ]

  run python3 -c "
import json
km=json.load(open('$km'))
assert 'wannabuild' in km, 'marketplace missing from known_marketplaces'
inst=json.load(open('$installed'))
assert 'wannabuild@wannabuild' in inst.get('plugins',{}), 'plugin missing from installed_plugins'
"
  [ "$status" -eq 0 ]
}

@test "install-factory-plugin: installs generated wb droids" {
  fake_home="$(setup_tmpdir)/host"
  mkdir -p "$fake_home"

  run_install "$fake_home" >/dev/null

  droids="$fake_home/.factory/droids"
  [ -e "$droids/wb-architect.md" ]
  [ -e "$droids/wb-integration-tester.md" ]
  [ -e "$droids/wb-advisor.md" ]
}

@test "install-factory-plugin: second run is idempotent" {
  fake_home="$(setup_tmpdir)/host"
  mkdir -p "$fake_home"

  run run_install "$fake_home"
  [ "$status" -eq 0 ]

  run run_install "$fake_home"
  [ "$status" -eq 0 ]

  cache="$fake_home/.factory/plugins/cache/wannabuild/wannabuild/local"
  [ -e "$cache/commands/wannabuild.md" ]
  [ -e "$fake_home/.factory/droids/wb-advisor.md" ]
}
