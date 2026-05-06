# wb-runtime Full System Spec

Date: 2026-05-06

Status: proposed

## Purpose

WannaBuild needs one durable runtime contract that every host follows. Skills and
`AGENTS.md` remain the readable policy layer. `wb-runtime` becomes the local
execution kernel that owns workflow state, legal transitions, gates, event
history, task execution, checkpointing, resume, and adapter parity.

The goal is not to replace skills. The goal is to make skill promises true even
when a host, model, or long-running session would otherwise drift.

## Problem

Current WannaBuild behavior can diverge by harness:

- Claude Code can use `SessionStart` and `UserPromptSubmit` hooks to inject
  context before the model answers.
- Codex currently relies on `AGENTS.md`, skill text, and scripts the model is
  instructed to run.
- Cursor and other hosts may rely on rule files, prompts, or future adapter APIs.

That creates different enforcement levels for the same user workflow. The user
experience should not depend on whether a host supports hooks. Different hosts
may use different adapter mechanics, but the semantics must be identical.

## Product Principle

Same WannaBuild behavior everywhere. Different adapter mechanisms only.

Host adapters may vary in how they call the runtime, but all must consult the
same runtime for:

- active workflow detection
- current phase and legal next action
- phase transitions
- hard gates
- pause conditions
- task scheduling
- checkpoint and verification status
- resume context
- final readiness

## Non-Goals

- Do not replace skills, prompts, or agents with Rust logic.
- Do not build a blind infinite agent loop.
- Do not require a daemon for the first production version.
- Do not make every host implement its own state machine.
- Do not make Rust perform product judgment; it enforces gates and records
  decisions, while agents and users make product choices.

## System Layers

```text
User prompt
  -> host adapter
  -> wb-runtime context/gate/transition API
  -> skills and agents execute allowed work
  -> wb-runtime records events, checkpoints, verification, and next action
```

### Policy Layer

Owned by:

- `AGENTS.md`
- `skills/wannabuild/SKILL.md`
- phase skills such as `wb-plan`, `wb-build`, `wb-qa`
- specialist prompts
- docs

Responsibilities:

- describe how WannaBuild should feel
- define user-facing workflow
- define agent obligations
- describe review/QA standards
- explain host usage

### Runtime Layer

Owned by `wb-runtime`.

Responsibilities:

- state machine
- gate enforcement
- event log
- task graph
- checkpoint indexing
- resume context
- scheduling decisions
- adapter-neutral status and context output
- durable pause/block/complete semantics

### Adapter Layer

Owned by host-specific integrations:

- Claude Code hooks
- Codex skill bootstrap / future hook support
- Cursor rules or helper scripts
- shell/manual use
- future provider adapters

Responsibilities:

- call `wb-runtime context` at the required moments
- call hard gates before dangerous phases
- render runtime context into the host's supported format
- pass execution events back to the runtime
- avoid reimplementing runtime policy

## Runtime Modes

### CLI Mode

Required first. The runtime is invoked as a command and exits.

Examples:

```bash
wb-runtime context --project .
wb-runtime status --project .
wb-runtime assert-plan-ready --project .
wb-runtime transition --project . --to plan --status complete
wb-runtime event --project . --type checkpoint --path .wannabuild/checkpoints/step-001.json
```

CLI mode is enough for hooks, Codex bootstraps, scripts, tests, and manual
operator use.

### Daemon Mode

Later. A local daemon can keep in-memory indexes, stream progress, watch files,
and coordinate long-running work. The daemon must expose the same semantics as
the CLI.

The CLI remains the compatibility surface even when a daemon exists.

## Core State Model

`wb-runtime` stores durable state under `.wannabuild/` and may use SQLite for
indexed runtime data.

Required files:

```text
.wannabuild/
├── state.json
├── loop-state.json
├── runtime.db
├── events.jsonl
├── spec/
│   ├── requirements.md
│   ├── design.md
│   └── tasks.md
├── checkpoints/
├── review/
├── outputs/
└── decisions.md
```

### JSON State

`state.json` remains the portable, human-inspectable workflow state. Required
fields: project, mode, current_phase, phase_status, public_stage,
workflow_status, control_mode, started_at, updated_at, artifacts,
phase_history, public_stage_history, pause_reason, blocked_reason,
active_task_ids, and runtime_version.

### Event Log

`events.jsonl` is append-only. Event types: workflow_started,
workflow_resumed, user_prompt_received, runtime_context_emitted, phase_started,
phase_completed, phase_blocked, phase_paused, transition_requested,
transition_accepted, transition_denied, gate_checked, gate_passed, gate_failed,
task_created, task_started, task_completed, task_blocked, checkpoint_written,
verification_started, verification_passed, verification_failed, review_started,
review_passed, review_failed, qa_started, qa_passed, qa_failed,
human_judgment_required, and workflow_completed.

