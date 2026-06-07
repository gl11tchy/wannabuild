# WannaBuild Tasks Phase

## Contract Standard

This prompt follows `docs/contract-standard.md` and the four mandates in
`skills/internal/build/references/doctrine.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed. Scope validation is mandatory on every run and its PASS is an
unconditional hard gate (Mandate 3); no gate in this phase is conditioned on whether an
optional step "was run". Specialist judgment is advisory; the mandatory steps below are not.

> Phase 3 of 7 in the WannaBuild SDD pipeline. Decomposes the design into ordered, atomic implementation tasks with dependencies, acceptance criteria, and required integration tests.

## Agents

Tasks use these specialist perspectives. Scope validation always runs; the other two run
when the objective decision table below fires. Selection is deterministic — the same input
selects the same agents every run.

| Agent | File | Role |
|---|---|---|
| Task Decomposer | `wb-task-decomposer` | Breaks design into atomic tasks |
| Dependency Mapper | `wb-dependency-mapper` | Maps task dependencies, critical path, and parallelization opportunities |
| Scope Validator | `wb-scope-validator` | Validates task coverage against requirements |

### Specialist decision table (deterministic, not judgment)

| Specialist | Runs when | Floor |
|---|---|---|
| Scope Validator | Always | MANDATORY every run — no exception, no bypass |
| Task Decomposer | The design names more than 1 component OR the plan anticipates more than 5 tasks | Required when either threshold is met |
| Dependency Mapper | Any task declares a dependency on another task, OR more than 1 task touches a shared file | Required when either condition is met |

This is a fixed pipeline with adaptive depth (Mandate 4): which specialists run is fully
determined by the table, never by "smallest useful set" or run-to-run judgment. Scope
validation is the un-skippable floor.

## Trigger Conditions

**Explicit:**

- `/wannabuild-tasks` (auto-prefixed when installed as plugin)
- "Break this into tasks"
- "What do we need to do?"

**Implicit (from orchestrator):**

- Design phase completes → auto-transition to Tasks

## Input

**Handoff from Design:**

```json
{
  "phase": "tasks",
  "from": "design",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "design": ".wannabuild/spec/design.md"
  },
  "codebase_path": "/path/to/project"
}
```

## Execution Flow

1. Read `spec/requirements.md` and `spec/design.md` completely.
2. **Upstream-quality pre-check (mandatory).** Confirm `requirements.md` contains an
   Acceptance Criteria section with at least one concrete, checkable criterion, and that
   `design.md` is substantive (names the components/data/interfaces the tasks will touch).
   If either file is stub-quality, missing acceptance criteria, or internally ambiguous,
   STOP — do not decompose against an unmeasurable goal. Return control to the
   Discover/Requirements phase for collaborative grilling (one question at a time, each
   with a recommended answer) and re-enter Tasks only after `assert-discovery-ready` passes.
3. Run task decomposition when the design names more than 1 component or the plan
   anticipates more than 5 tasks (per the specialist decision table).
4. Run **scope validation on every run** (mandatory): it must verify a bidirectional
   mapping — every requirement item in `requirements.md` maps to at least one task ID, AND
   every task ID maps to at least one requirement item. Run dependency mapping when any task
   declares a dependency or more than 1 task touches a shared file.
5. Record specialist-selection rationale (which table conditions fired) in
   `.wannabuild/decisions.md`.
6. Present the task plan plus a DECISIONS block to the user for collaborative review.
7. Write `.wannabuild/spec/tasks.md` only after Scope Validator emits PASS.

## Agent Spawning

### Adaptive pattern

```text
Task(subagent_type="<selected specialist>", run_in_background=<true only when independent>)
  capability_tier: <lightweight / standard / strong>
  reasoning_effort: <low / medium / high>
  ownership: <task decomposition / dependency mapping / scope coverage / test planning>
  prompt: "Analyze the requirements and design for <specific ownership area>.
           Write your full report to .wannabuild/outputs/<agent>-tasks.md.
           Return ONLY: 'COMPLETE - [one sentence]. Report at <path>'"
