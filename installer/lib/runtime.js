"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const https = require("node:https");
const crypto = require("node:crypto");
const { spawnSync } = require("node:child_process");
const { resolveTarget } = require("./platform");
const { runCapture } = require("./run");
const minisign = require("./minisign");

const RELEASE_BASE = "https://github.com/gl11tchy/wannabuild/releases/download";

// archiveName(tag, target) -> the published archive filename for this build.
// Mirrors the package step in the release-binaries job of release-please.yml:
//   wb-runtime-<tag>-<label>.tar.gz   (tag carries its leading "v")
function archiveName(tag, target) {
  return `wb-runtime-${tag}-${target.label}.tar.gz`;
}

// installRuntime({ dir, tag, ref }) -> { binaryPath, archive, sha256, target }
// Downloads the prebuilt wb-runtime archive for this platform, verifies its
// sha256 against the release's minisign-signed SHA256SUMS manifest, extracts the
// binary, and installs it atomically at <dir>/target/debug/wb-runtime[.exe]
// (mode 0o755). The trusted digest comes from a manifest whose Ed25519 signature
// is checked against the public key shipped in this package BEFORE any binary is
// downloaded, so a single tampered release asset cannot pass even if its own
// sha256 line is rewritten. The binary is only placed after the archive's sha256
// matches that signed digest, so a corrupt or forged download never becomes the
// active gate engine.
async function installRuntime(options) {
  const dir = path.resolve(options.dir);
  const tag = options.tag;
  const pinnedRef = options.ref || null;
  const target = resolveTarget();
  const archive = archiveName(tag, target);

  const archiveUrl = `${RELEASE_BASE}/${tag}/${archive}`;

  let expected;
  try {
    expected = await resolveExpectedSha(tag, archive, pinnedRef);
  } catch (err) {
    throw friendlyDownloadError(err, tag, archive);
  }
  const workDir = fs.mkdtempSync(path.join(os.tmpdir(), "wb-runtime-"));
  const tmpArchive = path.join(workDir, archive);

  try {
    try {
      await downloadToFile(archiveUrl, tmpArchive);
    } catch (err) {
      throw friendlyDownloadError(err, tag, archive);
    }
    const binaryPath = extractVerifiedBinary(tmpArchive, expected, workDir, path.join(dir, "target", "debug"), target.exe);
    return { binaryPath, archive, sha256: expected, target };
  } finally {
    safeRmrf(workDir);
  }
}

// friendlyDownloadError(err, tag, archive) -> Error
// Turns a bare HTTP 404 (release carries no prebuilt assets yet, or none for
// this platform) into actionable guidance instead of a cryptic status code.
function friendlyDownloadError(err, tag, archive) {
  if (err && /HTTP 404/.test(String(err.message))) {
    return new Error(
      `No prebuilt wb-runtime asset for release ${tag} (looked for ${archive}).\n` +
        "That release may predate the prebuilt-binary workflow, or your platform's " +
        "build is not published yet. Install from a release that carries " +
        "wb-runtime-*.tar.gz assets:\n" +
        "  npx wannabuild --ref <tag>\n" +
        "Releases: https://github.com/gl11tchy/wannabuild/releases"
    );
  }
  return err;
}

// extractVerifiedBinary(archiveFile, expectedSha, workDir, destDir, exe) -> binaryPath
// Verifies archiveFile's sha256 equals expectedSha BEFORE unpacking anything,
// extracts wb-runtime[exe] from it, then installs the binary atomically at
// destDir/wb-runtime[exe] (staged inside destDir then renamed, mode 0o755) so a
// host resolver never observes a half-written or unverified binary. Exported so
// the verify/reject path is unit-testable without a network round trip.
function extractVerifiedBinary(archiveFile, expectedSha, workDir, destDir, exe) {
  const actual = sha256File(archiveFile);
  if (actual !== expectedSha) {
    throw new Error(
      `Checksum mismatch for ${path.basename(archiveFile)}.\n` +
        `  expected: ${expectedSha}\n` +
        `  actual:   ${actual}\n` +
        "Refusing to install an unverified gate runtime. This usually means a " +
        "corrupted download or a network proxy rewriting the file. Re-run; if it " +
        "persists, open an issue."
    );
  }

  const binName = `wb-runtime${exe || ""}`;
  const extractDir = fs.mkdtempSync(path.join(workDir, "x-"));
  const res = spawnSync("tar", ["-xzf", archiveFile, "-C", extractDir], { stdio: "pipe" });
  if (res.error || res.status !== 0) {
    const detail = res.error ? res.error.message : String(res.stderr || "");
    throw new Error(
      `Failed to unpack ${path.basename(archiveFile)} with tar: ${detail}\n` +
        "tar is required to extract the runtime archive (preinstalled on macOS, " +
        "Linux, and Windows 10+). Install tar and re-run."
    );
  }
  const extracted = path.join(extractDir, binName);
  if (!fs.existsSync(extracted)) {
    throw new Error(`Archive ${path.basename(archiveFile)} did not contain ${binName}.`);
  }

  fs.mkdirSync(destDir, { recursive: true });
  const binaryPath = path.join(destDir, binName);
  const staging = path.join(destDir, `.wb-runtime.${process.pid}.${Date.now()}.tmp`);
  try {
    fs.copyFileSync(extracted, staging);
    fs.chmodSync(staging, 0o755);
    // rename is atomic within a filesystem, so the canonical path flips from
    // absent/old to fully-written-and-executable in one step.
    fs.renameSync(staging, binaryPath);
  } catch (err) {
    safeUnlink(staging);
    throw err;
  }
  return binaryPath;
}

