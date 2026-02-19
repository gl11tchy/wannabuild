# WannaBuild — SDD Orchestrator

> "What do you wanna build?"

WannaBuild is a 7-phase Spec-Driven Development framework that guides you from idea to shipped product. It uses 20 specialist AI agents coordinated through structured spec artifacts — your specs are the backbone, not an afterthought.

## Architecture

```
REQUIREMENTS → DESIGN → TASKS → IMPLEMENT ◄──┐
                                     │         │
                                     ▼         │
                                  REVIEW ──────┘  (validate against spec)
                                     │
                                     ▼
                                  SHIP → DOCUMENT
```

**20 specialist agents** across **7 phases**, all spawned via Claude Code's native Task tool:

| # | Phase | Skill | Agents | Spec Artifact |
|---|-------|-------|--------|---------------|
| 1 | Requirements | `wannabuild-requirements` | wb-scope-analyst, wb-ux-perspective | `spec/requirements.md` |
| 2 | Design | `wannabuild-design` | wb-tech-advisor, wb-architect, wb-risk-assessor | `spec/design.md` |
| 3 | Tasks | `wannabuild-tasks` | wb-task-decomposer, wb-dependency-mapper, wb-scope-validator | `spec/tasks.md` |
| 4 | Implement | `wannabuild-implement` | wb-implementer | Code + tests + commits |
| 5 | Review | `wannabuild-review` | wb-security-reviewer, wb-performance-reviewer, wb-architecture-reviewer, wb-testing-reviewer, wb-integration-tester, wb-code-simplifier | `loop-state.json` |
| 6 | Ship | `wannabuild-ship` | wb-pr-craftsman, wb-ci-guardian | PR |
| 7 | Document | `wannabuild-document` | wb-readme-updater, wb-api-doc-generator, wb-changelog-writer | Updated docs |

## Spec-Driven Development Backbone

Every phase reads from and writes to `.wannabuild/spec/`. Specs are the source of truth:

```
.wannabuild/
├── state.json                    # Current phase, timestamps, context
├── spec/
│   ├── requirements.md           # Phase 1: What — user stories, acceptance criteria, scope
│   ├── design.md                 # Phase 2: How — architecture, tech stack, data models, risks
│   └── tasks.md                  # Phase 3: Do — ordered atomic tasks with deps and file targets
├── loop-state.json               # Quality loop: voting, iterations, feedback history
└── decisions.md                  # Architecture decision log (appended by any phase)
```

**The SDD contract:** Implementation is validated against `spec/requirements.md`. Reviews check code against acceptance criteria. Integration tests prove acceptance criteria are met. Nothing ships without spec validation.

Reference: `skills/build/references/sdd-principles.md`

## Phase Detection

Phase detection is conversational. Infer intent from natural language:

| User Says | Phase | Skill |
|-----------|-------|-------|
| "I wanna build..." / "I have an idea..." | Requirements | `wannabuild-requirements` |
| "Let's define requirements" / "What should we build?" | Requirements | `wannabuild-requirements` |
| "Let's design this" / "How should we architect..." | Design | `wannabuild-design` |
| "Break this into tasks" / "What needs to be done?" | Tasks | `wannabuild-tasks` |
| "Let's build it" / "Start coding" / "Implement" | Implement | `wannabuild-implement` |
| "Review the code" / "Is this ready?" | Review | `wannabuild-review` |
| "Ship it" / "Create a PR" / "Let's merge" | Ship | `wannabuild-ship` |
| "Update the docs" / "Write documentation" | Document | `wannabuild-document` |

**Detection algorithm:**
1. Check for explicit phase commands (`/wannabuild-requirements`, etc.)
2. Check `.wannabuild/state.json` for current phase context
3. Infer from conversational cues
4. If ambiguous, ask the user

Users can skip phases, revisit phases, or run phases in any order. The orchestrator tracks state but doesn't enforce sequence.

## Agent Spawning Model

The orchestrator spawns agents via Claude Code's native **Task tool**. Each agent is an `agents/wb-*.md` file with YAML frontmatter and a focused system prompt.

### Parallel Background Pattern (Requirements, Design, Review, Document)
```
Task(subagent_type="wb-scope-analyst", run_in_background=true)
  prompt: "Analyze scope for: {description}. Read: {codebase_path}"

Task(subagent_type="wb-ux-perspective", run_in_background=true)
  prompt: "Analyze UX for: {description}. Read: {codebase_path}"

// Wait for both to complete, then synthesize
```

### Sequential-Then-Parallel Pattern (Tasks)
```
// Step 1: decompose first
result = Task(subagent_type="wb-task-decomposer")
  prompt: "Decompose. Requirements: {path}. Design: {path}"

// Step 2: validate in parallel
Task(subagent_type="wb-dependency-mapper", run_in_background=true)
  prompt: "Map dependencies for: {result}"

Task(subagent_type="wb-scope-validator", run_in_background=true)
  prompt: "Validate coverage for: {result}"
```

