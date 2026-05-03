---
name: wb-build
description: Standalone WannaBuild build toolbox skill for implementing a concrete plan or task with focused verification and adaptive delegation.
---

# wb-build

Use this toolbox skill when the user wants implementation without running the full WannaBuild loop.

## Mandatory Toolbox Bootstrap

Before any toolbox phase work:

- If no concrete task exists, ask for the actual goal first.
- If the current project is a git repo and a concrete task exists, use the same mandatory workspace/worktree bootstrap as `wannabuild` before reading, writing, planning, or editing.
- If already inside an isolated WannaBuild workspace, resume there.
- Otherwise create an isolated workspace with `scripts/wannabuild-workspace.sh --json` when available.
- Continue only in the isolated workspace; never keep working in the original checkout.

## Purpose

Implement the requested change in micro-steps with evidence that the work satisfies the goal.

## Defaults

- Require a concrete task or plan before editing.
- Keep changes surgical and consistent with the existing codebase.
- Stay single-owner by default when coherence matters.
- Use adaptive parallel implementation only for genuinely disjoint files, modules, or acceptance criteria.
- Record delegation rationale when sub-agents are used.
- Run the narrowest meaningful checks first, then broader checks when risk or blast radius requires them.

## Flow

1. State assumptions and success criteria.
2. Inspect the relevant code and tests.
3. Implement the smallest coherent slice.
4. Verify with targeted tests, lint, build, or manual checks.
5. Report changed files, checks run, risks, and remaining work.

## Output

Prefer concise summaries. Write implementation artifacts to files and keep final responses focused on what changed and how it was verified.