### SQLite Index

`runtime.db` indexes state and events for fast queries. Tables: `workflows`,
`events`, `tasks`, `task_dependencies`, `checkpoints`, `artifacts`, `gates`,
`reviews`, `qa_runs`, `adapter_sessions`, and `locks`.

SQLite is an implementation detail. JSON files remain the compatibility and
debugging surface.

## State Machine

Public stages:

```text
discover -> research? -> plan -> implement -> review -> qa -> ship -> summary
```

Internal phases:

```text
requirements -> research? -> design -> tasks -> implement -> review -> qa -> ship -> document
```

Allowed transitions:

- no workflow -> discover
- discover -> research
- discover -> plan
- research -> plan
- plan -> implement
- implement -> review
- review -> implement remediation
- review -> qa
- qa -> implement remediation
- qa -> ship
- ship -> summary
- summary -> complete

Forbidden transitions:

- no concrete task -> plan
- no concrete task -> implement
- discover -> implement
- plan incomplete -> implement
- review failed -> summary
- QA failed -> summary
- blocked phase -> next phase without a resolved unblock event

## Hard Gates

Hard gates are non-negotiable runtime checks.

### Concrete Task Gate

Blocks planning and implementation when no concrete task, stage intent, or
exploratory idea intent exists.

Allowed response:

```text
Tell me what you want to build or change.
```

### Planning Gate

Blocks implementation until Plan is complete.

Pass evidence:

- `.wannabuild/spec/design.md` exists
- `.wannabuild/spec/tasks.md` exists
- or phase history contains `design: complete` and `tasks: complete`
- `state.json.public_stage_history` may record `plan: complete` only after the
  runtime has already validated one of the real evidence paths above; it is not
  standalone pass evidence.

Runtime command:

```bash
wb-runtime assert-plan-ready --project .
```

Current compatibility command:

```bash
scripts/wannabuild-session.sh assert-plan-ready .
```

### Implementation Workspace Gate

Before implementation, decide whether to continue in the current checkout or
create an isolated worktree.

Worktree is required only when:

- user asks for isolation
- parallel/risky changes justify it
- implementation plan explicitly selects it

### Review Gate

Blocks QA or summary when required reviewer verdicts fail.

Pass evidence:

- review verdicts exist
- hard blockers are resolved
- actionable findings are fixed or explicitly deferred with user judgment

### QA Gate

Blocks ship/summary when integration QA fails.

Pass evidence:

- acceptance criteria checked
- integration behavior checked
- `.wannabuild/outputs/qa-summary.md` exists
- a `qa_passed` event alone is not sufficient without structured acceptance and
  integration evidence
- hard gate verifier passes

### Ship Gate

Blocks final completion when delivery strategy requires user judgment.

Ask the user when choosing:

- stop after local preparation
- commit only
- push branch and create PR
- merge locally
- push directly to main

## Pause Conditions

`wb-runtime` pauses instead of continuing when:

- product direction is ambiguous
- scope materially changes
- destructive action is needed
- credentials are needed
- paid services are needed
- production data is needed
- merge/push/PR strategy is needed
- repeated verification failures exceed retry policy
- runtime detects conflicting edits or file ownership overlap
- user explicitly says stop, pause, plan only, discovery only, do not implement,
  QA only, review only, or equivalent

Vague acknowledgments such as `ok`, `uh ok`, `sounds good`, and `sure` do not
count as permission to skip phases.

## Runtime CLI Surface

### Workflow Commands

```bash
wb-runtime init --project .
wb-runtime status --project .
wb-runtime context --project . [--format text|json|host]
wb-runtime next-action --project .
wb-runtime pause --project . --reason <reason>
wb-runtime resume --project .
wb-runtime complete --project .
```

### Transition Commands

```bash
wb-runtime transition --project . --to discover --status in_progress
wb-runtime transition --project . --to plan --status complete
wb-runtime transition --project . --to implement --status in_progress
```

Transitions validate gates before writing state.

### Gate Commands

```bash
wb-runtime assert-concrete-task --project .
wb-runtime assert-plan-ready --project .
wb-runtime assert-review-ready --project .
wb-runtime assert-qa-ready --project .
wb-runtime assert-summary-ready --project .
```

### Task Commands

```bash
wb-runtime tasks import --project . --from .wannabuild/spec/tasks.md
wb-runtime tasks list --project .
wb-runtime tasks next --project .
wb-runtime tasks claim --project . --task <id> --owner <owner>
wb-runtime tasks complete --project . --task <id> --checkpoint <path>
wb-runtime tasks block --project . --task <id> --reason <reason>
```

