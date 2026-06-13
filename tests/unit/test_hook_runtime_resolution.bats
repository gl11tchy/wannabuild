#!/usr/bin/env bats
#
# The Claude/Factory hook's runtime_binary() must resolve the real Rust binary
# at the plugin-relative target/debug path on every OS — including the .exe
# sibling on Windows. If it can't, a host with the binary present silently runs
# the Python mirror instead of the real gates, which the doctor's PASS would
# then misreport. This pins the resolver (path-3 fallback) against both layouts.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

HOOK="${REPO_ROOT}/hooks/wannabuild-route.py"

setup() {
  PY3="$(command -v python3 || true)"
  if [ -z "$PY3" ]; then
    skip "python3 required"
  fi
  WORK="$(setup_tmpdir)"
  # Fake plugin layout: <plugin>/hooks/wannabuild-route.py is the hook; the
  # resolver looks at parents[1]/target/debug, i.e. <plugin>/target/debug.
  PLUGIN="$WORK/plugin"
  mkdir -p "$PLUGIN/hooks" "$PLUGIN/target/debug"
  cp "$HOOK" "$PLUGIN/hooks/wannabuild-route.py"
}

# resolve_via_hook: load the copied hook and print runtime_binary(), with a
# minimal PATH (no wb-runtime) and no WB_RUNTIME_BIN so ONLY the path-3 fallback
# is exercised. python3 is invoked by absolute path so the stubbed PATH cannot
# hide the interpreter.
resolve_via_hook() {
  env -u WB_RUNTIME_BIN PATH="$WORK/empty-path" "$PY3" - "$PLUGIN/hooks/wannabuild-route.py" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("wbhook", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
print(m.runtime_binary() or "NONE")
PY
}

@test "hook_runtime_resolution: resolves the bare wb-runtime at plugin/target/debug" {
  : >"$PLUGIN/target/debug/wb-runtime"
  run resolve_via_hook
  [ "$status" -eq 0 ]
  # .resolve() canonicalizes symlinked temp paths (macOS /var/folders), so match
  # the suffix and confirm the returned path is a real file.
  [[ "$output" == *"/target/debug/wb-runtime" ]]
  [ -f "$output" ]
}

@test "hook_runtime_resolution: resolves a Windows-style wb-runtime.exe sibling" {
  : >"$PLUGIN/target/debug/wb-runtime.exe"
  run resolve_via_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"/target/debug/wb-runtime.exe" ]]
  [ -f "$output" ]
}

@test "hook_runtime_resolution: returns NONE when no binary is present (mirror fallback)" {
  run resolve_via_hook
  [ "$status" -eq 0 ]
  [ "$output" = "NONE" ]
}
