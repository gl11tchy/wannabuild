# Task 1 — Fix `commands/wannabuild.md`

**Files:**

- Modify: `commands/wannabuild.md`

The current file says `Use the $wannabuild skill for this request` — Codex syntax that Claude Code can't act on. Replace it with a proper Claude Code slash command that directly instructs Claude to start the WannaBuild workflow.

## Step 1: Rewrite the command file

Replace the entire contents of `commands/wannabuild.md` with:

````markdown
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
````

## Step 2: Verify the file looks right

Read it back and confirm the frontmatter is valid and the instruction text is clear.

### Step 3: Commit

```bash
git add commands/wannabuild.md
git commit -m "fix: rewrite wannabuild command for Claude Code — drop Codex \$skill syntax"
```
