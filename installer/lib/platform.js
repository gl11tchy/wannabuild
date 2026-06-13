"use strict";

// Map the running Node process to the Rust target triple whose prebuilt
// wb-runtime binary is published on each GitHub release, plus the executable
// suffix that target uses. These triples MUST match the build matrix in
// .github/workflows/release-binaries.yml.
const TARGETS = {
  "darwin:arm64": { triple: "aarch64-apple-darwin", exe: "" },
  "darwin:x64": { triple: "x86_64-apple-darwin", exe: "" },
  "linux:x64": { triple: "x86_64-unknown-linux-musl", exe: "" },
  "linux:arm64": { triple: "aarch64-unknown-linux-musl", exe: "" },
  "win32:x64": { triple: "x86_64-pc-windows-msvc", exe: ".exe" },
};

// resolveTarget(platform, arch) -> { triple, exe }
// platform/arch default to the current process. Throws an actionable error for
// any combination WannaBuild does not publish a binary for, listing what is
// supported so the user knows immediately whether to file an issue.
function resolveTarget(platform, arch) {
  const plat = platform || process.platform;
  const cpu = arch || process.arch;
  const key = `${plat}:${cpu}`;
  const target = TARGETS[key];
  if (!target) {
    const supported = Object.keys(TARGETS).join(", ");
    throw new Error(
      `WannaBuild has no prebuilt wb-runtime binary for ${key}.\n` +
        `Supported platform:arch combinations: ${supported}.\n` +
        "Build from source instead: clone https://github.com/gl11tchy/wannabuild " +
        "and run scripts/install-<host>.sh with cargo available, or open an issue " +
        "requesting this target."
    );
  }
  return { triple: target.triple, exe: target.exe };
}

module.exports = { resolveTarget, TARGETS };
