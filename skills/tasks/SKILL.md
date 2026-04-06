# WannaBuild Tasks Phase

> Phase 3 of 7 in the WannaBuild SDD pipeline. Decomposes the design into ordered, atomic implementation tasks with dependencies, acceptance criteria, and required integration tests.

## Agents

Tasks use a sequential-then-parallel pattern with three agents:

| Agent | File | Role | Execution |
|-------|------|------|-----------|
| Task Decomposer | `wb-task-decomposer` | Breaks design into atomic tasks | **First** (needs design spec) |
| Dependency Mapper | `wb-dependency-mapper` | Maps task dependencies and critical path | **Then parallel** |
| Scope Validator | `wb-scope-validator` | Validates task coverage against requirements | **Then parallel** |

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

```
spec/requirements.md + spec/design.md (input)
        │
        ▼
┌──────────────────────────┐
│  Task Decomposer (first) │
│  Reads both specs        │
│  Produces task list      │
└────────────┬─────────────┘
             │
             ▼
┌────────────────────────────────────────┐
│  Parallel Validation                   │
│                                        │
│  ┌────────────────┐ ┌───────────────┐  │
│  │  Dependency    │ │    Scope      │  │
│  │   Mapper       │ │  Validator    │  │
│  │  (ordering)    │ │  (coverage)   │  │
│  └───────┬────────┘ └──────┬────────┘  │
│          │                 │           │
└──────────┼─────────────────┼───────────┘
           │                 │
           ▼                 ▼
     ┌──────────────────────────────┐
     │  Orchestrator                │
     │  Merge: tasks + deps + gaps  │
     └─────────────┬────────────────┘
                   │
                   ▼
     Present to user for review
                   │
                   ▼
     Write .wannabuild/spec/tasks.md
```

## Agent Spawning

**Step 1 — Task Decomposer (foreground, must complete first)**
```
Task(subagent_type="wb-task-decomposer")
  prompt: "Decompose into tasks. Requirements: {requirements_path}. Design: {design_path}. Codebase: {codebase_path}.
           Write your full task list to .wannabuild/outputs/task-decomposer.md.
           Return ONLY: 'COMPLETE — [N] tasks decomposed. Report at .wannabuild/outputs/task-decomposer.md'"
```

After Step 1 completes, read `.wannabuild/outputs/task-decomposer.md` to get the task list for passing to Step 2 agents.

**Step 2 — Dependency Mapper + Scope Validator (parallel background)**
```
Task(subagent_type="wb-dependency-mapper", run_in_background=true)
  prompt: "Map dependencies for tasks at .wannabuild/outputs/task-decomposer.md. Design: {design_path}.
           Write your full dependency analysis to .wannabuild/outputs/dependency-mapper.md.
           Return ONLY: 'COMPLETE — [one sentence summary]. Report at .wannabuild/outputs/dependency-mapper.md'"

Task(subagent_type="wb-scope-validator", run_in_background=true)
  prompt: "Validate coverage. Requirements: {requirements_path}. Design: {design_path}. Tasks: .wannabuild/outputs/task-decomposer.md.
           Write your full validation report to .wannabuild/outputs/scope-validator.md.
           Return ONLY: 'COMPLETE — [one sentence summary]. Report at .wannabuild/outputs/scope-validator.md'"
```

## Synthesis

After all agents complete, the orchestrator reads `.wannabuild/outputs/task-decomposer.md`, `.wannabuild/outputs/dependency-mapper.md`, and `.wannabuild/outputs/scope-validator.md`:

1. **Start with the task list** from Task Decomposer
2. **Overlay dependencies** from Dependency Mapper (update task Dependencies fields)
3. **Address coverage gaps** from Scope Validator:
   - Missing tasks → add them
   - Scope creep tasks → flag for user decision
   - Missing integration tests → add Integration Test field to tasks
4. **Add critical path** and parallelization info from Dependency Mapper
5. **Final validation:** Every task has files, acceptance criteria, integration test requirements, and micro-step checkpoints
6. **Present to user** for review

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
- [ ] Critical path is identified
- [ ] All requirements from `spec/requirements.md` have task coverage
- [ ] All acceptance criteria have integration test coverage in task specs
- [ ] Task sizes are honest (no L tasks that should be broken down)
- [ ] Every task includes ordered Micro-Steps with 2–5 min granularity
- [ ] Every micro-step has Verify + Checkpoint fields
- [ ] No single micro-step exceeds ~15 minutes without explicit split
- [ ] Scope Validator verdict is PASS

## Contract Validation

- `spec/tasks.md` must include at least:
  - `## Tasks`
  - Task entries with `**Files:**`, `**Acceptance:**`, `**Integration Test:**`
  - `Micro-Steps` entries that include `**Verify:**` and `**Checkpoint:**`
- `Scope-validator` must return PASS before implementation starts.
- `Dependency-mapper` must provide `critical_path` and `parallelization` sections.
- Task IDs from `Tasks` must map to requirement items from `requirements.md` (no orphan tasks).

## Edge Cases

- **Circular dependencies detected:** Dependency Mapper flags them. Orchestrator asks user to resolve by restructuring tasks.
- **Scope gaps found:** Scope Validator returns FAIL. Orchestrator adds missing tasks and re-runs validation.
- **Too many tasks:** If > 20 tasks, suggest breaking into milestones or multiple WannaBuild sessions.
- **User already has tasks:** Validate existing tasks against specs rather than generating new ones.
