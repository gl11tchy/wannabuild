# Claude Code Co-Primary Parity — Design

**Date:** 2026-04-06
**Goal:** Make Claude Code a co-primary host alongside Codex. Drop the "compatibility packaging" framing. Make the marketplace install (`/plugin install wannabuild@gl11tchy`) fully work and feel intentional.

## Problem

Two things are broken for Claude Code right now:

1. `commands/wannabuild.md` uses `$wannabuild` Codex syntax — Claude Code injects that text verbatim and nothing meaningful happens.
2. `skills/wannabuild/SKILL.md` references `../../scripts/wannabuild-workspace.sh` with paths that resolve relative to the SKILL.md file location in the plugin cache, but Claude executes them from the target project's working directory — the script is never found.

Beyond the bugs, the framing is wrong: Claude Code is described as "compatibility packaging" in CLAUDE.md, AGENTS.md, and the capability matrix. That positioning needs to go.

## Design

### Host Positioning

Claude Code and Codex become co-primary. Cursor stays secondary.

| Host | Status |
|---|---|
| Codex | Primary |
| Claude Code | Primary |
| Cursor | Secondary |

### Work Streams

#### 1. Fix the broken core

**`commands/wannabuild.md`**
Rewrite to contain the actual workflow entry instructions for Claude Code. Remove the `$wannabuild` Codex syntax. The command should directly instruct Claude to begin the WannaBuild workflow — emit the start banner, check for state.json for resume, and enter Discover.

**`skills/wannabuild/SKILL.md`**
Replace all `../../scripts/...` invocations with equivalent inline bash commands. The workspace bootstrap, session state writes, gate checks, and stage transitions are all expressible as direct shell commands and Write-tool operations without needing to locate an external script at runtime.

Scripts in `scripts/` remain as standalone developer utilities but become optional — the skill no longer depends on them.

#### 2. Claude Code install path

**`scripts/install-claude-skill.sh`**
New script. Installs WannaBuild as a local Claude Code plugin by symlinking the repo into Claude Code's local plugin directory. Mirrors `scripts/install-codex-skill.sh`.

**`adapters/claude-code/README.md`**
Rewrite as a full install guide. Cover both paths:
- Marketplace: `/plugin marketplace add gl11tchy/wannabuild` then `/plugin install wannabuild@gl11tchy`
- From repo: `./scripts/install-claude-skill.sh`

Include verification and first-use steps.

**`.claude/INSTALL.md`**
New file. Claude Code getting-started doc, parallel to `.codex/INSTALL.md`.

#### 3. Docs

**`docs/claude-code-getting-started.md`**
New file. Full getting-started guide for Claude Code users. Mirrors `docs/codex-getting-started.md`.

**`docs/host-capability-matrix.md`**
Update Claude Code row from "Compatibility" to "Primary". Update capability table to give Claude Code equal footing with Codex.

**`README.md`**
Elevate the Claude Code install section to equal prominence with Codex. Marketplace install becomes the primary Claude Code path. Repo install (`install-claude-skill.sh`) is secondary. Both are clearly documented.

#### 4. Positioning cleanup

- `CLAUDE.md` — remove "Claude Code is supported as compatibility packaging"
- `AGENTS.md` — update host positioning section to reflect co-primary
- `skills/build/SKILL.md` — remove any Codex-only assumptions in the host positioning section

## File Inventory

### Modified
- `commands/wannabuild.md`
- `skills/wannabuild/SKILL.md`
- `adapters/claude-code/README.md`
- `docs/host-capability-matrix.md`
- `README.md`
- `CLAUDE.md`
- `AGENTS.md`
- `skills/build/SKILL.md`

### Created
- `scripts/install-claude-skill.sh`
- `.claude/INSTALL.md`
- `docs/claude-code-getting-started.md`

## Success Criteria

1. `/plugin install wannabuild@gl11tchy` installs cleanly and `/wannabuild` starts the workflow
2. The workspace bootstrap runs correctly without requiring external scripts to be locatable
3. A Claude Code user following `adapters/claude-code/README.md` can be running in under 5 minutes
4. No file references Claude Code as "compatibility" or secondary to Codex
5. Codex install path still works unchanged