```

Spawn the specialists the decision table selected. Run them in parallel when their work is
independent; run them sequentially when one's output feeds the next decision. The selection
itself is fixed by the table — parallel vs. sequential is the only execution choice here.

## Synthesis

After selected analysis completes, the orchestrator reads the relevant `.wannabuild/outputs/` files:

1. **Start with a coherent task list** derived from the requirements and design
2. **Overlay dependencies** whenever dependency mapping ran (it runs whenever the table fires)
3. **Address coverage gaps from the mandatory scope validation:**
   - Missing tasks (uncovered requirement) → add them; a requirement may never ship without a task
   - Scope creep tasks (task with no requirement) → flag for user decision, do not silently keep or drop
   - Missing integration tests → add an Integration Test field to every task with externally-observable behavior
4. **Add critical path** and parallelization info whenever dependency mapping ran
5. **Add delegation guidance:** note which slices should stay single-owner and which can run in parallel
6. **Final validation:** Every task has files, acceptance criteria, integration test requirements, and micro-step checkpoints, and Scope Validator has emitted PASS
7. **Present to user** with a DECISIONS block for collaborative review

## Output Artifact

The phase produces `.wannabuild/spec/tasks.md`:

```markdown
# Task Spec

## Tasks

### Task 1: [Clear, imperative title]
- **Status:** pending
- **Files:** [specific files to create/modify]
- **Dependencies:** none
- **Acceptance:** [how to verify]
- **Integration Test:** [scenario] | resource: [concrete resource the test runs against — local app, ephemeral DB branch, real browser, fixture, edge function] | acquisition: [how QA obtains that resource per Mandate 2 — run locally, spin Supabase/Neon branch, drive Chrome, generate fixtures]
- **Complexity:** S/M/L
- **Micro-Steps:**
  1. [2–5 min step]
     - **Verify:** [command + expected output]
     - **Checkpoint:** `.wannabuild/checkpoints/task-1-step-1.md`

### Task 2: [title]
- **Status:** pending
- **Files:** [files]
- **Dependencies:** Task 1
- **Acceptance:** [criteria]
- **Integration Test:** [scenario] | resource: [concrete resource] | acquisition: [acquisition path]
- **Complexity:** S/M/L
- **Micro-Steps:**
  1. [2–5 min step]
     - **Verify:** [command + expected output]
     - **Checkpoint:** `.wannabuild/checkpoints/task-2-step-1.md`

[Continue for all tasks...]

## Critical Path
Task [X] → Task [Y] → Task [Z]
**Estimated duration:** [sum of critical path]

## Parallelization Opportunities
- **Group A:** Tasks [X, Y] (no mutual dependencies)
- **Group B:** Tasks [Z, W] (after Group A)

## Delegation Guidance
- **Recommended shape:** [single-owner / focused specialist / parallel slices]
- **Capability tier:** [lightweight / standard / strong]
- **Reasoning effort:** [low / medium / high]
- **Rationale:** [complexity, coupling, risk, uncertainty, ownership]

