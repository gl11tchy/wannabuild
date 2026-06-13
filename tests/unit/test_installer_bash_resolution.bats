#!/usr/bin/env bats
#
# Unit tests for installer/lib/run.js resolveBash(): the interpreter resolution
# order and its actionable failure.
#
# Order (per the NPX contract): WANNABUILD_BASH -> bash on PATH ->
# [win32 only: Git for Windows bash -> wsl.exe] -> throw. The win32-only tiers
# can't be exercised off Windows (process.platform is fixed), so they're covered
# by inspection; here we pin the cross-platform tiers and the no-bash error on
# the current platform. We invoke node by absolute path so the test still runs
# with a stubbed/empty PATH. No network.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

RUN_LIB="${REPO_ROOT}/installer/lib/run.js"

setup() {
  NODE_BIN="$(command -v node || true)"
  if [ -z "$NODE_BIN" ]; then
    skip "node is required for installer unit tests"
  fi
  WORK="$(setup_tmpdir)"
}

@test "resolveBash: WANNABUILD_BASH override takes precedence over PATH" {
  override="$WORK/mybash"
  printf '#!/bin/sh\n' >"$override"
  chmod +x "$override"
  run env WANNABUILD_BASH="$override" \
    "$NODE_BIN" -e 'process.stdout.write(require(process.argv[1]).resolveBash().command)' "$RUN_LIB"
  [ "$status" -eq 0 ]
  [ "$output" = "$override" ]
}

@test "resolveBash: falls back to a bash on PATH when no override is set" {
  bindir="$WORK/bin"
  mkdir -p "$bindir"
  printf '#!/bin/sh\n' >"$bindir/bash"
  chmod +x "$bindir/bash"
  # $bindir is first on PATH, so its bash is selected even if a system bash
  # exists elsewhere on the search path.
  run env -u WANNABUILD_BASH PATH="$bindir" \
    "$NODE_BIN" -e 'process.stdout.write(require(process.argv[1]).resolveBash().command)' "$RUN_LIB"
  [ "$status" -eq 0 ]
  [ "$output" = "$bindir/bash" ]
}

@test "resolveBash: throws an actionable error when no bash is available" {
  run env -u WANNABUILD_BASH PATH="" \
    "$NODE_BIN" -e 'try { require(process.argv[1]).resolveBash(); process.stdout.write("NO_THROW"); } catch (e) { process.stdout.write("THROW:" + String(e.message).split("\n")[0]); }' "$RUN_LIB"
  [ "$status" -eq 0 ]
  [[ "$output" == THROW:* ]]
  [[ "$output" == *"No usable bash interpreter found"* ]]
}
