# Tasks 6 + 7 — Host docs

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

### Step 3: Commit

```bash
git add docs/claude-code-getting-started.md
git commit -m "docs: add claude-code-getting-started.md"
```

---

## Task 7: Update `docs/host-capability-matrix.md`

**Files:**

- Modify: `docs/host-capability-matrix.md`

**Step 1: Read the current file** to locate the sections that need changing.

### Step 2: Update Priority order

Change:

```text
- Codex
- Cursor
- Claude Code
```

To:

```text
- Codex
- Claude Code
- Cursor
```

#### Step 3: Update Claude Code adapter description

Change the Claude Code section from:

```text
### Claude Code

Compatibility adapter.

Provides:
- `.claude-plugin/`
- plugin install docs
- Claude-oriented skill entry points
```

To:

```text
### Claude Code

Primary adapter.

Provides:
- Marketplace install: `/plugin install wannabuild@gl11tchy`
- Repo install: `scripts/install-claude-skill.sh`
- Slash command: `/wannabuild`
- Getting-started: `.claude/INSTALL.md`
- Full adapter guide: `adapters/claude-code/README.md`
```

#### Step 4: Update the capability table

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

##### Step 5: Update the "Rule" at the bottom

Change:

```text
If it does not work from a raw repo checkout in Codex, it does not define the core architecture.
```

To:

```text
If it does not work from a raw repo checkout in either Codex or Claude Code, it does not define the core architecture.
```

###### Step 6: Commit

```bash
git add docs/host-capability-matrix.md
git commit -m "docs: elevate Claude Code to co-primary in host capability matrix"
```
