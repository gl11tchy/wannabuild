---
name: wb-debug
description: Standalone WannaBuild debugging toolbox skill for reproducing, diagnosing, fixing, and verifying bugs without broad workflow ceremony.
---

# wb-debug

Use this toolbox skill when the user wants a bug investigated or fixed.

## Mandatory Toolbox Bootstrap

Before any toolbox phase work:

- If no concrete task exists, ask for the actual goal first.
- If the current project is a git repo and a concrete task exists, use the same mandatory workspace/worktree bootstrap as `wannabuild` before reading, writing, planning, or editing.
- If already inside an isolated WannaBuild workspace, resume there.
- Otherwise create an isolated workspace with `scripts/wannabuild-workspace.sh --json` when available.
- Continue only in the isolated workspace; never keep working in the original checkout.

## Purpose

Move from symptom to verified cause to minimal fix.

## Defaults

- Reproduce or characterize the failure before changing code.
- Prefer existing tests, logs, and small probes over speculation.
- State the suspected cause and what evidence supports it.
- Keep the fix narrow; do not refactor adjacent code unless required.
- Use sub-agents only for independent hypotheses, logs, environments, or risk areas.
- Verify the exact failure path after the fix.

## Flow

1. Capture symptoms, expected behavior, actual behavior, and reproduction steps.
2. Inspect the smallest relevant code path.
3. Form and test hypotheses.
4. Apply the minimal fix.
5. Run the reproduction and targeted regression checks.

## Output

Report root cause, changed files, verification evidence, and any residual risk.
