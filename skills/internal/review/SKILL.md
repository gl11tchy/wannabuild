# WannaBuild: Review Phase (Elite Code Review)

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
This phase inherits the four mandates in `skills/internal/build/references/doctrine.md`; where this file is silent, the doctrine governs, and every runtime gate fails closed and may not be rationalized past.
Runtime gates fail closed. Every reviewer's findings are binding: any critical or high finding from any reviewer blocks ship and must be remediated or escalated to the user — no reviewer's verdict is "advisory".

> "Does the code match the spec?"

Phase 5 of 7 in the WannaBuild SDD pipeline. Specialist reviewers validate the implementation against the spec artifacts. The full reviewer set for every iteration must unanimously PASS for code to ship. The integration tester is the terminal hard gate — its FAIL cannot be overridden at any escalation level.

The reviewer set is fixed, not adaptive (Doctrine Mandate 3). Only the *depth* of each reviewer's work scales with the change; which reviewers run is identical on every run:

- Every iteration runs all six reviewers: `wb-security-reviewer`, `wb-performance-reviewer`, `wb-architecture-reviewer`, `wb-testing-reviewer`, `wb-code-simplifier`, and `wb-integration-tester`.
- Each reviewer covers the **entire changed surface**, not a sample, and its verdict must enumerate what it covered.
- There is no impacted-only subset, no fast-track, no reviewer self-selecting out, and no "integration-only" path.
- Record the reviewer set and per-reviewer covered-surface in `.wannabuild/decisions.md` or review notes every iteration.

## Agents

### Reviewer Pool

| Agent | File | Role | Hard Gate? |
|-------|------|------|------------|
| Security Reviewer | `wb-security-reviewer` | OWASP, secrets, auth vulnerabilities | No |
| Performance Reviewer | `wb-performance-reviewer` | N+1 queries, memory, scalability | No |
| Architecture Reviewer | `wb-architecture-reviewer` | Design compliance, separation of concerns | No |
| Testing Reviewer | `wb-testing-reviewer` | Test quality, coverage, antipatterns | No |
| Integration Tester | `wb-integration-tester` | Acceptance criteria → test mapping, runs tests | **YES (terminal, non-overridable)** |
| Code Simplifier | `wb-code-simplifier` | Over-engineering, dead code, DRY | No |

"Hard Gate? No" means only that the reviewer is not the *terminal* gate. It does **not** make the reviewer optional or its findings advisory: every reviewer runs every iteration, and any critical or high finding from any reviewer blocks ship until remediated or explicitly escalated to the user.

## Full Reviewer Set Contract (Mode-agnostic)

- Every iteration — including iteration 1 and including one-line changes — runs all six reviewers. There is no fast-track and no reduced set; the `assert-review-ready` gate requires a PASS verdict from every reviewer.
- The set always includes all of: `wb-security-reviewer`, `wb-performance-reviewer`, `wb-architecture-reviewer`, `wb-testing-reviewer`, `wb-code-simplifier`, and `wb-integration-tester`.
- Any FAIL triggers the next iteration to re-run the full reviewer set (not an impacted subset) after remediation, so coverage is identical across iterations.
- The reviewer set never narrows for "low risk", "high confidence", or "no relevant surface" — those are not valid reasons to drop a reviewer.
- Do not reduce hard-gate logic in any scenario.

## Trigger Conditions

**Explicit:**

- `/wannabuild-review`
- "Review the code" / "Is this ready?" / "Code review"

**Implicit (from orchestrator):**

- Implement phase completes → auto-transition to Review

## Input

**Handoff from Implement:**

```json
{
  "phase": "review",
  "from": "implement",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "design": ".wannabuild/spec/design.md",
    "tasks": ".wannabuild/spec/tasks.md"
  },
  "implementation": {
    "tasks_completed": 8,
    "tests_written": 15,
    "checkpoints": [".wannabuild/checkpoints/task-1-step-1.md", "..."],
    "changed_files_from_last_checkpoint_window": ["src/auth.ts", "tests/auth.integration.test.ts"]
  }
}
```

Checkpoint summaries are first-class review input. Every reviewer covers the entire changed surface; the latest checkpoint window indicates where to spend the most depth, but it never narrows what a reviewer must inspect — the broader diff is always in scope.

Before spawning any reviewer for review phase:

```bash
scripts/validate-wannabuild-artifacts.sh . review
```

If this check fails, do not spawn reviewers. First attempt to repair the contract violation yourself (regenerate the missing artifact, recover acceptance criteria via the grill in Execution Flow step 1) and log the attempt. If the violation is one only the user can resolve (a product/scope decision or a destructive change), present the exact validation errors plus the candidate fixes as options with a recommended answer, and wait for an explicit approval word before proceeding.

