---
name: wb-review
description: WannaBuild review phase entrypoint for adaptive code, spec, and risk review with automatic remediation of actionable findings.
---

# wb-review

## Contract Standard

This prompt follows `docs/contract-standard.md` and inherits the four mandates in
`skills/internal/build/references/doctrine.md`; where this file is silent, the doctrine governs.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed and cannot be rationalized past. Specialist judgment is advisory; gates and acceptance criteria require execution evidence and override prose.

Use this phase skill when the user wants review or the active WannaBuild workflow is in Validate/Review. A `wb-review` or `wannabuild:wb-review` invocation starts or resumes the full WannaBuild loop unless the user explicitly says review only.

## Phase Bootstrap

Before any review phase work:

- If review is invoked without an explicit target, use the current checkout changes as the review target by default. Do not ask which target to use.
- Determine the review base deterministically: inspect uncommitted changes first; if none exist, diff the current branch against its `git merge-base` with the upstream branch, else the remote default branch resolved via `git symbolic-ref refs/remotes/origin/HEAD` (or `git remote show origin`). Only ask the user when both uncommitted changes and a base are genuinely undeterminable after running these commands.
- If this invocation would START (not resume) the full loop and no discovery/requirements artifacts exist for the change (`.wannabuild/spec/requirements.md` with an Acceptance Criteria section), route through mandatory discovery first. Review evaluates the change against discovered acceptance criteria, never against an invented intent.
- Work in the current checkout. Do not create an isolated worktree for review.

## Purpose

Find every correctness, regression, security, testing, architecture, and maintainability issue across the entire changed surface. Each dimension is reviewed on every iteration; none is declared clean without the evidence in the per-dimension completion table below.

## Defaults

- Lead with findings ordered by severity per the Severity Rubric, each grounded in file and line references; keep summaries secondary to actionable issues.
- Preserve active WannaBuild workflow state across turns until the task is complete or the user explicitly exits or stops.

## Flow

1. Identify the change scope and the discovered acceptance criteria the change must satisfy.
2. Inspect ALL changed diffs, the governing specs, and ALL tests touching the changed surfaces. No diff, spec, or test is skipped as "not relevant".
3. Build the Coverage Manifest: enumerate every changed surface and apply the required hats per the Deterministic Hat Selection table, spawning sub-agents per its trigger rule.
4. Acquire any environment needed to judge correctness/regression/security/behavior, then run the checks (see Verification Is Obtained, Never Waived). Record exact commands, exit codes, and output.
5. Fix findings per the Severity Rubric.
6. Rerun the full required hat set and every test touching the changed surfaces; capture fresh execution evidence.
7. Confirm the Review Pass Condition and proceed per its boundary rule.

## Hard Gate: Review Completeness (fails closed)

Enumerate EVERY changed surface from the diff — files, functions, endpoints, migrations, configs, generated artifacts. Build a coverage table:

| Surface | Hats applied | Dynamic check run | Evidence (command + exit code) |
|---|---|---|---|

The review CANNOT pass and CANNOT hand off to QA until 100% of changed surfaces appear in this table with at least one hat applied and, for any surface whose correctness depends on runtime behavior, a dynamic check with real evidence. A surface examined "partially" is not covered. This mirrors `assert-review-ready`: a verdict that enumerated a sample is a FAIL.

### Per-dimension completion

Every dimension below is exercised on every iteration. A dimension is "clean" only with the listed evidence — never by assertion:

| Dimension | Clean requires |
|---|---|
| Correctness | Acceptance criteria mapped to code; impacted tests executed and passing |
| Regression | Existing test suite run; touched call sites traced |
| Security | Auth/secrets/input-handling paths inspected; no introduced exposure |
| Testing | Every changed surface has covering tests that actually ran (`total > 0`, `failed == 0`) |
| Architecture | Boundaries and dependencies of changed modules inspected |
| Maintainability | Changed code read in full; complexity and duplication checked |

## Verification Is Obtained, Never Waived