## Coverage Summary
- **Requirements covered:** [N/N], computed by Scope Validator (not self-asserted). The 100% claim is valid only when Scope Validator emits PASS.
- **Uncovered requirements:** [list each, with a recommended resolution for the user to confirm — none allowed at handoff]
- **Scope-creep tasks:** [list each task with no requirement, with a recommended resolution for the user to confirm]
- **Integration tests specified:** [N/N] tasks with externally-observable behavior (each names its resource and acquisition path)
```

## State Update

Merge into existing state.json:

```json
{
  "current_phase": "tasks",
  "phase_status": "complete",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "design": ".wannabuild/spec/design.md",
    "tasks": ".wannabuild/spec/tasks.md"
  },
  "next_phase": "implement"
}
```

## Handoff to Implement Phase

Standard handoff:

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

## User Interaction

After synthesis, present the plan plus a DECISIONS block — this is the Plan→Implement phase
boundary, so it is a hard stop that requires an explicit approval word ("go", "proceed",
"approved", "continue", "next", "lgtm", "do it"). A vague acknowledgment ("ok", "sure")
does not cross the boundary.

> Here's your implementation plan — [N] tasks on the critical path, estimated [size]. Each task has target files, acceptance criteria, required integration tests (with named resources), and micro-step checkpoints. Before we start coding, confirm these DECISIONS:
>
> 1. **Decomposition granularity:** [chosen granularity]. Recommended: [answer] — [one-line rationale].
> 2. **Parallelization groups:** [proposed groups]. Recommended: [answer] — [rationale].
> 3. **Flagged scope-creep tasks (if any):** [task]. Recommended: keep / drop / split — [rationale].
> 4. **Coverage:** Scope Validator reports [N/N] requirements covered. [If any uncovered, list with recommended resolution.]
>
> Reply with an explicit approval word to proceed, or tell me which decision to change.

The user can:

- **Approve:** Move to Implement phase (requires an explicit approval word)
- **Reorder:** Change task priorities or dependencies
- **Split/merge:** Break large tasks into smaller ones or combine related ones
- **Remove:** Drop tasks (Scope Validator re-runs; a removal that uncovers a requirement is blocked until the user confirms a replacement)
- **Add:** Insert new tasks (Scope Validator re-runs to verify coverage)

## Quality Checklist

- [ ] Every task has specific file targets (not vague descriptions)
- [ ] Every task has verifiable acceptance criteria
- [ ] Every task with externally-observable behavior (UI, API, DB/migration, edge function, queue/job, external integration) has an Integration Test field that names its scenario, resource, and acquisition path
- [ ] Dependencies are correctly mapped (no circular deps)
- [ ] Critical path is identified whenever dependency mapping ran
- [ ] Every requirement from `spec/requirements.md` maps to at least one task (no uncovered requirements)
- [ ] Every task maps to at least one requirement (no orphan/scope-creep tasks, or each is flagged for user decision)
- [ ] All acceptance criteria have integration test coverage in task specs
- [ ] Task sizes are honest (no L tasks that should be broken down)
- [ ] Every task includes ordered Micro-Steps with 2–5 min granularity
- [ ] Every micro-step has Verify + Checkpoint fields
- [ ] No single micro-step exceeds ~15 minutes without explicit split
- [ ] Scope Validator was run (it is mandatory) and its verdict is PASS

## Contract Validation

- `spec/tasks.md` must include at least:
  - `## Tasks`
  - Task entries with `**Files:**`, `**Acceptance:**`, `**Integration Test:**`
  - `Micro-Steps` entries that include `**Verify:**` and `**Checkpoint:**`
- **Scope validation is mandatory and `Scope-validator` MUST return PASS before implementation starts.** This is a fail-closed gate with no "if it was run" qualifier — scope validation always runs.
- **Bidirectional coverage (fail-closed):** every requirement item in `requirements.md` MUST map to at least one task ID (no uncovered requirements), AND every task ID MUST map to at least one requirement item (no orphan/scope-creep tasks). Any uncovered requirement blocks handoff to Implement.
- **Whenever dependency mapping ran, `Dependency-mapper` MUST provide `critical_path` and `parallelization` sections.** Dependency mapping runs whenever the specialist decision table fires; when it ran, these sections are required, not optional.

## Edge Cases

- **Circular dependencies detected:** Dependency Mapper flags them. Orchestrator asks user to resolve by restructuring tasks.
- **Scope gaps found:** Scope Validator returns FAIL. Orchestrator adds missing tasks and re-runs validation.
- **Too many tasks:** If > 20 tasks, suggest breaking into milestones or multiple WannaBuild sessions.
- **User already has tasks:** Import them, then run the FULL Quality Checklist and the MANDATORY Scope Validator pass against `requirements.md` and `design.md`. Imported tasks may not enter Implement until Scope Validator emits PASS and bidirectional coverage holds. Importing a task plan never bypasses this phase's gates.
