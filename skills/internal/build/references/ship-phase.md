> Internal reference: this preserves the legacy Ship phase contract for orchestrator use; it is not a public top-level Claude-discoverable skill surface.

# WannaBuild: Ship Phase

> "Let's get this merged."

Phase 6 of 7 in the WannaBuild SDD pipeline. Prepares verified work for delivery, asks the user for the delivery path, executes it, and cleans up.

## Agents

| Agent | File | Role | Execution |
|-------|------|------|-----------|
| PR Craftsman | `wb-pr-craftsman` | Creates PR with spec-referenced description | **First** (sequential) |
| CI Guardian | `wb-ci-guardian` | Monitors CI; gates on the integration suite having run and passed (hard gate) | **Then** (sequential, after PR) |

## Trigger Conditions

**Explicit:**

- `/wannabuild-ship` (auto-prefixed when installed as plugin)
- "Ship it" / "Create a PR" / "Let's merge"

**Implicit (from orchestrator):**

- Review phase achieves unanimous PASS → auto-transition to Ship

## Input

**Handoff from Review:**

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
    "all_active_reviewers_passed": true
  }
}
```

## Execution Flow

```text
Review approval (input)
        │
        ▼
┌─────────────────────────┐
│  Pre-Ship Checklist      │
│  - Checkpoint evidence complete │
│  - All changes committed        │
│  - Branch/workspace ready       │
│  - No merge conflicts           │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│  PR Craftsman            │
│  - Prepare branch        │
│  - Create PR             │
│  - Reference specs       │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│  CI Guardian             │
│  - Monitor CI checks     │
│  - Verify integration    │
│    tests in pipeline     │
│  - Diagnose failures     │
└────────────┬────────────┘
             │
             ▼
    PR ready for merge
```

## Agent Spawning

These agents run **sequentially** (CI Guardian needs the PR to exist):

```text
// Step 1: Create PR
Task(subagent_type="wb-pr-craftsman")
  prompt: "Create PR. Specs at .wannabuild/spec/. Review approved after {iterations} iterations.
           Write your full output (PR URL, description, summary) to .wannabuild/outputs/pr-craftsman.md.
           Return ONLY: 'COMPLETE — PR #{pr_number} created. Report at .wannabuild/outputs/pr-craftsman.md'"

// Step 2: Monitor CI (after PR exists)
Task(subagent_type="wb-ci-guardian")
  prompt: "Monitor CI for PR #{pr_number}. Confirm the integration suite RAN and PASSED
           in a real environment (green CI job, or a provisioned/local run with captured
           exit code and output). If CI does not run it, run it yourself and gate on that.
           A skipped/absent/errored integration suite is a FAIL that blocks the phase —
           no override. Before reporting any failure as environmental, attempt to obtain
           the missing resource and log the attempt to .wannabuild/outputs/acquisition-log.json.
           Write your full CI report (with execution evidence) to .wannabuild/outputs/ci-guardian.md.
           Return ONLY: 'COMPLETE — CI {passed|failed}, [one sentence]. Report at .wannabuild/outputs/ci-guardian.md'"
```

## PR Description Template

The PR Craftsman uses spec artifacts to create comprehensive descriptions:

```markdown
## Summary
[1-3 bullets from requirements spec]

## Changes
[Grouped by area, derived from tasks spec]

## Spec References
- Requirements: `.wannabuild/spec/requirements.md`
- Design: `.wannabuild/spec/design.md`
- Tasks: `.wannabuild/spec/tasks.md`

## Testing
- Integration tests: [count] written, all passing
- Review: Active-set unanimous PASS in [N] iterations
- Test coverage: All acceptance criteria have integration tests

## Execution Evidence
- Checkpoints reviewed: [count]
- Latest checkpoint window: [task-step range]

