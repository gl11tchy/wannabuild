"use strict";

const fs = require("node:fs");
const path = require("node:path");
const readline = require("node:readline");
const { runCapture } = require("./run");

const REPO_URL = "https://github.com/gl11tchy/wannabuild";

// resolveRef(ref) -> a concrete git ref to check out and to derive the asset
// version from. When ref is provided it is returned verbatim. Otherwise we ask
// the remote for the latest release tag (highest semver vX.Y.Z) so checkout and
// downloaded binary stay in lockstep.
function resolveRef(ref) {
  if (ref) {
    return ref;
  }
  const tag = latestReleaseTag();
  if (!tag) {
    throw new Error(
      "Could not determine the latest WannaBuild release tag from " +
        `${REPO_URL}. Pass --ref <tag> explicitly (e.g. --ref v2.6.0).`
    );
  }
  return tag;
}

// latestReleaseTag() -> highest semver-style vX.Y.Z tag on the remote, or null.
// Uses `git ls-remote --tags` so no GitHub API token is needed and behaviour is
// identical in CI and on a developer machine.
function latestReleaseTag() {
  const result = runCapture("git", ["ls-remote", "--tags", REPO_URL]);
  if (result.status !== 0 || !result.stdout) {
    return null;
  }
  const versions = [];
  for (const line of result.stdout.split("\n")) {
    const match = line.match(/refs\/tags\/(v\d+\.\d+\.\d+)\^?\{?\}?$/);
    if (match) {
      versions.push(match[1]);
    }
  }
  if (versions.length === 0) {
    return null;
  }
  versions.sort(compareSemverTags);
  return versions[versions.length - 1];
}

function compareSemverTags(a, b) {
  const pa = a.replace(/^v/, "").split(".").map(Number);
  const pb = b.replace(/^v/, "").split(".").map(Number);
  for (let i = 0; i < 3; i++) {
    if (pa[i] !== pb[i]) {
      return pa[i] - pb[i];
    }
  }
  return 0;
}

// ensureCheckout({ dir, ref, yes }) -> resolved absolute dir.
// Guarantees <dir> is a clean checkout of REPO_URL at ref:
//   - missing dir            -> clone, then checkout ref
//   - existing git checkout  -> fetch, then checkout ref (after confirmation)
//   - existing non-repo dir  -> refuse (never blow away unknown content)
async function ensureCheckout(options) {
  const dir = path.resolve(options.dir);
  const ref = options.ref;
  const yes = Boolean(options.yes);

  if (!fs.existsSync(dir)) {
    cloneRepo(dir);
    checkoutRef(dir, ref);
    return dir;
  }

  if (!isGitCheckout(dir)) {
    throw new Error(
      `Refusing to use ${dir}: it exists but is not a WannaBuild git checkout.\n` +
        "Pass a different --dir, or remove that directory yourself first."
    );
  }

  if (!yes) {
    const ok = await confirm(
      `Update existing WannaBuild checkout at ${dir} to ${ref}? [y/N] `
    );
    if (!ok) {
      throw new Error("Aborted by user; checkout left unchanged.");
    }
  }

  fetchRepo(dir);
  checkoutRef(dir, ref);
  return dir;
}

function cloneRepo(dir) {
  fs.mkdirSync(path.dirname(dir), { recursive: true });
  const result = runCapture("git", ["clone", REPO_URL, dir]);
  if (result.status !== 0) {
    throw new Error(`git clone failed:\n${result.stderr || result.stdout}`);
  }
}

function fetchRepo(dir) {
  const result = runCapture("git", ["-C", dir, "fetch", "--tags", "--prune", "origin"]);
  if (result.status !== 0) {
    throw new Error(`git fetch failed:\n${result.stderr || result.stdout}`);
  }
}

function checkoutRef(dir, ref) {
  const result = runCapture("git", ["-C", dir, "checkout", "--quiet", ref]);
  if (result.status !== 0) {
    throw new Error(`git checkout ${ref} failed:\n${result.stderr || result.stdout}`);
  }
}

function isGitCheckout(dir) {
  return fs.existsSync(path.join(dir, ".git"));
}

// currentRef(dir) -> a human-readable description of the checked-out ref
// (tag name when on one, else short SHA), or null if it cannot be read.
function currentRef(dir) {
  const tag = runCapture("git", ["-C", dir, "describe", "--tags", "--exact-match"]);
  if (tag.status === 0 && tag.stdout) {
    return tag.stdout;
  }
  const sha = runCapture("git", ["-C", dir, "rev-parse", "--short", "HEAD"]);
  if (sha.status === 0 && sha.stdout) {
    return sha.stdout;
  }
  return null;
}

function confirm(question) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question(question, (answer) => {
      rl.close();
      resolve(/^y(es)?$/i.test(answer.trim()));
    });
  });
}

module.exports = { ensureCheckout, resolveRef, currentRef, REPO_URL };