## Execution Flow

1. Read specs, checkpoints, changed-file summaries, and test output. Before grading any reviewer, confirm the acceptance criteria are real and user-confirmed: if any criterion in `requirements.md` is missing, ambiguous, or appears auto-assumed (no recorded user confirmation in `.wannabuild/spec` or `decisions.md`), STOP and grill the user one question at a time — each with a recommended answer and its reasoning — to lock the criterion before any reviewer grades against it. Do not invent or assume criteria.
2. Build the active set as the full six reviewers — this is fixed, not selected.
3. Include `wb-integration-tester` in every review iteration as the terminal hard gate.
4. Run every reviewer at `standard` capability tier and `high` reasoning effort minimum; never assign a lightweight/low-effort reviewer to a real changed surface.
5. Run all reviewers in parallel; each reviewer covers the entire changed surface.
6. Collect verdicts, update loop state, and route remediation if any reviewer fails.
7. On retries, re-run the full six-reviewer set after remediation — never a narrowed subset.

## Agent Spawning

The reviewer list is fixed every iteration — no inference, no narrowing:

```text
active_reviewers = [
  wb-security-reviewer,
  wb-performance-reviewer,
  wb-architecture-reviewer,
  wb-testing-reviewer,
  wb-code-simplifier,
  wb-integration-tester,
]
# This list is identical on every run and every iteration.
# There is no "integration-only" path and no "low risk" / "no surface" omission.
```

Spawn all six `active_reviewers` in parallel (background):

```text
for reviewer in active_reviewers:
  Task(subagent_type="[reviewer]", run_in_background=true)
    capability_tier: standard   # minimum; strong for changes touching auth, data, or money
    reasoning_effort: high      # minimum for every reviewer; never low
    ownership: <full changed surface — the reviewer enumerates what it covered>
    prompt: "Review the ENTIRE changed surface against the specs.
             Before reporting any missing-env / cannot-run / no-fixture blocker,
             attempt resource acquisition and log it (see Resource Acquisition Mandate).
             Write full JSON verdict to .wannabuild/review/[reviewer]-iter-{N}.json.
             Return one-line VERDICT summary with file path."
```

Every reviewer covers the entire changed surface. A reviewer that examined only part of the diff has not completed its job and its verdict is a FAIL until it enumerates full coverage.

### Reviewer Focus Matrix

All six reviewers run every iteration. This matrix does **not** select which reviewers run — it only tells each reviewer where to spend the most depth on its full-surface pass. Each reviewer still covers the entire changed surface:

- `wb-security-reviewer`: prioritize auth/session/permission/crypto/secrets/input-validation; still scan all changed files for security regressions.
- `wb-performance-reviewer`: prioritize DB query paths, loops over collections, caching, rendering hotspots; still scan all changed files.
- `wb-architecture-reviewer`: prioritize module boundaries, service contracts, API shape, state management; still scan all changed files.
- `wb-testing-reviewer`: prioritize test harness, fixtures, assertions, coverage strategy; still scan all changed files.
- `wb-code-simplifier`: prioritize large refactors, abstraction churn, dead-code risk; still scan all changed files.
- `wb-integration-tester`: **terminal hard gate** — maps every acceptance criterion to an executed test.

The matrix never removes a reviewer. A change with "no obvious security surface" still gets a full `wb-security-reviewer` pass.

### Context Scope Rules

- Every reviewer gets: the full changed file list, full diff, and the full requirements/design/tasks specs — never a "scoped" or partial excerpt that would prevent full-surface coverage.
- Integration tester additionally gets: the full acceptance criteria map and all test files, and must execute the suite itself (see Resource Acquisition Mandate) rather than relying on a pre-supplied output summary.

## Resource Acquisition Mandate

Doctrine Mandate 2 governs here: "missing env", "no database", "can't run it", "no access", "no fixtures" are **never** grounds to skip a reviewer's coverage or the integration tester's execution. They are grounds to obtain the resource, and only then — if obtaining it is billable, outward-facing, or destructive — to ask the user.

Before any reviewer or the integration tester may report `blocked`, `cannot-run`, `missing-env`, or `missing-dependency`, it MUST first attempt to obtain the resource and record each attempt in `.wannabuild/outputs/acquisition-log.json` (what was needed, which tools/connectors/CLIs were tried, the result):

- Run the app or test suite locally; build it if it is not built.
- Provision an ephemeral database branch (Supabase or Neon via MCP) and point the suite at it.
- Drive the real UI with a browser (Chrome) or computer-use to exercise acceptance criteria.
- Read live library docs via Context7 instead of assuming an API shape.
- Generate fixtures and seed data instead of declaring "no fixtures".
- Stand up a preview/ephemeral environment (Railway/Vercel) for runtime checks.

