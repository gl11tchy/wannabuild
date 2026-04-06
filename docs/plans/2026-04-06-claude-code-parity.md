# Claude Code Co-Primary Parity — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make WannaBuild work fully in Claude Code via marketplace install, with Claude Code treated as a co-primary host alongside Codex.

**Architecture:** Fix two broken runtime gaps (Codex-syntax command, broken script paths), add a parallel Claude Code install path (marketplace + from-repo), and strip all "compatibility packaging" framing from docs and config files. Skills and agents stay shared; only the adapter layer changes.

**Tech Stack:** Bash, JSON, Markdown. No new dependencies.

---

## Task 1: Fix `commands/wannabuild.md`

**Files:**
- Modify: `commands/wannabuild.md`

The current file says `Use the $wannabuild skill for this request` — Codex syntax that Claude Code can't act on. Replace it with a proper Claude Code slash command that directly instructs Claude to start the WannaBuild workflow.

**Step 1: Rewrite the command file**

Replace the entire contents of `commands/wannabuild.md` with:

```markdown
---
description: Start the WannaBuild spec-driven development workflow
argument-hint: [what you want to build]
---

# /wannabuild

Start the WannaBuild spec-driven development workflow.

If invoked with no task or only a question about the workflow:

- do not inspect the repo
- do not infer the task from git state
- do not plan or implement anything

Respond with exactly:

```
[WB-START] WannaBuild STARTED | intent=build | mode=standard

Tell me what you want to build or change.
```

If invoked with a concrete task:

1. Check for `.wannabuild/state.json` — if it exists and is recoverable, resume with:
   `[WB-RESUME] WannaBuild RESUME | mode=standard | phase=<current_phase> | progress=<done>/<total>`
2. Otherwise emit the start banner and begin Discover immediately.

If the current directory is inside a git repo, create an isolated workspace before Discover (see Mandatory Workspace Bootstrap in the wannabuild skill).

Use the `wannabuild` skill for the full workflow contract.
```

**Step 2: Verify the file looks right**

Read it back and confirm the frontmatter is valid and the instruction text is clear.

**Step 3: Commit**

```bash
git add commands/wannabuild.md
git commit -m "fix: rewrite wannabuild command for Claude Code — drop Codex \$skill syntax"
```

---

## Task 2: Fix script path references in `skills/wannabuild/SKILL.md`

**Files:**
- Modify: `skills/wannabuild/SKILL.md`

The skill currently tells Claude to run `../../scripts/wannabuild-workspace.sh` and `../../scripts/wannabuild-session.sh`. These paths resolve relative to the SKILL.md file in the plugin cache but Claude executes bash from the target project's working directory — so the scripts are never found.

Fix: replace every script reference with equivalent inline instructions. The scripts remain as standalone developer utilities but the skill no longer depends on them being findable.

**Step 1: Replace the Mandatory Workspace Bootstrap section**

Find this block:

```
## Mandatory Workspace Bootstrap

If the current project is a git repo and the user has provided a concrete task:

1. create an isolated workspace before Discover
2. continue all reads and writes in that workspace only
3. never continue work in the original checkout

Use:

`../../scripts/wannabuild-workspace.sh --json`

Then initialize session state in the new workspace:

`../../scripts/wannabuild-session.sh init <workspace_path>`

Write `.wannabuild/workspace.json` and `.wannabuild/state.json` in the isolated workspace before continuing.

If workspace bootstrap fails, stop and report the failure instead of continuing in-place.
```

Replace with:

```markdown
## Mandatory Workspace Bootstrap

If the current project is a git repo and the user has provided a concrete task:

1. Create an isolated workspace before Discover
2. Continue all reads and writes in that workspace only
3. Never continue work in the original checkout

Run these commands from the target project root:

```bash
GIT_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$GIT_ROOT")
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
WB_TS=$(date +%Y%m%d%H%M%S)
WB_RAND=$(python3 -c "import secrets; print(''.join(secrets.choice('abcdefghijklmnopqrstuvwxyz0123456789') for _ in range(6)))")
WB_ID="${WB_TS}-build-${WB_RAND}"
WB_PARENT="$(dirname "$GIT_ROOT")/.wannabuild-workspaces/${REPO_NAME}"
WB_PATH="${WB_PARENT}/${WB_ID}"
WB_BRANCH="wannabuild/${WB_ID}"
mkdir -p "$WB_PARENT"
git worktree add -b "$WB_BRANCH" "$WB_PATH" HEAD
mkdir -p "$WB_PATH/.wannabuild"
```

Then write `.wannabuild/workspace.json` in the new workspace:

```json
{
  "workspace_id": "<WB_ID>",
  "source_repo": "<GIT_ROOT>",
  "source_branch": "<CURRENT_BRANCH>",
  "workspace_path": "<WB_PATH>",
  "branch_name": "<WB_BRANCH>",
  "dirty_snapshot": false
}
```

Then write `.wannabuild/state.json`:

```json
{
  "current_stage": "discover",
  "stage_status": "in_progress",
  "mode": "standard",
  "started_at": "<ISO timestamp>",
  "updated_at": "<ISO timestamp>",
  "artifacts": {}
}
```

If workspace bootstrap fails, stop and report the failure instead of continuing in-place.

> **Note:** If working from the WannaBuild repo directly, you can also run `scripts/wannabuild-workspace.sh --json` from the target project root instead of the inline commands above.
```

**Step 2: Replace all `wannabuild-session.sh` references**

Find every line that references `../../scripts/wannabuild-session.sh`. There are several across the Control Mode Gate, Research Gate, Review Gate, QA Gate, and Summary Guard sections. They look like:

```
`../../scripts/wannabuild-session.sh set-stage <workspace_path> control_mode_decision in_progress`
`../../scripts/wannabuild-session.sh set-control-mode <workspace_path> guided`
`../../scripts/wannabuild-session.sh set-stage <workspace_path> review in_progress`
```

Replace each with an inline description of what to write. For example, replace the three `wannabuild-session.sh` lines in the Control Mode Gate section with:

```
Update `.wannabuild/state.json` — set `current_stage: "control_mode_decision"`, `stage_status: "in_progress"`, `updated_at: <ISO timestamp>`.
```

And after the user answers, set `control_mode` to `"guided"` or `"autonomous"` in the same file.

Apply the same pattern everywhere `wannabuild-session.sh` is referenced — the session script just merges JSON fields into state.json. Claude can do this directly with the Edit or Write tool.

**Step 3: Replace the `wannabuild-gate-check.sh` reference**

Find:

```
- `../../scripts/wannabuild-gate-check.sh <workspace_path> summary`
```

Replace with:

```
Before summarizing, verify:
- `.wannabuild/review/` exists and contains at least one `*.json` verdict file
- All verdict files have `"status": "PASS"`
- `.wannabuild/outputs/qa-summary.md` exists

If any check fails, block the summary and report what is missing.
```

**Step 4: Replace the Internal References section**

Find:

```
## Internal References

Use these repo contracts as needed:

- `../../AGENTS.md`
- `../build/SKILL.md`
...
- `../../scripts/validate-wannabuild-artifacts.sh`
```

Replace with:

```markdown
## Internal References

Use these contracts as needed. If installed via the Claude Code marketplace, these are available at their relative paths within the plugin. If working directly from the repo, they are at the same relative paths.

- `AGENTS.md` (repo root) — primary operator contract
- `skills/build/SKILL.md` — full orchestrator contract
- `skills/requirements/SKILL.md`
- `skills/design/SKILL.md`
- `skills/tasks/SKILL.md`
- `skills/implement/SKILL.md`
- `skills/review/SKILL.md`
- `skills/ship/SKILL.md`
- `skills/document/SKILL.md`

> **Optional scripts (repo install only):** `scripts/validate-wannabuild-artifacts.sh` can be used for artifact validation if the WannaBuild repo is accessible. It is not required for normal skill execution.
```

**Step 5: Read the full modified file and verify no remaining `../../scripts/` references**

```bash
grep -n '\.\./\.\./scripts' skills/wannabuild/SKILL.md
```

Expected: no output.

**Step 6: Commit**

```bash
git add skills/wannabuild/SKILL.md
git commit -m "fix: replace script path references with inline equivalents in wannabuild skill"
```

---

## Task 3: Create `scripts/install-claude-skill.sh`

