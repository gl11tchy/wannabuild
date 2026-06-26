#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const { parseArgs } = require("../lib/args");
const { requireGit, requireBash, requirePythonForHosts } = require("../lib/prereqs");
const { ensureCheckout, resolveRef, currentRef } = require("../lib/checkout");
const { installRuntime, verifyRuntimeLiveness } = require("../lib/runtime");
const { resolveHosts, installHost } = require("../lib/hosts");
const { runScript, runCapture } = require("../lib/run");

const PKG = require("../package.json");
// The checkout lives in a subdirectory of ~/.wannabuild, never ~/.wannabuild
// itself. The runtime stores its out-of-tree evidence key at
// ~/.wannabuild/evidence.key (crates/wb-runtime/src/evidence.rs); defaulting the
// checkout to ~/.wannabuild would land the clone on top of that key, and
// ensureCheckout would then refuse the non-empty, non-git directory forever.
const DEFAULT_DIR = path.join(os.homedir(), ".wannabuild", "checkout");

main().catch((err) => {
  process.stderr.write(`\nwannabuild: ${err.message}\n`);
  process.exit(1);
});

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.error) {
    process.stderr.write(`wannabuild: ${opts.error}\n\n`);
    printHelp();
    process.exit(1);
  }

  switch (opts.subcommand) {
    case "help":
      printHelp();
      return;
    case "version":
      printVersion(opts);
      return;
    case "doctor":
      await runDoctor(opts);
      return;
    case "uninstall":
      runUninstall(opts);
      return;
    case "install":
    default:
      await runInstall(opts);
      return;
  }
}

async function runInstall(opts) {
  const dir = opts.dir ? path.resolve(opts.dir) : DEFAULT_DIR;
  const hosts = resolveHosts(opts.hosts);

  if (hosts.length === 0) {
    process.stderr.write(
      "wannabuild: no hosts detected (looked for ~/.claude, ~/.codex, ~/.factory, ~/.cursor).\n" +
        "Select one explicitly, e.g. `npx wannabuild --claude`.\n"
    );
    process.exit(1);
  }

  requireGit();
  requireBash();
  requirePythonForHosts(hosts);

  const tag = resolveRef(opts.ref);

  process.stdout.write(`WannaBuild installer v${PKG.version}\n`);
  process.stdout.write(`  checkout dir: ${dir}\n`);
  process.stdout.write(`  release ref:  ${tag}\n`);
  process.stdout.write(`  hosts:        ${hosts.join(", ")}\n\n`);

  await ensureCheckout({ dir, ref: tag, yes: opts.yes });

  // Cursor needs no runtime; only fetch/verify the binary when a runtime host
  // is selected so a Cursor-only install stays fully offline of releases.
  const needsRuntime = hosts.some((host) => host !== "cursor");
  let prebuilt = path.join(dir, "target", "debug", "wb-runtime");

  if (needsRuntime) {
    process.stdout.write("Downloading and verifying wb-runtime...\n");
    const placed = await installRuntime({ dir, tag, ref: opts.ref });
    prebuilt = placed.binaryPath;
    process.stdout.write(`  placed: ${prebuilt}\n`);
    process.stdout.write(`  sha256: ${placed.sha256}\n`);
    verifyRuntimeLiveness(prebuilt);
    process.stdout.write("  verified: wb-runtime executes on this platform\n\n");
  }

  const results = [];
  for (const host of hosts) {
    process.stdout.write(`Installing host: ${host}\n`);
    results.push(installHost(host, { dir, prebuilt }));
    process.stdout.write("\n");
  }

  process.stdout.write("WannaBuild installed.\n");
  for (const result of results) {
    process.stdout.write(`  ${result.host}: ${result.summary}\n`);
  }
  if (needsRuntime) {
    process.stdout.write(`\nRuntime binary: ${prebuilt}\n`);
  }
  process.stdout.write("\nRun `npx wannabuild doctor` to verify every host's runtime is wired.\n");
}

async function runDoctor(opts) {
  const dir = opts.dir ? path.resolve(opts.dir) : DEFAULT_DIR;
  const scriptPath = path.join(dir, "scripts", "wannabuild-doctor.sh");
  if (!fileExists(scriptPath)) {
    throw new Error(
      `No WannaBuild checkout at ${dir} (missing ${scriptPath}).\n` +
        "Run `npx wannabuild` first, or pass --dir to point at your checkout."
    );
  }
  runScript(scriptPath, { cwd: dir });
}

