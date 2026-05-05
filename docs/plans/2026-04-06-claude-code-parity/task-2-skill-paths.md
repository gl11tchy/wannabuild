# Task 2 — Fix script path references in `skills/wannabuild/SKILL.md`

**Files:**

- Modify: `skills/wannabuild/SKILL.md`

The skill currently tells Claude to run `../../scripts/wannabuild-workspace.sh` and `../../scripts/wannabuild-session.sh`. These paths resolve relative to the SKILL.md file in the plugin cache but Claude executes bash from the target project's working directory — so the scripts are never found.

Fix: replace every script reference with equivalent inline instructions. The scripts remain as standalone developer utilities but the skill no longer depends on them being findable.

## Step 1: Replace the Mandatory Workspace Bootstrap section

Find this block:

```text
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

````markdown
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
WB_PARENT="${GIT_ROOT}/.codex/worktrees/${REPO_NAME}"
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
````

**Step 2: Replace all `wannabuild-session.sh` references**

Find every line that references `../../scripts/wannabuild-session.sh`. There are several across the Control Mode Gate, Research Gate, Review Gate, QA Gate, and Summary Guard sections. They look like:

```text
`../../scripts/wannabuild-session.sh set-stage <workspace_path> control_mode_decision in_progress`
`../../scripts/wannabuild-session.sh set-control-mode <workspace_path> guided`
`../../scripts/wannabuild-session.sh set-stage <workspace_path> review in_progress`
```

Replace each with an inline description of what to write. For example, replace the three `wannabuild-session.sh` lines in the Control Mode Gate section with:

```text
Update `.wannabuild/state.json` — set `current_stage: "control_mode_decision"`, `stage_status: "in_progress"`, `updated_at: <ISO timestamp>`.
```

And after the user answers, set `control_mode` to `"guided"` or `"autonomous"` in the same file.

Apply the same pattern everywhere `wannabuild-session.sh` is referenced — the session script just merges JSON fields into state.json. Claude can do this directly with the Edit or Write tool.

**Step 3: Replace the `wannabuild-gate-check.sh` reference**

Find:

```text
- `../../scripts/wannabuild-gate-check.sh <workspace_path> summary`
```

Replace with:

```text
Before summarizing, verify:
- `.wannabuild/review/` exists and contains at least one `*.json` verdict file
- All verdict files have `"status": "PASS"`
- `.wannabuild/outputs/qa-summary.md` exists

If any check fails, block the summary and report what is missing.
```

### Step 4: Replace the Internal References section

Find:

```text
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

### Step 6: Commit

```bash
git add skills/wannabuild/SKILL.md
git commit -m "fix: replace script path references with inline equivalents in wannabuild skill"
```
