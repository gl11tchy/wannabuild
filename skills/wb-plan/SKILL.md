---
name: wb-plan
description: WannaBuild planning phase entrypoint for turning a brief or concrete task into architecture direction, implementation slices, and verification expectations.
---

# wb-plan

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed. Specialist judgment stays advisory unless a gate or acceptance criterion requires evidence.

Use this phase skill when the user invokes planning or the active WannaBuild workflow is in Plan. A `wb-plan` or `wannabuild:wb-plan` invocation starts or resumes the full WannaBuild loop unless the user explicitly says plan only or do not implement.

## Phase Bootstrap

Before any planning phase work:

- If no concrete task exists, ask for the actual goal first.
- Work in the current checkout by default.
- Do not create an isolated worktree for planning.

## Purpose

Produce a concrete, verifiable plan from a discovered brief, existing spec, or clear task.

## Defaults

- Start from the smallest plan that can satisfy the goal.
- Inspect only the files and docs needed to verify the direction.
- Prefer existing architecture, conventions, and helper APIs.
- Ask when ambiguity changes architecture, scope, or risk.
- Do not implement code while planning, but hand off to the WannaBuild implementation path after the plan is complete unless the user explicitly limited the workflow.
- Preserve active WannaBuild workflow state across turns until the task is complete or the user explicitly exits or stops.
- Do not treat vague acknowledgments like "ok" or "uh ok" as permission to skip planning or jump into implementation without a complete plan.
- Deploy sub-agents adaptively for independent architecture, risk, dependency, or task-decomposition questions.

## Flow

1. Confirm the goal, assumptions, constraints, and success criteria.
2. Map the affected surfaces and relevant existing patterns.
3. Choose the design direction and note tradeoffs only where they matter.
4. Break work into ordered slices with verification for each slice.
5. If the user did not explicitly request plan only, hand off to `wb-build` / Implement automatically.

## Output

Return the plan directly, or write/update `.wannabuild/spec/design.md` and `.wannabuild/spec/tasks.md` when the user asks for workflow artifacts. In full-loop mode, continue to implementation after the plan unless user judgment is required.
