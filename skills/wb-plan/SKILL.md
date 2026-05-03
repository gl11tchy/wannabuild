---
name: wb-plan
description: Standalone WannaBuild planning toolbox skill for turning a brief or concrete task into architecture direction, implementation slices, and verification expectations.
---

# wb-plan

Use this toolbox skill when the user wants planning only, not implementation.

## Mandatory Toolbox Bootstrap

Before any toolbox phase work:

- If no concrete task exists, ask for the actual goal first.
- If the current project is a git repo and a concrete task exists, use the same mandatory workspace/worktree bootstrap as `wannabuild` before reading, writing, planning, or editing.
- If already inside an isolated WannaBuild workspace, resume there.
- Otherwise create an isolated workspace with `scripts/wannabuild-workspace.sh --json` when available.
- Continue only in the isolated workspace; never keep working in the original checkout.

## Purpose

Produce a concrete, verifiable plan from a discovered brief, existing spec, or clear task.

## Defaults

- Start from the smallest plan that can satisfy the goal.
- Inspect only the files and docs needed to verify the direction.
- Prefer existing architecture, conventions, and helper APIs.
- Ask when ambiguity changes architecture, scope, or risk.
- Do not implement code while planning.
- Deploy sub-agents adaptively for independent architecture, risk, dependency, or task-decomposition questions.

## Flow

1. Confirm the goal, assumptions, constraints, and success criteria.
2. Map the affected surfaces and relevant existing patterns.
3. Choose the design direction and note tradeoffs only where they matter.
4. Break work into ordered slices with verification for each slice.
5. Stop at the planning boundary.

## Output

Return the plan directly, or write/update `.wannabuild/spec/design.md` and `.wannabuild/spec/tasks.md` when the user asks for workflow artifacts.