function runUninstall(opts) {
  const dir = opts.dir ? path.resolve(opts.dir) : DEFAULT_DIR;

  if (opts.purge) {
    if (!fs.existsSync(dir)) {
      process.stdout.write(`Nothing to purge: ${dir} does not exist.\n`);
      return;
    }
    if (!fs.existsSync(path.join(dir, ".git"))) {
      throw new Error(
        `Refusing to purge ${dir}: it is not a WannaBuild git checkout. ` +
          "Remove it yourself if you are sure."
      );
    }
    fs.rmSync(dir, { recursive: true, force: true });
    process.stdout.write(`Removed WannaBuild checkout: ${dir}\n`);
  } else {
    process.stdout.write(`WannaBuild checkout (not removed): ${dir}\n`);
    process.stdout.write("  To remove the checkout: npx wannabuild uninstall --purge\n");
  }

  process.stdout.write(
    "\nHost-managed entries are left in place. To remove them, delete the\n" +
      "matching entries below (the installer never deletes outside its checkout,\n" +
      "~/.codex/bin, or the documented host caches):\n\n" +
      `  Claude:  rm '${path.join(os.homedir(), ".claude/plugins/cache/gl11tchy/wannabuild")}'\n` +
      "           then remove \"wannabuild@gl11tchy\" from\n" +
      `           ${path.join(os.homedir(), ".claude/settings.json")} and installed_plugins.json\n` +
      `  Codex:   rm ${path.join(os.homedir(), ".codex/skills/wannabuild")} (and using-wannabuild, wb-*)\n` +
      `           rm ${path.join(os.homedir(), ".codex/bin/wb-runtime")}\n` +
      `  Factory: rm -r '${path.join(os.homedir(), ".factory/plugins/cache/wannabuild")}'\n` +
      `           rm ${path.join(os.homedir(), ".factory/droids")}/wb-*.md\n` +
      `  Cursor:  rm ${path.join(os.homedir(), ".cursor/rules/wannabuild.mdc")} (if you copied it)\n`
  );
}

function printVersion(opts) {
  process.stdout.write(`${PKG.version}\n`);
  const dir = opts.dir ? path.resolve(opts.dir) : DEFAULT_DIR;
  if (!fs.existsSync(path.join(dir, ".git"))) {
    return;
  }
  const ref = currentRef(dir);
  if (ref) {
    process.stdout.write(`checkout: ${dir} @ ${ref}\n`);
  }
  const bin = path.join(dir, "target", "debug", "wb-runtime");
  const binExe = process.platform === "win32" ? `${bin}.exe` : bin;
  const target = fileExists(binExe) ? binExe : fileExists(bin) ? bin : null;
  if (target) {
    const result = runCapture(target, ["--version"]);
    if (result.status === 0 && result.stdout) {
      process.stdout.write(`wb-runtime: ${result.stdout}\n`);
    }
  }
}

function printHelp() {
  process.stdout.write(
    `wannabuild ${PKG.version} — install WannaBuild into your coding-agent hosts\n` +
      "\n" +
      "Usage:\n" +
      "  npx wannabuild [install] [hosts] [options]   Install into detected/selected hosts\n" +
      "  npx wannabuild doctor [options]              Run the repo doctor against the checkout\n" +
      "  npx wannabuild uninstall [--purge] [--dir]   Show removal steps (or purge the checkout)\n" +
      "  npx wannabuild version                       Print versions (package, checkout, runtime)\n" +
      "  npx wannabuild help                          Show this help\n" +
      "\n" +
      "Host selection (any present disables auto-detect):\n" +
      "  --claude --codex --factory --cursor\n" +
      "\n" +
      "Options:\n" +
      "  --dir <path>   Checkout location (default: ~/.wannabuild/checkout)\n" +
      "  --ref <ref>    Git ref to install; pins checkout and asset (default: latest release tag)\n" +
      "  --yes, -y      Non-interactive; do not prompt before updating an existing checkout\n" +
      "  --purge        With uninstall: remove the checkout directory\n" +
      "  --version, -v  Print the installer version\n" +
      "  --help, -h     Show this help\n" +
      "\n" +
      "By default every detected host runs the real Rust wb-runtime gate engine —\n" +
      "never a degraded fallback. The binary is downloaded prebuilt and verified by\n" +
      "sha256 against the release checksums.\n"
  );
}

function fileExists(p) {
  try {
    return fs.statSync(p).isFile();
  } catch {
    return false;
  }
}
