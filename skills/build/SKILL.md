# WannaBuild — SDD Orchestrator

> "What do you wanna build?"

WannaBuild is a spec-driven orchestration framework that guides work from idea to verified outcome using a compact public workflow backed by structured artifacts and specialist prompts.

## Public Workflow Model

The intended user-facing flow is:

1. Discover
2. Control mode gate
3. Research gate
4. Plan
5. Implement gate
6. Review
7. QA
8. Summary

Internally, the orchestrator uses finer-grained phases and artifacts to keep the workflow rigorous. Those phases are execution detail; the external experience should stay compact.

## Workflow Start Indicator

WannaBuild must emit deterministic start banners before doing any phase work.

### New session start

Use **exactly** this line for fresh starts:

`[WB-START] WannaBuild STARTED | intent=build | mode=standard`

If the user gave any explicit intent (`build`, `requirements`, `tasks`, `implement`, etc.), include it in `intent=<...>`.

### Resume start

If `.wannabuild/state.json` exists and is recoverable, use this exact line:

`[WB-RESUME] WannaBuild RESUME | mode=standard | phase=<current_phase> | progress=<done>/<total>`

Examples:
- `[WB-START] WannaBuild STARTED | intent=build | mode=standard`
- `[WB-RESUME] WannaBuild RESUME | mode=standard | phase=implement | progress=5/8`

For fresh build intent (`I wanna build`, `build ...`), start discovery immediately.

### Start/Gate De-duplication Rule

To avoid repeated user-facing messages:

- Emit `[WB-START]` or `[WB-RESUME]` once per turn, never twice back-to-back.
- If the latest assistant message already equals the intended banner or gate question and the user has not answered yet, do not send it again.
- For guided gates, ask once per unresolved stage; wait for user input before repeating.
- If a reminder is needed, paraphrase rather than sending an identical line.

## Architecture

Internal phase graph:

```
REQUIREMENTS → DESIGN → TASKS → IMPLEMENT ◄──┐
                                     │         │
                                     ▼         │
                                  REVIEW ──────┘  (validate against spec)
                                     │
                                     ▼
                                  SHIP → DOCUMENT
```

**21 core specialist agents** across **7 internal phases**, used behind the condensed workflow model.

## Public-to-Internal Mapping

| Public Step | Internal Execution Surfaces |
|---|---|
| Discover | Requirements |
| Control mode gate | Guided or autonomous preference |
| Research gate | Optional research burst using specialist agents |
| Plan | Design + Tasks |
| Implement gate | Single agent or parallel implementation choice |
| Implement | Implement |
| Review | Review |
| QA | Integration gate + final verification |
| Summary | Ship/Document/handoff synthesis |

### Standard Internal Flow

| # | Phase | Skill | Agents | Spec Artifact |
|---|-------|-------|--------|---------------|
| 1 | Requirements | `wannabuild-requirements` | wb-scope-analyst, wb-ux-perspective | `spec/requirements.md` |
| 2 | Design | `wannabuild-design` | wb-tech-advisor, wb-architect, wb-risk-assessor | `spec/design.md` |
| 3 | Tasks | `wannabuild-tasks` | wb-task-decomposer, wb-dependency-mapper, wb-scope-validator | `spec/tasks.md` |
| 4 | Implement | `wannabuild-implement` | wb-implementer, wb-implementer-escalated | Code + tests + checkpoints |
| 5 | Review | `wannabuild-review` | wb-security-reviewer, wb-performance-reviewer, wb-architecture-reviewer, wb-testing-reviewer, wb-integration-tester, wb-code-simplifier | `loop-state.json` |
| 6 | Ship | `wannabuild-ship` | wb-pr-craftsman, wb-ci-guardian | PR |
| 7 | Document | `wannabuild-document` | wb-readme-updater, wb-api-doc-generator, wb-changelog-writer | Updated docs |

## Single Workflow Mode

WannaBuild now runs one standard workflow mode at the top level.

- do not ask the user to choose Full, Light, or Spark
- start with the standard start banner
- proceed into Discover immediately

For compatibility with older internal phase files, hidden state may still persist `mode: "full"`. That compatibility field is not a user-facing concept anymore.