**Files:**
- Create: `scripts/install-claude-skill.sh`

This script installs WannaBuild as a local Claude Code plugin from the repo, equivalent to `install-codex-skill.sh` for Codex. It creates the plugin directory structure in the Claude Code plugin cache and registers it in settings.

**Step 1: Create the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_CACHE="${HOME}/.claude/plugins/cache/gl11tchy/wannabuild/local"
SETTINGS="${HOME}/.claude/settings.json"
INSTALLED="${HOME}/.claude/plugins/installed_plugins.json"

# Create plugin directory pointing to this repo
mkdir -p "$(dirname "$PLUGIN_CACHE")"
if [[ -L "$PLUGIN_CACHE" ]]; then
  rm "$PLUGIN_CACHE"
fi
ln -s "$ROOT" "$PLUGIN_CACHE"

# Register in installed_plugins.json
python3 - "$PLUGIN_CACHE" "$INSTALLED" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone

install_path, installed_file = sys.argv[1:]
installed_path = Path(installed_file)

data = {"version": 2, "plugins": {}}
if installed_path.exists():
    try:
        data = json.loads(installed_path.read_text())
    except Exception:
        pass

key = "wannabuild@gl11tchy"
now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
data.setdefault("plugins", {})[key] = [
    {
        "scope": "user",
        "installPath": install_path,
        "version": "local",
        "installedAt": now,
        "lastUpdated": now,
        "gitCommitSha": "local"
    }
]
installed_path.write_text(json.dumps(data, indent=4))
print(f"Registered {key} in installed_plugins.json")
PY

# Enable in settings.json
python3 - "$SETTINGS" <<'PY'
import json, sys
from pathlib import Path

settings_path = Path(sys.argv[1])
settings = {}
if settings_path.exists():
    try:
        settings = json.loads(settings_path.read_text())
    except Exception:
        pass

settings.setdefault("enabledPlugins", {})["wannabuild@gl11tchy"] = True
settings_path.write_text(json.dumps(settings, indent=4))
print("Enabled wannabuild@gl11tchy in settings.json")
PY

echo ""
echo "Installed WannaBuild for Claude Code:"
echo "  Plugin path: $PLUGIN_CACHE -> $ROOT"
echo ""
echo "Run /reload-plugins in Claude Code, then invoke:"
echo "  /wannabuild"
```

**Step 2: Make it executable**

```bash
chmod +x scripts/install-claude-skill.sh
```

**Step 3: Verify it looks right**

```bash
head -5 scripts/install-claude-skill.sh
```

Expected: shebang and `set -euo pipefail`.

**Step 4: Commit**

```bash
git add scripts/install-claude-skill.sh
git commit -m "feat: add install-claude-skill.sh for local Claude Code plugin install"
```

---

## Task 4: Create `.claude/INSTALL.md`

**Files:**
- Create: `.claude/INSTALL.md`

Parallel to `.codex/INSTALL.md`. Getting-started guide for Claude Code users.

**Step 1: Create the directory and file**

```markdown
# WannaBuild for Claude Code

## Marketplace Install (recommended)

From any Claude Code session:

```
/plugin marketplace add gl11tchy/wannabuild
/plugin install wannabuild@gl11tchy
```

Then restart Claude Code and invoke:

```
/wannabuild
```

## From Repo

Clone the repository, then run:

```bash
./scripts/install-claude-skill.sh
```

Then run `/reload-plugins` in Claude Code and invoke:

```
/wannabuild
```

## Verify

Start a new Claude Code session in any project and run:

```
/wannabuild
```

You should see:

```
[WB-START] WannaBuild STARTED | intent=build | mode=standard

Tell me what you want to build or change.
```

## Troubleshoot

Run the doctor script to check your environment:

```bash
./scripts/wannabuild-doctor.sh
```
```

**Step 2: Verify**

Read `.claude/INSTALL.md` and confirm it looks clean.

**Step 3: Commit**

```bash
git add .claude/INSTALL.md
git commit -m "docs: add .claude/INSTALL.md for Claude Code getting-started"
```

---

## Task 5: Rewrite `adapters/claude-code/README.md`

**Files:**
- Modify: `adapters/claude-code/README.md`

The current file is three lines. Rewrite it as a proper adapter guide.

**Step 1: Rewrite**

```markdown
# Claude Code Adapter

