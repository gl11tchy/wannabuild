# WannaBuild: Review Phase (Elite Code Review)

> "Does the code match the spec?"

Phase 5 of 7 in the WannaBuild SDD pipeline. Specialist reviewers validate the implementation against the spec artifacts. The active reviewer set for each iteration must unanimously PASS for code to ship. The integration tester is a hard gate — no override for missing tests.

The reviewer set is adaptive:

- Choose reviewers from changed surfaces, acceptance criteria, risk, and prior failures.
- Always include `wb-integration-tester`.
- Add reviewers only when they have distinct risk ownership and expected evidence.
- If impact is ambiguous, broaden the reviewer set.
- Record reviewer selection rationale in `.wannabuild/decisions.md` or review notes.

## Agents

### Reviewer Pool

| Agent | File | Role | Hard Gate? |
|-------|------|------|------------|
| Security Reviewer | `wb-security-reviewer` | OWASP, secrets, auth vulnerabilities | No |
| Performance Reviewer | `wb-performance-reviewer` | N+1 queries, memory, scalability | No |
| Architecture Reviewer | `wb-architecture-reviewer` | Design compliance, separation of concerns | No |
| Testing Reviewer | `wb-testing-reviewer` | Test quality, coverage, antipatterns | No |
| Integration Tester | `wb-integration-tester` | Acceptance criteria → test mapping, runs tests | **YES** |
| Code Simplifier | `wb-code-simplifier` | Over-engineering, dead code, DRY | No |

## Fast-Track Review Contract (Mode-agnostic)

- Iteration 1 may start with a reduced reviewer set only if the fast-track matrix in `skills/build/SKILL.md` is met and the rationale is recorded.
- Set must always include `wb-integration-tester`.
- Any FAIL in fast-track triggers the next iteration to run the impacted reviewers plus any reviewers needed to cover uncertainty.
- If impact routing confidence is unclear, broaden the reviewer set immediately.
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

Checkpoint summaries are first-class review input. Reviewer routing should prioritize changed files from the latest checkpoint window before falling back to broader diff context.

Before spawning any reviewer for review phase:

```bash
scripts/validate-wannabuild-artifacts.sh . review
```

If this check fails, do not spawn reviewers; present the exact validation errors and ask the user how to proceed.

## Execution Flow

1. Read specs, checkpoints, changed-file summaries, and test output.
2. Select reviewers by changed surfaces, risk, acceptance criteria, and prior failures.
3. Include `wb-integration-tester` in every review iteration.
4. Choose capability tier and reasoning effort for each reviewer based on risk and ambiguity.
5. Run selected reviewers in parallel when their inspections are independent.
6. Collect verdicts, update loop state, and route remediation if any active reviewer fails.
7. On retries, rerun impacted reviewers plus the integration hard gate; broaden if confidence is low.

## Agent Spawning

Build the reviewer list per iteration before spawning:

```text
active_reviewers = infer_reviewers(
  changed_files,
  acceptance_criteria,
  checkpoints,
  prior_failures,
  risk_profile
)

active_reviewers = union(active_reviewers, [wb-integration-tester])

IF active_reviewers has no distinct reviewer beyond integration AND risk is low:
  proceed with integration hard gate only

IF impact uncertain OR blast radius high:
  broaden active_reviewers until risk ownership is covered
```

Spawn only `active_reviewers` in parallel (background):

```text
for reviewer in active_reviewers:
  Task(subagent_type="[reviewer]", run_in_background=true)
    capability_tier: <lightweight / standard / strong>
    reasoning_effort: <low / medium / high>
    ownership: <risk class, file surface, acceptance criteria, or test concern>
    prompt: "Review using relevant specs + scoped diff context.
             Write full JSON verdict to .wannabuild/review/[reviewer]-iter-{N}.json.
             Return one-line VERDICT summary with file path."
```

Do not spawn a reviewer that has no relevant risk surface to inspect.

### Reviewer Impact Routing Matrix

Use changed files from last checkpoint window + prior failures to choose impacted reviewers:

