"use strict";

const KNOWN_SUBCOMMANDS = ["install", "doctor", "uninstall", "help", "version"];
const HOST_FLAGS = ["claude", "codex", "factory", "cursor"];

// parseArgs(argv) -> parsed options, or { error } when the input is malformed.
// argv is the raw process argv without the leading [node, script] entries.
//
// Shape on success:
//   {
//     subcommand: "install" | "doctor" | "uninstall" | "help" | "version",
//     hosts: string[] | null,   // null => auto-detect; non-empty => explicit set
//     dir: string | null,       // null => caller default (~/.wannabuild)
//     ref: string | null,       // null => latest release tag
//     yes: boolean,             // non-interactive
//     purge: boolean,           // uninstall --purge
//   }
function parseArgs(argv) {
  const opts = {
    subcommand: null,
    hosts: [],
    dir: null,
    ref: null,
    yes: false,
    purge: false,
  };
  let helpFlag = false;
  let versionFlag = false;

  const args = Array.isArray(argv) ? argv.slice() : [];
  while (args.length > 0) {
    const arg = args.shift();

    if (arg === "--help" || arg === "-h") {
      helpFlag = true;
      continue;
    }
    if (arg === "--version" || arg === "-v") {
      versionFlag = true;
      continue;
    }
    if (arg === "--yes" || arg === "-y") {
      opts.yes = true;
      continue;
    }
    if (arg === "--purge") {
      opts.purge = true;
      continue;
    }
    if (arg === "--claude" || arg === "--codex" || arg === "--factory" || arg === "--cursor") {
      opts.hosts.push(arg.slice(2));
      continue;
    }
    if (arg === "--dir" || arg === "--ref") {
      const key = arg.slice(2);
      if (args.length === 0) {
        return { error: `Flag ${arg} requires a value.` };
      }
      opts[key] = args.shift();
      continue;
    }
    if (arg.startsWith("--dir=")) {
      opts.dir = arg.slice("--dir=".length);
      continue;
    }
    if (arg.startsWith("--ref=")) {
      opts.ref = arg.slice("--ref=".length);
      continue;
    }
    if (arg.startsWith("-")) {
      return { error: `Unknown flag: ${arg}` };
    }
    // First bare token is the subcommand; any further bare token is an error.
    if (opts.subcommand === null) {
      if (!KNOWN_SUBCOMMANDS.includes(arg)) {
        return { error: `Unknown subcommand: ${arg}`, subcommand: "help" };
      }
      opts.subcommand = arg;
      continue;
    }
    return { error: `Unexpected argument: ${arg}` };
  }

  // Bare flags map to their subcommands when none was given explicitly.
  if (helpFlag) {
    opts.subcommand = "help";
  } else if (versionFlag && opts.subcommand === null) {
    opts.subcommand = "version";
  } else if (opts.subcommand === null) {
    opts.subcommand = "install";
  }

  // null hosts means auto-detect; an explicit set disables detection.
  opts.hosts = opts.hosts.length > 0 ? dedupe(opts.hosts) : null;
  return opts;
}

function dedupe(list) {
  return list.filter((value, index) => list.indexOf(value) === index);
}

module.exports = { parseArgs, KNOWN_SUBCOMMANDS, HOST_FLAGS };
