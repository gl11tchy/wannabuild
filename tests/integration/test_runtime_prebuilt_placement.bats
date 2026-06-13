#!/usr/bin/env bats
#
# Integration tests for the shared prebuilt-runtime placement contract.
#
# The npx CLI builds nothing on the user's machine: it places a CI-built
# wb-runtime binary and tells each host install script where it is via
# WB_RUNTIME_PREBUILT. These tests stand in a fake executable for that env var
# and assert each script copies it to the exact path that host's runtime
# resolver checks, with the executable bit set. No cargo, no network: the fake
# binary is a one-line shell script, so the scripts must take the prebuilt
# branch and skip building.
#
# Paths under test:
#   Codex:   <CODEX_HOME>/bin/wb-runtime
#   Factory: <factory plugin cache>/local/target/debug/wb-runtime

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

CODEX_INSTALL="${REPO_ROOT}/scripts/install-codex-skill.sh"
FACTORY_INSTALL="${REPO_ROOT}/scripts/install-factory-plugin.sh"

# make_fake_runtime <path>
#   Writes an executable stand-in for the prebuilt wb-runtime so the install
#   scripts' `-x` checks pass and they take the prebuilt-copy branch. A unique
#   marker lets us prove the placed file is a copy of *this* binary and not a
#   freshly built one.
make_fake_runtime() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat >"$path" <<'EOF'
#!/usr/bin/env bash
echo "wb-runtime fake 2.6.0"
EOF
  chmod +x "$path"
}

@test "runtime_placement: codex installer copies WB_RUNTIME_PREBUILT to ~/.codex/bin/wb-runtime (+x)" {
  fake_home="$(setup_tmpdir)/host"
  mkdir -p "$fake_home"
  prebuilt="$(setup_tmpdir)/prebuilt/wb-runtime"
  make_fake_runtime "$prebuilt"

  run env WANNABUILD_HOST_HOME="$fake_home" \
    CODEX_HOME="$fake_home/.codex" \
    WB_RUNTIME_PREBUILT="$prebuilt" \
    bash "$CODEX_INSTALL"
  [ "$status" -eq 0 ]

  placed="$fake_home/.codex/bin/wb-runtime"
  [ -f "$placed" ]
  [ -x "$placed" ]
  # The placed file must be a byte-for-byte copy of the prebuilt fake, proving
  # the script did not invoke cargo to produce a different binary.
  run cmp -s "$prebuilt" "$placed"
  [ "$status" -eq 0 ]
}

@test "runtime_placement: factory installer copies WB_RUNTIME_PREBUILT into the plugin cache target/debug (+x)" {
  fake_home="$(setup_tmpdir)/host"
  mkdir -p "$fake_home"
  prebuilt="$(setup_tmpdir)/prebuilt/wb-runtime"
  make_fake_runtime "$prebuilt"

  run env WANNABUILD_HOST_HOME="$fake_home" \
    FACTORY_HOME="$fake_home/.factory" \
    FACTORY_MARKETPLACE="wannabuild" \
    WB_RUNTIME_PREBUILT="$prebuilt" \
    bash "$FACTORY_INSTALL"
  [ "$status" -eq 0 ]

  cache="$fake_home/.factory/plugins/cache/wannabuild/wannabuild/local"
  placed="$cache/target/debug/wb-runtime"
  [ -f "$placed" ]
  [ -x "$placed" ]
  run cmp -s "$prebuilt" "$placed"
  [ "$status" -eq 0 ]
}

@test "runtime_placement: factory binary lands under the same cache as the plugin payload" {
  fake_home="$(setup_tmpdir)/host"
  mkdir -p "$fake_home"
  prebuilt="$(setup_tmpdir)/prebuilt/wb-runtime"
  make_fake_runtime "$prebuilt"

  run env WANNABUILD_HOST_HOME="$fake_home" \
    FACTORY_HOME="$fake_home/.factory" \
    FACTORY_MARKETPLACE="wannabuild" \
    WB_RUNTIME_PREBUILT="$prebuilt" \
    bash "$FACTORY_INSTALL"
  [ "$status" -eq 0 ]

  cache="$fake_home/.factory/plugins/cache/wannabuild/wannabuild/local"
  # The hook resolves runtime at parents[1]/target/debug/wb-runtime, where the
  # hook lives at <cache>/hooks/. So the binary must sit beside, not above, the
  # copied plugin payload.
  [ -e "$cache/hooks/wannabuild-route.py" ]
  [ -x "$cache/target/debug/wb-runtime" ]
}