- `wb-security-reviewer`: auth/session/permission/crypto/secrets/input-validation changes.
- `wb-performance-reviewer`: DB query paths, loops over collections, caching, rendering hotspots.
- `wb-architecture-reviewer`: module boundaries, service contracts, API shape, state management.
- `wb-testing-reviewer`: test harness, fixtures, assertions, coverage strategy changes.
- `wb-code-simplifier`: large refactors, abstraction churn, dead-code risk areas.
- `wb-integration-tester`: **always included** (hard gate).

If routing confidence is low, broaden the reviewer set until the changed surfaces and risks are covered.

### Context Scope Rules

- Non-integration reviewers get: changed file list, diff summary, and only relevant spec excerpts.
- Integration tester gets: full acceptance criteria map + relevant test files + test command output summary.

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

If any verdict file is malformed JSON or missing required fields, treat it as a review hard failure:

- report the exact path and parser error
- write `loop-state.json` status as `blocked`
- skip auto-continuation until contract fixes or user instruction is applied

Display (counts reflect the **active reviewer set** for that iteration):

```text
Review Results — Iteration [N]:
  Active reviewers: Security, Performance, Integration Tester
  ✓ Security: PASS
  ✗ Performance: FAIL — [summary]
  ✓ Integration Tester: PASS

  [2/3 PASS] — Sending feedback to wb-implementer-escalated...
```

Or on adaptive retry success:

```text
Review Results — Iteration [N]:
  Active reviewers: Performance, Integration Tester
  ✓ Performance: PASS
  ✓ Integration Tester: PASS

  [2/2 PASS] — Unanimous approval for active set. Ready to ship.
```

## The Integration Tester: Hard Gate

The `wb-integration-tester` has special enforcement rules:

1. **Maps every acceptance criterion** from `spec/requirements.md` to test files
2. **Runs the actual test suite** — doesn't just read code
3. **Validates test quality** — meaningful assertions, edge cases, isolation
4. **FAIL if ANY criterion lacks a test** — no exceptions
5. **Cannot be overridden** — at escalation, "ship with known issues" is removed if this agent is failing

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

This consolidated feedback (not the raw agent files) is passed to `wb-implementer-escalated` for fixes. Then the next review iteration runs the adaptive active reviewer set (impacted reviewers + integration tester; full fallback when impact is ambiguous). Stop for user input only when a finding requires product judgment, destructive changes, credentials, paid services, or scope expansion.

## Loop State

Updated in `.wannabuild/loop-state.json` after each iteration. See orchestrator SKILL.md for full schema.

## References

Review agents can reference:

- `skills/review/references/security-checklist.md` — regex patterns, OWASP, framework checks
- `skills/review/references/architecture-patterns.md` — DRY, clean code, refactoring patterns

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

Orchestrator: I'll review the recent changes with the relevant specialist perspectives...
[Selects reviewers from changed surfaces, risk, and test evidence]
[Reports verdicts]
```

When running standalone without spec artifacts, reviewers use general best practices instead of spec validation. The integration tester checks for test existence rather than spec coverage mapping. Standalone runs still use adaptive reviewer selection.

## Quality Checklist

- [ ] Active reviewer set selected from changed surfaces, risk, acceptance criteria, and prior failures
- [ ] Integration tester included in every iteration
- [ ] Verdicts are valid JSON with required fields
- [ ] Loop state updated in `loop-state.json` (includes `active_reviewers` and counts)
- [ ] Feedback aggregated by file (not by agent) for `wb-implementer-escalated`
- [ ] Integration tester ran the actual test suite
- [ ] Unanimous approval from active reviewer set before proceeding to Ship

## Contract Validation

- If any review artifact is malformed (`state.json`, checkpoint window, verdict JSON), route to `blocked` status and request user clarification.
- Reviewer selection uses:
  - impacted reviewers from changed surfaces and prior failures
  - plus `wb-integration-tester` always
  - broader coverage if routing confidence is low
- Hard gate rule: `wb-integration-tester` must be PASS for all approved states.
- Merge iteration feedback by file and severity before passing to implementer remediation.

## Failure Fallback

- If `loop-state.status` indicates `blocked`, do not auto-continue.
- If `max_iterations` is reached with unresolved failures, surface:
  - unresolved items by file
  - whether overrides are allowed (disabled when integration tester is failing)
