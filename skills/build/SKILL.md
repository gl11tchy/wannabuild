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

**20 specialist agents** across **7 phases**, all spawned via Claude Code's native Task tool.

### Full Mode

| # | Phase | Skill | Agents | Spec Artifact |
|---|-------|-------|--------|---------------|
| 1 | Requirements | `wannabuild-requirements` | wb-scope-analyst, wb-ux-perspective | `spec/requirements.md` |
| 2 | Design | `wannabuild-design` | wb-tech-advisor, wb-architect, wb-risk-assessor | `spec/design.md` |
| 3 | Tasks | `wannabuild-tasks` | wb-task-decomposer, wb-dependency-mapper, wb-scope-validator | `spec/tasks.md` |
| 4 | Implement | `wannabuild-implement` | wb-implementer | Code + tests + commits |
| 5 | Review | `wannabuild-review` | wb-security-reviewer, wb-performance-reviewer, wb-architecture-reviewer, wb-testing-reviewer, wb-integration-tester, wb-code-simplifier | `loop-state.json` |
| 6 | Ship | `wannabuild-ship` | wb-pr-craftsman, wb-ci-guardian | PR |
| 7 | Document | `wannabuild-document` | wb-readme-updater, wb-api-doc-generator, wb-changelog-writer | Updated docs |

### Light Mode

| # | Phase | Skill | Agents | Spec Artifact |
|---|-------|-------|--------|---------------|
| 1 | Requirements | `wannabuild-requirements` | wb-scope-analyst, wb-ux-perspective | `spec/requirements.md` |
| 2 | Design | — | **skipped** | — |
| 3 | Tasks | `wannabuild-tasks` | wb-task-decomposer, wb-scope-validator | `spec/tasks.md` |
| 4 | Implement | `wannabuild-implement` | wb-implementer | Code + tests + commits |
| 5 | Review | `wannabuild-review` | wb-security-reviewer, wb-architecture-reviewer, wb-integration-tester | `loop-state.json` |
| 6 | Ship | `wannabuild-ship` | wb-pr-craftsman, wb-ci-guardian | PR |
| 7 | Document | `wannabuild-document` | wb-changelog-writer | Updated docs |

## Mode Selection

Before any phase routing, ask the user which mode they want. This fires **once** at session start — on resume, the stored mode is used silently.

> **Which mode?**
> - **Full** — All 7 phases including design. Best for new products, new codebases, or features that require architectural decisions.
> - **Light** — Skips design. Requirements → Tasks → Implement → Review → Ship → Document. Best for everyday features and fixes on an existing codebase where the architecture is already known.

Both modes run the same SDD backbone with the same spec artifacts, the same integration tester hard gate, and the same ship phase. Light mode skips design entirely and runs a leaner review (3 reviewers instead of 6). Use Full any time you're making significant architectural decisions — Light assumes you already know how you're building it.

**Persistence:** Write the chosen mode to `state.json` **before spawning any phase agent**. On resume, if `state.json` already has a valid `mode` key (`"full"` or `"light"`), use it silently — do not re-ask. If the value is absent, unrecognized, or unparseable (corrupt state), ask the mode question again and warn the user; then default to `"full"` if the response is still ambiguous. Legacy `state.json` files without a `mode` key default to `"full"` silently.

## Spec-Driven Development Backbone

Every phase reads from and writes to `.wannabuild/spec/`. Specs are the source of truth:

```
.wannabuild/
├── state.json                    # Current phase, timestamps, context
├── spec/
│   ├── requirements.md           # Phase 1: What — user stories, acceptance criteria, scope
│   ├── design.md                 # Phase 2: How — architecture, tech stack, data models, risks
│   └── tasks.md                  # Phase 3: Do — ordered atomic tasks with deps and file targets
├── outputs/                      # Full agent outputs (file-first pattern — keeps main context lean)
│   ├── scope-analyst.md          # Requirements agents
│   ├── ux-perspective.md
│   ├── architect.md              # Design agents
│   ├── tech-advisor.md
│   ├── risk-assessor.md
│   ├── task-decomposer.md        # Tasks agents
│   ├── dependency-mapper.md
│   ├── scope-validator.md
│   ├── pr-craftsman.md           # Ship agents
│   ├── ci-guardian.md
│   ├── readme-updater.md         # Document agents
│   ├── api-doc-generator.md
│   └── changelog-writer.md
├── review/                       # Reviewer verdicts — one file per agent per iteration
│   ├── security-iter-1.json
│   ├── performance-iter-1.json
│   └── ...
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
1. Resolve mode — see Mode Selection section. Mode is determined and persisted before any phase routing.
2. Check for explicit phase commands (`/wannabuild-requirements`, etc.)
3. Check `.wannabuild/state.json` for current phase context
4. Infer from conversational cues
5. If ambiguous, ask the user

Users can skip phases, revisit phases, or run phases in any order. The orchestrator tracks state but doesn't enforce sequence.

## Agent Spawning Model

The orchestrator spawns agents via Claude Code's native **Task tool**. Each agent is an `agents/wb-*.md` file with YAML frontmatter and a focused system prompt.

### File-First Output Pattern

All agents write their full analysis to `.wannabuild/outputs/` (or `.wannabuild/review/` for reviewers), then return only a one-line status to the main conversation. The orchestrator reads files for synthesis instead of reading message content. This keeps the main thread to ~1 line per agent completion instead of ~500 words.

**Output layout:**
```
.wannabuild/
  outputs/
    scope-analyst.md, ux-perspective.md
    architect.md, tech-advisor.md, risk-assessor.md
    task-decomposer.md, dependency-mapper.md, scope-validator.md
    implementer-summary.md
    pr-craftsman.md, ci-guardian.md
    readme-updater.md, api-doc-generator.md, changelog-writer.md
  review/
    security-iter-1.json, performance-iter-1.json, ...  (one file per agent per iteration)
