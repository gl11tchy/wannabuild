# WannaBuild Philosophy (Internal Reference)

> This document supplements [`docs/philosophy.md`](../../../docs/philosophy.md) with operational details and internal framing relevant to the orchestrator and phase agents.

Read `docs/philosophy.md` for the canonical user-facing philosophy, principles, and positioning.

## Principles as They Apply to the Orchestrator

The principles in `docs/philosophy.md` translate into these orchestrator-level behaviors:

### 1. Specs Are the Backbone

The SDD pipeline uses three lightweight specs that drive everything:
- **Requirements** — what to build (user stories, acceptance criteria, test scenarios)
- **Design** — how to build it (architecture, tech stack, risks)
- **Tasks** — the work (ordered, atomic, with test requirements)

The orchestrator must never spawn implementation agents without at least requirements + tasks. Design may be absent for implement/review transitions if the user explicitly accepts the risk (see `transition-shim.md`).

### 2. Conversation Over Commands

The orchestrator should infer intent from natural conversation, not require flag-based invocation. Phase transitions happen when conditions are met, not when the user types a command.

### 3. Flexibility Over Dogma

The orchestrator enforces only one hard rule: integration tests for every acceptance criterion. Everything else is guidance. Phases can be entered, exited, and skipped.

### 4. Depth Through Specialists

The orchestrator deploys 6 parallel specialists in review rather than a single generalist reviewer. Each specialist does one thing exceptionally well.

### 5. Executor-Led, Advisor-Assisted

The active executor owns tools, edits, and validation end-to-end. The advisor provides bounded read-only guidance only when a decision is genuinely high-impact or uncertain (see `advisor-escalation.md`).

### 6. Quality is a Loop, Not a Gate

Code stays in the review loop until all active reviewers unanimously PASS. Max 3 iterations, then escalate. Integration test failures cannot be overridden.

### 7. Phases, Not Stages

Fluid phases you can enter, exit, and skip. Not a linear approval chain. The stage machine tracks public stages for state continuity, but phases are tools, not rules.

### 8. State Without Ceremony

Simple files in `.wannabuild/` that the user can read and edit themselves. Merge-update only, never full replacement. Fail-closed on malformed JSON.

## The Indie Hacker Test

Every orchestrator feature must pass:

> Would a solo developer at 11 PM, excited about their side project, actually use this?

If it feels like ceremony, paperwork, or bureaucracy → cut it.
If it helps them ship faster without cutting corners → keep it.

Exception: integration tests. They're the one mandate because shipping untested code wastes more time than writing the tests.

## Anti-Patterns the Orchestrator Must Reject

- The 50-Page PRD — A focused requirements spec beats a bloated PRD.
- Mandatory TDD for Everything — Write tests where they matter (integration tests for acceptance criteria, unit tests for complex logic).
- 100% Coverage — Meaningful integration tests that prove acceptance criteria beats 100% line coverage.
- Process for Process's Sake — Every process must earn its place.
- Skipping Integration Tests — "The code works, I tested it manually" is never acceptable.

---

*See `docs/philosophy.md` for the full user-facing philosophy document.*
