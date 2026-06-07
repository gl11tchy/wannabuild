# WannaBuild Philosophy (Internal Reference)

> This document supplements [`docs/philosophy.md`](../../../../docs/philosophy.md) with operational details and internal framing relevant to the orchestrator and phase agents.

Read `docs/philosophy.md` for the canonical user-facing philosophy, principles, and positioning.

## Principles as They Apply to the Orchestrator

The principles in `docs/philosophy.md` translate into these orchestrator-level behaviors:

### 1. Specs Are the Backbone

The SDD pipeline uses three lightweight specs that drive everything:

- **Requirements** — what to build (user stories, acceptance criteria, test scenarios)
- **Design** — how to build it (architecture, tech stack, risks)
- **Tasks** — the work (ordered, atomic, with test requirements)

The orchestrator must never spawn implementation agents without a completed discovery brief (with acceptance criteria), requirements, design, and tasks. The `assert-discovery-ready` and `assert-plan-ready` gates enforce this and fail closed — there is no "accept the risk and skip" path for a core gate.

### 2. Conversation Over Commands

The orchestrator should infer intent from natural conversation, not require flag-based invocation. Phase transitions happen when conditions are met, not when the user types a command.

### 3. Strict Where It Counts

The orchestrator enforces hard, fail-closed rules: discovery is mandatory before planning; the full reviewer set runs every iteration; the integration tester is terminal with execution evidence for every acceptance criterion; and resources must be acquired (or the user asked) before any work is declared blocked. These are gates, not guidance — see [doctrine.md](doctrine.md). Flexibility lives in *how deep* each phase goes, never in *whether* a core gate runs.

### 4. Depth Through Specialists

The orchestrator deploys 6 parallel specialists in review rather than a single generalist reviewer. Each specialist does one thing exceptionally well.

### 5. Executor-Led, Advisor-Assisted

The active executor owns tools, edits, and validation end-to-end. The advisor provides bounded read-only guidance only when a decision is genuinely high-impact or uncertain (see `advisor-escalation.md`).

### 6. Quality is a Loop AND a Gate

Code stays in the review loop until the **full** reviewer set (not a subset) unanimously PASSes, each reviewer having covered the entire changed surface. Max 3 iterations, then escalate to the user. Integration test failures are terminal and cannot be overridden.

### 7. Fixed Pipeline, Adaptive Depth

The same phases run in the same order on every task — a deterministic pipeline, not an à-la-carte menu. The user chooses where to *start* and approves each boundary, but core phases are never skipped. What adapts is the depth of work inside each phase, so the experience is identical every run.

### 8. State Without Ceremony

Simple files in `.wannabuild/` that the user can read and edit themselves. Merge-update only, never full replacement. Fail-closed on malformed JSON.

## The Indie Hacker Test

Every orchestrator feature must pass:

> Would a solo developer at 11 PM, excited about their side project, actually use this?

If it feels like ceremony, paperwork, or bureaucracy → cut it.
If it helps them ship faster without cutting corners → keep it.

Exception: the doctrine mandates (mandatory discovery, resource acquisition before "blocked", full-set review, integration tests for every acceptance criterion). They earn their place because skipping them wastes far more time than honoring them.

## Anti-Patterns the Orchestrator Must Reject

- The 50-Page PRD — A focused requirements spec beats a bloated PRD.
- Mandatory TDD for Everything — Write tests where they matter (integration tests for acceptance criteria, unit tests for complex logic).
- 100% Coverage — Meaningful integration tests that prove acceptance criteria beats 100% line coverage.
- Process for Process's Sake — Every process must earn its place.
- Skipping Integration Tests — "The code works, I tested it manually" is never acceptable.
- Blaming the Environment — "I couldn't test it, the env/database/credentials were missing" is never acceptable. Acquire the resource (run the app, spin a DB branch, drive a browser, generate fixtures) or ask the user; never skip.
- Lazy Review — A reviewer that examines part of the diff and returns a flake PASS has not reviewed. Each reviewer covers the whole changed surface.

---

*See `docs/philosophy.md` for the full user-facing philosophy document.*