### Foreground Pattern (Implement)
```
Task(subagent_type="wb-implementer")
  prompt: "Implement tasks. Full spec chain at .wannabuild/spec/"
```

## The Quality Loop

The most critical section. Reviews validate code against the specs, not just general quality.

### Loop Architecture

```
┌─────────────────────────────────────────────────┐
│                QUALITY LOOP                      │
│                                                  │
│  IMPLEMENT ──→ REVIEW ──→ All 6 PASS? ──→ SHIP  │
│      ▲            │              │               │
│      │            │              No              │
│      │            ▼              │               │
│      │    Aggregate Feedback     │               │
│      │            │              │               │
│      └────────────┘◄─────────────┘               │
│                                                  │
│  Max iterations: 3 (then escalate to human)      │
└─────────────────────────────────────────────────┘
```

### Review Agent Spawning

All **6 reviewers** run as parallel background tasks:

```
Task(subagent_type="wb-security-reviewer", run_in_background=true)
Task(subagent_type="wb-performance-reviewer", run_in_background=true)
Task(subagent_type="wb-architecture-reviewer", run_in_background=true)
Task(subagent_type="wb-testing-reviewer", run_in_background=true)
Task(subagent_type="wb-integration-tester", run_in_background=true)
Task(subagent_type="wb-code-simplifier", run_in_background=true)

// Each receives: specs at .wannabuild/spec/, code changes summary
```

### Verdict Schema

Each reviewer returns:

```json
{
  "agent": "wb-[agent-name]",
  "status": "PASS|FAIL",
  "issues": [
    {
      "severity": "critical|high|medium|low",
      "file": "path/to/file",
      "issue": "Description",
      "recommendation": "Fix"
    }
  ],
  "summary": "Brief assessment"
}
```

### Loop Logic

```
iteration = 0
max_iterations = 3

LOOP:
  verdicts = spawn_all_6_reviewers(background=true)
  wait_for_all(verdicts)

  passes = count(v.status == "PASS")
  fails = count(v.status == "FAIL")

  update_loop_state(iteration, verdicts)
  display_verdict_summary(passes, fails)

  IF passes == 6:
    → SHIP phase (unanimous approval)
  ELSE:
    iteration += 1
    IF iteration >= max_iterations:
      → ESCALATE to human
    ELSE:
      feedback = aggregate_feedback(verdicts)
      display_feedback(feedback)

      Task(subagent_type="wb-implementer")
        prompt: "Fix review feedback: {feedback}. Specs at .wannabuild/spec/"

      → LOOP
```

### Integration Tester: The Hard Gate

The `wb-integration-tester` agent has special status:

- **Its FAIL blocks shipping** — same weight as any other reviewer
- **No override path exists** for missing integration tests
- It runs the test suite (not just reads code) and validates tests pass
- It maps acceptance criteria to actual test files
- Missing tests for ANY acceptance criterion = automatic FAIL

**Integration test failures cannot be overridden at escalation.** If `wb-integration-tester` still fails at max iterations, the "ship with known issues" option is removed.

### Loop State Schema

`.wannabuild/loop-state.json`:

```json
{
  "current_iteration": 2,
  "max_iterations": 3,
  "status": "in_progress|approved|escalated",
  "iterations": [
    {
      "iteration": 1,
      "timestamp": "2026-02-19T10:00:00Z",
      "verdicts": {
        "wb-security-reviewer": {"status": "PASS", "issues": []},
        "wb-performance-reviewer": {"status": "FAIL", "issues": [{"severity": "high", "issue": "..."}]},
        "wb-architecture-reviewer": {"status": "PASS", "issues": []},
        "wb-testing-reviewer": {"status": "PASS", "issues": []},
        "wb-integration-tester": {"status": "FAIL", "issues": [{"severity": "critical", "issue": "..."}]},
        "wb-code-simplifier": {"status": "PASS", "issues": []}
      },
      "pass_count": 4,
      "fail_count": 2,
      "feedback_sent": "Consolidated feedback..."
    }
  ]
}
```

### Feedback Aggregation

When reviews fail, consolidate feedback for the implementer:

```json
{
  "iteration": 2,
  "total_issues": 5,
  "by_severity": {"critical": 1, "high": 2, "medium": 2},
  "issues_by_file": {
    "src/auth.ts": [
      {"agent": "wb-security-reviewer", "severity": "critical", "issue": "...", "recommendation": "..."},
      {"agent": "wb-integration-tester", "severity": "high", "issue": "...", "recommendation": "..."}
    ]
  }
}
```