### Event Commands

```bash
wb-runtime event append --project . --type checkpoint --json <payload>
wb-runtime event list --project . --since <cursor>
wb-runtime event replay --project .
```

### Adapter Commands

```bash
wb-runtime adapter context --project . --host claude-code --event SessionStart
wb-runtime adapter context --project . --host claude-code --event UserPromptSubmit --prompt <text>
wb-runtime adapter context --project . --host codex --event bootstrap --prompt <text>
wb-runtime adapter route --project . --host <host> --prompt <text>
```

## Context Output Contract

`wb-runtime context` returns compact, host-neutral context.

Text form:

```text
WannaBuild runtime state is active.
- workflow_status: in_progress
- public_stage: plan
- current_phase: design
- phase_status: in_progress
- allowed_next_action: complete design and tasks before implementation
- forbidden: do not implement or edit code until assert-plan-ready passes
- vague_acknowledgment_policy: continue current phase; do not skip
```

JSON form:

```json
{
  "runtime_active": true,
  "workflow_status": "in_progress",
  "public_stage": "plan",
  "current_phase": "design",
  "phase_status": "in_progress",
  "allowed_next_action": "complete_plan_before_implementation",
  "forbidden_actions": [
    "implement_before_plan",
    "edit_code_before_plan_gate"
  ],
  "required_gates": [
    "assert-plan-ready"
  ],
  "pause_required": false
}
```

## Task DAG

The Task DAG is derived from `.wannabuild/spec/tasks.md`.

Each task has: id, title, description, phase, dependencies, owner, expected
files, acceptance criteria, verification commands, checkpoint path, status,
retry count, blocked reason, risk level, and parallelizable flag.

Task statuses: pending, ready, claimed, in_progress, verifying, complete,
blocked, failed, and skipped.

## Scheduler

The scheduler chooses the smallest execution shape that can complete the plan.

Execution shapes:

- single-owner
- staged single-owner
- parallel independent slices
- review-loop remediation
- human-guided

Rules:

- default to single-owner
- use parallel only for disjoint tasks
- never assign overlapping write ownership without explicit coordination
- stop adding workers when ownership stops being distinct
- record scheduler rationale in `.wannabuild/decisions.md`

The scheduler may be CLI-driven initially:

```bash
wb-runtime tasks next --project .
```

Daemon mode later may run scheduling continuously.

## Agent Adapter Layer

Adapters translate runtime tasks into host-specific execution.

Common interface:

- `prepare_context(task)`
- `start_agent(task, context)`
- `poll_agent(task)`
- `collect_result(task)`
- `record_checkpoint(task, result)`
- `abort(task, reason)`

Host adapters:

- Codex local
- Claude Code
- Cursor
- shell/manual
- future provider APIs

Adapters must not own workflow legality. They ask `wb-runtime`.

## Checkpoint Contract

Every non-trivial implementation step writes a checkpoint.

Checkpoint fields:

- task id
- owner
- files changed
- commands run
- command results
- acceptance criteria covered
- risks
- follow-ups
- timestamp
- resume instructions

Checkpoints are canonical resume anchors.

## Review And QA

Review and QA remain separate stages.

Review answers:

- Does the implementation match the spec?
- Did it introduce bugs or regressions?
- Are required tests present?
- Are security, architecture, and maintainability risks acceptable?

QA answers:

- Does the integrated user flow work?
- Are acceptance criteria covered?
- Did the hard integration gate pass?

`wb-runtime` blocks summary until both pass.

## Observability

Runtime observability includes:

- event log
- status command
- live progress view
- task graph view
- gate history
- retry history
- blocked reasons
- per-agent duration
- verification history
- final summary data

Future daemon command:

```bash
wb-runtime watch --project .
```

## Security

The runtime must:

- never execute untrusted code from specs by default
- require explicit allowlists for verification commands
- redact secrets in logs
- avoid storing credentials
- use file locks for state writes
- validate all JSON state before transition
- preserve audit trail
- make destructive actions explicit pause points

## Concurrency

Use lock files or SQLite transactions for:

- state transitions
- task claims
- checkpoint writes
- event append
- gate checks tied to transitions

No two adapters may claim the same task concurrently.

Parallel agents must declare file ownership before editing.

## Host Parity Requirements

All hosts must call equivalent runtime operations.

| Moment | Runtime call |
|---|---|
| session start/resume | `wb-runtime context --project .` |
| user prompt | `wb-runtime adapter context --prompt <text>` |
| before implementation | `wb-runtime assert-plan-ready --project .` |
| phase complete | `wb-runtime transition --to <stage> --status complete` |
| checkpoint | `wb-runtime event append --type checkpoint` |
| review complete | `wb-runtime assert-review-ready --project .` |
| QA complete | `wb-runtime assert-qa-ready --project .` |
| summary | `wb-runtime assert-summary-ready --project .` |

