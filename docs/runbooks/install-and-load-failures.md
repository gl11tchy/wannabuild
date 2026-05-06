# Runbook: install + plugin-load failures

Real failure modes users hit when installing WannaBuild into Claude Code,
Codex, Cursor, or Factory — with diagnostics and fixes. Add new entries here
the first time a user reports a failure rather than letting them be lost in
issue history.

---

## `/reload-plugins` crashes with `TypeError: X?.reduce is not a function`

**Symptom.** Claude Code throws

```text
TypeError: X?.reduce is not a function. (In 'X?.reduce((P,G)=>P+G.hooks.length,0)', 'X?.reduce' is undefined)
```

immediately after running `/reload-plugins`.

**Cause.** `hooks/hooks.json` is double-wrapped under an outer `"hooks"` key.
Claude Code's plugin loader expects the file body to be the event map directly
(`{ "SessionStart": [...], "UserPromptSubmit": [...] }`), not nested.

**Diagnose.** Print the first key of the file:

```bash
python3 -c 'import json,sys; print(list(json.load(open(sys.argv[1])).keys())[:3])' \
  ~/.claude/plugins/cache/gl11tchy/wannabuild/*/hooks/hooks.json
```

If the output is `['hooks']`, you have the wrapped shape.

**Fix.** Upgrade to ≥ 2.2.5 (`/plugin update wannabuild@gl11tchy`). The fix
landed in [PR #8](https://github.com/gl11tchy/wannabuild/pull/8) and is
regression-pinned by `tests/unit/test_plugin_hooks_shape.bats`.

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

## Adding a new entry

When a user reports a failure that isn't here:

1. Capture the exact symptom (error text, terminal output, screenshot).
2. Find the root cause; record the diagnostic command that reveals it.
3. Add a new section to this file in the format above (Symptom / Cause /
   Diagnose / Fix).
4. If a fix requires a code change, link the PR.
5. If the failure could be regression-tested, open an issue or PR adding
   that test before closing the user's report.
