---
name: wb-ship
description: WannaBuild ship/summary phase entrypoint for preparing verified work, asking for delivery mode, executing it, and cleaning up.
---

# wb-ship

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed. Specialist judgment stays advisory unless a gate or acceptance criterion requires evidence.

Use this phase skill when the user wants to ship, merge, push, create a PR, or prepare final delivery. A `wb-ship` or `wannabuild:wb-ship` invocation starts or resumes the full WannaBuild loop; if review or QA evidence is missing, resume the missing phase before declaring the work ready.

## Phase Bootstrap

Before any ship/summary phase work:

- If no concrete task exists, ask for the actual goal first.
- Work in the current checkout by default.
- Do not create an isolated worktree for ship/handoff.

## Purpose

Turn completed, reviewed, and QA-verified work into a clear ship-ready handoff, then ask for the delivery path.

## Defaults

- Confirm review and QA evidence before declaring work ready.
- Do not hide failed or skipped checks.
- Do not create draft PRs unless the user explicitly asks for a draft.
- If a PR or pushed branch is involved, verify CI before final summary; failed CI routes back to remediation, and absent CI needs explicit user acknowledgment.
- Keep release notes and PR text grounded in actual changes.
- Run cleanup after the selected delivery action.
- Use sub-agents only for distinct release, CI, documentation, or risk ownership.
- Preserve active WannaBuild workflow state across turns until the task is complete or the user explicitly exits or stops.

## Flow

1. Collect changed files, acceptance evidence, review status, and QA status.
2. Identify unresolved risks or follow-ups.
3. Prepare commits, release notes, PR body, and final verification evidence as needed.
4. Ask the user to choose exactly one delivery path:
   - merge locally
   - push branch and create a PR
   - push directly to `origin/main`
   - stop after local preparation
5. Execute the selected path.
6. If a PR or pushed branch is involved, check CI status after the delivery action.
7. Run `scripts/wannabuild-gate-check.sh <project_root> summary`; stop if the runtime gate fails.
8. Run cleanup: prune/remove temporary worktrees when safe, delete local/remote topic branches when appropriate, remove generated transient files, and verify the final git status.
9. Stop with a concise summary.

## Output

Return a concise ship summary with delivery action, commit/PR/merge details, verification, cleanup performed, risks, and remaining work.
