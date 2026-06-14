#!/usr/bin/env bats
#
# Unit tests for the npx installer's platform mapping and arg parsing.
#
# These exercise installer/lib/platform.js and the installer CLI surface
# (installer/bin/wannabuild.js) without touching the network, cargo, or the
# real $HOME. Node (>=18) is required; if it is absent the tests skip rather
# than fail.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

INSTALLER_DIR="${REPO_ROOT}/installer"
PLATFORM_JS="${INSTALLER_DIR}/lib/platform.js"
BIN_JS="${INSTALLER_DIR}/bin/wannabuild.js"

setup() {
  if ! command -v node >/dev/null 2>&1; then
    skip "node not on PATH"
  fi
}

# resolve <platform> <arch>  -> prints "<label> <exe>" via lib/platform.js.
# The label MUST match a release-binaries matrix label (release-please.yml). Exits non-zero
# (and prints the actionable error) when resolveTarget throws.
resolve() {
  local platform="$1" arch="$2"
  node -e '
    const { resolveTarget } = require(process.argv[1]);
    const r = resolveTarget(process.argv[2], process.argv[3]);
    process.stdout.write(r.label + " " + JSON.stringify(r.exe));
  ' "$PLATFORM_JS" "$platform" "$arch"
}

@test "installer_platform: darwin/arm64 maps to macos-arm64 (no exe)" {
  [ -f "$PLATFORM_JS" ]
  run resolve darwin arm64
  [ "$status" -eq 0 ]
  [ "$output" = 'macos-arm64 ""' ]
}

@test "installer_platform: darwin/x64 maps to macos-x86_64 (no exe)" {
  run resolve darwin x64
  [ "$status" -eq 0 ]
  [ "$output" = 'macos-x86_64 ""' ]
}

@test "installer_platform: linux/x64 maps to linux-x86_64 (no exe)" {
  run resolve linux x64
  [ "$status" -eq 0 ]
  [ "$output" = 'linux-x86_64 ""' ]
}

@test "installer_platform: linux/arm64 maps to linux-arm64 (no exe)" {
  run resolve linux arm64
  [ "$status" -eq 0 ]
  [ "$output" = 'linux-arm64 ""' ]
}

@test "installer_platform: win32/x64 maps to windows-x86_64 with .exe" {
  run resolve win32 x64
  [ "$status" -eq 0 ]
  [ "$output" = 'windows-x86_64 ".exe"' ]
}

@test "installer_platform: unsupported platform/arch throws an actionable error" {
  run resolve sunos sparc
  [ "$status" -ne 0 ]
  [[ "$output" == *"no prebuilt wb-runtime binary"* ]]
  [[ "$output" == *"sunos:sparc"* ]]
}

@test "installer_platform: error lists the supported combinations" {
  run resolve plan9 mips
  [ "$status" -ne 0 ]
  # The error enumerates the supported platform:arch combos (what a user knows
  # about their machine).
  [[ "$output" == *"darwin:arm64"* ]]
  [[ "$output" == *"win32:x64"* ]]
}
