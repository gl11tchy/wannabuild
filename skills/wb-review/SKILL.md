---
name: wb-review
description: Standalone WannaBuild review toolbox skill for adaptive code, spec, and risk review without automatically advancing to QA or ship.
---

# wb-review

Use this toolbox skill when the user wants review only.

## Toolbox Bootstrap

Before any toolbox phase work:

- If no concrete task exists, ask for the actual goal first.
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
- Do not fix issues unless the user asks.

## Flow

1. Identify the change scope and intended behavior.
2. Inspect relevant diffs, specs, and tests.
3. Run targeted reviewer hats; add sub-agents only for distinct risk ownership.
4. Separate blockers from non-blocking notes.
5. Stop before QA or implementation.

## Output

Return findings first. If no issues are found, say so and note remaining test gaps or residual risk.
