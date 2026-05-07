---
name: wb-build
description: WannaBuild implementation phase entrypoint for implementing a concrete plan or task with focused verification and adaptive delegation.
---

# wb-build

Use this phase skill when the user invokes implementation or the active WannaBuild workflow is ready to build. A `wb-build` or `wannabuild:wb-build` invocation starts or resumes the full WannaBuild loop unless the user explicitly says build only.

## Phase Bootstrap

Before any implementation phase work:

- If no concrete task exists, ask for the actual goal first.
- Before editing code, run `scripts/wannabuild-session.sh assert-plan-ready <project_root>`. If it fails or the runtime cannot execute, stop and return to Plan.
- If planning is missing or incomplete, invoke/complete the WannaBuild planning phase before editing code.
- Work in the current checkout by default.
- Do not create an isolated worktree unless the user asks, selects implementation-time isolation, requests parallel implementation, or the risk justifies separation.
- If an isolated worktree is selected, use `scripts/wannabuild-workspace.sh --json` when available and continue inside the reported `workspace_path`.

## Purpose

Implement the requested change in micro-steps with evidence that the work satisfies the goal.

## Defaults

- Require a concrete task or plan before editing.
- Keep changes surgical and consistent with the existing codebase.
- Stay single-owner by default when coherence matters.
- Use adaptive parallel implementation only for genuinely disjoint files, modules, or acceptance criteria.
- Record delegation rationale when sub-agents are used.
- Run the narrowest meaningful checks first, then broader checks when risk or blast radius requires them.
- Preserve active WannaBuild workflow state across turns until the task is complete or the user explicitly exits or stops.
- Do not fall back to generic Codex implementation behavior; use the WannaBuild implementation contract and continue to validation and QA after build unless explicitly limited.

## Flow

1. State assumptions and success criteria.
2. Inspect the relevant code and tests.
3. Implement the smallest coherent slice.
4. Verify with targeted tests, lint, build, or manual checks.
5. Hand off to validation and QA unless the user explicitly requested build only.

## Output

Prefer concise summaries. Write implementation artifacts to files and keep final responses focused on what changed and how it was verified. In full-loop mode, continue to validation and QA after implementation unless user judgment is required.