## Control Mode Gate

After Discover, ask exactly once:

1. Continue in guided mode
2. Switch to autonomous mode

Guided mode:

- ask for user preference at each later gate
- do not advance silently

Autonomous mode:

- continue adaptively through later gates without asking every time
- still stop for destructive actions, real blockers, or ambiguity that changes scope materially

Persist the choice as `control_mode` in `.wannabuild/state.json`.

## Adaptive Research Gate

After discovery, decide whether more investigation would materially improve planning quality.

When research is warranted, ask the user:

1. Kick off research agents
2. Move to planning

Use the research gate when one or more of these are true:

- architecture direction remains unclear
- a package, framework, or external dependency decision matters
- codebase reconnaissance is incomplete
- domain, API, auth, billing, or infra uncertainty is still high
- parallel investigation would reduce planning risk

If the user chooses research:

- run a bounded research burst using existing specialists
- default set:
  - `wb-tech-advisor`
  - `wb-architect`
  - `wb-risk-assessor`
- optional additions:
  - `wb-scope-analyst`
  - `wb-ux-perspective`
- synthesize findings into `.wannabuild/outputs/research-summary.md`
- then proceed to planning

If the user chooses planning:

- move directly to Design + Tasks

## Implementation Gate

After planning is complete and the approach is verified, ask the user:

1. Implement in single agent mode
2. Implement with parallel agents

Default to single agent mode unless the work splits cleanly.

## Model Tiering Defaults

Quality stays non-negotiable, but model spend is differentiated by role:

- **Spec phases run on Opus** (`wb-scope-analyst`, `wb-ux-perspective`, `wb-tech-advisor`, `wb-architect`, `wb-risk-assessor`, `wb-task-decomposer`, `wb-dependency-mapper`, `wb-scope-validator`) to maximize spec quality.
- **Default implementation:** `wb-implementer`
- **Escalated implementation:** `wb-implementer-escalated`
- **Hard gate remains unchanged:** integration testing still blocks ship on FAIL.

Escalation rules:
1. If complexity is flagged high up front, use `wb-implementer-escalated` immediately.
2. If review iteration 1 fails, all remediation iterations use `wb-implementer-escalated`.

## Advisor Escalation

WannaBuild supports executor-led, advisor-assisted execution. The active executor owns the task end-to-end, including tool use, implementation, validation, and handoff. For high-impact or uncertain decisions, the executor may consult a higher-capability advisor for bounded guidance.

The advisor may provide a plan, correction, risk assessment, or stop signal, but must not call tools, edit files, run commands, or produce user-facing output. Advisor use must be selective, capped, and grounded in the current spec and repository context.

Use advisor escalation for architecture decisions, material ambiguity, high-risk integrations, uncertain review remediation, conflicting specialist outputs, suspected wrong execution paths, or test strategy uncertainty. Do not use it for routine implementation details, one-line fixes, style-only questions, or generic double checks.

Default guardrails:
- `advisor_escalation`: enabled unless explicitly disabled
- `advisor_max_uses_per_phase`: 3
- `advisor_context_scope`: `spec_plus_targeted_repo_summary`
- `advisor_record_decisions`: true
- `advisor_on_limit`: `pause-and-ask`

If advisor use exceeds the configured phase limit, pause and ask the user before continuing. Record advisor-influenced decisions in `.wannabuild/decisions.md` when they affect scope, architecture, implementation strategy, or validation. Host adapters may implement this with native model/tool support, but the core contract remains model-agnostic.

Advisor escalation is a stateful workflow primitive, not only a prompt suggestion. When escalation criteria match before high-risk design, high-risk implementation, uncertain review remediation, or max-iteration-adjacent review decisions, the orchestrator must check the phase budget, invoke the best available host advisor mechanism, save `.wannabuild/outputs/advisor/<phase>-escalation-<N>.md`, merge-update `state.json.advisor`, and then resume the executor. In Factory/Droid, prefer the project droid `wb-advisor`; in Claude Platform API contexts, a host adapter may use `advisor_20260301`.

## Adaptive Review Defaults

Quality gates stay strict, but retry behavior is adaptive by default:

- **Iteration 1 review:** run the base reviewer set.
- **Iteration 2+ review:** run only impacted reviewers **plus `wb-integration-tester` (always)**.
- **Fallback safety:** if impact scope is ambiguous, rerun the full reviewer set.
- **Context slicing:** pass only changed-file summaries + relevant spec excerpts (not full artifacts) to non-integration reviewers.
- **Guardrail behavior:** when configured limits are hit, pause and ask the user whether to continue instead of silently fanning out.

## Parallelization Policy

Parallelism is selective, not a default aesthetic.

- **Keep sequential by default** for Discover, Plan, QA, and Summary.
- **Use parallelism** for:
  - internal discovery analysis when multiple bounded perspectives materially help
  - implementation only when workstreams are truly disjoint
  - review hats that can inspect the same finished work independently
- **Do not parallelize** merely because multiple agents exist. Coherence beats fan-out.
- **If uncertain, stay single-owner** until the work naturally splits.

## Artifact Backbone

Internal phases read from and write to `.wannabuild/spec/`. Specs remain the source of truth:

```
.wannabuild/
├── state.json                    # Current phase, timestamps, context
├── spec/
│   ├── requirements.md           # Phase 1: What — user stories, acceptance criteria, scope
│   ├── design.md                 # Phase 2: How — architecture, tech stack, data models, risks
│   └── tasks.md                  # Phase 3: Do — ordered atomic tasks with deps and file targets
├── outputs/                      # Agent outputs (file-first pattern — keeps main context lean)
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
├── checkpoints/                  # Micro-step evidence for implement/resume/review routing
│   ├── task-1-step-1.md
│   └── ...
├── review/                       # Reviewer verdicts — one file per agent per iteration
│   ├── security-iter-1.json
│   ├── performance-iter-1.json
│   └── ...
├── loop-state.json               # Quality loop: voting, iterations, feedback history
└── decisions.md                  # Architecture decision log (appended by any phase)
```

**Core contract:** implementation is validated against `spec/requirements.md`; reviews check code against acceptance criteria; integration tests prove those criteria are met.

Reference: `skills/build/references/sdd-principles.md`

### Fast-Track Review Decision Matrix (Execution Defaults)

Only apply when this session is clearly tiny + low risk:

- `files_changed <= 2`
- `estimated_scope` is `tiny`
- `risk_label` is `low`
- no auth/session, secrets, crypto, DB schema migration, payment, or infra-policy risk flags
- no reviewer confidence ambiguity from checkpoint/scope diff

If eligible, Iteration 1 reviewer set is `wb-integration-tester` plus up to 2 high-confidence impacted reviewers.
If **any** fast-track reviewer fails or confidence drops, rerun the full base reviewer set in the next review iteration.
The integration hard gate is never bypassed.

## Public Step Routing

Public routing is conversational. The user should mostly experience step-level intent, not internal phase mechanics.

| User Says | Public Step | Internal Execution |
|-----------|-------------|--------------------|
| "I wanna build..." / "I have an idea..." / "build..." | Discover | Requirements |
| "guided mode" / "autonomous mode" | Control mode gate | Guided or autonomous preference |
| "Research this first" / "Investigate options" | Research gate | Optional research burst |
| "Let's define what we're building" / "What should we build?" | Discover | Requirements |
| "Let's plan this" / "How should we architect..." / "Break this into tasks" | Plan | Design + Tasks |
| "Let's build it" / "Start coding" / "Implement" | Implement | Implement |
| "Review the code" / "Is this ready?" | Review | Review |
| "QA this" / "Did we actually cover the requirements?" | QA | Review hard gate + final verification |
| "Summarize what happened" / "What is left?" | Summary | Ship/Document/handoff synthesis |

**Routing algorithm:**
1. Check for explicit internal phase commands (`/wannabuild-requirements`, etc.) when a host adapter exposes them.
2. Check `.wannabuild/state.json` for current internal context.
3. Infer the user's public step from conversational cues.
4. Map the public step to the appropriate internal execution surface.
5. If ambiguous, ask the user.

Users can still skip around. The orchestrator tracks internal state but should preserve a compact public experience.

