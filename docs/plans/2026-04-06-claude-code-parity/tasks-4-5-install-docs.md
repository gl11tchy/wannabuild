# Tasks 4 + 5 — Install docs and adapter README

## Task 4: Create `.claude/INSTALL.md`

**Files:**

- Create: `.claude/INSTALL.md`

Parallel to `.codex/INSTALL.md`. Getting-started guide for Claude Code users.

### Step 1: Create the directory and file

````markdown
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
````

### Step 2: Verify

Read `.claude/INSTALL.md` and confirm it looks clean.

#### Step 3: Commit

```bash
git add .claude/INSTALL.md
git commit -m "docs: add .claude/INSTALL.md for Claude Code getting-started"
```

---

## Task 5: Rewrite `adapters/claude-code/README.md`

**Files:**

- Modify: `adapters/claude-code/README.md`

The current file is three lines. Rewrite it as a proper adapter guide.

### Step 1: Rewrite

````markdown
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

For a full getting-started walkthrough, see `.claude/INSTALL.md` (link path: `../../.claude/INSTALL.md` from `adapters/claude-code/README.md`).

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
````

### Step 2: Commit

```bash
git add adapters/claude-code/README.md
git commit -m "docs: rewrite Claude Code adapter README as a proper install guide"
```
