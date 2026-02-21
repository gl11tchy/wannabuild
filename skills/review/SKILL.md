# WannaBuild: Review Phase (Elite Code Review)

> "Does the code match the spec?"

Phase 5 of 7 in the WannaBuild SDD pipeline. Specialist reviewers validate the implementation against the spec artifacts. The active reviewer set for each iteration must unanimously PASS for code to ship. The integration tester is a hard gate — no override for missing tests.

The reviewer set depends on the session mode (stored in `.wannabuild/state.json`) and iteration:
- **Iteration 1:** run the full base set for the mode (Full=6, Light=3, Spark=3)
- **Iteration 2+:** run only impacted reviewers + the mode baseline integration tester (`wb-integration-tester` or `wb-integration-tester-spark`) always
- **Fallback:** if impact is ambiguous, run the full base set

## Agents

### Full Mode (all 6)

| Agent | File | Role | Hard Gate? |
|-------|------|------|------------|
| Security Reviewer | `wb-security-reviewer` | OWASP, secrets, auth vulnerabilities | No |
| Performance Reviewer | `wb-performance-reviewer` | N+1 queries, memory, scalability | No |
| Architecture Reviewer | `wb-architecture-reviewer` | Design compliance, separation of concerns | No |
| Testing Reviewer | `wb-testing-reviewer` | Test quality, coverage, antipatterns | No |
| Integration Tester | `wb-integration-tester` | Acceptance criteria → test mapping, runs tests | **YES** |
| Code Simplifier | `wb-code-simplifier` | Over-engineering, dead code, DRY | No |

### Light Mode (3 reviewers)

| Agent | File | Role | Hard Gate? |
|-------|------|------|------------|
| Security Reviewer | `wb-security-reviewer` | OWASP, secrets, auth vulnerabilities | No |
| Architecture Reviewer | `wb-architecture-reviewer` | Design compliance, separation of concerns | No |
| Integration Tester | `wb-integration-tester` | Acceptance criteria → test mapping, runs tests | **YES** |

### Spark Mode (3 reviewers)

| Agent | File | Role | Hard Gate? |
|-------|------|------|------------|
| Security Reviewer | `wb-security-reviewer-spark` | OWASP, secrets, auth vulnerabilities | No |
| Architecture Reviewer | `wb-architecture-reviewer-spark` | Design compliance, separation of concerns | No |
| Integration Tester | `wb-integration-tester-spark` | Acceptance criteria → test mapping, runs tests | **YES** |


## Fast-Track Review Contract (Mode-agnostic)

- Iteration 1 may start with the reduced reviewer set only if matrix criteria in `AGENTS.md` are met.
- Set must always include the mode baseline integration tester (`wb-integration-tester` or `wb-integration-tester-spark`).
- Any FAIL in fast-track triggers the next iteration to run the full base reviewer set.
- If impact routing confidence is unclear, route to the full base reviewer set immediately.
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

```
Code changes + spec artifacts (input)
        │
        ▼
┌──────────────────────────────────────────────────────────────┐
│ Iteration 1: Full base reviewer set for mode                │
│   - Full mode: security, performance, architecture, testing, │
│                integration, code-simplifier                 │
│   - Light mode: security, architecture, integration         │
└──────────────────────────────────────────────────────────────┘
        │
        ▼
Collect verdicts → update loop-state → all active reviewers PASS?
        │
   YES  ▼                                     NO
      Ship                        Aggregate failures + changed files
                                              │
                                              ▼
                                Escalated implementer remediates
                                              │
                                              ▼
┌──────────────────────────────────────────────────────────────┐
│ Iteration 2+: Adaptive reviewer rerun                       │
│   active_reviewers = impacted_reviewers(changes, failures)  │
│                      + integration tester (always)           │
│   if impact uncertain: fallback to full base reviewer set    │
└──────────────────────────────────────────────────────────────┘
```

## Agent Spawning

Build the reviewer list per iteration before spawning:

```
base_reviewers_full  = [wb-security-reviewer, wb-performance-reviewer, wb-architecture-reviewer, wb-testing-reviewer, wb-integration-tester, wb-code-simplifier]
base_reviewers_light  = [wb-security-reviewer, wb-architecture-reviewer, wb-integration-tester]
base_reviewers_spark  = [wb-security-reviewer-spark, wb-architecture-reviewer-spark, wb-integration-tester-spark]

IF iteration == 1:   # first pass
  active_reviewers = base_reviewers_{mode}
ELSE:
  impacted = infer_impacted_reviewers(changed_files_since_last_iteration, prior_failures)
  active_reviewers = union(impacted, [wb-integration-tester])

  IF active_reviewers empty OR impact uncertain:
    active_reviewers = base_reviewers_{mode}
```

Spawn only `active_reviewers` in parallel (background):

```
for reviewer in active_reviewers:
  Task(subagent_type="[reviewer]", run_in_background=true)
    prompt: "Review using relevant specs + scoped diff context.
             Write full JSON verdict to .wannabuild/review/[reviewer]-iter-{N}.json.
             Return one-line VERDICT summary with file path."
```

### Reviewer Impact Routing Matrix

Use changed files from last checkpoint window + prior failures to choose impacted reviewers:

- `wb-security-reviewer`: auth/session/permission/crypto/secrets/input-validation changes.
- `wb-performance-reviewer`: DB query paths, loops over collections, caching, rendering hotspots.
- `wb-architecture-reviewer`: module boundaries, service contracts, API shape, state management.
- `wb-testing-reviewer`: test harness, fixtures, assertions, coverage strategy changes.
- `wb-code-simplifier`: large refactors, abstraction churn, dead-code risk areas.
- `wb-integration-tester`: **always included** (hard gate).
  (Spark mode uses `wb-integration-tester-spark`.)

If routing confidence is low, run the full base reviewer set for the selected mode.

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

```
Review Results — Iteration [N]:
  Active reviewers: Security, Performance, Integration Tester
  ✓ Security: PASS
  ✗ Performance: FAIL — [summary]
  ✓ Integration Tester: PASS

  [2/3 PASS] — Sending feedback to wb-implementer-escalated...
```

Or on adaptive retry success:

```
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

When any reviewer fails, read the detail files for all failing agents (`.wannabuild/review/[agent]-iter-{N}.json`), then aggregate their issues into consolidated feedback for `wb-implementer-escalated`:

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

This consolidated feedback (not the raw agent files) is passed to `wb-implementer-escalated` for fixes. Then the next review iteration runs the adaptive active reviewer set (impacted reviewers + integration tester; full fallback when impact is ambiguous).

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

```
User: /wannabuild-review

Orchestrator: I'll review the recent changes with my specialist team...
[Spawns the mode base reviewer set against the current diff or specified files]
[Reports verdicts]
```

When running standalone without spec artifacts, reviewers use general best practices instead of spec validation. The integration tester checks for test existence rather than spec coverage mapping. Standalone runs always use Full mode (all 6 reviewers) unless a `.wannabuild/state.json` with a stored mode is present.

## Quality Checklist

- [ ] Active reviewer set selected correctly for the iteration (base on iter-1, adaptive on retries)
- [ ] Integration tester included in every iteration
- [ ] Verdicts are valid JSON with required fields
- [ ] Loop state updated in `loop-state.json` (includes `mode`, `active_reviewers`, and counts)
- [ ] Feedback aggregated by file (not by agent) for `wb-implementer-escalated`
- [ ] Integration tester ran the actual test suite
- [ ] Unanimous approval from active reviewer set before proceeding to Ship

## Contract Validation

- If any review artifact is malformed (`state.json`, checkpoint window, verdict JSON), route to `blocked` status and request user clarification.
- Iteration 1 uses full mode base set; iterations 2+ use:
  - impacted reviewers from change surface
  - plus `wb-integration-tester` always
  - fallback to base set if routing confidence is low
- Hard gate rule: `wb-integration-tester` must be PASS for all approved states.
- Merge iteration feedback by file and severity before passing to implementer remediation.

## Failure Fallback

- If `loop-state.status` indicates `blocked`, do not auto-continue.
- If `max_iterations` is reached with unresolved failures, surface:
  - unresolved items by file
  - whether overrides are allowed (disabled when integration tester is failing)