WannaBuild for Claude Code. Supports marketplace install and repo-based local install.

## Install

### Marketplace (recommended)

```
/plugin marketplace add gl11tchy/wannabuild
/plugin install wannabuild@gl11tchy
```

Restart Claude Code, then:

```
/wannabuild
```

### From Repo

```bash
./scripts/install-claude-skill.sh
```

Run `/reload-plugins`, then:

```
/wannabuild
```

## Usage

Start with a natural description:

```
I wanna build a Stripe billing flow for my SaaS
```

WannaBuild responds with the start banner and enters Discover.

For a full getting-started walkthrough, see [.claude/INSTALL.md](../../.claude/INSTALL.md).

## What's Installed

| Surface | Path |
|---|---|
| Slash command | `commands/wannabuild.md` → `/wannabuild` |
| Orchestrator skill | `skills/wannabuild/` |
| Phase skills | `skills/build/`, `skills/requirements/`, etc. |
| Specialist agents | `agents/wb-*.md` |
| Utility scripts | `scripts/` (optional, for repo installs) |

## Verification

```bash
./scripts/wannabuild-doctor.sh
```
```

**Step 2: Commit**

```bash
git add adapters/claude-code/README.md
git commit -m "docs: rewrite Claude Code adapter README as a proper install guide"
```

---

## Task 6: Create `docs/claude-code-getting-started.md`

**Files:**
- Create: `docs/claude-code-getting-started.md`

Parallel to `docs/codex-getting-started.md`. Check what that file contains first, then mirror its structure.

**Step 1: Read `docs/codex-getting-started.md`** to understand what to mirror.

**Step 2: Create `docs/claude-code-getting-started.md`**

Follow the same structure as the Codex version but with Claude Code-specific install steps, invocation syntax, and notes. Key differences:
- Install via `/plugin marketplace add gl11tchy/wannabuild` + `/plugin install wannabuild@gl11tchy`
- Invoke via `/wannabuild` (not `$wannabuild`)
- Workspace creation uses the inline git commands (not script paths)

**Step 3: Commit**

```bash
git add docs/claude-code-getting-started.md
git commit -m "docs: add claude-code-getting-started.md"
```

---

## Task 7: Update `docs/host-capability-matrix.md`

**Files:**
- Modify: `docs/host-capability-matrix.md`

**Step 1: Read the current file** to locate the sections that need changing.

**Step 2: Update Priority order**

Change:
```
- Codex
- Cursor
- Claude Code
```

To:
```
- Codex
- Claude Code
- Cursor
```

**Step 3: Update Claude Code adapter description**

Change the Claude Code section from:

```
### Claude Code

Compatibility adapter.

Provides:
- `.claude-plugin/`
- plugin install docs
- Claude-oriented skill entry points
```

To:

```
### Claude Code

Primary adapter.

Provides:
- Marketplace install: `/plugin install wannabuild@gl11tchy`
- Repo install: `scripts/install-claude-skill.sh`
- Slash command: `/wannabuild`
- Getting-started: `.claude/INSTALL.md`
- Full adapter guide: `adapters/claude-code/README.md`
```

**Step 4: Update the capability table**

Change the Claude column from showing partial/reference support to showing full support equal to Codex. Specifically:

| Capability | Codex | Claude Code |
|---|---|---|
| Workflow contract | Primary | Primary |
| `.wannabuild/` artifacts | Yes | Yes |
| Validator script | Yes | Yes |
| Slash commands / invocation | `$wannabuild` | `/wannabuild` |
| Plugin install path | Script symlink | Marketplace or script |
| Repo-only usage | Yes | Yes |
| Getting-started doc | Yes | Yes |

**Step 5: Update the "Rule" at the bottom**

Change:
```
If it does not work from a raw repo checkout in Codex, it does not define the core architecture.
```

To:
```
If it does not work from a raw repo checkout in either Codex or Claude Code, it does not define the core architecture.
```

**Step 6: Commit**

```bash
git add docs/host-capability-matrix.md
git commit -m "docs: elevate Claude Code to co-primary in host capability matrix"
```

---

## Task 8: Update `README.md`

**Files:**
- Modify: `README.md`

**Step 1: Read the current Install section** (lines around 100-150).

**Step 2: Restructure the Install section**

The current order is Codex → Cursor → Claude Code Plugin. Change to:

```markdown
## Install

