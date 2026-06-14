#!/usr/bin/env bats
#
# Unit tests for the security-critical verify-and-place step of the npx
# installer (installer/lib/runtime.js extractVerifiedBinary).
#
# Contract: the prebuilt wb-runtime archive is verified, extracted, and the
# binary installed at the canonical resolver path ONLY when the archive's
# sha256 matches the expected digest. On a mismatch the function refuses
# (throws) and leaves nothing at the destination, so an unverified binary can
# never become the active gate engine. No network: we build a local .tar.gz
# (exactly as the release-binaries job in release-please.yml packages it) and an
# independently-computed digest.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

RUNTIME_LIB="${REPO_ROOT}/installer/lib/runtime.js"

setup() {
  if ! command -v node >/dev/null 2>&1; then
    skip "node is required for installer unit tests"
  fi
  if ! command -v tar >/dev/null 2>&1; then
    skip "tar is required to build the runtime archive fixture"
  fi
  WORK="$(setup_tmpdir)"
  SRCDIR="$WORK/src"
  mkdir -p "$SRCDIR"
  printf '#!/bin/sh\necho "wb-runtime fake"\n' >"$SRCDIR/wb-runtime"
  chmod +x "$SRCDIR/wb-runtime"
  # Package exactly like the release-binaries job (release-please.yml): tar -czf ... -C <dir> wb-runtime.
  ARCHIVE="$WORK/wb-runtime-vX-test.tar.gz"
  tar -czf "$ARCHIVE" -C "$SRCDIR" wb-runtime
}

# archive_sha: sha256 of $ARCHIVE, computed independently of the code under test.
archive_sha() {
  node -e 'const c=require("crypto"),f=require("fs");process.stdout.write(c.createHash("sha256").update(f.readFileSync(process.argv[1])).digest("hex"))' "$ARCHIVE"
}

@test "extractVerifiedBinary: extracts and installs an executable when the sha256 matches" {
  local sha dest placed
  sha="$(archive_sha)"
  dest="$WORK/dest"
  # extractVerifiedBinary(archiveFile, expectedSha, workDir, destDir, exe)
  run node -e 'process.stdout.write(require(process.argv[1]).extractVerifiedBinary(process.argv[2], process.argv[3], process.argv[4], process.argv[5], ""))' \
    "$RUNTIME_LIB" "$ARCHIVE" "$sha" "$WORK" "$dest"
  [ "$status" -eq 0 ]
  placed="$dest/wb-runtime"
  [ -f "$placed" ]
  [ -x "$placed" ]
  run grep -q "wb-runtime fake" "$placed"
  [ "$status" -eq 0 ]
}

@test "extractVerifiedBinary: refuses (throws) and writes nothing on a sha256 mismatch" {
  local dest
  dest="$WORK/dest-bad"
  run node -e 'require(process.argv[1]).extractVerifiedBinary(process.argv[2], "0000000000000000000000000000000000000000000000000000000000000000", process.argv[3], process.argv[4], "")' \
    "$RUNTIME_LIB" "$ARCHIVE" "$WORK" "$dest"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Checksum mismatch"* ]]
  # Verification runs before extraction, so nothing reaches the destination.
  [ ! -e "$dest/wb-runtime" ]
}

@test "extractVerifiedBinary: leaves no staging file at the destination on success" {
  local sha dest
  sha="$(archive_sha)"
  dest="$WORK/dest-clean"
  run node -e 'require(process.argv[1]).extractVerifiedBinary(process.argv[2], process.argv[3], process.argv[4], process.argv[5], "")' \
    "$RUNTIME_LIB" "$ARCHIVE" "$sha" "$WORK" "$dest"
  [ "$status" -eq 0 ]
  # Only the final binary should remain — no .wb-runtime.*.tmp staging artifact.
  run bash -c "ls -A '$dest'"
  [ "$output" = "wb-runtime" ]
}
