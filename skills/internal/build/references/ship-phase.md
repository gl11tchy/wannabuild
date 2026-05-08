> Internal reference: this preserves the legacy Ship phase contract for orchestrator use; it is not a public top-level Claude-discoverable skill surface.

# WannaBuild: Ship Phase

> "Let's get this merged."

Phase 6 of 7 in the WannaBuild SDD pipeline. Prepares verified work for delivery, asks the user for the delivery path, executes it, and cleans up.

## Agents

| Agent | File | Role | Execution |
|-------|------|------|-----------|
| PR Craftsman | `wb-pr-craftsman` | Creates PR with spec-referenced description | **First** (sequential) |
| CI Guardian | `wb-ci-guardian` | Monitors CI, verifies integration tests in pipeline | **Then** (sequential, after PR) |

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
  prompt: "Monitor CI for PR #{pr_number}. Verify integration tests run in pipeline.
           Write your full CI report to .wannabuild/outputs/ci-guardian.md.
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

## CI Guardian: Integration Test Verification

The CI Guardian specifically verifies that integration tests run in the CI pipeline:

- Confirms test suite is part of CI configuration
- Verifies integration tests passed (not just unit tests)
- Flags if integration tests were skipped or absent from CI
- Reports full check status with timing

## Delivery Strategy

After final local verification passes, the orchestrator presents delivery options to the user:

> Checks are green. How do you want to ship?
>
> 1. **Merge locally**
> 2. **Push branch and create a PR**
> 3. **Push directly to `origin/main`**
> 4. **Stop after local preparation**

The orchestrator executes only the selected path. After execution, run cleanup: prune/remove temporary worktrees when safe, delete topic branches when appropriate, remove generated transient files, and verify final git status.

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

- **No remote repository:** Skip PR creation, just verify local state is clean.
- **Protected branch:** Guide user through required approvals.
- **CI failures:** CI Guardian diagnoses and reports. If it's a test failure, route back to implementer.
- **Merge conflicts:** Guide user through resolution, then re-run CI.
- **No CI pipeline:** CI Guardian reports the gap and recommends setup. Ship proceeds with user acknowledgment.

## Quality Checklist

- [ ] Checkpoint evidence is complete and reviewable
- [ ] All changes committed (no dirty working tree)
- [ ] Delivery path confirmed by user
- [ ] Selected delivery action completed
- [ ] CI checks passed when a PR or pushed branch is involved
- [ ] Post-delivery cleanup completed

## Contract Validation

- PR readiness requires:
  - clean working tree or explicit user-confirmed skip reason
  - committed implementation artifacts
  - merged checkpoints reviewed from implement phase
- PR craftsman output should include all three spec references and integration test proof.
- CI guardian must verify integration tests are part of CI commandset, not only present locally.
