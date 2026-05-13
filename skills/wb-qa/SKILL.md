---
name: wb-qa
description: WannaBuild QA phase entrypoint for validating acceptance criteria, integration behavior, and release readiness evidence.
---

# wb-qa

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed. Specialist judgment stays advisory unless a gate or acceptance criterion requires evidence.

Use this phase skill when the user wants QA or the active WannaBuild workflow is in QA. A `wb-qa` or `wannabuild:wb-qa` invocation starts or resumes the full WannaBuild loop unless the user explicitly says QA only.

## Phase Bootstrap

Before any QA phase work:

- If no concrete task exists, ask for the actual goal first.
- Work in the current checkout by default.
- Do not create an isolated worktree for QA.

## Purpose

Validate that the implemented behavior satisfies the acceptance criteria and integration expectations.

## Defaults

- Treat integration behavior as the hard gate.
- Derive checks from requirements, changed surfaces, and risk.
- Prefer real tests and end-to-end flows over inspection-only confidence.
- Keep exploratory checks bounded and evidence-driven.
- Use sub-agents only for independent platforms, flows, or risk classes.
- Do not ship or summarize as complete while QA is failing.
- Preserve active WannaBuild workflow state across turns until the task is complete or the user explicitly exits or stops.

## Flow

1. Identify acceptance criteria and affected flows.
2. Select the smallest check set that covers the risk.
3. Run automated tests, manual flows, or environment checks as appropriate.
4. Record pass/fail evidence and blockers.
5. Hand off to ship/summary unless the user explicitly requested QA only.

## Output

Report checks run, results, failures, residual risk, and whether the integration gate passed. In full-loop mode, continue to ship/summary after QA passes unless user judgment is required.
