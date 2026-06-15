"use strict";

// Minimal minisign (Ed25519) signature verifier — pure `node:crypto`, zero
// dependencies, preserving the installer's "Node built-ins only" invariant. It
// verifies the detached minisign signature over the release `SHA256SUMS`
// manifest so a single tampered release asset cannot pass even if its own
// sha256 line is rewritten: the per-archive digest the installer trusts is read
// from a manifest whose signature is checked against the package-shipped key.
//
// Supports minisign's default prehashed mode (signature algorithm `ED`:
// Ed25519 over the BLAKE2b-512 hash of the message — what minisign and rsign2
// emit by default) as well as the legacy raw mode (`Ed`). Both the message
// signature and minisign's global signature (which authenticates the trusted
// comment) are verified.
//
// Wire format (base64-decoded payload lines):
//   public key : "Ed"(2) | keyID(8) | ed25519_public_key(32)            = 42 B
//   signature  : "ED"/"Ed"(2) | keyID(8) | ed25519_signature(64)        = 74 B
//   global sig : ed25519 over (signature(64) || trusted_comment_bytes)  = 64 B

const crypto = require("node:crypto");

// SubjectPublicKeyInfo DER prefix that wraps a raw 32-byte Ed25519 public key.
const ED25519_SPKI_PREFIX = Buffer.from("302a300506032b6570032100", "hex");
const TRUSTED_COMMENT_PREFIX = "trusted comment: ";

// parsePublicKey(pubText) -> { keyID: Buffer(8), publicKey: KeyObject }
// Throws on a malformed key: the public key ships inside this package, so a
// structural problem is a packaging bug worth surfacing loudly, not a silent
// verification failure.
function parsePublicKey(pubText) {
  const lines = String(pubText).trim().split(/\r?\n/);
  const raw = Buffer.from((lines[1] || "").trim(), "base64");
  if (raw.length !== 42 || raw.slice(0, 2).toString("latin1") !== "Ed") {
    throw new Error("Malformed minisign public key (expected an 'Ed' key on line 2).");
  }
  return {
    keyID: raw.slice(2, 10),
    publicKey: crypto.createPublicKey({
      key: Buffer.concat([ED25519_SPKI_PREFIX, raw.slice(10)]),
      format: "der",
      type: "spki",
    }),
  };
}

// parseSignature(sigText) -> parsed signature, or null if the (untrusted)
// signature text is structurally invalid. Returning null rather than throwing
// lets the caller fail closed uniformly on any bad/forged signature.
function parseSignature(sigText) {
  const lines = String(sigText).trim().split(/\r?\n/);
  const raw = Buffer.from((lines[1] || "").trim(), "base64");
  if (raw.length !== 74) return null;
  const trustedLine = lines[2] || "";
  if (!trustedLine.startsWith(TRUSTED_COMMENT_PREFIX)) return null;
  const globalSignature = Buffer.from((lines[3] || "").trim(), "base64");
  if (globalSignature.length !== 64) return null;
  return {
    algorithm: raw.slice(0, 2).toString("latin1"),
    keyID: raw.slice(2, 10),
    signature: raw.slice(10),
    trustedComment: trustedLine.slice(TRUSTED_COMMENT_PREFIX.length),
    globalSignature,
  };
}

// verify(manifestBytes, sigText, pubText) -> boolean
// True only when sigText is a valid minisign signature over manifestBytes under
// pubText. Returns false (never throws) for any failure on the untrusted
// signature — wrong key id, unsupported algorithm, bad message signature, or a
// forged trusted comment — so callers fail closed with a single check. Throws
// only if the package-shipped public key itself is malformed.
function verify(manifestBytes, sigText, pubText) {
  const { keyID, publicKey } = parsePublicKey(pubText);
  const sig = parseSignature(sigText);
  if (!sig) return false;
  if (!Buffer.from(keyID).equals(sig.keyID)) return false;

  const message = Buffer.isBuffer(manifestBytes)
    ? manifestBytes
    : Buffer.from(String(manifestBytes), "utf8");

  let signed;
  if (sig.algorithm === "ED") {
    signed = crypto.createHash("blake2b512").update(message).digest();
  } else if (sig.algorithm === "Ed") {
    signed = message;
  } else {
    return false;
  }

  if (!crypto.verify(null, signed, publicKey, sig.signature)) return false;

  const globalInput = Buffer.concat([sig.signature, Buffer.from(sig.trustedComment, "utf8")]);
  return crypto.verify(null, globalInput, publicKey, sig.globalSignature);
}

module.exports = { verify };
