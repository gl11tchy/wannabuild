# WannaBuild: Implement Phase

> "Let's build this thing."

Phase 4 of 7 in the WannaBuild SDD pipeline. The implementer works through the task spec, writing feature code and integration tests, making atomic commits.

## Agent

| Agent | File | Role |
|-------|------|------|
| Implementer | `wb-implementer` | Executes tasks from spec, writes code + integration tests, commits |

This is a single-agent phase. The implementer runs in the foreground with full tool access.

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

## Execution Flow

```
spec/tasks.md (ordered task list)
        │
        ▼
┌─────────────────────────┐
│  For each task:         │
│                         │
│  1. Read task spec      │
│  2. Check dependencies  │
│  3. Study existing code │
│  4. Write tests first   │
│  5. Implement feature   │
│  6. Run test suite      │
│  7. Commit atomically   │
│  8. Update task status  │
│                         │
│  Repeat until all done  │
└────────────┬────────────┘
             │
             ▼
    Implementation complete
             │
             ▼
    Handoff to Review phase
```

## Agent Spawning

```
Task(subagent_type="wb-implementer")
  prompt: "Implement all tasks from .wannabuild/spec/tasks.md.
           Read the full spec chain at .wannabuild/spec/ first.
           Codebase at: {codebase_path}"
```

The implementer runs in the foreground (not background) because it needs interactive tool access for reading, writing, and running commands.

## Integration Tests Are Non-Negotiable

Every task with an "Integration Test" field MUST have corresponding test code. The implementer agent's prompt enforces this:

- Write the integration test first (when applicable)
- The test should define "working" before the feature code exists
- A task is NOT complete until its tests pass
- This is validated by `wb-integration-tester` in the Review phase

## Task Execution Protocol

For each task in `spec/tasks.md`:

1. **Read the task** — understand files, deps, acceptance criteria, required tests
2. **Check dependencies** — verify prerequisite tasks are complete
3. **Study existing code** — read target files, match patterns and conventions
4. **Write integration test** — define expected behavior as a test (TDD approach when applicable)
5. **Implement** — minimum code to satisfy acceptance criteria and pass tests
6. **Run tests** — verify changes work and don't break existing tests
7. **Commit** — atomic commit with conventional message (`feat:`, `fix:`, `test:`)
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

The implementer addresses each issue, runs tests again, and commits fixes. It does NOT skip integration test requirements — those are non-negotiable regardless of which iteration.

## Coding Standards

- **Follow existing patterns.** Match the codebase's style, naming, and structure.
- **Quality, not perfection.** Ship working code. Don't gold-plate.
- **Commit frequently.** One task = one commit minimum.
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
**Commit:** [hash and message]
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
    "commits": ["abc1234", "def5678", "..."]
  }
}
```

## Edge Cases

- **Task blocked by external dependency:** Report the blocker, skip the task, continue with unblocked tasks. Flag in summary.
- **Spec is wrong:** If implementation reveals a spec error, note the deviation and explain why. Don't silently diverge.
- **Tests can't be written yet:** If test infrastructure doesn't exist, create it as part of the first task that needs tests.
- **Resuming after interruption:** Read `spec/tasks.md` for task statuses. Pick up from the first incomplete task.

## Quality Checklist

- [ ] All tasks from `spec/tasks.md` are complete
- [ ] Every task with an Integration Test field has written tests
- [ ] All tests pass (new and existing)
- [ ] Commits follow conventional commit format
- [ ] No hardcoded secrets, tokens, or credentials
- [ ] Code follows existing codebase patterns
- [ ] Spec deviations are documented
