# Runbook: install + plugin-load failures

Real failure modes users hit when installing WannaBuild into Claude Code,
Codex, Cursor, or Factory — with diagnostics and fixes. Add new entries here
the first time a user reports a failure rather than letting them be lost in
issue history.

---

## `/plugin` Errors tab shows `TypeError: v?.reduce is not a function`

**Symptom.** Opening `/plugin` in Claude Code surfaces an entry under the
Errors tab attributed to `plugin-system`:

```text
v?.reduce is not a function.
(In 'v?.reduce((E,h)=>E+h.hooks.length,0)', 'v?.reduce' is undefined)
```

The same error pattern (`?.reduce` over `h.hooks.length`) was previously
caused by a wrapped `hooks/hooks.json`; this is a different surface in
Claude Code's plugin UI.

**Cause.** A stray `"hooks": "./hooks/hooks.json"` field on the plugin entry
inside `.claude-plugin/marketplace.json`. Every other plugin in every
marketplace leaves this field undefined, so Claude Code's UI reducer
short-circuits the optional chain. The wannabuild entry held a string left
over from before inline hooks landed in `.claude-plugin/plugin.json`, and the
reducer crashes trying to call `.reduce` on it.

The canonical hook definition lives inline in `.claude-plugin/plugin.json`;
the marketplace.json field was redundant.

**Diagnose.**

```bash
jq '.plugins[] | select(.name=="wannabuild") | .hooks' \
  ~/.claude/plugins/marketplaces/gl11tchy/.claude-plugin/marketplace.json
```

If the output is anything other than `null`, you have the broken declaration.

**Fix.** Upgrade WannaBuild (`/plugin update wannabuild@gl11tchy`). The
release removes the stray field; `scripts/wannabuild-doctor.sh` now asserts
its absence to prevent regression.

---

## `/plugin` reports `Failed to load hooks from .../hooks/hooks.json`

**Symptom.** Per-plugin error under wannabuild:

```text
Failed to load hooks from .../hooks/hooks.json: [
  { "expected": "record", "code": "invalid_type", "path": ["hooks"],
    "message": "Invalid input: expected record, received undefined" }
]
```

**Cause.** `hooks/hooks.json` is in the legacy unwrapped event-map shape
(`{ "SessionStart": [...], "UserPromptSubmit": [...] }`). Claude Code's
current plugin loader requires the file to be wrapped under a top-level
`hooks` key:

```json
{ "hooks": { "SessionStart": [...], "UserPromptSubmit": [...] } }
```

The unwrapped shape was adopted in WannaBuild 2.2.5 to fix a different
`?.reduce` crash from an earlier Claude Code build. That code path has since
been rewritten, and the current loader rejects the unwrapped shape.

**Diagnose.**

```bash
python3 -c 'import json,sys; print(list(json.load(open(sys.argv[1])).keys()))' \
  ~/.claude/plugins/cache/gl11tchy/wannabuild/*/hooks/hooks.json
```

If you see event names (`['SessionStart', 'UserPromptSubmit']`) instead of
`['hooks']`, you have the legacy unwrapped shape.

**Fix.** Upgrade WannaBuild (`/plugin update wannabuild@gl11tchy`). The
release re-wraps the file; `tests/unit/test_plugin_hooks_shape.bats` pins
the new shape.

---

## Plugin appears installed but doesn't route natural-language prompts

**Symptom.** Doctor passes, install script reported success, but typing a
feature request in Claude Code does nothing — no autoroute, no skills loaded.

**Cause.** Claude Code reads plugin state at session start. The new install is
not picked up until a reload.

**Fix.** Run `/reload-plugins` in Claude Code. If that errors, see the entry
above.

---

## `${CLAUDE_PLUGIN_ROOT}` not expanded in hook command

**Symptom.** Hook script fails with a `No such file or directory` pointing at
a literal `${CLAUDE_PLUGIN_ROOT}/hooks/wannabuild-route.py` path.