```

**Compact return formats:**
- Analysis agents: `COMPLETE — [one sentence]. Report at .wannabuild/outputs/[agent].md`
- Reviewer agents: `VERDICT: PASS — no issues found. Details at .wannabuild/review/[agent]-iter-{N}.json`
                or `VERDICT: FAIL — [M] issues ([X] critical). Details at .wannabuild/review/[agent]-iter-{N}.json`

### Parallel Background Pattern (Requirements, Design, Review, Document)

**Requirements (both modes — identical):**
```
Task(subagent_type="wb-scope-analyst", run_in_background=true)
  prompt: "Analyze scope for: {description}. Read: {codebase_path}.
           Write full analysis to .wannabuild/outputs/scope-analyst.md.
           Return ONLY: 'COMPLETE — [one sentence]. Report at .wannabuild/outputs/scope-analyst.md'"

Task(subagent_type="wb-ux-perspective", run_in_background=true)
  prompt: "Analyze UX for: {description}. Read: {codebase_path}.
           Write full analysis to .wannabuild/outputs/ux-perspective.md.
           Return ONLY: 'COMPLETE — [one sentence]. Report at .wannabuild/outputs/ux-perspective.md'"

// Wait for both to complete, then read .wannabuild/outputs/ files and synthesize
```

**Full mode — Design:**
```
Task(subagent_type="wb-architect", run_in_background=true)
  // Write to .wannabuild/outputs/architect.md. Return one-liner.
Task(subagent_type="wb-tech-advisor", run_in_background=true)
  // Write to .wannabuild/outputs/tech-advisor.md. Return one-liner.
Task(subagent_type="wb-risk-assessor", run_in_background=true)
  // Write to .wannabuild/outputs/risk-assessor.md. Return one-liner.
// Wait for all three, read output files, then synthesize
```

**Light mode — Design: skipped.** Proceed directly from requirements to tasks. No design.md is written.

### Sequential-Then-Parallel Pattern (Tasks)

**Full mode:**
```
// Step 1: decompose first (writes to .wannabuild/outputs/task-decomposer.md)
Task(subagent_type="wb-task-decomposer")
  prompt: "Decompose. Requirements: {path}. Design: {path}.
           Write full task list to .wannabuild/outputs/task-decomposer.md.
           Return ONLY: 'COMPLETE — [N] tasks decomposed. Report at .wannabuild/outputs/task-decomposer.md'"

// Step 2: read output file, pass path to validators in parallel
Task(subagent_type="wb-dependency-mapper", run_in_background=true)
  prompt: "Map dependencies for tasks at .wannabuild/outputs/task-decomposer.md.
           Write to .wannabuild/outputs/dependency-mapper.md. Return one-liner."

Task(subagent_type="wb-scope-validator", run_in_background=true)
  prompt: "Validate coverage. Requirements: {path}. Tasks at .wannabuild/outputs/task-decomposer.md.
           Write to .wannabuild/outputs/scope-validator.md. Return one-liner."
```

**Light mode:**
```
// Step 1: decompose from requirements only (no design.md — work within existing codebase patterns)
Task(subagent_type="wb-task-decomposer")
  prompt: "Decompose. Requirements: {path}. No design spec — infer from existing codebase: {codebase_path}.
           Write full task list to .wannabuild/outputs/task-decomposer.md.
           Return ONLY: 'COMPLETE — [N] tasks decomposed. Report at .wannabuild/outputs/task-decomposer.md'"