## Review History
- Iteration 1 (base set): [[passes]/[active_count] PASS] — fixed [issues]
- Iteration 2+ (adaptive): [[passes]/[active_count] PASS] — approved
```

## CI Guardian: Integration Test Hard Gate

The integration tester is the terminal hard gate (doctrine Mandate 3). CI Guardian
MUST confirm the integration suite **ran and passed in a real environment** — a green
CI run, or a provisioned/local run with captured exit code and output. This is a
blocking gate, not advisory flagging:

- Confirms the integration suite is part of CI configuration **and** that the job
  actually executed (not skipped, not cached-out, not errored).
- Confirms integration tests ran and passed (`total > 0`, `failed == 0`,
  `errored == 0`), not just unit tests, with the captured run recorded in
  `.wannabuild/outputs/ci-guardian.md`.
- If the integration suite is skipped, absent, errored, or did not complete, the result
  is **FAIL**. A FAIL **blocks** the phase. There is no override path and no
  acknowledgment that lets Ship proceed past it (doctrine Mandate 3).
- If CI does not run the integration suite, CI Guardian MUST run the full integration
  suite locally (or in a provisioned environment per Mandate 2), capture exit code and
  output, and gate on that real result — never on the mere presence of a test file.
- Reports full check status with timing and the recorded execution evidence.

## Delivery Strategy

Delivery is the one decision in this phase that affects outward/destructive behavior,
so the orchestrator collaborates: it presents the options with a recommended default
and the trade-off of each, then waits for the user to choose (doctrine Mandate 4).
This prompt fires only after the integration hard gate has passed.

> Checks are green and the integration suite passed. How do you want to ship?
> (Recommended: option 2 — it gives a review trail plus CI on the PR.)
>
> 1. **Merge locally** — fastest, but no PR review trail and no PR-level CI.
> 2. **Push branch and create a PR** — RECOMMENDED; gives review plus CI on the PR.
> 3. **Push directly to `origin/main`** — only if the branch is unprotected; bypasses
>    review. Outward action, so it requires explicit confirmation.
> 4. **Stop after local preparation** — leaves verified work committed locally for you
>    to deliver later.

The orchestrator executes only the user-selected path; it never picks silently. After
execution, cleanup is **mandatory** and runs with deterministic criteria:

- Remove a temporary worktree once its branch is merged or no longer checked out.
- Delete the topic branch only after its PR is merged or the user confirms abandonment.
- Remove generated transient files under `.wannabuild/tmp/`.
- Verify the tree is clean (`git status --porcelain` empty) and record the final state.

## State Update

Merge into existing state.json (preserving `mode` and all other existing keys):

```json
{
  "current_phase": "ship",
  "phase_status": "complete",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "design": ".wannabuild/spec/design.md",
    "tasks": ".wannabuild/spec/tasks.md"
  },
  "ship": {
    "pr_number": 42,
    "pr_url": "https://github.com/user/repo/pull/42",
    "ci_status": "passed",
    "delivery_strategy": "push_pr"
  },
  "next_phase": "document"
}
```

## Handoff to Document

```json
{
  "phase": "document",
  "from": "ship",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "design": ".wannabuild/spec/design.md",
    "tasks": ".wannabuild/spec/tasks.md"
  },
  "ship": {
    "pr_number": 42,
    "pr_url": "...",
    "merge_commit": "abc1234"
  }
}
```

## Edge Cases

Each edge case is an obligation to acquire a resource or collaborate on a decision —
never a license to skip PR creation, testing, or the integration gate (doctrine
Mandates 2 and 3). Every claimed blocker requires a logged attempt in
`.wannabuild/outputs/acquisition-log.json` (`assert-acquisition-attempted`).

- **No remote detected:** Do not skip PR creation by assumption. First run
  `git remote -v`. If none, present the user with options each carrying a recommended
  default — recommended: create a GitHub remote via `gh repo create` and proceed with
  the PR flow; alternatives: connect an existing remote, or choose the merge-locally /
  stop-after-prep delivery path. Record the attempt in the acquisition log.
- **Protected branch:** Present options with a recommendation — recommended: open a PR
  and request the required reviewers; alternatives: ask an admin to approve, or stop
  after local preparation. Do not attempt a direct push to a protected branch.
- **CI failures:** ANY unresolved failing required check (test, build, lint, infra,
  env) **blocks** the merge — there is no "only test failures route back" carve-out.
  CI Guardian diagnoses and, before reporting any failure as environmental/external,
  MUST attempt to obtain the missing resource per Mandate 2 (provision a DB branch on
  Supabase/Neon, set required env/vars on the CI or Railway/Vercel build, generate
  fixtures, read live docs via Context7) and record each attempt in the acquisition
  log. A test failure routes back to the implementer; an unrecoverable
  billable/outward/destructive blocker is surfaced to the user — neither is silently
  shipped past.
- **Merge conflicts:** First attempt an automated rebase/merge, then re-run the full
  integration suite and re-gate on it. If the conflict cannot be resolved
  automatically, present the conflicting hunks and ask the user how to resolve; never
  ship without the integration suite passing on the resolved tree.
- **No CI pipeline detected:** The phase MUST NOT proceed on acknowledgment alone. CI
  Guardian MUST first obtain a real verification environment: run the full integration
  suite locally and capture exit code and output, **and** offer to provision CI
  (scaffold a GitHub Actions workflow, or a Railway/Vercel build pipeline) with that as
  the recommended option. The integration hard gate is satisfied only by a captured
  passing run; the absence of a pipeline never satisfies it.

## Quality Checklist

- [ ] Checkpoint evidence is complete and reviewable
- [ ] Working tree verified clean via `git status --porcelain` (empty)
- [ ] Integration suite ran and PASSED in a real environment (green CI run OR
      provisioned/local run with captured exit code and output) — REQUIRED for every
      delivery path, including merge-locally and stop-after-prep
- [ ] Delivery path confirmed by the user's explicit selection
- [ ] Selected delivery action completed
- [ ] All required CI checks green when a PR or pushed branch is involved
- [ ] Post-delivery cleanup completed (worktrees, topic branch, `.wannabuild/tmp/`,
      clean `git status`)

## Contract Validation

- PR readiness requires:
  - a verified-clean working tree (`git status --porcelain` empty). There is no
    free-text skip: if the tree is dirty, the agent MUST commit or stash the changes
    (or surface them and ask) before proceeding.
  - committed implementation artifacts
  - merged checkpoints reviewed from implement phase
- PR craftsman output MUST include all three spec references AND integration-test proof
  (the recorded passing run). Missing either is a contract violation that blocks the
  phase.
- CI guardian MUST verify the integration suite actually ran and passed in CI (or in a
  provisioned/local run with captured output), not merely that the tests are listed in
  the CI commandset or present locally. A listed-but-not-executed suite is a FAIL.