## Execution Model

The orchestrator uses the host-native task or delegation surface. Each agent is an `agents/wb-*.md` file with YAML frontmatter and a focused system prompt.

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
  checkpoints/
    task-1-step-1.md, task-1-step-2.md, ...
  review/
    security-iter-1.json, performance-iter-1.json, ...  (one file per agent per iteration)
```

**Compact return formats:**
- Analysis agents: `COMPLETE — [one sentence]. Report at .wannabuild/outputs/[agent].md`
- Reviewer agents: `VERDICT: PASS — no issues found. Details at .wannabuild/review/[agent]-iter-{N}.json`
                or `VERDICT: FAIL — [M] issues ([X] critical). Details at .wannabuild/review/[agent]-iter-{N}.json`

### Parallel Background Pattern

**Research burst:**
```
Task(subagent_type="wb-tech-advisor", run_in_background=true)
Task(subagent_type="wb-architect", run_in_background=true)
Task(subagent_type="wb-risk-assessor", run_in_background=true)
// Optionally add wb-scope-analyst and wb-ux-perspective when scope or UX uncertainty remains high
// Synthesize into .wannabuild/outputs/research-summary.md, then proceed to planning
```

**Requirements:**
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

**Design:**
```
Task(subagent_type="wb-architect", run_in_background=true)
  // Write to .wannabuild/outputs/architect.md. Return one-liner.
Task(subagent_type="wb-tech-advisor", run_in_background=true)
  // Write to .wannabuild/outputs/tech-advisor.md. Return one-liner.
Task(subagent_type="wb-risk-assessor", run_in_background=true)
  // Write to .wannabuild/outputs/risk-assessor.md. Return one-liner.
// Wait for all three, read output files, then synthesize
```

### Sequential-Then-Parallel Pattern (Tasks)
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

### Foreground Pattern (Implement)
```
# Default path
Task(subagent_type="wb-implementer")
  prompt: "Implement tasks in micro-steps. Spec chain at .wannabuild/spec/.
           Write checkpoint files under .wannabuild/checkpoints/"

# Escalated path (high-complexity upfront or any remediation after first failed review)
Task(subagent_type="wb-implementer-escalated")
  prompt: "Implement tasks/fixes in micro-steps. Spec chain at .wannabuild/spec/.
           Write checkpoint files under .wannabuild/checkpoints/"
```

## Implement → Review Transition (Checkpoint-Aware)

Before spawning reviewers, the orchestrator reads the latest checkpoint files in `.wannabuild/checkpoints/` and builds a changed-step summary.

Required behavior:
- include the **latest checkpoint** window in review inputs
- pass changed files from checkpoints to adaptive reviewer routing
- if no checkpoints exist, fall back to spec + diff-only routing and warn the user

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
│  Base reviewer set: 6 reviewers                              │
│  Max iterations: 3 (then escalate to human)                  │
└──────────────────────────────────────────────────────────────┘
```

### Review Agent Spawning

Build an active reviewer set before spawning review tasks:

```
base_reviewers_full  = [security, performance, architecture, testing, integration-tester, code-simplifier]
base_reviewers_light = [security, architecture, integration-tester]

IF iteration == 1:
  active_reviewers = base_reviewers_{mode}
ELSE:
  impacted = infer_impacted_reviewers(changed_files_since_last_iteration, previous_failures)
  active_reviewers = union(impacted, [integration-tester])

  IF active_reviewers is empty OR impact inference uncertain:
    active_reviewers = base_reviewers_{mode}
```

Then spawn only `active_reviewers` in parallel background tasks (same file-first verdict contract):

```
for reviewer in active_reviewers:
  Task(subagent_type=reviewer, run_in_background=true)
    // Write to .wannabuild/review/[reviewer]-iter-{N}.json
    // Return one-line VERDICT summary
```

Context policy for reviewer prompts:
- **Security/Architecture/Performance/Testing/Code-simplifier:** diff summary + touched files + relevant spec excerpts.
- **Integration tester:** full acceptance criteria + test files + command output summaries.

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
iteration = 1
max_iterations = config.max_review_iterations ?? 3
base_reviewers = [security, performance, architecture, testing, integration-tester, code-simplifier]

