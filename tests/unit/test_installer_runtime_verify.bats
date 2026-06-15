#!/usr/bin/env bats
#
# Unit tests for the two security-critical verification steps of the npx
# installer:
#   1. installer/lib/minisign.js verify() — the detached minisign (Ed25519)
#      signature over the release SHA256SUMS manifest is the trust root.
#   2. installer/lib/runtime.js extractVerifiedBinary — the archive's sha256
#      must match the (now signed) expected digest before the binary is placed.
#
# Contract: the prebuilt wb-runtime archive is verified, extracted, and the
# binary installed at the canonical resolver path ONLY when the archive's
# sha256 matches a digest read from a signed manifest. A bad signature, a
# tampered manifest, or a sha256 mismatch all refuse and leave nothing at the
# destination, so an unverified binary can never become the active gate engine.
# No network and no external signer: the .tar.gz is built locally (exactly as
# the release-binaries job packages it) and the minisign keypair + signature are
# generated with Node crypto in the standard minisign wire format, so these
# tests run wherever node does.

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

RUNTIME_LIB="${REPO_ROOT}/installer/lib/runtime.js"
MINISIGN_LIB="${REPO_ROOT}/installer/lib/minisign.js"

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

# write_minisign_fixture <dir>: emits SHA256SUMS, key.pub, wrong.pub, and a
# genuine SHA256SUMS.minisig (minisign prehashed "ED" wire format) using only
# Node crypto — no minisign/rsign binary, so the signature cases run everywhere.
write_minisign_fixture() {
  WORK_DIR="$1" node <<'NODE'
const fs = require("fs"), c = require("crypto");
const dir = process.env.WORK_DIR;
const rawPub = (pk) => pk.export({ format: "der", type: "spki" }).slice(-32);
const manifest = Buffer.from(
  "1111111111111111111111111111111111111111111111111111111111111111  wb-runtime-vX-test.tar.gz\n"
);
const kp = c.generateKeyPairSync("ed25519");
const keyID = Buffer.from("0102030405060708", "hex");
// minisign prehashed mode: Ed25519 over BLAKE2b-512(message).
const prehash = c.createHash("blake2b512").update(manifest).digest();
const sig = c.sign(null, prehash, kp.privateKey);
const tc = "timestamp:0\tfile:SHA256SUMS\tprehashed";
const gsig = c.sign(null, Buffer.concat([sig, Buffer.from(tc)]), kp.privateKey);
const pub =
  "untrusted comment: wannabuild test\n" +
  Buffer.concat([Buffer.from("Ed"), keyID, rawPub(kp.publicKey)]).toString("base64") + "\n";
const sigFile =
  "untrusted comment: wannabuild test\n" +
  Buffer.concat([Buffer.from("ED"), keyID, sig]).toString("base64") + "\n" +
  "trusted comment: " + tc + "\n" + gsig.toString("base64") + "\n";
fs.writeFileSync(dir + "/SHA256SUMS", manifest);
fs.writeFileSync(dir + "/key.pub", pub);
fs.writeFileSync(dir + "/SHA256SUMS.minisig", sigFile);
// An unrelated keypair (different keyID + key) for the wrong-key case.
const kp2 = c.generateKeyPairSync("ed25519");
fs.writeFileSync(
  dir + "/wrong.pub",
  "untrusted comment: wrong\n" +
    Buffer.concat([Buffer.from("Ed"), Buffer.from("0807060504030201", "hex"), rawPub(kp2.publicKey)]).toString("base64") + "\n"
);
NODE
}

# minisign_verify <manifest> <sig> <pub>: prints "true"/"false" from verify().
minisign_verify() {
  node -e 'const m=require(process.argv[1]),fs=require("fs");process.stdout.write(String(m.verify(fs.readFileSync(process.argv[2]),fs.readFileSync(process.argv[3],"utf8"),fs.readFileSync(process.argv[4],"utf8"))))' \
    "$MINISIGN_LIB" "$1" "$2" "$3"
}

@test "minisign.verify: accepts a genuine signature over the manifest" {
  write_minisign_fixture "$WORK"
  run minisign_verify "$WORK/SHA256SUMS" "$WORK/SHA256SUMS.minisig" "$WORK/key.pub"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "minisign.verify: rejects a tampered manifest (digest byte flipped)" {
  write_minisign_fixture "$WORK"
  node -e 'const fs=require("fs");const b=fs.readFileSync(process.argv[1]);b[0]^=1;fs.writeFileSync(process.argv[1],b)' "$WORK/SHA256SUMS"
  run minisign_verify "$WORK/SHA256SUMS" "$WORK/SHA256SUMS.minisig" "$WORK/key.pub"
  [ "$output" = "false" ]
}

@test "minisign.verify: rejects a corrupted signature" {
  write_minisign_fixture "$WORK"
  node -e 'const fs=require("fs");const L=fs.readFileSync(process.argv[1],"utf8").split("\n");const s=Buffer.from(L[1],"base64");s[20]^=1;L[1]=s.toString("base64");fs.writeFileSync(process.argv[1],L.join("\n"))' "$WORK/SHA256SUMS.minisig"
  run minisign_verify "$WORK/SHA256SUMS" "$WORK/SHA256SUMS.minisig" "$WORK/key.pub"
  [ "$output" = "false" ]
}

@test "minisign.verify: rejects an absent signature (fail closed)" {
  write_minisign_fixture "$WORK"
  : >"$WORK/empty.minisig"
  run minisign_verify "$WORK/SHA256SUMS" "$WORK/empty.minisig" "$WORK/key.pub"
  [ "$output" = "false" ]
}

@test "minisign.verify: rejects a signature from the wrong key (keyID mismatch)" {
  write_minisign_fixture "$WORK"
  run minisign_verify "$WORK/SHA256SUMS" "$WORK/SHA256SUMS.minisig" "$WORK/wrong.pub"
  [ "$output" = "false" ]
}

@test "minisign.verify: rejects a forged trusted comment (global signature)" {
  write_minisign_fixture "$WORK"
  node -e 'const fs=require("fs");const L=fs.readFileSync(process.argv[1],"utf8").split("\n");L[2]="trusted comment: forged";fs.writeFileSync(process.argv[1],L.join("\n"))' "$WORK/SHA256SUMS.minisig"
  run minisign_verify "$WORK/SHA256SUMS" "$WORK/SHA256SUMS.minisig" "$WORK/key.pub"
  [ "$output" = "false" ]
}