**Cause.** The plugin is registered in `installed_plugins.json` but not
enabled in `~/.claude/settings.json`. Claude Code only substitutes
`${CLAUDE_PLUGIN_ROOT}` for *enabled* plugins.

**Diagnose.**

```bash
jq '.enabledPlugins' ~/.claude/settings.json
```

You should see `"wannabuild@gl11tchy": true`.

**Fix.** Re-run `scripts/install-claude-skill.sh`. The script enables the
plugin in settings.json idempotently.

---

## Hook timeout — natural-language routing dropped silently

**Symptom.** Long prompts work; short prompts don't get the WannaBuild
context. No visible error.

**Cause.** `wannabuild-route.py` exceeded the per-hook timeout (5 s default).
The `|| true` at the end of the hook command masks the failure so the rest of
the session continues unaffected.

**Diagnose.** Run the router by hand against a SessionStart event:

```bash
time echo '{"hook_event_name":"SessionStart"}' | \
  python3 ~/.claude/plugins/cache/gl11tchy/wannabuild/*/hooks/wannabuild-route.py
```

If wall time > 4 s, you'll hit the timeout under load.

**Fix.** Bump the `timeout` field in `hooks/hooks.json` (e.g., to 10 s) for
your local install, or open an issue with the timing data.

---

## Marketplace clone is stale after a release

**Symptom.** A bug fix landed on `main` and was tagged, but `/plugin update`
still pulls the old version.

**Cause.** Claude Code caches the marketplace clone at
`~/.claude/plugins/marketplaces/<owner>/`. It refreshes on `/plugin`, not on
`/plugin update`.

**Fix.** Run `/plugin` (the marketplace browser) once to refresh, then
`/plugin update wannabuild@gl11tchy`.

---

## `python3` not found on hook execution

**Symptom.** Plugin loaded, hooks registered, but no autoroute injection.
Sometimes Claude Code logs a non-zero exit code from the hook.

**Cause.** The hook command tries `python3 || python || py -3 || true`. On a
host where none resolve, the chain ends in `true` and the failure is masked.

**Diagnose.**

```bash
command -v python3 python py-3 || echo "no python found"
```

**Fix.** Install Python 3.x. macOS: `brew install python@3.11`. Ubuntu:
`apt-get install python3`. Windows: install from python.org and ensure
`python3` is on PATH (or use WSL, where the install script handles
`/mnt/<drive>/Users/<user>/` paths).

---

## Version skew between manifest and plugin metadata

**Symptom.** `.release-please-manifest.json` says one version,
`.claude-plugin/plugin.json` says another, and `gh release list` shows yet a
third. Users on the marketplace can't tell which version they have.

**Cause.** Pre-2.2.5 the release-please config had no `extra-files` block, so
the plugin/marketplace JSONs had to be bumped manually.

