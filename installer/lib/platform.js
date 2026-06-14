"use strict";

// Map the running Node process to the release-asset LABEL whose prebuilt
// wb-runtime archive is published on each GitHub release, plus the executable
// suffix the binary inside that archive uses. These labels MUST match the build
// matrix in the release-binaries job of .github/workflows/release-please.yml.
const TARGETS = {
  "darwin:arm64": { label: "macos-arm64", exe: "" },
  "darwin:x64": { label: "macos-x86_64", exe: "" },
  "linux:x64": { label: "linux-x86_64", exe: "" },
  "linux:arm64": { label: "linux-arm64", exe: "" },
  "win32:x64": { label: "windows-x86_64", exe: ".exe" },
};

// resolveTarget(platform, arch) -> { label, exe }
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
  return { label: target.label, exe: target.exe };
}

module.exports = { resolveTarget, TARGETS };