### Claude Code

Primary path for Claude Code users.

**Marketplace:**

```
/plugin marketplace add gl11tchy/wannabuild
/plugin install wannabuild@gl11tchy
```

Restart Claude Code, then:

```
/wannabuild
```

**From repo:**

```bash
./scripts/install-claude-skill.sh
```

Then run `/reload-plugins` and invoke `/wannabuild`.

See [adapters/claude-code/README.md](adapters/claude-code/README.md) and [.claude/INSTALL.md](.claude/INSTALL.md).

### Codex

Primary path for Codex users.

[keep existing Codex install content here]

### Cursor

[keep existing Cursor install content here]
```

**Step 3: Update the badge row** at the top to add or update a Claude Code badge alongside the Codex one.

**Step 4: Commit**

```bash
git add README.md
git commit -m "docs: elevate Claude Code install to co-primary in README"
```

---

## Task 9: Positioning cleanup — `CLAUDE.md`, `AGENTS.md`, `skills/build/SKILL.md`

**Files:**
- Modify: `CLAUDE.md`
- Modify: `AGENTS.md`
- Modify: `skills/build/SKILL.md`

**Step 1: Fix `CLAUDE.md`**

Read the file. Find the Positioning section that says:

```
- Codex is the primary experience
- Cursor is the secondary adapter
- Claude Code is supported as compatibility packaging
```

Change to:

```
- Codex and Claude Code are co-primary experiences
- Cursor is the secondary adapter
```

Also update any Product Model or Core Surfaces sections that reference Claude Code as secondary.

**Step 2: Fix `AGENTS.md`**

Read the file. Find the Host Positioning section:

```
## Host Positioning

- Codex is the primary experience.
- Cursor is the secondary adapter.
- Claude Code remains supported as compatibility packaging.
```

Change to:

```
## Host Positioning

- Codex and Claude Code are co-primary experiences.
- Cursor is the secondary adapter.

For Claude Code: marketplace install via `/plugin install wannabuild@gl11tchy` or repo install via `scripts/install-claude-skill.sh`.
For Codex: install via `scripts/install-codex-skill.sh`.
```

**Step 3: Fix `skills/build/SKILL.md`**

Read the file. Find the Host Positioning section near the top. Change any "Claude Code as compatibility" language to match co-primary framing.

**Step 4: Verify — grep for stale framing across all files**

```bash
grep -rn "compatibility packaging\|compatibility adapter\|Claude Code remains\|Claude support remains" \
  CLAUDE.md AGENTS.md skills/ adapters/ README.md docs/
```

Expected: no output.

**Step 5: Commit**

```bash
git add CLAUDE.md AGENTS.md skills/build/SKILL.md
git commit -m "docs: update positioning — Claude Code is co-primary, not compatibility packaging"
```

---

## Task 10: End-to-end verification

**Step 1: Run the doctor script**

```bash
./scripts/wannabuild-doctor.sh
```

Expected: passes without errors.

**Step 2: Verify no stale Codex-only syntax in Claude-facing files**

```bash
grep -n '\$wannabuild' commands/wannabuild.md
```

Expected: no output.

**Step 3: Verify no broken script paths in skill**

```bash
grep -n '\.\./\.\./scripts' skills/wannabuild/SKILL.md
```

Expected: no output.

**Step 4: Verify install script is executable**

```bash
ls -la scripts/install-claude-skill.sh
```

Expected: `-rwxr-xr-x`

**Step 5: Check all new/modified files exist**

```bash
ls -1 \
  commands/wannabuild.md \
  skills/wannabuild/SKILL.md \
  scripts/install-claude-skill.sh \
  .claude/INSTALL.md \
  adapters/claude-code/README.md \
  docs/claude-code-getting-started.md \
  docs/host-capability-matrix.md
```

**Step 6: Final commit if any loose ends**

```bash
git status
```

If clean, done. If not, commit any remaining changes.
