# Tasks 8 + 9 — Positioning

## Task 8: Update `README.md`

**Files:**

- Modify: `README.md`

**Step 1: Read the current Install section** (lines around 100-150).

### Step 2: Restructure the Install section

The current order is Codex → Cursor → Claude Code Plugin. Change to:

````markdown
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
````

**Step 3: Update the badge row** at the top to add or update a Claude Code badge alongside the Codex one.

#### Step 4: Commit

```bash
git add README.md
git commit -m "docs: elevate Claude Code install to co-primary in README"
```

---

## Task 9: Positioning cleanup — `CLAUDE.md`, `AGENTS.md`, `skills/internal/build/SKILL.md`

**Files:**

- Modify: `CLAUDE.md`
- Modify: `AGENTS.md`
- Modify: `skills/internal/build/SKILL.md`

**Step 1: Fix `CLAUDE.md`**

Read the file. Find the Positioning section that says:

```text
- Codex is the primary experience
- Cursor is the secondary adapter
- Claude Code is supported as compatibility packaging
```

Change to:

```text
- Codex and Claude Code are co-primary experiences
- Cursor is the secondary adapter
```

Also update any Product Model or Core Surfaces sections that reference Claude Code as secondary.

**Step 2: Fix `AGENTS.md`**

Read the file. Find the Host Positioning section:

```text
## Host Positioning

- Codex is the primary experience.
- Cursor is the secondary adapter.
- Claude Code remains supported as compatibility packaging.
```

Change to:

```text
## Host Positioning

- Codex and Claude Code are co-primary experiences.
- Cursor is the secondary adapter.

For Claude Code: marketplace install via `/plugin install wannabuild@gl11tchy` or repo install via `scripts/install-claude-skill.sh`.
For Codex: install via `scripts/install-codex-skill.sh`.
```

**Step 3: Fix `skills/internal/build/SKILL.md`**

Read the file. Find the Host Positioning section near the top. Change any "Claude Code as compatibility" language to match co-primary framing.

### Step 4: Verify — grep for stale framing across all files

```bash
grep -rn "compatibility packaging\|compatibility adapter\|Claude Code remains\|Claude support remains" \
  CLAUDE.md AGENTS.md skills/ adapters/ README.md docs/
```

Expected: no output.

#### Step 5: Commit

```bash
git add CLAUDE.md AGENTS.md skills/internal/build/SKILL.md
git commit -m "docs: update positioning — Claude Code is co-primary, not compatibility packaging"
```
