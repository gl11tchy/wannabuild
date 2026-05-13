---
name: wb-review
description: WannaBuild review phase entrypoint for adaptive code, spec, and risk review with automatic remediation of actionable findings.
---

# wb-review

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed. Specialist judgment stays advisory unless a gate or acceptance criterion requires evidence.

Use this phase skill when the user wants review or the active WannaBuild workflow is in Validate/Review. A `wb-review` or `wannabuild:wb-review` invocation starts or resumes the full WannaBuild loop unless the user explicitly says review only.

## Phase Bootstrap

Before any review phase work:

- If review is invoked without an explicit target, treat the current checkout changes as the review target by default.
- Inspect uncommitted changes first; if none exist, inspect the current branch diff against its upstream or main/base branch when discoverable.
- Ask for clarification only when no explicit target and no reviewable diff can be found.
- Work in the current checkout by default.
- Do not create an isolated worktree for review.

## Purpose

Find correctness, regression, security, testing, architecture, and maintainability issues that matter for the change.

## Defaults

- Lead with findings ordered by severity.
- Ground each finding in file and line references.
- Keep summaries secondary to actionable issues.
- Select reviewer hats from changed surfaces, risk, and acceptance criteria.
- Always call out missing verification when it affects confidence.
- Fix actionable bugs, regressions, missing required tests, and clear contract violations by default.
- Do not fix subjective style notes, scope changes, destructive changes, or product decisions without user confirmation.
- Preserve active WannaBuild workflow state across turns until the task is complete or the user explicitly exits or stops.
- Continue to QA after review passes unless the user explicitly requested review only.

## Flow

1. Identify the change scope and intended behavior.
2. Inspect relevant diffs, specs, and tests.
3. Run targeted reviewer hats; add sub-agents only for distinct risk ownership.
4. Fix actionable findings automatically.
5. Rerun impacted checks and reviewer hats.
6. Hand off to QA unless the user explicitly requested review only.

## Output

Return a concise review summary: issues found, fixes applied, checks rerun, and remaining risk. If no issues are found, say so and note remaining test gaps or residual risk.