// verifyRuntimeLiveness(binaryPath) -> void
// Runs `wb-runtime --version` to confirm the placed binary actually executes on
// this platform; throws otherwise. wb-runtime is intentionally versioned 0.1.0
// independent of the release tag, so this is a liveness check (does it run?),
// not a version-equality assertion.
function verifyRuntimeLiveness(binaryPath) {
  const result = runCapture(binaryPath, ["--version"]);
  if (result.status !== 0) {
    const why = result.stderr || result.stdout || (result.error && result.error.message) || "";
    throw new Error(
      `Placed wb-runtime but it failed to execute (\`wb-runtime --version\` exit ${result.status}).\n${why}`
    );
  }
}

const MANIFEST_NAME = "SHA256SUMS";

// resolveExpectedSha(tag, archive, pinnedRef) -> the trusted sha256 for archive.
//
// Trust root: download the signed SHA256SUMS manifest and its minisign
// signature, verify the signature against the public key shipped in this package
// BEFORE any binary is fetched, then read this archive's digest from the
// now-trusted manifest. Fails closed — a missing or forged signature, the wrong
// key, or a manifest that omits this archive all throw before any install.
//
// Legacy opt-in: a release that predates signed manifests publishes no
// SHA256SUMS. Only when the user explicitly pinned --ref to such a tag do we
// fall back to its unsigned per-archive <archive>.sha256, with a loud warning. A
// default/latest install refuses an unsigned release, so the unsigned path is
// never reachable without a deliberate --ref — there is no silent downgrade.
async function resolveExpectedSha(tag, archive, pinnedRef) {
  const base = `${RELEASE_BASE}/${tag}`;
  const manifestUrl = `${base}/${MANIFEST_NAME}`;

  let manifest;
  try {
    manifest = await fetchText(manifestUrl);
  } catch (err) {
    if (!isHttp404(err)) throw err;
    return resolveUnsignedSha(base, archive, tag, pinnedRef);
  }

  let signature;
  try {
    signature = await fetchText(`${manifestUrl}.minisig`);
  } catch (err) {
    if (isHttp404(err)) {
      throw new Error(
        `Release ${tag} publishes ${MANIFEST_NAME} but not ${MANIFEST_NAME}.minisig. ` +
          "Refusing to install against an unsigned checksum manifest."
      );
    }
    throw err;
  }

  const pubKey = fs.readFileSync(path.join(__dirname, "..", "wannabuild-release.pub"), "utf8");
  if (!minisign.verify(Buffer.from(manifest, "utf8"), signature, pubKey)) {
    throw new Error(
      `Signature verification FAILED for ${tag}/${MANIFEST_NAME}.\n` +
        "The release checksum manifest is not signed by the WannaBuild release " +
        "key shipped with this installer. Refusing to install — this is exactly " +
        "the tampered/forged-release case the signature exists to stop."
    );
  }

  return shaFromManifest(manifest, archive, MANIFEST_NAME);
}