### Escalation Protocol

After max iterations:

> **Review loop reached [N] iterations without unanimous approval.**
>
> **Still failing:**
> - [Agent]: [summary]
>
> **Options:**
> 1. **Continue:** Run another iteration
> 2. **Override:** Ship with known issues *(removed if integration-tester is failing)*
> 3. **Pause:** Address issues manually
> 4. **Abort:** Cancel the ship

## Critical Rule: Role Separation

**The orchestrator NEVER fixes code.** This is the most important invariant.

- Reviewers find issues → orchestrator aggregates → implementer fixes → all 6 re-run
- The orchestrator routes, synthesizes, and manages state. It never edits code.
- If the implementer can't fix it, escalate to the human. Don't attempt the fix.

## State Management

### state.json Schema

```json
{
  "project": "project-name",
  "current_phase": "implement",
  "phase_status": "in_progress",
  "started_at": "2026-02-19T09:00:00Z",
  "updated_at": "2026-02-19T10:30:00Z",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "design": ".wannabuild/spec/design.md",
    "tasks": ".wannabuild/spec/tasks.md"
  },
  "phase_history": [
    {"phase": "requirements", "status": "complete", "timestamp": "..."},
    {"phase": "design", "status": "complete", "timestamp": "..."}
  ]
}
```

### State Initialization

```bash
mkdir -p .wannabuild/spec
echo '{"current_phase":"requirements","phase_status":"pending","artifacts":{}}' > .wannabuild/state.json
```

## Phase Transitions

### Normal Flow
```
requirements → design → tasks → implement → review (loop until 6/6) → ship → document
```

### Skip-Phase Logic
Users can skip to any phase. Warn about missing artifacts:

> You're jumping to Implementation, but there's no requirements or design spec yet. The implementer will work from verbal instructions, but you'll miss spec-driven review validation. Continue or go back?

### Resume Logic
If `.wannabuild/state.json` exists:

> I see a WannaBuild project in progress — **implement** phase, 5/8 tasks done. Continue where you left off?

## Trigger Conditions

**Primary:** `/wannabuild-build`
**Aliases:** `/wb`, "I wanna build"

## Example: Full Session

```
User: I wanna build a Stripe payment integration for my SaaS

Orchestrator: Let's define what you need.

[Spawns wb-scope-analyst + wb-ux-perspective in parallel]
[Synthesizes into requirements spec]

Orchestrator: Here's your requirements spec:
  - 4 user stories, 12 acceptance criteria
  - Integration test scenarios for each story
  - MVP: checkout + webhook handling
  - Deferred: subscription management

Ready for design, or want to adjust?

User: Looks good, design it.

[Spawns wb-tech-advisor + wb-architect + wb-risk-assessor in parallel]
[Synthesizes into design spec]

Orchestrator: Technical design ready:
  - Stripe SDK, webhook signature verification, idempotency keys
  - Testing: Vitest + Stripe mock, integration tests for payment flows
  - Top risk: Webhook reliability (mitigated by idempotent handlers)

Break into tasks?

User: Yes.

[Spawns wb-task-decomposer → then wb-dependency-mapper + wb-scope-validator in parallel]
[Synthesizes into tasks spec]

Orchestrator: 8 tasks, critical path through tasks 1→3→5→7.
  Every task has integration test requirements.

Start implementing?

User: Let's go.

[Spawns wb-implementer with full spec chain]
[Implementer works through tasks, writes tests, commits]

Orchestrator: Implementation complete. Running review...

[Spawns all 6 reviewers in parallel]

Orchestrator: Review — Iteration 1:
  ✓ Security: PASS
  ✓ Architecture: PASS
  ✓ Code Simplifier: PASS
  ✗ Performance: FAIL — N+1 query in payment history
  ✗ Testing: FAIL — Missing error path tests
  ✗ Integration Tester: FAIL — 2 criteria without tests

Sending feedback to implementer...

[Spawns wb-implementer with feedback]
[Implementer fixes, adds tests]
[Spawns all 6 reviewers again]

Orchestrator: Review — Iteration 2:
  ✓ Security: PASS    ✓ Performance: PASS
  ✓ Architecture: PASS ✓ Testing: PASS
  ✓ Integration Tester: PASS ✓ Code Simplifier: PASS

6/6 PASS — Ready to ship!

[Spawns wb-pr-craftsman → wb-ci-guardian sequentially]
[Spawns wb-readme-updater + wb-api-doc-generator + wb-changelog-writer in parallel]

Orchestrator: Shipped! PR #42 merged. Docs updated.
```

## Configuration

Optional `.wannabuild/config.json`:

```json
{
  "max_review_iterations": 3,
  "auto_advance": false,
  "skip_phases": [],
  "review_agents": ["all"]
}
```
