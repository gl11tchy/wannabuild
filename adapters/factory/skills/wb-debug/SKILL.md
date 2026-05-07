---
name: wb-debug
description: WannaBuild debugging implementation entrypoint for reproducing, diagnosing, fixing, and verifying bugs within the full loop.
---

# wb-debug

Use this phase skill when the user wants a bug investigated or fixed. A `wb-debug` or `wannabuild:wb-debug` invocation starts or resumes the full WannaBuild loop unless the user explicitly says debug only.

## Phase Bootstrap

Before any debugging phase work:

- If no concrete task exists, ask for the actual goal first.
- Work in the current checkout by default.
- Do not create an isolated worktree unless the user asks, selects implementation-time isolation, requests parallel implementation, or the risk justifies separation.
- If an isolated worktree is selected, use `scripts/wannabuild-workspace.sh --json` when available and continue inside the reported `workspace_path`.
- If the fix requires product or architecture choices not already planned, invoke/complete the planning phase before editing code.

## Purpose

Move from symptom to verified cause to minimal fix.

## Defaults

- Reproduce or characterize the failure before changing code.
- Prefer existing tests, logs, and small probes over speculation.
- State the suspected cause and what evidence supports it.
- Keep the fix narrow; do not refactor adjacent code unless required.
- Use sub-agents only for independent hypotheses, logs, environments, or risk areas.
- Verify the exact failure path after the fix.
- Preserve active WannaBuild workflow state across turns until the task is complete or the user explicitly exits or stops.
- Continue to validation and QA after the fix unless the user explicitly requested debug only.

## Flow

1. Capture symptoms, expected behavior, actual behavior, and reproduction steps.
2. Inspect the smallest relevant code path.
3. Form and test hypotheses.
4. Apply the minimal fix.
5. Run the reproduction and targeted regression checks.

## Output

Report root cause, changed files, verification evidence, and any residual risk.
