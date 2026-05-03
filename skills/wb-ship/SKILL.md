---
name: wb-ship
description: Standalone WannaBuild ship toolbox skill for packaging completed work into a concise handoff, commit, or PR-ready summary after verification.
---

# wb-ship

Use this toolbox skill when the user wants to package verified work for handoff, commit, or pull request.

## Mandatory Toolbox Bootstrap

Before any toolbox phase work:

- If no concrete task exists, ask for the actual goal first.
- If the current project is a git repo and a concrete task exists, use the same mandatory workspace/worktree bootstrap as `wannabuild` before reading, writing, planning, or editing.
- If already inside an isolated WannaBuild workspace, resume there.
- Otherwise create an isolated workspace with `scripts/wannabuild-workspace.sh --json` when available.
- Continue only in the isolated workspace; never keep working in the original checkout.

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