// Step 2: validate scope (no dependency-mapper; single agent runs in background)
Task(subagent_type="wb-scope-validator", run_in_background=true)
  prompt: "Validate coverage. Requirements: {path}. Tasks at .wannabuild/outputs/task-decomposer.md.
           Write to .wannabuild/outputs/scope-validator.md. Return one-liner."
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
┌──────────────────────────────────────────────────────────────┐
│                      QUALITY LOOP                            │
│                                                              │
│  IMPLEMENT ──→ REVIEW ──→ All reviewers PASS? ──→ SHIP       │
│      ▲            │                    │                     │
│      │            │                    No                    │
│      │            ▼                    │                     │
│      │    Aggregate Feedback           │                     │
│      │            │                    │                     │
│      └────────────┘◄────────────────────┘                    │
│                                                              │
│  Full mode: 6 reviewers, unanimous = 6/6                     │
│  Light mode: 3 reviewers, unanimous = 3/3                    │
│  Max iterations: 3 (then escalate to human)                  │
└──────────────────────────────────────────────────────────────┘
```

### Review Agent Spawning

**Full mode — all 6 reviewers** run as parallel background tasks. Each writes full JSON verdict to `.wannabuild/review/[agent]-iter-{N}.json` and returns a one-line verdict summary:

```
Task(subagent_type="wb-security-reviewer", run_in_background=true)
  // Write to .wannabuild/review/security-iter-{N}.json. Return: 'VERDICT: PASS|FAIL — ...'
Task(subagent_type="wb-performance-reviewer", run_in_background=true)
  // Write to .wannabuild/review/performance-iter-{N}.json. Return: 'VERDICT: PASS|FAIL — ...'
Task(subagent_type="wb-architecture-reviewer", run_in_background=true)
  // Write to .wannabuild/review/architecture-iter-{N}.json. Return: 'VERDICT: PASS|FAIL — ...'
Task(subagent_type="wb-testing-reviewer", run_in_background=true)
  // Write to .wannabuild/review/testing-iter-{N}.json. Return: 'VERDICT: PASS|FAIL — ...'
Task(subagent_type="wb-integration-tester", run_in_background=true)
  // Write to .wannabuild/review/integration-tester-iter-{N}.json. Return: 'VERDICT: PASS|FAIL — ...'
Task(subagent_type="wb-code-simplifier", run_in_background=true)
  // Write to .wannabuild/review/code-simplifier-iter-{N}.json. Return: 'VERDICT: PASS|FAIL — ...'

// Each receives: specs at .wannabuild/spec/, code changes summary
```

**Light mode — 3 reviewers** run as parallel background tasks. Same file-first pattern:

```
Task(subagent_type="wb-security-reviewer", run_in_background=true)
  // Write to .wannabuild/review/security-iter-{N}.json. Return: 'VERDICT: PASS|FAIL — ...'
Task(subagent_type="wb-architecture-reviewer", run_in_background=true)
  // Write to .wannabuild/review/architecture-iter-{N}.json. Return: 'VERDICT: PASS|FAIL — ...'
Task(subagent_type="wb-integration-tester", run_in_background=true)
  // Write to .wannabuild/review/integration-tester-iter-{N}.json. Return: 'VERDICT: PASS|FAIL — ...'

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
reviewer_count = (mode == "full") ? 6 : 3

