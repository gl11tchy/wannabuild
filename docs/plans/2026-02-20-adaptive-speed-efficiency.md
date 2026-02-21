# Adaptive Review Speed/Efficiency Defaults Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add adaptive orchestration defaults that preserve quality gates while reducing wasted reviewer/agent runs and oversized context payloads.

**Architecture:** Keep first-pass review comprehensive, then make retries selective: re-run only impacted reviewers plus the integration tester hard gate. Add explicit pause-and-ask guardrails for run limits and context limits so workflows cannot silently spiral. Persist policy knobs in `.wannabuild/config.json` schema docs.

**Tech Stack:** Markdown-only framework repo (skills + agent profile docs), Claude Code Task orchestration semantics.

---

### Task 1: Update build orchestrator policy docs

**Files:**
- Modify: `skills/build/SKILL.md`

**Step 1: Add adaptive orchestration policy section**
- Document default behavior:
  - Iteration 1 uses full reviewer set for selected mode.
  - Iteration 2+ uses impacted reviewers + integration tester.
  - Fallback to full reviewer set when impact cannot be determined.

**Step 2: Update review loop pseudocode**
- Replace `spawn_reviewers(mode, background=true)` with adaptive selection logic.
- Include `select_reviewers(mode, iteration, changed_files, previous_failures)`.
- Keep unanimous approval requirement over active reviewer set + mandatory integration tester.

**Step 3: Add pause-and-ask guardrails**
- Add guardrail checks before spawning agents/reviewers:
  - max agent runs per phase
  - max review runs total
  - max chars per reviewer prompt context
- Behavior on limit: pause and ask user to continue or tighten scope.

**Step 4: Update config schema example**
- Add keys for adaptive selection, context slicing, and pause policy.

### Task 2: Update review phase docs for adaptive reruns

**Files:**
- Modify: `skills/review/SKILL.md`

**Step 1: Replace static execution flow with adaptive flow**
- Document first-pass full coverage and retry selective coverage.

**Step 2: Add reviewer impact routing matrix**
- Define mapping from changed file scope/failure type to reviewers.
- Integration tester always included.

**Step 3: Update agent spawning examples**
- Keep per-reviewer command templates.
- Add section showing dynamic reviewer list generation.

**Step 4: Update verdict display examples**
- Show display based on active reviewer set for iteration.

### Task 3: Align implement/repo-level docs

**Files:**
- Modify: `skills/implement/SKILL.md`
- Modify: `AGENTS.md`
- Modify: `README.md`

**Step 1: Clarify escalation trigger language**
- Ensure implement docs reference adaptive retries and escalation handoff.

**Step 2: Add short “Adaptive by default” callout**
- In AGENTS/README, mention that retry loops are selective and integration tester always runs.

### Task 4: Verification and consistency pass

**Files:**
- Verify: `skills/build/SKILL.md`, `skills/review/SKILL.md`, `skills/implement/SKILL.md`, `AGENTS.md`, `README.md`

**Step 1: Run consistency grep checks**
- Ensure no stale statements claim “all reviewers rerun every iteration”.

**Step 2: Sanity-check model + adaptive policy coherence**
- Confirm docs still reflect model tiering policy (Opus specs, Sonnet implementer default, escalated implementer inherits parent model).

**Step 3: Summarize diff and surface behavior changes**
- Provide concise changelog-style summary for user signoff.
