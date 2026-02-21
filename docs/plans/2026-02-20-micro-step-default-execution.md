# Micro-Step Default Execution (No Git Assumptions) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make WannaBuild execute implementation in strict micro-steps by default (step-by-step verification/checkpoints) to reduce drift and long-running stalls, without assuming git commits during implementation.

**Architecture:** Keep the existing 7-phase pipeline and hard integration-test gate. Change only execution granularity: each Task becomes a sequence of micro-steps (single objective + immediate verification + checkpoint). Persist progress in `.wannabuild/checkpoints/` so the orchestrator can pause/resume cleanly and adaptive review can scope reruns to the exact changed slices.

**Tech Stack:** Markdown framework repo (`skills/*.md`, `agents/*.md`, `README.md`, `AGENTS.md`), Task-tool orchestration semantics, file-first artifacts under `.wannabuild/`.

---

### Task 1: Define micro-step contract in Tasks phase output

**Files:**
- Modify: `skills/tasks/SKILL.md`
- Modify: `agents/wb-task-decomposer.md`

**Step 1: Add micro-step schema to task spec format**
- Add required section under each task:
  - `Micro-Steps` (ordered, 2–5 min each)
  - `Verify` command/output expectation per micro-step
  - `Checkpoint` artifact path per micro-step

**Step 2: Update task quality checklist**
- Add checklist lines that fail if a task is too large or missing micro-steps.

**Step 3: Update decomposer prompt rules**
- Require decomposer to split any task larger than ~15 minutes into multiple micro-steps.
- Require explicit “drift risk” note for each task.

**Step 4: Verify doc changes**
Run:
```bash
grep -n "Micro-Steps\|Checkpoint\|2–5 min\|drift" skills/tasks/SKILL.md agents/wb-task-decomposer.md
```
Expected: matching lines in both files.

---

### Task 2: Make implementers execute one micro-step at a time

**Files:**
- Modify: `skills/implement/SKILL.md`
- Modify: `agents/wb-implementer.md`
- Modify: `agents/wb-implementer-escalated.md`

**Step 1: Replace task-level execution language with micro-step loop**
- Enforce loop: `read step -> implement minimal change -> verify -> write checkpoint -> continue`.

**Step 2: Add checkpoint format and location**
- Standardize checkpoint file path:
  - `.wannabuild/checkpoints/task-{N}-step-{M}.md`
- Include fields:
  - changed files
  - verify command + result
  - pending next micro-step

**Step 3: Remove git assumptions from implementation rules**
- Replace “commit frequently / one task = one commit minimum” with:
  - “checkpoint every micro-step, optional VCS commit at phase boundaries.”

**Step 4: Verify removal + additions**
Run:
```bash
grep -n "checkpoint every micro-step\|task-{N}-step-{M}\|optional VCS" skills/implement/SKILL.md agents/wb-implementer.md agents/wb-implementer-escalated.md
grep -n "one task = one commit\|commit frequently" skills/implement/SKILL.md agents/wb-implementer.md agents/wb-implementer-escalated.md
```
Expected:
- first grep finds new policy lines
- second grep returns no required-commit policy lines.

---

### Task 3: Teach orchestrator to track micro-step checkpoints

**Files:**
- Modify: `skills/build/SKILL.md`

**Step 1: Add checkpoint lifecycle to architecture docs**
- Update `.wannabuild/` tree to include:
  - `checkpoints/`

**Step 2: Update implement/review transition**
- Require orchestrator to read latest checkpoints before spawning review.
- Include changed-step summary in review input (for adaptive reviewer routing).

**Step 3: Add resume behavior**
- If interrupted mid-task, resume from latest checkpoint step instead of restarting whole task.

**Step 4: Verify references exist**
Run:
```bash
grep -n "checkpoints/\|latest checkpoint\|resume" skills/build/SKILL.md
```
Expected: all three concepts present.

---

### Task 4: Align adaptive review docs with micro-step evidence

**Files:**
- Modify: `skills/review/SKILL.md`

**Step 1: Update input contract**
- Add checkpoint summaries as first-class review input.

**Step 2: Update impact routing matrix**
- Note that impacted reviewer selection should use:
  - changed files from last checkpoint window
  - prior failed reviewer categories

**Step 3: Keep integration tester hard gate unchanged**
- Explicitly restate no-override and always-include behavior.

**Step 4: Verify coherence**
Run:
```bash
grep -n "checkpoint\|changed files from last checkpoint window\|hard gate" skills/review/SKILL.md
```
Expected: all appear.

---

### Task 5: Remove git-assumption language from user-facing docs

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `skills/ship/SKILL.md`
- Modify: `skills/document/SKILL.md`

**Step 1: Update README + AGENTS wording**
- Explain default is micro-step checkpoints + verify loops.
- Keep VCS as optional packaging concern for ship phase.

**Step 2: Update ship/document templates**
- Replace review summary wording that assumes commit history is always present.
- Allow checkpoint-based evidence summaries.

**Step 3: Verify no forced-commit wording remains in implementation flow docs**
Run:
```bash
grep -RIn "commit" README.md AGENTS.md skills/implement/SKILL.md agents/wb-implementer.md agents/wb-implementer-escalated.md
```
Expected: no mandatory commit language in implementation flow.

---

### Task 6: Final consistency and signoff report

**Files:**
- Verify all edited files above

**Step 1: Run policy consistency checks**
Run:
```bash
grep -RIn "micro-step\|checkpoint\|integration tester\|hard gate\|adaptive" skills/*.md AGENTS.md README.md
```
Expected: policy appears in build/tasks/implement/review and top-level docs.

**Step 2: Run stale-phrasing checks**
Run:
```bash
! grep -RIn "one task = one commit\|commit frequently" skills/implement/SKILL.md agents/wb-implementer.md agents/wb-implementer-escalated.md
```
Expected: command exits 0 (no stale lines).

**Step 3: Produce summary for David**
- List exact behavior changes (before/after).
- Confirm integration-test hard gate unchanged.
- Confirm default micro-step execution is enabled.
