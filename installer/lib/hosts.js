"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { runScript } = require("./run");

// Host directories under the user's home that signal "this host is present".
const HOST_DIRS = {
  claude: ".claude",
  codex: ".codex",
  factory: ".factory",
  cursor: ".cursor",
};

const ALL_HOSTS = ["claude", "codex", "factory", "cursor"];

// detectHosts() -> the hosts whose home directory exists. Used when the user
// passes no explicit --claude/--codex/--factory/--cursor flags.
function detectHosts() {
  const home = os.homedir();
  return ALL_HOSTS.filter((host) => directoryExists(path.join(home, HOST_DIRS[host])));
}

// resolveHosts(selected) -> the host set to install.
//   selected === null  -> auto-detect
//   selected is array  -> use it verbatim (caller already validated names)
function resolveHosts(selected) {
  if (selected && selected.length > 0) {
    return selected;
  }
  return detectHosts();
}

// installHost(host, ctx) -> { host, summary }
// Dispatches one host's install. ctx carries:
//   dir            absolute checkout root (also where the runtime was placed)
//   prebuilt       absolute path to <dir>/target/debug/wb-runtime
// Each bash script resolves its own ROOT from its location inside <dir>, so we
// just hand it WB_RUNTIME_PREBUILT and let it place/verify the binary.
function installHost(host, ctx) {
  switch (host) {
    case "claude":
      return runHostScript(host, "install-claude-skill.sh", ctx);
    case "codex":
      return runHostScript(host, "install-codex-skill.sh", ctx);
    case "factory":
      return runHostScript(host, "install-factory-plugin.sh", ctx);
    case "cursor":
      return installCursor(ctx);
    default:
      throw new Error(`Unknown host: ${host}`);
  }
}

function runHostScript(host, scriptName, ctx) {
  const scriptPath = path.join(ctx.dir, "scripts", scriptName);
  if (!fileExists(scriptPath)) {
    throw new Error(`Missing install script for ${host}: ${scriptPath}`);
  }
  runScript(scriptPath, {
    cwd: ctx.dir,
    env: { WB_RUNTIME_PREBUILT: ctx.prebuilt },
  });
  return { host, summary: hostSummary(host, ctx) };
}

// installCursor(ctx) -> writes guidance only. Cursor is rules-only and invokes
// no runtime, so there is no JSON registration and no binary placement. We
// confirm the rule file exists in the checkout and print where to load it from.
function installCursor(ctx) {
  const rulePath = path.join(ctx.dir, ".cursor", "rules", "wannabuild.mdc");
  if (!fileExists(rulePath)) {
    throw new Error(`Cursor rule pointer missing from checkout: ${rulePath}`);
  }
  process.stdout.write(
    "Cursor is rules-only and runs no runtime.\n" +
      `  Load this rule in Cursor: ${rulePath}\n` +
      "  Then describe a feature in chat to start the WannaBuild workflow.\n"
  );
  return { host: "cursor", summary: `rule pointer: ${rulePath} (no runtime)` };
}

function hostSummary(host, ctx) {
  switch (host) {
    case "claude":
      return `Claude plugin linked; runtime at ${ctx.prebuilt}`;
    case "codex":
      return `Codex skills linked; runtime copied to ~/.codex/bin/wb-runtime`;
    case "factory":
      return `Factory plugin + droids installed; runtime in factory plugin cache`;
    default:
      return host;
  }
}

function directoryExists(p) {
  try {
    return fs.statSync(p).isDirectory();
  } catch {
    return false;
  }
}

function fileExists(p) {
  try {
    return fs.statSync(p).isFile();
  } catch {
    return false;
  }
}

module.exports = { detectHosts, resolveHosts, installHost, ALL_HOSTS, HOST_DIRS };
