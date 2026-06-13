"use strict";

const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");

// resolveBash() -> absolute path or bare command for a usable bash interpreter.
// Order (per the NPX contract):
//   1. $WANNABUILD_BASH
//   2. bash on PATH
//   3. Git for Windows bash (both Program Files locations)
//   4. wsl.exe (bash via WSL)
// Throws an actionable error when nothing is found. The repo scripts already
// handle path translation/junctions; we never reimplement that here.
function resolveBash() {
  const override = process.env.WANNABUILD_BASH;
  if (override && fileExists(override)) {
    return { command: override, wrapWsl: false };
  }

  const onPath = whichBash();
  if (onPath) {
    return { command: onPath, wrapWsl: false };
  }

  if (process.platform === "win32") {
    const gitCandidates = [
      "C:\\Program Files\\Git\\bin\\bash.exe",
      "C:\\Program Files (x86)\\Git\\bin\\bash.exe",
    ];
    for (const candidate of gitCandidates) {
      if (fileExists(candidate)) {
        return { command: candidate, wrapWsl: false };
      }
    }
    if (whichExecutable("wsl.exe")) {
      return { command: "wsl.exe", wrapWsl: true };
    }
  }

  throw new Error(
    "No usable bash interpreter found.\n" +
      (process.platform === "win32"
        ? "Install Git for Windows (https://git-scm.com/download/win) or enable WSL, " +
          "or set WANNABUILD_BASH to a bash.exe path."
        : "Install bash, or set WANNABUILD_BASH to a bash path.")
  );
}

// runScript(scriptPath, { args, env, cwd }) -> void
// Spawns bash on the given repo script, inheriting stdio so the user sees the
// script's own output. Throws on a non-zero exit so callers fail loudly.
function runScript(scriptPath, options) {
  const opts = options || {};
  const { command, wrapWsl } = resolveBash();
  const scriptArgs = Array.isArray(opts.args) ? opts.args : [];

  const spawnArgs = wrapWsl
    ? ["bash", scriptPath, ...scriptArgs]
    : [scriptPath, ...scriptArgs];

  const result = spawnSync(command, spawnArgs, {
    stdio: "inherit",
    env: { ...process.env, ...(opts.env || {}) },
    cwd: opts.cwd || undefined,
  });

  if (result.error) {
    throw new Error(`Failed to run ${path.basename(scriptPath)}: ${result.error.message}`);
  }
  if (result.status !== 0) {
    const code = result.signal ? `signal ${result.signal}` : `exit code ${result.status}`;
    throw new Error(`${path.basename(scriptPath)} failed (${code}).`);
  }
}

// runCapture(command, args) -> { status, stdout, stderr }
// Runs a binary and captures its output. Used to read wb-runtime --version and
// to query the latest release tag via git. Never throws on non-zero exit; the
// caller decides what a failure means.
function runCapture(command, args) {
  const result = spawnSync(command, args || [], {
    encoding: "utf8",
    env: process.env,
  });
  return {
    status: result.status,
    signal: result.signal,
    error: result.error,
    stdout: (result.stdout || "").trim(),
    stderr: (result.stderr || "").trim(),
  };
}

function fileExists(p) {
  try {
    return fs.statSync(p).isFile();
  } catch {
    return false;
  }
}

function whichBash() {
  return whichExecutable(process.platform === "win32" ? "bash.exe" : "bash");
}

// whichExecutable(name) -> absolute path or null. Walks PATH manually so we do
// not depend on any external `which`/`where` binary being present.
function whichExecutable(name) {
  const pathEnv = process.env.PATH || "";
  const sep = process.platform === "win32" ? ";" : ":";
  const exts =
    process.platform === "win32"
      ? (process.env.PATHEXT || ".EXE;.CMD;.BAT").split(";")
      : [""];
  for (const dir of pathEnv.split(sep)) {
    if (!dir) continue;
    const base = path.join(dir, name);
    const candidates = name.includes(".") ? [base] : [base, ...exts.map((e) => base + e)];
    for (const candidate of candidates) {
      if (fileExists(candidate)) {
        return candidate;
      }
    }
  }
  return null;
}

module.exports = { resolveBash, runScript, runCapture, whichExecutable };
