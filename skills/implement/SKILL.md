# WannaBuild: Implement Phase

> "Let's build this thing."

Phase 4 of 7 in the WannaBuild SDD pipeline. The implementer works through the task spec in micro-steps, writing feature code and integration tests with checkpoint evidence after each verified step.

## Agent

| Agent | File | Role |
|-------|------|------|
| Implementer (default) | `wb-implementer` | Executes tasks from spec using the parent session model, writes code + integration tests, checkpoints |
| Implementer (escalated) | `wb-implementer-escalated` | Same implementation role, but inherits parent model for high-complexity work and review-loop remediation |

This phase may run single-owner or parallel implementation depending on the task plan.

- Use single-owner implementation when tasks are tightly coupled, tiny, or need one coherent editor.
- Use parallel implementation only for disjoint slices with explicit file/module/acceptance ownership.
- Choose capability tier and reasoning effort from task complexity, risk, uncertainty, and remediation history.
- Do not hard-code concrete model IDs or fixed implementer counts.
- Record execution shape and delegation rationale in `.wannabuild/decisions.md` or checkpoints.

Advisor escalation may assist the implementer when the path is materially uncertain, but it does not replace the implementer. The implementer remains the foreground executor with full tool ownership; the advisor only provides bounded guidance, correction, risk assessment, or a stop signal.

## Trigger Conditions

**Explicit:**
- `/wannabuild-implement` (auto-prefixed when installed as plugin)
- "Let's build it" / "Start coding" / "Implement"

**Implicit (from orchestrator):**
- Tasks phase completes → auto-transition to Implement

## Input

**Handoff from Tasks:**
```json
{
  "phase": "implement",
  "from": "tasks",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "design": ".wannabuild/spec/design.md",
    "tasks": ".wannabuild/spec/tasks.md"
  },
  "codebase_path": "/path/to/project"
}
```

The implementer reads all three spec artifacts before writing any code.

Before writing any code, run:

```bash
scripts/validate-wannabuild-artifacts.sh . implement
```

Pause and resolve contract violations before proceeding.

## Execution Flow

1. Read `spec/requirements.md`, `spec/design.md`, and `spec/tasks.md`.
2. Read the task plan's Delegation Guidance.
3. Choose implementation shape:
   - single-owner for coupled work
   - parallel slices for disjoint ownership
   - stronger capability/higher reasoning for high-risk or ambiguous slices
4. Study existing code and local conventions.
5. Implement in micro-steps with tests and verification.
6. Write checkpoints for each completed micro-step.
7. Integrate parallel slices before Review.
8. Run transition validation and hand off to Review.

## Agent Spawning

```
# Single-owner path
Task(subagent_type="<selected implementer>")
  capability_tier: <standard or strong>
  reasoning_effort: <medium or high>
  ownership: <all tasks or specific remediation slice>
  prompt: "Implement owned tasks from .wannabuild/spec/tasks.md.
           Read the full spec chain at .wannabuild/spec/ first.
           Codebase at: {codebase_path}.
           Write checkpoints and delegation rationale."

# Parallel path
for each independent slice:
  Task(subagent_type="<selected implementer>", run_in_background=true)
    capability_tier: <standard or strong>
    reasoning_effort: <medium or high>
    ownership: <disjoint files/modules/acceptance criteria>
    prompt: "Implement only your owned slice.
             You are not alone in the codebase; do not revert others' edits.
             Write checkpoints and return a compact completion summary."
```

Use background implementers only when the host supports safe parallel editing and the slices have disjoint write ownership. Otherwise keep the foreground implementer as the single tool-using owner.

## Integration Tests Are Non-Negotiable

Every task with an "Integration Test" field MUST have corresponding test code. The implementer agent's prompt enforces this:

- Write the integration test first (when applicable)
- The test should define "working" before the feature code exists
- A task is NOT complete until its tests pass
- This is validated by `wb-integration-tester` in the Review phase

## Checkpoint Format

Each completed micro-step writes a checkpoint file at:
- `.wannabuild/checkpoints/task-{N}-step-{M}.md`

Checkpoint content should include:
- changed files
- verify command + result
- pending next micro-step
- execution shape and delegation rationale when the step used or integrated sub-agent work

## Task Execution Protocol

For each task in `spec/tasks.md`:

1. **Read the task** — understand files, deps, acceptance criteria, required tests
2. **Check dependencies** — verify prerequisite tasks are complete
3. **Study existing code** — read target files, match patterns and conventions
4. **Execute micro-steps in order** — one micro-step at a time (`read step -> implement minimal change -> verify -> write checkpoint -> continue`)
5. **Write or update tests** — derive expected behavior from the clarified requirements; use TDD when it helps, but do not replace product intent with test mechanics
6. **Run tests** — verify changes work and don't break existing tests
7. **Write checkpoint evidence** — `.wannabuild/checkpoints/task-{N}-step-{M}.md`
8. **Report status** — mark task complete, note any deviations from spec

