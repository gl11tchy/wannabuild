#!/usr/bin/env bats
#
# Unit tests for the security-critical verify-and-place step of the npx
# installer (installer/lib/runtime.js placeVerifiedBinary).
#
# Contract: the prebuilt wb-runtime is installed at the canonical resolver path
# ONLY when its sha256 matches the expected digest; on a mismatch the function
# refuses (throws) and leaves nothing at the destination, so an unverified
# binary can never become the active gate engine. No network: we feed it a
# local file and an independently-computed digest.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

RUNTIME_LIB="${REPO_ROOT}/installer/lib/runtime.js"

setup() {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for installer unit tests"
  fi
  WORK="$(setup_tmpdir)"
  SRC="$WORK/src-bin"
  printf 'fake wb-runtime payload\n' >"$SRC"
}

# src_sha: sha256 of $SRC, computed independently of the code under test.
src_sha() {
  node -e 'const c=require("crypto"),f=require("fs");process.stdout.write(c.createHash("sha256").update(f.readFileSync(process.argv[1])).digest("hex"))' "$SRC"
}

@test "placeVerifiedBinary: installs an executable binary when the sha256 matches" {
  local sha dest placed
  sha="$(src_sha)"
  dest="$WORK/dest"
  run node -e 'process.stdout.write(require(process.argv[1]).placeVerifiedBinary(process.argv[2], process.argv[3], process.argv[4], "", "wb-runtime"))' \
    "$RUNTIME_LIB" "$SRC" "$sha" "$dest"
  [ "$status" -eq 0 ]
  placed="$dest/wb-runtime"
  [ -f "$placed" ]
  [ -x "$placed" ]
  run cmp -s "$SRC" "$placed"
  [ "$status" -eq 0 ]
}

@test "placeVerifiedBinary: refuses (throws) and writes nothing on a sha256 mismatch" {
  local dest
  dest="$WORK/dest-bad"
  run node -e 'require(process.argv[1]).placeVerifiedBinary(process.argv[2], "0000000000000000000000000000000000000000000000000000000000000000", process.argv[3], "", "wb-runtime")' \
    "$RUNTIME_LIB" "$SRC" "$dest"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Checksum mismatch"* ]]
  # The verification runs before any write, so nothing must exist at the path.
  [ ! -e "$dest/wb-runtime" ]
}

@test "placeVerifiedBinary: leaves no staging file behind on success" {
  local sha dest
  sha="$(src_sha)"
  dest="$WORK/dest-clean"
  run node -e 'require(process.argv[1]).placeVerifiedBinary(process.argv[2], process.argv[3], process.argv[4], "", "wb-runtime")' \
    "$RUNTIME_LIB" "$SRC" "$sha" "$dest"
  [ "$status" -eq 0 ]
  # Only the final binary should remain — no .wb-runtime.*.tmp staging artifact.
  run bash -c "ls -A '$dest'"
  [ "$output" = "wb-runtime" ]
}
