# Fast-Track Decision Matrix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Define and implement a deterministic fast-track review pathway with explicit fallback rules so low-risk changes stay fast without weakening hard gates.

**Architecture:** Keep the framework behavior in documentation artifacts only. Centralize policy in `AGENTS.md`, then align orchestrator guidance in `skills/build/SKILL.md`, and make reviewer behavior explicit in `skills/review/SKILL.md`. This creates one source for decision criteria and two explicit consumers so execution and expectations stay consistent.

**Tech Stack:** Markdown documentation updates, shell-based file operations, git.

---

### Task 1: Add fast-track decision matrix to AGENTS policy

**Files:**
- Modify: `AGENTS.md`

**Step 1: Open the current quality loop section and define explicit criteria block**

```markdown
## Quality Loop

- Iteration 1 runs the full base reviewer set for the mode (Full=6, Light=3)
- Iteration 2+ runs only impacted reviewers + integration tester (always)
- Each reviewer returns PASS or FAIL with structured JSON verdict
- If ANY fails, aggregated feedback goes to `wb-implementer-escalated`
- Loop continues until unanimous approval from the active reviewer set
- Max 3 iterations before escalation
- Guardrails should pause-and-ask when run/context limits are reached (no silent fan-out)
- **Fast-Track Decision Matrix (optional):**
  - Eligible only when all conditions are true:
    - `files_changed <= 2`
    - `estimated_scope` is `tiny`
    - `risk_label` is `low`
    - no `db` migration, auth/session, secret-handling, or payment/financial changes
  - Reviewer set for Iteration 1: `wb-integration-tester` + at most 2 high-confidence impacted reviewers.
  - Integration hard gate is always included and unchanged.
  - If **any** reviewer returns FAIL, impact confidence is uncertain, or gating signals conflict, next iteration switches to the full base reviewer set for that mode.
- **Integration tester FAIL blocks shipping — no override path**
```

**Step 2: Verify the policy is present and only appears once**

Run:

```bash
rg -n "Fast-Track Decision Matrix|Integration tester FAIL blocks shipping|Decision Matrix" AGENTS.md
```

Expected: 3 matched lines in the `Quality Loop` block with the matrix and hard gate text.

**Step 3: Commit this task**

```bash
git add AGENTS.md
git commit -m "docs: add deterministic fast-track decision matrix"
```

### Task 2: Align orchestrator defaults in build skill

**Files:**
- Modify: `skills/build/SKILL.md`

**Step 1: Add an execution default section that mirrors the matrix criteria**

Insert after the existing "Adaptive Speed/Efficiency Defaults" section:

```markdown
### Fast-Track Review Decision Matrix (Execution Defaults)

Only apply when this session is clearly tiny + low risk:

- `files_changed <= 2`
- `estimated_scope` is `tiny`
- `risk_label` is `low`
- no auth/session, secrets, crypto, DB schema migration, payment, or infra-policy risk flags
- no reviewer confidence ambiguity from checkpoint/scope diff

If eligible, Iteration 1 reviewer set is `wb-integration-tester` plus up to 2 high-confidence impacted reviewers.
If **any** fast-track reviewer fails or confidence drops, rerun the full base set on the next review iteration.
The integration hard gate is never bypassed.
```

**Step 2: Verify the section is under Adaptive Speed controls and references the fallback explicitly**

Run:

```bash
rg -n "Fast-Track Review Decision Matrix|files_changed|fallback" skills/build/SKILL.md
```

Expected: one section with all required criteria and a mandatory fallback line.

**Step 3: Commit this task**

```bash
git add skills/build/SKILL.md
git commit -m "docs: align build skill with fast-track matrix"
```

### Task 3: Make reviewer behavior explicit in review skill

**Files:**
- Modify: `skills/review/SKILL.md`

**Step 1: Add fast-track fallback contract to review execution rules**

Insert immediately after the reviewer set section:

```markdown
### Fast-Track Review Contract (Mode-agnostic)

- Iteration 1 may start with the reduced reviewer set only if matrix criteria in `AGENTS.md` are met.
- Set must always include `wb-integration-tester`.
- A single FAIL in fast-track triggers the next iteration to run the full mode base reviewer set.
- If impact routing confidence is unclear, route to full base reviewer set immediately.
- Do not reduce hard-gate logic in any scenario.
```

**Step 2: Verify language consistency across matrix references**

Run:

```bash
rg -n "Fast-Track|full base reviewer set|integration tester|hard gate" skills/review/SKILL.md
```

Expected: fast-track section appears once and references full-set fallback and hard-gate invariance.

**Step 3: Commit this task**

```bash
git add skills/review/SKILL.md
git commit -m "docs: define fast-track review contract and fallback behavior"
```

### Optional verification sweep (post-tasks)

**Step 1: Confirm all three policy touchpoints changed together**

```bash
git diff --name-only HEAD~3..HEAD
```

Expected output:

```text
AGENTS.md
skills/build/SKILL.md
skills/review/SKILL.md
```

**Step 2: Spot-check for ambiguous criteria drift**

```bash
rg -n "Fast-Track|fallback|hard gate|integration tester" AGENTS.md skills/build/SKILL.md skills/review/SKILL.md
```

Expected: matching terminology across files.

---

Plan complete and saved to `docs/plans/2026-02-21-fast-track-decision-matrix.md`. Two execution options:

1. Subagent-Driven (this session) — dispatch fresh subagent per task, review between tasks, fast iteration.
2. Parallel Session (separate) — Open new session with executing-plans, batch execution with checkpoints.

Which approach?
