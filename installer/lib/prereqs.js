"use strict";

const { resolveBash, whichExecutable } = require("./run");

// requireGit() -> throws an actionable error if git is not on PATH. git is
// needed to clone/update the WannaBuild checkout.
function requireGit() {
  if (!whichExecutable(process.platform === "win32" ? "git.exe" : "git")) {
    throw new Error(
      "git is required but was not found on PATH.\n" +
        "Install git (https://git-scm.com/downloads) and re-run."
    );
  }
}

// requireBash() -> throws if no usable bash interpreter can be located. The
// host install scripts are bash; without bash we cannot install and must not
// silently degrade.
function requireBash() {
  // resolveBash throws its own actionable message when nothing is usable.
  resolveBash();
}

// requirePythonForHosts(hosts) -> throws if any selected host needs Python and
// none is on PATH. The Claude and Factory install scripts run Python to edit
// the host JSON config; Codex and Cursor do not. The message mirrors
// install-claude-skill.sh's guidance so users see the same instructions
// regardless of where the check fires.
function requirePythonForHosts(hosts) {
  const needsPython = hosts.some((host) => host === "claude" || host === "factory");
  if (!needsPython) {
    return;
  }
  const found = ["python3", "python", "py"].some((name) => whichExecutable(name));
  if (found) {
    return;
  }
  throw new Error(
    "No Python interpreter on PATH.\n\n" +
      "WannaBuild's Claude and Factory install scripts (and the runtime hook) need\n" +
      "Python 3.x. Install one of:\n" +
      "  - macOS:   brew install python@3.11\n" +
      "  - Ubuntu:  sudo apt-get install python3\n" +
      "  - Windows: install from python.org and ensure python3 is on PATH\n\n" +
      "Then re-run."
  );
}

module.exports = { requireGit, requireBash, requirePythonForHosts };
