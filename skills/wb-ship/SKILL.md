---
name: wb-ship
description: Standalone WannaBuild ship toolbox skill for packaging completed work into a concise handoff, commit, or PR-ready summary after verification.
---

# wb-ship

Use this toolbox skill when the user wants to package verified work for handoff, commit, or pull request.

## Toolbox Bootstrap

Before any toolbox phase work:

- If no concrete task exists, ask for the actual goal first.
- Work in the current checkout by default.
- Do not create an isolated worktree for ship/handoff.

## Purpose

Turn completed, reviewed, and QA-verified work into a clear ship-ready handoff.

## Defaults

- Confirm review and QA evidence before declaring work ready.
- Do not hide failed or skipped checks.
- Keep release notes and PR text grounded in actual changes.
- Avoid extra cleanup or refactoring during ship unless required.
- Use sub-agents only for distinct release, CI, documentation, or risk ownership.

## Flow

1. Collect changed files, acceptance evidence, review status, and QA status.
2. Identify unresolved risks or follow-ups.
3. Prepare the requested handoff, commit message, PR body, or release note.
4. Run final lightweight sanity checks when appropriate.
5. Stop after the requested ship artifact or action.

## Output

Return a concise ship summary with changes, verification, risks, and any requested commit or PR details.