If a finding's correctness, regression, security, or behavior cannot be judged from source, you MUST acquire the environment to judge it before reporting — never downgrade an unmet verification requirement to a soft note:

- Auto-acquire (no permission needed): run the test suite and targeted tests; build and run the app locally; create an ephemeral/local DB branch (Supabase/Neon/Railway); drive the running UI with a browser (Chrome) or computer-use; generate fixtures and seed data; read live docs via Context7; stand up a preview/ephemeral environment.
- Stop-and-ask only for billable, outward-facing, or destructive acquisition (paid provisioning, deploys, production data, external sends). Present the exact resource needed and why.
- A verification may be reported as BLOCKED only after a logged acquisition attempt in `.wannabuild/outputs/acquisition-log.json` recording what was needed, which tools/connectors/CLIs were attempted, and the result. `assert-acquisition-attempted` rejects any blocked status without a logged attempt.
- "Tests not run", "missing env", "no access", and "can't test" are never a stopping point — they are an instruction to acquire or to ask, then proceed.

## Deterministic Hat Selection

Apply the full required hat set to every changed surface on every iteration — no impacted-only subset, no fast-track for small diffs, no self-selecting out. Detect the surface types in the diff and apply the mapped hats; the mapping is fixed, so two runs over the same diff select the same hats.

| Surface type detected | Required hats |
|---|---|
| Backend / data-layer logic | correctness + security + data-integrity |
| API / contract change | contract + regression |
| UI change | behavior (run it in a browser) + accessibility |
| Auth / secrets / payments | security (mandatory) |
| Migration / schema change | data-integrity (run against an ephemeral DB branch) |
| Build / config / CI | regression + integration |

Across all detected surfaces, the union always includes correctness, security, testing, architecture, and maintainability. Add a sub-agent for a surface type when it carries distinct risk ownership (security on an auth surface, data-integrity on a migration); the trigger is the surface type's presence, not subjective judgment.

## Severity Rubric

Classification is fixed so two runs label the same finding identically:

- critical = data loss, security hole, or a broken core flow.
- high = incorrect behavior on a supported path, or a missing required test.
- medium = regression risk or maintainability hazard.
- low = style or clarity only.

Auto-fix every critical and high finding — bugs, regressions, missing required tests, and clear contract violations — and re-verify each with execution evidence. Medium and low findings are reported; fix them when the change is non-destructive and within the established scope, otherwise present them as options (see Collaboration on Substantive Decisions).

## Collaboration on Substantive Decisions

When intended behavior is ambiguous, acceptance criteria conflict, a finding is suspicious-but-not-clearly-wrong, or a fix would change scope/design/product behavior — including subjective style notes, scope changes, destructive changes, and product decisions — surface the interpretations and present the options to the user, each with your recommended answer and its reasoning, before reviewing against an assumed intent or applying the change. Never act on these silently. Do not pause for mechanical choices (which base to diff, which file to open); decide those autonomously and keep moving.

## Review Pass Condition

Review PASSES only when ALL hold:

1. The Coverage Manifest is complete — 100% of changed surfaces covered with evidence.
2. Every per-dimension completion requirement is met.
3. Every critical and high finding is fixed and re-verified with execution evidence.
4. Impacted tests were actually run and pass (`total > 0`, `failed == 0`, `errored == 0`).
5. No verification remains in BLOCKED state without an exhausted, logged acquisition attempt.

At the Review → QA boundary, present what review produced, name QA as the next phase, and wait for an explicit approval word ("go", "proceed", "approved", "continue", "next", "lgtm", "do it"). A vague acknowledgment ("ok", "sure") does not cross the boundary. Only after approval, and only with the Pass Condition met, continue to QA — unless the user requested review only.

## Output

Return a review summary: the Coverage Manifest, issues found by severity, fixes applied with their re-verification evidence, checks rerun (commands + exit codes), and any BLOCKED verification with its acquisition-log reference. There is no "no issues found, gaps noted" outcome: an open test gap or residual risk is itself a finding that must be closed by running the test or escalated as a blocking finding before review can pass.