LOOP:
  spawn_reviewers(mode, background=true)
  // Each reviewer writes to .wannabuild/review/[agent]-iter-{iteration}.json
  // and returns a one-line verdict to the main conversation
  wait_for_all_one_liners()

  // Read verdict files to get full detail
  verdicts = read_all_verdict_files(iteration)
  passes = count(v.status == "PASS")
  fails = count(v.status == "FAIL")

  update_loop_state(iteration, verdicts)
  display_verdict_summary(passes, fails)

  IF passes == reviewer_count:
    → SHIP phase (unanimous approval)
  ELSE:
    iteration += 1
    IF iteration >= max_iterations:
      → ESCALATE to human
    ELSE:
      // Read failing agents' detail files to build consolidated feedback
      feedback = aggregate_feedback_from_files(verdicts, iteration)
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
  "mode": "full",           // "full" (6 reviewers) or "light" (3 reviewers)
  "current_iteration": 2,
  "max_iterations": 3,
  "reviewer_count": 6,      // 6 for full, 3 for light
  "status": "in_progress|approved|escalated",
  "iterations": [
    {
      "iteration": 1,
      "timestamp": "2026-02-19T10:00:00Z",
      "verdicts": {
        // Full mode: all 6 keys present
        // Light mode: wb-security-reviewer, wb-architecture-reviewer, wb-integration-tester
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

- Reviewers find issues → orchestrator aggregates → implementer fixes → all reviewers re-run
- The orchestrator routes, synthesizes, and manages state. It never edits code.
- If the implementer can't fix it, escalate to the human. Don't attempt the fix.

## State Management

### state.json Schema

```json
{
  "project": "project-name",
  "mode": "full",
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

The `mode` field is `"full"` or `"light"`. It is written immediately after the user answers the mode question — not at initialization. If absent or unrecognized (legacy or corrupt state), default to `"full"`.

### State Update Rule

All phase state updates **merge into existing state.json** — they never replace it wholesale. This preserves the `mode` key (and any other existing keys) across every phase transition. Each phase's SKILL.md shows only the fields it writes; all other fields are left untouched.

### State Initialization

```bash
mkdir -p .wannabuild/spec .wannabuild/outputs .wannabuild/review
echo '{"current_phase":"requirements","phase_status":"pending","artifacts":{}}' > .wannabuild/state.json
# mode is written immediately after the user answers the mode question, before any phase agent is spawned
```

## Phase Transitions

### Normal Flow
```
requirements → design → tasks → implement → review (loop until all pass) → ship → document
```

### Skip-Phase Logic
Users can skip to any phase. Warn about missing artifacts:

> You're jumping to Implementation, but there's no requirements or design spec yet. The implementer will work from verbal instructions, but you'll miss spec-driven review validation. Continue or go back?

### Resume Logic
If `.wannabuild/state.json` exists, read the stored `mode` and skip the mode question. Resume banner example:

> I see a WannaBuild project in progress — **Light mode**, **implement** phase, 5/8 tasks done. Continue where you left off?

## Trigger Conditions

**Primary:** `/wannabuild-build`
**Aliases:** `/wb`, "I wanna build"

## Example: Full Session

```
User: I wanna build a Stripe payment integration for my SaaS

Orchestrator: Which mode?
  - Full — All agents, full quality loop. For new products or complex features.
  - Light — Same phases, fewer agents, faster. For everyday features and fixes.

User: Full

Orchestrator: Let's define what you need.

[Spawns wb-scope-analyst + wb-ux-perspective in parallel — each writes to .wannabuild/outputs/]
[Agents return: "COMPLETE — ... Report at .wannabuild/outputs/scope-analyst.md"]
[Orchestrator reads output files, synthesizes into requirements spec]

Orchestrator: Here's your requirements spec:
  - 4 user stories, 12 acceptance criteria
  - Integration test scenarios for each story
  - MVP: checkout + webhook handling
  - Deferred: subscription management

Ready for design, or want to adjust?

User: Looks good, design it.

[Spawns wb-tech-advisor + wb-architect + wb-risk-assessor in parallel — each writes to .wannabuild/outputs/]
[Agents return one-liners. Orchestrator reads output files, synthesizes into design spec]

Orchestrator: Technical design ready:
  - Stripe SDK, webhook signature verification, idempotency keys
  - Testing: Vitest + Stripe mock, integration tests for payment flows
  - Top risk: Webhook reliability (mitigated by idempotent handlers)

Break into tasks?

User: Yes.

[Spawns wb-task-decomposer (foreground) — writes to .wannabuild/outputs/task-decomposer.md]
[Spawns wb-dependency-mapper + wb-scope-validator in parallel — each writes to .wannabuild/outputs/]
[Orchestrator reads output files, synthesizes into tasks spec]

Orchestrator: 8 tasks, critical path through tasks 1→3→5→7.
  Every task has integration test requirements.

Start implementing?

User: Let's go.

[Spawns wb-implementer with full spec chain]
[Implementer works through tasks, writes tests, commits]

Orchestrator: Implementation complete. Running review...

[Spawns all 6 reviewers in parallel — each writes to .wannabuild/review/[agent]-iter-1.json]
[Agents return one-line verdicts. Orchestrator reads review files for detail.]

Orchestrator: Review — Iteration 1:
  ✓ Security: PASS
  ✓ Architecture: PASS
  ✓ Code Simplifier: PASS
  ✗ Performance: FAIL — N+1 query in payment history
  ✗ Testing: FAIL — Missing error path tests
  ✗ Integration Tester: FAIL — 2 criteria without tests

Sending feedback to implementer...

[Orchestrator reads failing agents' .wannabuild/review/ files, aggregates feedback]
[Spawns wb-implementer with consolidated feedback]
[Implementer fixes, adds tests]
[Spawns all 6 reviewers again — writes to [agent]-iter-2.json]

Orchestrator: Review — Iteration 2:
  ✓ Security: PASS    ✓ Performance: PASS
  ✓ Architecture: PASS ✓ Testing: PASS
  ✓ Integration Tester: PASS ✓ Code Simplifier: PASS

6/6 PASS — Ready to ship!

[Spawns wb-pr-craftsman → wb-ci-guardian sequentially — each writes to .wannabuild/outputs/]
[Spawns wb-readme-updater + wb-api-doc-generator + wb-changelog-writer in parallel — each writes to .wannabuild/outputs/]

Orchestrator: Shipped! PR #42 merged. Docs updated.
```

## Configuration

Optional `.wannabuild/config.json`:

```json
{
  "max_review_iterations": 3,
  "auto_advance": false,
  "skip_phases": []
}
```
