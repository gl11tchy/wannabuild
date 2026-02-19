# WannaBuild Tasks Phase

> Phase 3 of 7 in the WannaBuild SDD pipeline. Decomposes the design into ordered, atomic implementation tasks with dependencies, acceptance criteria, and required integration tests.

## Agents

This phase uses 3 specialist agents in a sequential-then-parallel pattern:

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

**Step 1: Task Decomposer (foreground, must complete first)**
```
Task(subagent_type="wb-task-decomposer")
  prompt: "Decompose into tasks. Requirements: {requirements_path}. Design: {design_path}. Codebase: {codebase_path}"
```

**Step 2: Dependency Mapper + Scope Validator (parallel, after step 1)**
```
Task(subagent_type="wb-dependency-mapper", run_in_background=true)
  prompt: "Map dependencies for these tasks: {task_decomposer_output}. Design: {design_path}"

Task(subagent_type="wb-scope-validator", run_in_background=true)
  prompt: "Validate coverage. Requirements: {requirements_path}. Design: {design_path}. Tasks: {task_decomposer_output}"
```

## Synthesis

After all three agents complete, the orchestrator:

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