Claude Code can call these from hooks.

Codex must call them from skill bootstrap or an adapter script until native hook
support exists.

Cursor can call them from rules/helpers.

## Migration Plan

### Phase 0: Compatibility Gate

Current state:

- `scripts/wannabuild-session.sh assert-plan-ready`
- Claude hook runtime context
- skill and `AGENTS.md` hard-gate text

### Phase 1: Rust CLI Kernel

Build `wb-runtime` with:

- status
- context
- assert-plan-ready
- transition
- event append
- JSON validation
- file locking
- event log

No daemon yet.

### Phase 2: Replace Shell Gate

Update:

- Claude hook calls `wb-runtime context`
- `wb-build` requires `wb-runtime assert-plan-ready`
- validation scripts use runtime gate
- dry-runs cover runtime outputs

Keep shell script as compatibility wrapper.

### Phase 3: Task DAG

Add:

- task import from `.wannabuild/spec/tasks.md`
- task dependency graph
- claim/complete/block commands
- checkpoint validation
- scheduler rationale output

### Phase 4: Adapter Execution

Add host adapters that can:

- start task execution
- record results
- handle parallel slices
- enforce file ownership
- update checkpoints

### Phase 5: Daemon And Live UI

Add optional daemon:

- watch mode
- live progress
- event streaming
- faster indexes
- long-running completion engine

### Phase 6: Advanced Scheduler

Add:

- adaptive parallelism
- retry policy
- staged waves
- confidence scoring
- agent performance history
- automatic remediation loops

## Rust Crates And Implementation Direction

Suggested crates: `clap` for CLI, `serde` / `serde_json` for state,
`rusqlite` or `sqlx` for SQLite, `time` for timestamps, `thiserror` /
`anyhow` for errors, `fs2` or SQLite transactions for locking, `tracing` for
logs, `camino` for UTF-8 paths, `insta` for snapshot tests, and `assert_cmd`
for CLI tests.

Module layout:

```text
crates/wb-runtime/
├── src/
│   ├── main.rs
│   ├── cli.rs
│   ├── state.rs
│   ├── events.rs
│   ├── gates.rs
│   ├── transitions.rs
│   ├── context.rs
│   ├── tasks.rs
│   ├── scheduler.rs
│   ├── adapters.rs
│   ├── checkpoints.rs
│   ├── storage.rs
│   └── errors.rs
└── tests/
```

## Test Strategy

### Unit Tests

- state load/save
- event append
- transition validation
- gate pass/fail
- context output
- vague acknowledgment classification
- task DAG parsing
- scheduler decisions

### Integration Tests

- no task blocks planning
- plan incomplete blocks implementation
- plan complete allows implementation
- failed review blocks summary
- failed QA blocks summary
- checkpoint replay resumes task
- concurrent task claim is safe
- host adapter context is consistent across Claude/Codex/Cursor formats

### Golden Tests

Golden fixtures under `skills/build/dry-runs/` should assert:

- active workflow runtime context
- `wb-discover` entrypoint continues full loop
- vague acknowledgments do not skip phases
- implementation cannot start before Plan
- review and QA remain distinct
- summary requires evidence

## Acceptance Criteria

The system is successful when:

- every host gets equivalent next-action and forbidden-action context
- implementation cannot proceed before Plan is complete
- `wb-discover`, `wb-plan`, and `wb-build` are phase entrypoints into one loop
- vague acknowledgments never skip required phases
- workflow resumes from durable state after restart
- task execution can resume from checkpoints
- review and QA block summary when failing
- scheduler decisions are recorded
- all gates are testable outside any particular host

## Open Questions

- Should `runtime.db` be required immediately or introduced after JSONL events?
- Should task DAG parsing require a structured tasks format, or infer from
  Markdown first?
- What is the Codex-native equivalent of Claude `UserPromptSubmit` hooks?
- Should `wb-runtime` ship inside this repo first or as a separate crate?
- Should daemon mode use JSON-RPC, gRPC, Unix sockets, or a simple local HTTP
  API?
- What verification command allowlist is acceptable for target projects?
- How should adapter credentials be represented without storing secrets?

## Recommended First Cut

Build the Rust CLI kernel first:

```text
status
context
assert-plan-ready
transition
event append
```

Back it with JSON files and JSONL events. Add SQLite only when task graph and
query performance need it.

Then replace the shell compatibility gate and hook logic with calls to
`wb-runtime`.

After that, build the Task DAG and scheduler.

The daemon comes last, once the CLI semantics are boring and impossible to
misinterpret.