// resolveUnsignedSha: the pre-signing fallback. Reachable only via an explicit
// --ref to a tag that publishes no signed manifest.
function resolveUnsignedSha(base, archive, tag, pinnedRef) {
  if (!pinnedRef) {
    throw new Error(
      `Release ${tag} has no signed ${MANIFEST_NAME} manifest, so the wb-runtime ` +
        "binary cannot be checked against a signed checksum. Refusing to install.\n" +
        "Install the latest signed release:\n" +
        "  npx wannabuild\n" +
        "Releases: https://github.com/gl11tchy/wannabuild/releases"
    );
  }
  process.stderr.write(
    `\n⚠ UNSIGNED RELEASE: ${tag} predates signed checksum manifests.\n` +
      `  Verifying ${archive} against its unsigned ${archive}.sha256 only ` +
      "(HTTPS + sha256,\n  no signature). You pinned this with --ref; a default " +
      "install would refuse it.\n  Prefer a signed release where possible.\n\n"
  );
  return fetchExpectedSha(`${base}/${archive}.sha256`, archive);
}

// fetchExpectedSha(sumUrl, archive) -> sha256 from a standalone per-archive
// .sha256 file (the legacy, unsigned format kept for pre-signing releases).
function fetchExpectedSha(sumUrl, archive) {
  return fetchText(sumUrl).then((body) => shaFromManifest(body, archive, `${archive}.sha256`));
}

// shaFromManifest(body, archive, sourceLabel) -> the lowercase sha256 listed for
// archive in a "<64hex>  <filename>" checksum body (shasum/GNU/sha256sum format,
// optional "*"). Throws if the archive is not listed.
function shaFromManifest(body, archive, sourceLabel) {
  for (const line of body.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    const match = trimmed.match(/^([0-9a-fA-F]{64})\s+\*?(.+)$/);
    if (match && path.basename(match[2]) === archive) {
      return match[1].toLowerCase();
    }
  }
  throw new Error(
    `${sourceLabel} did not list a checksum for ${archive}. The release may ` +
      "be missing this platform's archive; open an issue with your OS/arch."
  );
}

// isHttp404(err) -> true if err is a fetch failure carrying HTTP 404.
function isHttp404(err) {
  return Boolean(err && /HTTP 404/.test(String(err.message)));
}

// downloadToFile(url, dest) -> resolves once the response is fully written.
// Follows GitHub's redirect to the asset CDN. Treats any non-2xx final status
// as fatal.
function downloadToFile(url, dest) {
  return new Promise((resolve, reject) => {
    const request = (current, redirects) => {
      if (redirects > 10) {
        reject(new Error(`Too many redirects fetching ${url}`));
        return;
      }
      https
        .get(current, { headers: { "User-Agent": "wannabuild-installer" } }, (res) => {
          const status = res.statusCode || 0;
          if (status >= 300 && status < 400 && res.headers.location) {
            res.resume();
            request(new URL(res.headers.location, current).toString(), redirects + 1);
            return;
          }
          if (status !== 200) {
            res.resume();
            reject(
              new Error(
                `Download failed (HTTP ${status}) for ${current}. ` +
                  "The release asset for your platform may not exist yet."
              )
            );
            return;
          }
          const out = fs.createWriteStream(dest);
          res.pipe(out);
          out.on("finish", () => out.close(resolve));
          out.on("error", (err) => {
            safeUnlink(dest);
            reject(err);
          });
        })
        .on("error", reject);
    };
    request(url, 0);
  });
}

function fetchText(url) {
  return new Promise((resolve, reject) => {
    const request = (current, redirects) => {
      if (redirects > 10) {
        reject(new Error(`Too many redirects fetching ${url}`));
        return;
      }
      https
        .get(current, { headers: { "User-Agent": "wannabuild-installer" } }, (res) => {
          const status = res.statusCode || 0;
          if (status >= 300 && status < 400 && res.headers.location) {
            res.resume();
            request(new URL(res.headers.location, current).toString(), redirects + 1);
            return;
          }
          if (status !== 200) {
            res.resume();
            reject(new Error(`Fetch failed (HTTP ${status}) for ${current}.`));
            return;
          }
          let body = "";
          res.setEncoding("utf8");
          res.on("data", (chunk) => {
            body += chunk;
          });
          res.on("end", () => resolve(body));
        })
        .on("error", reject);
    };
    request(url, 0);
  });
}

function sha256File(file) {
  const hash = crypto.createHash("sha256");
  hash.update(fs.readFileSync(file));
  return hash.digest("hex");
}

function safeUnlink(file) {
  try {
    fs.unlinkSync(file);
  } catch {
    // best-effort cleanup
  }
}

function safeRmrf(dir) {
  try {
    fs.rmSync(dir, { recursive: true, force: true });
  } catch {
    // best-effort cleanup
  }
}

module.exports = {
  installRuntime,
  extractVerifiedBinary,
  verifyRuntimeLiveness,
  archiveName,
  sha256File,
};
