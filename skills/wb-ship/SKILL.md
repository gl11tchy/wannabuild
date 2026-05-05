---
name: wb-ship
description: Standalone WannaBuild ship toolbox skill for preparing verified work, asking for delivery mode, executing it, and cleaning up.
---

# wb-ship

Use this toolbox skill when the user wants to ship, merge, push, create a PR, or prepare final delivery.

## Toolbox Bootstrap

Before any toolbox phase work:

- If no concrete task exists, ask for the actual goal first.
- Work in the current checkout by default.
- Do not create an isolated worktree for ship/handoff.

## Purpose

Turn completed, reviewed, and QA-verified work into a clear ship-ready handoff, then ask for the delivery path.

## Defaults

- Confirm review and QA evidence before declaring work ready.
- Do not hide failed or skipped checks.
- Keep release notes and PR text grounded in actual changes.
- Run cleanup after the selected delivery action.
- Use sub-agents only for distinct release, CI, documentation, or risk ownership.

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
6. Run cleanup: prune/remove temporary worktrees when safe, delete local/remote topic branches when appropriate, remove generated transient files, and verify the final git status.
7. Stop with a concise summary.

## Output

Return a concise ship summary with delivery action, commit/PR/merge details, verification, cleanup performed, risks, and remaining work.
