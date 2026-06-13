#!/usr/bin/env bats
#
# Unit tests for the doctor's "Runtime binary" fail-closed section.
#
# The contract: when a host is installed (its home dir exists) but the real
# wb-runtime binary is absent or not executable at that host's resolved path,
# the doctor must FAIL (exit non-zero) — never warn. A silent fallback to the
# degraded Python mirror has to be loud.
#
# We drive the doctor with a fake $WB_RUNTIME_BIN so its unrelated golden-path
# gate checks do not require cargo; the runtime-binary section under test does
# its own per-host `-x` checks against the host homes we point it at. We assert
# the doctor surfaces a FAIL that names wb-runtime and exits non-zero, which is
# the fail-closed behavior regardless of which other sections also report.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

# A fake executable that the doctor can shell out to for any incidental runtime
# resolution; it is NOT placed at any host path, so the per-host checks still
# see the binary as absent.
setup() {
  FAKE_BIN="$(setup_tmpdir)/fake/wb-runtime"
  mkdir -p "$(dirname "$FAKE_BIN")"
  cat >"$FAKE_BIN" <<'EOF'
#!/usr/bin/env bash
echo "wb-runtime fake"
exit 0
EOF
  chmod +x "$FAKE_BIN"

  HOST_HOME="$(setup_tmpdir)/hosthome"
  mkdir -p "$HOST_HOME"
}

# run_doctor: invoke the doctor with the runtime-binary section's host homes
# pointed at our controlled HOST_HOME and a fake global runtime override.
run_doctor() {
  run env \
    HOME="$HOST_HOME" \
    WANNABUILD_HOST_HOME="$HOST_HOME" \
    WB_RUNTIME_BIN="$FAKE_BIN" \
    bash "$REPO_ROOT/scripts/wannabuild-doctor.sh"
}

@test "doctor_runtime_binary: doctor exposes a Runtime binary section" {
  # Present a Codex install so the section has a host to check.
  mkdir -p "$HOST_HOME/.codex/bin"
  cp "$FAKE_BIN" "$HOST_HOME/.codex/bin/wb-runtime"
  run_doctor
  [[ "$output" == *"Runtime binary"* ]]
}

@test "doctor_runtime_binary: FAILs and exits non-zero when an installed Codex host has no runtime binary" {
  # Codex is "installed" (its home exists) but no binary was placed.
  mkdir -p "$HOST_HOME/.codex/skills"
  run_doctor
  [ "$status" -ne 0 ]
  # Scope to the runtime-binary section's own message so this cannot pass on an
  # unrelated FAIL — and would fail if the fail-closed guard were removed.
  [[ "$output" == *"Codex wb-runtime present and executable: missing"* ]]
  [[ "$output" == *"fall back to Python mirror"* ]]
}

@test "doctor_runtime_binary: FAILs when the Codex runtime binary exists but is not executable" {
  # The kernel ignores the executable bit for root, so -x would pass and this
  # case cannot be exercised; skip rather than assert a guarantee that does not
  # hold for the current user.
  if [ "$(id -u)" -eq 0 ]; then
    skip "root bypasses the executable bit; -x semantics do not apply"
  fi
  mkdir -p "$HOST_HOME/.codex/bin"
  # Non-executable file at the resolved path must still trip the gate.
  printf 'not a real binary\n' >"$HOST_HOME/.codex/bin/wb-runtime"
  chmod -x "$HOST_HOME/.codex/bin/wb-runtime"
  run_doctor
  [ "$status" -ne 0 ]
  [[ "$output" == *"Codex wb-runtime present and executable: present but not executable"* ]]
}
