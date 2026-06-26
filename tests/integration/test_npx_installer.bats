#!/usr/bin/env bats
#
# Integration tests for the npx installer CLI (installer/bin/wannabuild.js).
#
# Covers only the offline, side-effect-free surface: the help and version
# subcommands and rejection of unknown input. Nothing here clones, downloads,
# builds, or mutates a host — those paths require the network and a release
# asset and are exercised by the script-placement tests against fakes.
#
# Node (>=18) is required; absent it, these tests skip rather than fail,
# matching how the cargo-dependent runtime tests gate on their toolchain.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

INSTALLER_DIR="${REPO_ROOT}/installer"
BIN_JS="${INSTALLER_DIR}/bin/wannabuild.js"
PKG_JSON="${INSTALLER_DIR}/package.json"

setup() {
  if ! command -v node >/dev/null 2>&1; then
    skip "node not on PATH"
  fi
  [ -f "$BIN_JS" ] || skip "installer CLI not present at $BIN_JS"
  # A per-test HOME so any accidental detection of host dirs reads an empty
  # tree and the CLI never touches the real ~/.claude, ~/.codex, etc.
  FAKE_HOME="$(setup_tmpdir)/home"
  mkdir -p "$FAKE_HOME"
}

# pkg_version: the version field from installer/package.json, read with node so
# the assertion tracks whatever release-please bumps it to.
pkg_version() {
  node -e 'process.stdout.write(require(process.argv[1]).version)' "$PKG_JSON"
}

run_cli() {
  run env HOME="$FAKE_HOME" node "$BIN_JS" "$@"
}

@test "npx_installer: package.json declares the wannabuild bin" {
  run node -e '
    const p = require(process.argv[1]);
    if (p.name !== "wannabuild") { console.error("name", p.name); process.exit(1); }
    if (!p.bin || p.bin.wannabuild !== "bin/wannabuild.js") { console.error("bin", JSON.stringify(p.bin)); process.exit(1); }
  ' "$PKG_JSON"
  [ "$status" -eq 0 ]
}

@test "npx_installer: --help exits 0 and prints usage" {
  run_cli --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"wannabuild"* ]]
  [[ "$output" == *"install"* ]]
  [[ "$output" == *"doctor"* ]]
  [[ "$output" == *"uninstall"* ]]
}

@test "npx_installer: help subcommand exits 0 and prints usage" {
  run_cli help
  [ "$status" -eq 0 ]
  [[ "$output" == *"install"* ]]
}

@test "npx_installer: default checkout dir is a subdir of ~/.wannabuild, not the key dir" {
  # The runtime owns ~/.wannabuild for its out-of-tree evidence key
  # (~/.wannabuild/evidence.key). The checkout must default to a subdirectory so
  # the two never collide; help advertises that contract.
  run_cli --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"~/.wannabuild/checkout"* ]]
  # Guard against a regression to the bare ~/.wannabuild default.
  [[ "$output" != *"default: ~/.wannabuild)"* ]]
}

@test "npx_installer: -h is an alias for help" {
  run_cli -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"install"* ]]
}

@test "npx_installer: --version exits 0 and prints the package version" {
  want="$(pkg_version)"
  run_cli --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"$want"* ]]
}

@test "npx_installer: version subcommand exits 0 and prints the package version" {
  want="$(pkg_version)"
  run_cli version
  [ "$status" -eq 0 ]
  [[ "$output" == *"$want"* ]]
}

@test "npx_installer: -v is an alias for version" {
  want="$(pkg_version)"
  run_cli -v
  [ "$status" -eq 0 ]
  [[ "$output" == *"$want"* ]]
}

@test "npx_installer: unknown subcommand exits non-zero" {
  run_cli frobnicate
  [ "$status" -ne 0 ]
}

@test "npx_installer: unknown flag exits non-zero" {
  run_cli --nope
  [ "$status" -ne 0 ]
}