Stop-and-ask is permitted **only** for billable, outward-facing, or destructive acquisition (paid provisioning, production data, external sends, deploys hard to reverse). Present the specific resource needed and why; do not silently skip.

`blocked` is a last resort, never a default off-ramp. The `assert-acquisition-attempted` gate rejects any `blocked`/`failed` status that lacks a logged acquisition attempt. All validation and QA evidence must record exactly what was executed — real commands, real exit codes, real output — never assertions that work "should" pass.

## Verdict Format

Each reviewer returns:

```json
{
  "agent": "wb-[agent-name]",
  "status": "PASS|FAIL",
  "issues": [
    {
      "severity": "critical|high|medium|low",
      "file": "path/to/file",
      "line": 42,
      "issue": "Description",
      "recommendation": "How to fix"
    }
  ],
  "summary": "Brief assessment"
}
```

The integration tester additionally returns:

```json
{
  "agent": "wb-integration-tester",
  "status": "PASS|FAIL",
  "hard_gate": true,
  "test_execution": {
    "total": 15,
    "passed": 14,
    "failed": 1,
    "duration_ms": 3200
  },
  "coverage_map": [
    {"criterion": "...", "test_file": "...", "status": "covered|MISSING"}
  ]
}
```

## Synthesis and Verdict Display

After all reviewers complete, read each `.wannabuild/review/[agent]-iter-{N}.json` file to collect full verdicts. Parse the `status` and `issues` fields to build the display. (The one-line returns tell you which agents completed, but all detail comes from the files.)

If any verdict file is malformed JSON or missing required fields, fail closed for that reviewer — never route the run to `blocked`:

- report the exact path and parser error
- re-run that reviewer once; if it still returns invalid JSON, record that reviewer's status as `FAIL` and route remediation
- if `wb-integration-tester` returns malformed/missing JSON, `blocked`, or `cannot-run` without a logged acquisition attempt, treat it as a hard-gate FAIL (not `blocked`) and require remediation before continuing

Display (the full six-reviewer set runs every iteration, so counts are always out of 6):

```text
Review Results — Iteration [N]:
  Reviewers: Security, Performance, Architecture, Testing, Code Simplifier, Integration Tester
  ✓ Security: PASS
  ✗ Performance: FAIL — [summary]
  ✓ Architecture: PASS
  ✓ Testing: PASS
  ✓ Code Simplifier: PASS
  ✓ Integration Tester: PASS

  [5/6 PASS] — Sending feedback to wb-implementer-escalated...
```

Or on a clean iteration:

```text
Review Results — Iteration [N]:
  Reviewers: Security, Performance, Architecture, Testing, Code Simplifier, Integration Tester
  ✓ Security: PASS
  ✓ Performance: PASS
  ✓ Architecture: PASS
  ✓ Testing: PASS
  ✓ Code Simplifier: PASS
  ✓ Integration Tester: PASS

  [6/6 PASS] — Unanimous approval. Ready to ship.
```

## The Integration Tester: Hard Gate

The `wb-integration-tester` has special enforcement rules:

1. **Maps every acceptance criterion** from `spec/requirements.md` to test files
2. **Runs the actual test suite** — doesn't just read code. If the suite cannot run (no DB, no env, unbuilt app), the tester MUST first acquire the resource per the Resource Acquisition Mandate (build the app, provision a Supabase/Neon branch, generate fixtures, stand up a preview env) and log each attempt in `acquisition-log.json`. "Couldn't run it" is never a PASS and never a silent skip.
3. **Validates test quality** with concrete gates — PASS requires ALL of:
   - every acceptance criterion mapped to at least one EXECUTED, passing test (the mapping logged with run output)
   - each mapped test has at least one assertion on observable behavior, not merely "does not throw"
   - at least one negative/edge case per criterion that has a failure mode
   - tests are isolated (no dependence on another test's side effects or ordering)
4. **FAIL if ANY criterion lacks a test, or any test exists but could not be executed** — no exceptions. A criterion whose test exists but did not run (for any reason, including missing infra) is a FAIL until the infra is acquired and the test runs.
5. **PASS requires execution evidence** — `test_execution` showing `total > 0`, `failed == 0`, `errored == 0`, and a `coverage_map` in which every criterion is `covered` (none `missing` or `partial`). "Status: PASS" with zero tests executed is a FAIL.
6. **Cannot be overridden** — at any escalation level, "ship with known issues" is removed if this agent is failing. There is no override path.

This enforces WannaBuild's core principle: **integration tests are non-negotiable**.

## Feedback Aggregation

When any reviewer fails, read the detail files for all failing agents (`.wannabuild/review/[agent]-iter-{N}.json`), then aggregate their actionable issues into consolidated feedback for `wb-implementer-escalated` and fix them automatically:

```json
{
  "iteration": 1,
  "total_issues": 5,
  "by_severity": {"critical": 1, "high": 2, "medium": 2},
  "issues_by_file": {
    "src/auth.ts": [
      {"agent": "wb-security-reviewer", "severity": "critical", "issue": "SQL injection", "recommendation": "Use parameterized queries"}
    ]
  }
}
```

This consolidated feedback (not the raw agent files) is passed to `wb-implementer-escalated` for fixes. Then the next review iteration re-runs the full six-reviewer set (never an impacted subset). Stop for user input only when a finding genuinely requires product judgment, a destructive change, or scope expansion. "Needs credentials" or "needs a paid service" is **not** an automatic stop: first exhaust the Resource Acquisition Mandate (local run, ephemeral DB branch, fixtures, preview env, Context7 docs) and log the attempts; only stop-and-ask if the remaining acquisition is itself billable, outward-facing, or destructive, and then name the specific resource and why.

## Loop State

Updated in `.wannabuild/loop-state.json` after each iteration. See orchestrator SKILL.md for full schema.

## References

Review agents can reference:

- `skills/internal/review/references/security-checklist.md` — regex patterns, OWASP, framework checks
- `skills/internal/review/references/architecture-patterns.md` — DRY, clean code, refactoring patterns

## Handoff to Ship

On unanimous approval:

```json
{
  "phase": "ship",
  "from": "review",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "design": ".wannabuild/spec/design.md",
    "tasks": ".wannabuild/spec/tasks.md"
  },
  "review": {
    "iterations": 2,
    "final_verdict": "APPROVED",
    "all_active_reviewers_passed": true
  }
}
```

## Standalone Usage

Elite Code Review can also run standalone (outside the WannaBuild pipeline):

```text
User: /wannabuild-review

Orchestrator: I'll review the recent changes with the full specialist set...
[Runs all six reviewers over the entire changed surface]
[Reports verdicts]
```

Standalone runs do NOT downgrade the gate. The full six-reviewer set still runs, each over the entire changed surface, and the integration tester still maps and executes tests. If spec artifacts are missing, do not silently fall back to "general best practices" or "test existence only": grill the user one question at a time — each with a recommended answer — to recover the acceptance criteria the change is meant to satisfy, write them to `.wannabuild/spec/requirements.md`, then review and map every criterion to an executed test exactly as in pipeline mode. The integration tester's PASS still requires execution evidence and full criterion coverage.

## Quality Checklist

- [ ] All six reviewers ran this iteration, each covering the entire changed surface
- [ ] Every acceptance criterion confirmed (grilled and locked if missing/ambiguous) before grading
- [ ] Integration tester included in every iteration as the terminal hard gate
- [ ] Verdicts are valid JSON with required fields
- [ ] Loop state updated in `loop-state.json` (includes `active_reviewers` and counts)
- [ ] Feedback aggregated by file (not by agent) for `wb-implementer-escalated`
- [ ] Integration tester executed the actual test suite with `total > 0`, `failed == 0`, `errored == 0`
- [ ] Any `blocked`/`cannot-run` claim has a logged acquisition attempt in `acquisition-log.json`
- [ ] Unanimous PASS from all six reviewers before proceeding to Ship

## Contract Validation

- If any review artifact is malformed (`state.json`, checkpoint window, verdict JSON), first attempt to repair or re-run the producing step and log the attempt; treat the affected reviewer as `FAIL` and route remediation. Do not park the run as `blocked` without a logged acquisition/repair attempt — `assert-acquisition-attempted` rejects an unlogged `blocked`.
- The reviewer set is fixed: all six reviewers (`wb-security-reviewer`, `wb-performance-reviewer`, `wb-architecture-reviewer`, `wb-testing-reviewer`, `wb-code-simplifier`, `wb-integration-tester`) run every iteration over the entire changed surface. There is no selection, no impacted-only subset, and no confidence-based broadening.
- Hard gate rule: `wb-integration-tester` must be PASS with execution evidence for all approved states.
- Merge iteration feedback by file and severity before passing to implementer remediation.

## Failure Fallback

- If `loop-state.status` indicates `blocked`, do not auto-continue, and confirm the `acquisition-log.json` records the attempts that justify it.
- If `max_iterations` is reached with unresolved failures, surface:
  - unresolved items by file
  - Overrides are disabled whenever `wb-integration-tester` is FAIL/blocked (terminal, never overridable) or whenever any reviewer reports a critical or high finding. Such findings block ship and cannot be overridden; surface them by file and require an explicit user decision before any further action.
