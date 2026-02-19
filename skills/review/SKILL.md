# WannaBuild: Review Phase (Elite Code Review)

> "Does the code match the spec?"

Phase 5 of 7 in the WannaBuild SDD pipeline. Six specialist reviewers validate the implementation against the spec artifacts. All 6 must PASS for code to ship. The integration tester is a hard gate — no override for missing tests.

## Agents

| Agent | File | Role | Hard Gate? |
|-------|------|------|------------|
| Security Reviewer | `wb-security-reviewer` | OWASP, secrets, auth vulnerabilities | No |
| Performance Reviewer | `wb-performance-reviewer` | N+1 queries, memory, scalability | No |
| Architecture Reviewer | `wb-architecture-reviewer` | Design compliance, separation of concerns | No |
| Testing Reviewer | `wb-testing-reviewer` | Test quality, coverage, antipatterns | No |
| Integration Tester | `wb-integration-tester` | Acceptance criteria → test mapping, runs tests | **YES** |
| Code Simplifier | `wb-code-simplifier` | Over-engineering, dead code, DRY | No |

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
    "commits": ["abc1234", "def5678"]
  }
}
```

## Execution Flow

```
Code changes + spec artifacts (input)
        │
        ▼
┌──────────────────────────────────────────────────────────────┐
│  All 6 Reviewers in Parallel (background)                    │
│                                                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                    │
│  │ Security │ │  Perf    │ │  Arch    │                    │
│  │ Reviewer │ │ Reviewer │ │ Reviewer │                    │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘                    │
│       │             │            │                           │
│  ┌────┴─────┐ ┌─────┴────┐ ┌────┴─────┐                    │
│  │ Testing  │ │Integ.    │ │  Code    │                    │
│  │ Reviewer │ │ Tester   │ │Simplifier│                    │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘                    │
│       │             │            │                           │
└───────┼─────────────┼────────────┼───────────────────────────┘
        │             │            │
        ▼             ▼            ▼
  ┌──────────────────────────────────────┐
  │  Orchestrator: Collect 6 Verdicts    │
  │  Update loop-state.json              │
  │  6/6 PASS? → Ship                   │
  │  Any FAIL? → Feedback → Implement   │
  └──────────────────────────────────────┘
```

## Agent Spawning

All 6 reviewers spawn as parallel background tasks:

```
Task(subagent_type="wb-security-reviewer", run_in_background=true)
  prompt: "Review code for security. Specs at .wannabuild/spec/. [diff summary]"

Task(subagent_type="wb-performance-reviewer", run_in_background=true)
  prompt: "Review code for performance. Specs at .wannabuild/spec/. [diff summary]"

Task(subagent_type="wb-architecture-reviewer", run_in_background=true)
  prompt: "Review architecture compliance. Specs at .wannabuild/spec/. [diff summary]"

Task(subagent_type="wb-testing-reviewer", run_in_background=true)
  prompt: "Review test quality. Specs at .wannabuild/spec/. [diff summary]"

Task(subagent_type="wb-integration-tester", run_in_background=true)
  prompt: "Validate integration tests against acceptance criteria. Specs at .wannabuild/spec/. [diff summary]"

Task(subagent_type="wb-code-simplifier", run_in_background=true)
  prompt: "Review code complexity. Specs at .wannabuild/spec/. [diff summary]"
```

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

After all 6 complete, display:

```
Review Results — Iteration [N]:
  ✓ Security: PASS
  ✓ Performance: PASS
  ✗ Architecture: FAIL — [summary]
  ✓ Testing: PASS
  ✗ Integration Tester: FAIL — [summary]
  ✓ Code Simplifier: PASS

  [4/6 PASS] — Sending feedback to implementer...
```

Or on success:

```
Review Results — Iteration [N]:
  ✓ Security: PASS     ✓ Performance: PASS
  ✓ Architecture: PASS ✓ Testing: PASS
  ✓ Integration Tester: PASS ✓ Code Simplifier: PASS

  [6/6 PASS] — Unanimous approval! Ready to ship.
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

When any reviewer fails, aggregate feedback:

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

This is sent to the implementer for fixes. Then ALL 6 reviewers re-run (not just the ones that failed).

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
    "all_agents_passed": true
  }
}
```

## Standalone Usage

Elite Code Review can also run standalone (outside the WannaBuild pipeline):

```
User: /wannabuild-review

Orchestrator: I'll review the recent changes with 6 specialists...
[Spawns all 6 reviewers against the current diff or specified files]
[Reports verdicts]
```

When running standalone without spec artifacts, reviewers use general best practices instead of spec validation. The integration tester checks for test existence rather than spec coverage mapping.

## Quality Checklist

- [ ] All 6 reviewers spawned and returned verdicts
- [ ] Verdicts are valid JSON with required fields
- [ ] Loop state updated in `loop-state.json`
- [ ] Feedback aggregated by file (not by agent) for implementer
- [ ] Integration tester ran the actual test suite
- [ ] Unanimous approval before proceeding to Ship
