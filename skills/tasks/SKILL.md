# WannaBuild Tasks Phase

> Phase 3 of 7 in the WannaBuild SDD pipeline. Decomposes the design into ordered, atomic implementation tasks with dependencies, acceptance criteria, and required integration tests.

## Agents

The agent set depends on the session mode (stored in `.wannabuild/state.json`). Both modes use the sequential-then-parallel pattern.

### Full Mode (3 agents)

| Agent | File | Role | Execution |
|-------|------|------|-----------|
| Task Decomposer | `wb-task-decomposer` | Breaks design into atomic tasks | **First** (needs design spec) |
| Dependency Mapper | `wb-dependency-mapper` | Maps task dependencies and critical path | **Then parallel** |
| Scope Validator | `wb-scope-validator` | Validates task coverage against requirements | **Then parallel** |

### Light Mode (2 agents)

| Agent | File | Role | Execution |
|-------|------|------|-----------|
| Task Decomposer | `wb-task-decomposer` | Breaks design into atomic tasks | **First** (needs design spec) |
| Scope Validator | `wb-scope-validator` | Validates task coverage against requirements | **Then** (background) |

## Trigger Conditions

**Explicit:**
- `/wannabuild-tasks` (auto-prefixed when installed as plugin)
- "Break this into tasks"
- "What do we need to do?"

**Implicit (from orchestrator):**
- Design phase completes → auto-transition to Tasks (Full mode)
- Requirements phase completes → auto-transition to Tasks (Light mode — design skipped)

## Input

**Handoff from Design (Full mode):**
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

**Handoff from Requirements (Light mode — no design.md):**
```json
{
  "phase": "tasks",
  "from": "requirements",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md"
  },
  "codebase_path": "/path/to/project"
}
```

## Execution Flow

**Full mode (decomposer → dependency-mapper + scope-validator in parallel):**
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

**Light mode (decomposer → scope-validator, no dependency-mapper, no design.md):**
```
spec/requirements.md (input — no design.md in Light mode)
        │
        ▼
┌──────────────────────────┐
│  Task Decomposer (first) │
│  Reads requirements      │
│  Infers from codebase    │
│  Produces task list      │
└────────────┬─────────────┘
             │
             ▼
     ┌───────────────┐
     │    Scope      │
     │  Validator    │
     │  (coverage)   │
     └──────┬────────┘
            │
            ▼
     ┌──────────────────────────────┐
     │  Orchestrator                │
     │  Merge: tasks + gaps         │
     └─────────────┬────────────────┘
                   │
                   ▼
     Present to user for review
                   │
                   ▼
     Write .wannabuild/spec/tasks.md
```

## Agent Spawning

**Step 1 — Full mode: Task Decomposer (foreground, must complete first)**
```
Task(subagent_type="wb-task-decomposer")
  prompt: "Decompose into tasks. Requirements: {requirements_path}. Design: {design_path}. Codebase: {codebase_path}.
           Write your full task list to .wannabuild/outputs/task-decomposer.md.
           Return ONLY: 'COMPLETE — [N] tasks decomposed. Report at .wannabuild/outputs/task-decomposer.md'"
```

**Step 1 — Light mode: Task Decomposer (foreground, must complete first — no design.md)**
```
Task(subagent_type="wb-task-decomposer")
  prompt: "Decompose into tasks. Requirements: {requirements_path}. No design spec — infer architecture from existing codebase at {codebase_path}.
           Write your full task list to .wannabuild/outputs/task-decomposer.md.
           Return ONLY: 'COMPLETE — [N] tasks decomposed. Report at .wannabuild/outputs/task-decomposer.md'"
```

After Step 1 completes, read `.wannabuild/outputs/task-decomposer.md` to get the task list for passing to Step 2 agents.

**Step 2 — Full mode: Dependency Mapper + Scope Validator (parallel background)**
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

**Step 2 — Light mode: Scope Validator only (no dependency-mapper, no design.md)**
```
Task(subagent_type="wb-scope-validator", run_in_background=true)
  prompt: "Validate coverage. Requirements: {requirements_path}. No design spec. Tasks: .wannabuild/outputs/task-decomposer.md.
           Write your full validation report to .wannabuild/outputs/scope-validator.md.
           Return ONLY: 'COMPLETE — [one sentence summary]. Report at .wannabuild/outputs/scope-validator.md'"
```

## Synthesis

After all agents complete (3 in Full mode, 2 in Light mode), the orchestrator reads `.wannabuild/outputs/task-decomposer.md`, `.wannabuild/outputs/dependency-mapper.md` (Full mode only), and `.wannabuild/outputs/scope-validator.md`. Note: steps referencing design.md apply to Full mode only — Light mode has no design.md:

1. **Start with the task list** from Task Decomposer
2. **Overlay dependencies** from Dependency Mapper (update task Dependencies fields)
3. **Address coverage gaps** from Scope Validator:
   - Missing tasks → add them
   - Scope creep tasks → flag for user decision
   - Missing integration tests → add Integration Test field to tasks
4. **Add critical path** and parallelization info from Dependency Mapper
5. **Final validation:** Every task has files, acceptance criteria, and integration test requirements
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

### Task 2: [title]
- **Status:** pending
- **Files:** [files]
- **Dependencies:** Task 1
- **Acceptance:** [criteria]
- **Integration Test:** [required tests]
- **Complexity:** S/M/L

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

Merge into existing state.json (preserving `mode` and all other existing keys). In Light mode, omit `design` from artifacts (it was never written):

**Full mode:**
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

**Light mode:**
```json
{
  "current_phase": "tasks",
  "phase_status": "complete",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "tasks": ".wannabuild/spec/tasks.md"
  },
  "next_phase": "implement"
}
```

## Handoff to Implement Phase

**Full mode:**
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

**Light mode:**
```json
{
  "phase": "implement",
  "from": "tasks",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "tasks": ".wannabuild/spec/tasks.md"
  },
  "codebase_path": "/path/to/project"
}
```

## User Interaction

After synthesis:

> Here's your implementation plan — [N] tasks on the critical path, estimated [size]. Each task has its target files, acceptance criteria, and required integration tests defined. Review the task order and let me know if you want to adjust anything before we start coding.

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
- [ ] Scope Validator verdict is PASS

## Edge Cases

- **Circular dependencies detected:** Dependency Mapper flags them. Orchestrator asks user to resolve by restructuring tasks.
- **Scope gaps found:** Scope Validator returns FAIL. Orchestrator adds missing tasks and re-runs validation.
- **Too many tasks:** If > 20 tasks, suggest breaking into milestones or multiple WannaBuild sessions.
- **User already has tasks:** Validate existing tasks against specs rather than generating new ones.
