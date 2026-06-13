"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const https = require("node:https");
const crypto = require("node:crypto");
const { resolveTarget } = require("./platform");
const { runCapture } = require("./run");

const RELEASE_BASE = "https://github.com/gl11tchy/wannabuild/releases/download";

// assetName(version, target) -> the published binary filename for this build.
// Mirrors the rename step in release-binaries.yml:
//   wb-runtime-v<version>-<triple>[.exe]
function assetName(version, target) {
  return `wb-runtime-v${version}-${target.triple}${target.exe}`;
}

// tagToVersion(tag) -> the asset version (tag without a leading "v").
function tagToVersion(tag) {
  return String(tag).replace(/^v/, "");
}

// installRuntime({ dir, version, tag }) -> { binaryPath, asset, sha256 }
// Downloads the prebuilt wb-runtime for this platform plus the release
// SHA256SUMS, verifies the binary's sha256 against the matching manifest line,
// then writes it to <dir>/target/debug/wb-runtime (mode 0o755). The binary is
// only moved into place after verification passes, so a corrupt download never
// becomes the active gate engine. Integrity rests on HTTPS-to-GitHub plus the
// checksum; the manifest itself is not independently signed (see installer
// README for the optional signing hardening).
async function installRuntime(options) {
  const dir = path.resolve(options.dir);
  const tag = options.tag;
  const version = options.version || tagToVersion(tag);
  const target = resolveTarget();
  const asset = assetName(version, target);

  const binUrl = `${RELEASE_BASE}/${tag}/${asset}`;
  const sumsUrl = `${RELEASE_BASE}/${tag}/SHA256SUMS`;

  const expected = await fetchExpectedSha(sumsUrl, asset);
  const tmpFile = path.join(
    os.tmpdir(),
    `wb-runtime-${process.pid}-${Date.now()}${target.exe}`
  );

  try {
    await downloadToFile(binUrl, tmpFile);
    // wb-runtime is the OS-native binary regardless of the upstream asset name;
    // Claude/Codex/Factory resolvers all look for target/debug/wb-runtime[.exe].
    const destDir = path.join(dir, "target", "debug");
    const binaryPath = placeVerifiedBinary(tmpFile, expected, destDir, target.exe, asset);
    return { binaryPath, asset, sha256: expected, target };
  } finally {
    safeUnlink(tmpFile);
  }
}

// placeVerifiedBinary(srcFile, expectedSha, destDir, exe, label) -> binaryPath
// Verifies srcFile's sha256 equals expectedSha BEFORE writing anything, then
// installs it atomically at destDir/wb-runtime[exe] (mode 0o755): the file is
// staged inside destDir and renamed into place, so a host resolver never
// observes a half-written or unverified binary at the canonical path. Exported
// so the verify/reject path is unit-testable without a network round trip.
function placeVerifiedBinary(srcFile, expectedSha, destDir, exe, label) {
  const actual = sha256File(srcFile);
  if (actual !== expectedSha) {
    throw new Error(
      `Checksum mismatch for ${label || path.basename(srcFile)}.\n` +
        `  expected: ${expectedSha}\n` +
        `  actual:   ${actual}\n` +
        "Refusing to install an unverified gate runtime. This usually means a " +
        "corrupted download or a network proxy rewriting the file. Re-run; if it " +
        "persists, open an issue."
    );
  }
  fs.mkdirSync(destDir, { recursive: true });
  const binaryPath = path.join(destDir, `wb-runtime${exe || ""}`);
  const staging = path.join(destDir, `.wb-runtime.${process.pid}.${Date.now()}.tmp`);
  try {
    fs.copyFileSync(srcFile, staging);
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

// verifyRuntimeVersion(binaryPath, expectedVersion) -> void
// Runs `wb-runtime --version` and asserts it equals the package version, so a
// stale or mismatched binary fails the install loudly instead of silently
// enforcing the wrong contract.
function verifyRuntimeVersion(binaryPath, expectedVersion) {
  const result = runCapture(binaryPath, ["--version"]);
  if (result.status !== 0) {
    throw new Error(
      `Placed wb-runtime but \`wb-runtime --version\` failed (exit ${result.status}).\n` +
        `${result.stderr || result.stdout}`
    );
  }
  // clap prints "wb-runtime <version>"; tolerate either bare or prefixed forms.
  const reported = result.stdout.split(/\s+/).pop();
  if (reported !== expectedVersion) {
    throw new Error(
      `Runtime version drift: wb-runtime reports ${reported} but this installer is ` +
        `${expectedVersion}. Re-run with a matching --ref, or report this.`
    );
  }
}

function fetchExpectedSha(sumsUrl, asset) {
  return fetchText(sumsUrl).then((body) => {
    for (const line of body.split("\n")) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      // GNU coreutils format: "<64hex>  <filename>" (two spaces).
      const match = trimmed.match(/^([0-9a-fA-F]{64})\s+\*?(.+)$/);
      if (match && match[2] === asset) {
        return match[1].toLowerCase();
      }
    }
    throw new Error(
      `SHA256SUMS does not list ${asset}. The release may be missing this ` +
        "platform's binary; open an issue with your OS/arch."
    );
  });
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

module.exports = {
  installRuntime,
  placeVerifiedBinary,
  verifyRuntimeVersion,
  assetName,
  tagToVersion,
  sha256File,
};