LOOP:
  enforce_guardrails_or_pause(
    max_agent_runs_per_phase,
    max_total_review_runs,
    max_prompt_chars_per_reviewer,
    policy="pause-and-ask"
  )

  IF iteration == 1:
    active_reviewers = base_reviewers
  ELSE:
    impacted = infer_impacted_reviewers(changed_files_since_last_iteration, previous_failures)
    active_reviewers = union(impacted, [integration-tester])
    IF active_reviewers is empty OR impact inference uncertain:
      active_reviewers = base_reviewers

  spawn_reviewers(active_reviewers, background=true)
  wait_for_all_one_liners()

  verdicts = read_all_verdict_files(iteration)
  passes = count(v.status == "PASS")
  fails = count(v.status == "FAIL")

  update_loop_state(iteration, active_reviewers, verdicts)
  display_verdict_summary(passes, fails, active_reviewers)

  IF passes == len(active_reviewers):
    → SHIP phase (unanimous approval from active reviewers)
  ELSE:
    iteration += 1
    IF iteration > max_iterations:
      → ESCALATE to human
    ELSE:
      feedback = aggregate_feedback_from_files(verdicts, iteration)
      display_feedback(feedback)

      Task(subagent_type="wb-implementer-escalated")
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
  "mode": "standard",
  "current_iteration": 2,
  "max_iterations": 3,
  "base_reviewer_count": 6,
  "status": "in_progress|approved|escalated",
  "guardrails": {
    "max_agent_runs_per_phase": 18,
    "max_total_review_runs": 12,
    "max_prompt_chars_per_reviewer": 12000,
    "on_limit": "pause-and-ask"
  },
  "iterations": [
    {
      "iteration": 1,
      "timestamp": "2026-02-19T10:00:00Z",
      "active_reviewers": [
        "wb-security-reviewer",
        "wb-performance-reviewer",
        "wb-architecture-reviewer",
        "wb-testing-reviewer",
        "wb-integration-tester",
        "wb-code-simplifier"
      ],
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
    },
    {
      "iteration": 2,
      "timestamp": "2026-02-19T10:07:00Z",
      "active_reviewers": [
        "wb-performance-reviewer",
        "wb-integration-tester"
      ],
      "verdicts": {
        "wb-performance-reviewer": {"status": "PASS", "issues": []},
        "wb-integration-tester": {"status": "PASS", "issues": []}
      },
      "pass_count": 2,
      "fail_count": 0
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

- Reviewers find issues → orchestrator aggregates → implementer fixes → adaptive reviewer rerun (impacted + integration tester)
- The orchestrator routes, synthesizes, and manages state. It never edits code.
- If the implementer can't fix it, escalate to the human. Don't attempt the fix.

## State Management

### state.json Schema

```json
{
  "project": "project-name",
  "mode": "standard",
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
  ],
  "advisor": {
    "enabled": true,
    "max_uses_per_phase": 3,
    "uses_by_phase": {
      "design": 0,
      "implement": 0,
      "review": 0
    },
    "escalations": []
  }
}
```

The `mode` field is `"standard"` when present.

### State Update Rule

All phase state updates **merge into existing state.json** — they never replace it wholesale. This preserves the `mode` key (and any other existing keys) across every phase transition. Each phase's SKILL.md shows only the fields it writes; all other fields are left untouched.

### State Initialization

```bash
mkdir -p .wannabuild/spec .wannabuild/outputs .wannabuild/checkpoints .wannabuild/review
echo '{"current_phase":"requirements","phase_status":"pending","artifacts":{}}' > .wannabuild/state.json
# mode is initialized to "standard" during bootstrap; no mode question is asked
```

## Internal Phase Transitions

### Internal Normal Flow
```
requirements → design → tasks → implement → review (loop until all pass) → ship → document
```

### Public Normal Flow
```
discover → control_mode_decision → research_decision (optional research) → plan → implementation_decision → implement → review → qa → summary
```

### Skip-Phase Logic
Users can skip to any phase. Warn about missing artifacts:

> You're jumping to Implementation, but there's no requirements or design spec yet. The implementer will work from verbal instructions, but you'll miss spec-driven review validation. Continue or go back?

### Resume Logic
If `.wannabuild/state.json` exists, read the stored state and resume directly in standard mode. Resume must still emit a banner before continuing:

> `[WB-RESUME] WannaBuild RESUME | mode=standard | phase=<current_phase> | progress=<done>/<total>`

When resuming mid-implementation, continue from the latest checkpoint instead of restarting the full task list.

## Trigger Conditions

**Primary:** `/wannabuild` (Claude Code), `$wannabuild` (Codex)
**Aliases:** `/wb`, "I wanna build", "build", "plan and build"

## Example

```
User: I wanna build a Stripe payment integration for my SaaS

Orchestrator: Discover -> Control mode -> Research? -> Plan -> Implement -> Review -> QA -> Summary
  - Discover: captured goals and constraints
  - Control mode: guided vs autonomous decision recorded
  - Research gate: optional investigation chosen (or skipped)
  - Plan: plan and architecture verified
  - Implement: checkpoints written
  - Review: adaptive reviewer set passed
  - QA: acceptance criteria covered
  - Summary: concise handoff with remaining gaps
```

## Configuration

Optional `.wannabuild/config.json`:

```json
{
  "max_review_iterations": 3,
  "auto_advance": false,
  "skip_phases": [],
  "adaptive_review_reruns": true,
  "review_rerun_policy": "impacted_plus_integration",
  "review_context_scope": "diff_plus_targeted_spec",
  "max_agent_runs_per_phase": 18,
  "max_total_review_runs": 12,
  "max_prompt_chars_per_reviewer": 12000,
  "on_limit": "pause-and-ask",
  "advisor_escalation": true,
  "advisor_max_uses_per_phase": 3,
  "advisor_context_scope": "spec_plus_targeted_repo_summary",
  "advisor_record_decisions": true,
  "advisor_on_limit": "pause-and-ask"
}
```

## Contract Documents

Use these references before spawning phase agents:

- `skills/build/references/artifact-contracts.md`
- `skills/build/references/advisor-escalation.md`
- `skills/build/references/review-routing.md`
- `skills/build/references/loop-state.md`
- `skills/build/references/exit-conditions.md`
- `skills/build/references/sdd-principles.md`
- `skills/build/references/transition-shim.md`
- `skills/build/references/dry-run-checks.md`
- `skills/build/schemas/state.schema.json`
- `skills/build/schemas/loop-state.schema.json`
- `skills/build/schemas/review-verdict.schema.json`
- `skills/build/schemas/checkpoint.schema.json`

## Pre-flight Validation

Before entering any phase, the orchestrator must:

- Parse `state.json` safely; if invalid or missing required keys, bootstrap state.
- Validate required artifacts for the requested phase.
- Build checkpoint summary from the latest `.wannabuild/checkpoints/` window before review routing.
- Abort gracefully if any required verdict JSON is malformed and ask for user resolution.
- Run the transition shim check:

```bash
scripts/validate-wannabuild-artifacts.sh . <target_phase>
```

where `<target_phase>` is one of:
`requirements`, `design`, `tasks`, `implement`, `review`, `ship`, `document`.

If validation reports any `ERROR`, block the transition and keep state unchanged until the user resolves it.

## Transition Guardrail Enforcement

At each transition:

1. Merge-validates writes into existing JSON artifacts (`state.json`, `loop-state.json`) only.
2. Runs schema-level checks against state and loop artifacts before spawning phase agents.
3. Validates routing context and review window when entering review.
4. Re-runs lightweight review-verdict integrity checks before loop aggregation.
5. Stops execution on malformed JSON or missing required keys (fail-closed).

If the shim fails, report exact file and field path in the handoff summary and wait for user direction.

## Exit and Guardrail Defaults

- Use `in_progress` until the active-reviewer loop reaches unanimous approval.
- On `escalated` conditions, do not offer ship-with-known-issues when integration tester is failing.
- Default hard-fail reasons include:
  - malformed review verdict JSON
  - missing acceptance-criterion mapping
- Resume and continue logic should prefer latest checkpoint window over restarting task sequence.