## Handling Review Feedback

When the quality loop sends feedback (after a FAIL verdict), the implementer receives aggregated issues:

```json
{
  "iteration": 2,
  "issues_by_file": {
    "src/auth.ts": [
      {"agent": "wb-security-reviewer", "severity": "critical", "issue": "...", "recommendation": "..."}
    ]
  }
}
```

The escalated implementer (`wb-implementer-escalated`) addresses each issue, runs tests again, and records checkpoint evidence per micro-step. Remediation should stay scoped to failing areas so adaptive review reruns remain fast. It does NOT skip integration test requirements — those are non-negotiable regardless of which iteration.

Use advisor escalation during remediation only when the fix path is unclear, reviewer findings conflict, the likely fix changes architecture or validation strategy, or continuing could worsen risk. The advisor must not call tools, edit files, run commands, or produce user-facing output. If the guidance changes implementation strategy, architecture, scope, or validation, record the decision in `.wannabuild/decisions.md` and, when useful, save a compact report under `.wannabuild/outputs/advisor/`.

## Coding Standards

- **Follow existing patterns.** Match the codebase's style, naming, and structure.
- **Quality, not perfection.** Ship working code. Don't gold-plate.
- **checkpoint every micro-step.**
- **VCS commits are optional during micro-steps, but mandatory before ship/PR creation.**
- **Test as you go.** Run the test suite after each task.

## When to Ask vs. Push Forward

**Ask the user:**
- Requirements are ambiguous and could go either way
- A task seems impossible or contradicts the design spec
- External dependencies are unavailable
- The task is significantly larger than estimated

**Push forward:**
- Minor implementation details not covered by spec
- Choice between equivalent approaches
- Small deviations that don't affect acceptance criteria

## Output

The implementer reports per-task progress:

```markdown
### Task [N]: [title] — COMPLETE
**Files changed:** [list]
**Tests written:** [test file: descriptions]
**Checkpoints:** [.wannabuild/checkpoints/task-{N}-step-{M}.md, ...]
**Notes:** [discoveries, deviations]
```

And a final summary:

```markdown
## Implementation Summary
- **Tasks completed:** [N/total]
- **Tests written:** [count]
- **Tests passing:** [count]
- **Blockers:** [any unresolved issues]
- **Spec deviations:** [any differences and why]
```

## State Update

Merge into existing state.json (preserving `mode` and all other existing keys):

```json
{
  "current_phase": "implement",
  "phase_status": "complete",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "design": ".wannabuild/spec/design.md",
    "tasks": ".wannabuild/spec/tasks.md"
  },
  "next_phase": "review"
}
```

## Handoff to Review

```json
{
  "phase": "review",
  "from": "implement",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "design": ".wannabuild/spec/design.md",
    "tasks": ".wannabuild/spec/tasks.md"
  },
  "implementation": {
    "tasks_completed": 8,
    "tasks_total": 8,
    "tests_written": 15,
    "checkpoints": [".wannabuild/checkpoints/task-1-step-1.md", "..."]
  }
}
```

Before handing off, rerun transition validation:

```bash
scripts/validate-wannabuild-artifacts.sh . review
```

Only launch review agents when this passes.

## Edge Cases

- **Task blocked by external dependency:** Report the blocker, skip the task, continue with unblocked tasks. Flag in summary.
- **Spec is wrong:** If implementation reveals a spec error, note the deviation and explain why. Don't silently diverge.
- **Tests can't be written yet:** If test infrastructure doesn't exist, create it as part of the first task that needs tests.
- **Resuming after interruption:** Read `spec/tasks.md` for task statuses. Pick up from the first incomplete task.

## Quality Checklist

- [ ] All tasks from `spec/tasks.md` are complete
- [ ] Every task with an Integration Test field has written tests
- [ ] All tests pass (new and existing)
- [ ] Checkpoint evidence exists for each completed micro-step
- [ ] No hardcoded secrets, tokens, or credentials
- [ ] Code follows existing codebase patterns
- [ ] Spec deviations are documented

## Contract Validation

- If `design.md` is missing, proceed with `requirements + existing code patterns` and fail fast with explicit note before implementation begins.
- Each completed micro-step must produce one checkpoint with:
  - changed files
  - command + expected output
  - next pending step
- Any task with an `Integration Test` requirement must have a corresponding passing integration test in repo before it is marked complete.
- Handoff to review must include:
  - tasks completed count
  - checksums or file list from latest checkpoints
  - explicit test pass/fail counts
