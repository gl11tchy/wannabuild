# WannaBuild Tasks Phase

> Phase 3 of 7 in the WannaBuild SDD pipeline. Decomposes the design into ordered, atomic implementation tasks with dependencies, acceptance criteria, and required integration tests.

## Agents

Tasks can use these specialist perspectives when they materially improve task quality:

| Agent | File | Role |
|---|---|---|
| Task Decomposer | `wb-task-decomposer` | Breaks design into atomic tasks |
| Dependency Mapper | `wb-dependency-mapper` | Maps task dependencies, critical path, and parallelization opportunities |
| Scope Validator | `wb-scope-validator` | Validates task coverage against requirements |

Do not force a fixed three-agent pattern. The orchestrator chooses the smallest useful set based on complexity, coupling, risk, and uncertainty.

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
2. Decide whether the task plan can be produced single-owner or needs specialist analysis.
3. Use task decomposition first only when the work needs structured breakdown before dependency or coverage review.
4. Add dependency mapping, scope validation, or other checks only when they answer distinct questions.
5. Record delegation rationale in `.wannabuild/decisions.md`.
6. Present the task plan to the user for review.
7. Write `.wannabuild/spec/tasks.md`.

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

Use multiple agents only when their work can proceed independently or when sequential output from one agent is needed before the next decision.

## Synthesis

After selected analysis completes, the orchestrator reads the relevant `.wannabuild/outputs/` files:

1. **Start with a coherent task list** derived from the requirements and design
2. **Overlay dependencies** when dependency analysis was run
3. **Address coverage gaps** when scope validation was run:
   - Missing tasks → add them
   - Scope creep tasks → flag for user decision
   - Missing integration tests → add Integration Test field to tasks
4. **Add critical path** and parallelization info when useful
5. **Add delegation guidance:** note which slices should stay single-owner and which can run in parallel
6. **Final validation:** Every task has files, acceptance criteria, integration test requirements, and micro-step checkpoints
7. **Present to user** for review

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
- **Integration Test:** [required test scenarios]
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
- **Integration Test:** [required tests]
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
- **Requirements covered:** [N/N] (100%)
- **Integration tests specified:** [N/N] tasks
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

After synthesis:

> Here's your implementation plan — [N] tasks on the critical path, estimated [size]. Each task has target files, acceptance criteria, required integration tests, and micro-step checkpoints defined. Review the task order and let me know if you want to adjust anything before we start coding.

The user can:

- **Approve:** Move to Implement phase
- **Reorder:** Change task priorities or dependencies
- **Split/merge:** Break large tasks into smaller ones or combine related ones
- **Remove:** Drop tasks (with warning if it creates coverage gaps)
- **Add:** Insert new tasks (Scope Validator re-runs to verify coverage)
- **Skip:** Jump to implementation if they already have a task plan

## Quality Checklist

- [ ] Every task has specific file targets (not vague descriptions)
- [ ] Every task has verifiable acceptance criteria
- [ ] Every user-facing task has an Integration Test field
- [ ] Dependencies are correctly mapped (no circular deps)
- [ ] Critical path is identified when dependency mapping was needed
- [ ] All requirements from `spec/requirements.md` have task coverage
- [ ] All acceptance criteria have integration test coverage in task specs
- [ ] Task sizes are honest (no L tasks that should be broken down)
- [ ] Every task includes ordered Micro-Steps with 2–5 min granularity
- [ ] Every micro-step has Verify + Checkpoint fields
- [ ] No single micro-step exceeds ~15 minutes without explicit split
- [ ] Scope Validator verdict is PASS when scope validation was run

## Contract Validation

- `spec/tasks.md` must include at least:
  - `## Tasks`
  - Task entries with `**Files:**`, `**Acceptance:**`, `**Integration Test:**`
  - `Micro-Steps` entries that include `**Verify:**` and `**Checkpoint:**`
- If scope validation was run, `Scope-validator` must return PASS before implementation starts.
- If dependency mapping was run, `Dependency-mapper` must provide `critical_path` and `parallelization` sections.
- Task IDs from `Tasks` must map to requirement items from `requirements.md` (no orphan tasks).

## Edge Cases

- **Circular dependencies detected:** Dependency Mapper flags them. Orchestrator asks user to resolve by restructuring tasks.
- **Scope gaps found:** Scope Validator returns FAIL. Orchestrator adds missing tasks and re-runs validation.
- **Too many tasks:** If > 20 tasks, suggest breaking into milestones or multiple WannaBuild sessions.
- **User already has tasks:** Validate existing tasks against specs rather than generating new ones.