**Fix.** Confirm `release-please-config.json` has `extra-files` for the three
JSONs (landed in
[PR #10](https://github.com/gl11tchy/wannabuild/pull/10)). After that, every
release-please PR should bump all four files together.

---

## `install-claude-skill.sh` fails on Windows

**Symptom.** Script aborts with permission errors creating symlinks, or
references a path that doesn't exist on the host.

**Cause.** Windows symlinks need elevated privileges or developer mode. The
script falls back to `mklink /J` junctions via `cmd.exe`/PowerShell, which
require WSL-aware path translation.

**Fix.** Set `WANNABUILD_HOST_HOME` explicitly before running:

```bash
WANNABUILD_HOST_HOME="/mnt/c/Users/<you>" bash scripts/install-claude-skill.sh
```

If you don't have `mklink` or PowerShell available, use a real WSL session
and re-run. The Linux path branch creates ordinary symlinks and works on any
distro.

---

## Doctor PASSes locally but plugin doesn't load on a teammate's machine

**Symptom.** `scripts/wannabuild-doctor.sh` reports "Repo surfaces ready" on
your machine, but a teammate hits a load error.

**Cause.** Doctor verifies the *source repo* is intact. It does **not**
verify the install is wired to a specific user's `$HOME`.

**Diagnose.** On the teammate's machine, check:

```bash
ls -la ~/.claude/plugins/cache/gl11tchy/wannabuild/
jq '.plugins' ~/.claude/plugins/installed_plugins.json
jq '.enabledPlugins' ~/.claude/settings.json
```

**Fix.** Have them run `bash scripts/install-claude-skill.sh` from the repo
clone. The script writes all three config files idempotently.

---

## How to verify your install is working

After `/plugin install wannabuild@gl11tchy` (or running an install script),
confirm the install actually took.

**1. Plugin registered in installed_plugins.json:**

```bash
jq '.plugins | keys[]' ~/.claude/plugins/installed_plugins.json | grep wannabuild
```

You should see `"wannabuild@gl11tchy"`.

**2. Plugin enabled in settings.json:**

```bash
jq '.enabledPlugins."wannabuild@gl11tchy"' ~/.claude/settings.json
```

You should see `true`.

**3. Plugin cache layout is intact:**

```bash
ls ~/.claude/plugins/cache/gl11tchy/wannabuild/*/
```

You should see `.claude-plugin/`, `hooks/`, and `skills/` (among others).

**4. Hooks file parses correctly:**

```bash
python3 -c '
import json,sys
for f in sys.argv[1:]:
    d=json.load(open(f))
    assert "hooks" not in d, f"{f}: double-wrapped"
    assert isinstance(d.get("SessionStart"),list), f"{f}: SessionStart missing"
    print(f"{f}: OK")
' ~/.claude/plugins/cache/gl11tchy/wannabuild/*/hooks/hooks.json
```

If all four checks pass, run `/reload-plugins` in Claude Code and type a
natural feature prompt — you should see the WannaBuild routing context
injected into the next response.

If any check fails, find the matching entry above (e.g.,
`/reload-plugins` crash points to the hooks shape entry) for the fix.

---

## `npx wannabuild` cannot find bash on Windows

**Symptom.** `npx wannabuild` aborts on Windows with an error that no usable
bash was found, before any host is installed.

**Cause.** The installer runs the repo's bash install scripts; it never
reimplements their path-translation/junction logic in Node. On Windows it
locates bash in order: `$WANNABUILD_BASH`, `bash` on `PATH`, Git for Windows
(`C:\Program Files\Git\bin\bash.exe` and the x86 variant), then `wsl.exe bash`.
If none resolve, it fails rather than degrading.

**Fix.** Install [Git for Windows](https://git-scm.com/download/win) (ships
`bash.exe`) or enable WSL, then re-run. To point at a specific bash:

```bash
WANNABUILD_BASH="/c/Program Files/Git/bin/bash.exe" npx wannabuild
```

---

## `npx wannabuild` checksum mismatch on the prebuilt runtime

**Symptom.** Install aborts after downloading the `wb-runtime` archive with a
sha256 mismatch against its `.sha256`.

**Cause.** The downloaded archive does not match the published checksum — a
truncated or corrupted download, a proxy/mirror rewriting the asset, or a stale
release asset. The installer verifies every download and refuses to unpack or
place an unverified gate binary; it never falls back to an unchecked copy.

**Diagnose.** Confirm you can reach the release assets and that the tag exists:

```bash
gh release view v<version> --json assets --jq '.assets[].name'
```

You should see `wb-runtime-v<version>-<label>.tar.gz` (and its `.sha256`) for
your platform, where `<label>` is one of `macos-arm64`, `macos-x86_64`,
`linux-x86_64`, `linux-arm64`, `windows-x86_64`.

**Fix.** Re-run `npx wannabuild` (a fresh download usually clears a transient
corruption). If it persists, pin to a known-good release with `--ref` (for
example `npx wannabuild --ref v<version>`) and check whether a corporate proxy
is rewriting GitHub release downloads.

---

## `npx wannabuild` reports an unsupported platform/arch

**Symptom.** Install stops immediately with an error that your
`platform`/`arch` combination is not supported, before any download.

**Cause.** Prebuilt runtimes are published only for the release matrix:
`macos-arm64`, `macos-x86_64`, `linux-x86_64`, `linux-arm64`, and
`windows-x86_64`. Other targets (for example 32-bit, or linux on a
non-x64/arm64 arch) have no asset, so the installer fails loudly rather than
guessing.

**Fix.** Use a supported platform, or build `wb-runtime` from source with cargo
and install the relevant host from a clone (see each adapter README's
"From source" path). On an unsupported arch, the from-source path is the only
route — the npx installer will not synthesize a binary it cannot verify.

---

## `npx wannabuild doctor` fails: runtime binary absent for an installed host

**Symptom.** A host is installed, but `npx wannabuild doctor` (or
`scripts/wannabuild-doctor.sh`) reports `FAIL` for that host's runtime binary
and exits non-zero.

**Cause.** This is intentional fail-closed behavior. If a host is installed but
its `wb-runtime` binary is missing or not executable, the host would silently
fall back to the degraded Python mirror instead of the real Rust gates. Doctor
makes that loud: it checks each installed host's binary at its resolution path —
`~/.wannabuild/checkout/target/debug/wb-runtime` (Claude), `~/.codex/bin/wb-runtime`
(Codex), and `<plugin cache>/local/target/debug/wb-runtime` (Factory) — and
fails when one is absent or not `-x`.

**Diagnose.** Check the path for the failing host, e.g. for Codex:

```bash
ls -l ~/.codex/bin/wb-runtime
```

A missing file, or one without the executable bit, is the cause.

**Fix.** Re-run `npx wannabuild` (optionally scoped, e.g. `--codex`). It
re-downloads the verified binary and re-places it where the host resolves it,
then runs `wb-runtime --version` to confirm the placed binary executes on this
platform. If the install completes but doctor still fails, confirm the binary is
executable (`chmod +x` on the resolution path) and re-run doctor.

---

## `npx wannabuild` aborts: `Refusing to use ~/.wannabuild: ... not a WannaBuild git checkout`

**Symptom.** `npx wannabuild` stops immediately with `Refusing to use
/…/.wannabuild: it exists but is not a WannaBuild git checkout. Pass a different
--dir, or remove that directory yourself first.` — but you never created a
checkout there.

**Cause.** Legacy layout collision. The runtime stores its out-of-tree evidence
key at `~/.wannabuild/evidence.key`, created the first time you run QA
(`record-test-evidence`). Installer builds before this fix also defaulted the
repo checkout to `~/.wannabuild` itself, so once the key existed the installer
found a non-empty, non-git directory and refused to clone over it — correctly,
because it must never destroy the signing key. Current builds clone into
`~/.wannabuild/checkout` instead, so the key and the checkout no longer share a
directory and a fresh install just works.

**Fix.** Re-run an installer that uses the `~/.wannabuild/checkout` default
(`npx wannabuild`). If you are pinned to an older build, install to an explicit
subdirectory — `npx wannabuild --dir ~/.wannabuild/checkout` — and pass the same
`--dir` to `doctor`/`uninstall`. Do **not** `rm -rf ~/.wannabuild`: that deletes
`evidence.key`, after which every already-recorded evidence record stops
verifying. A stray *git* checkout left at `~/.wannabuild` by a pre-fix install is
safe to remove once the new `~/.wannabuild/checkout` install succeeds — but leave
`~/.wannabuild/evidence.key` in place.

---

## Adding a new entry

When a user reports a failure that isn't here:

1. Capture the exact symptom (error text, terminal output, screenshot).
2. Find the root cause; record the diagnostic command that reveals it.
3. Add a new section to this file in the format above (Symptom / Cause /
   Diagnose / Fix).
4. If a fix requires a code change, link the PR.
5. If the failure could be regression-tested, open an issue or PR adding
   that test before closing the user's report.
