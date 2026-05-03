---
name: wb-qa
description: Standalone WannaBuild QA toolbox skill for validating acceptance criteria, integration behavior, and release readiness evidence.
---

# wb-qa

Use this toolbox skill when the user wants QA or final verification only.

## Mandatory Toolbox Bootstrap

Before any toolbox phase work:

- If no concrete task exists, ask for the actual goal first.
- If the current project is a git repo and a concrete task exists, use the same mandatory workspace/worktree bootstrap as `wannabuild` before reading, writing, planning, or editing.
- If already inside an isolated WannaBuild workspace, resume there.
- Otherwise create an isolated workspace with `scripts/wannabuild-workspace.sh --json` when available.
- Continue only in the isolated workspace; never keep working in the original checkout.

## Purpose

Validate that the implemented behavior satisfies the acceptance criteria and integration expectations.

## Defaults

- Treat integration behavior as the hard gate.
- Derive checks from requirements, changed surfaces, and risk.
- Prefer real tests and end-to-end flows over inspection-only confidence.
- Keep exploratory checks bounded and evidence-driven.
- Use sub-agents only for independent platforms, flows, or risk classes.
- Do not ship or summarize as complete while QA is failing.

## Flow

1. Identify acceptance criteria and affected flows.
2. Select the smallest check set that covers the risk.
3. Run automated tests, manual flows, or environment checks as appropriate.
4. Record pass/fail evidence and blockers.
5. Stop before ship unless the user asks to continue.

## Output

Report checks run, results, failures, residual risk, and whether the integration gate passed.
