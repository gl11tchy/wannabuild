# Build Artifact Contracts

WannaBuild runtime data in `.wannabuild/` is interpreted from these contracts.

## Schema Sources

- `skills/build/schemas/state.schema.json`
- `skills/build/schemas/loop-state.schema.json`
- `skills/build/schemas/review-verdict.schema.json`
- `skills/build/schemas/checkpoint.schema.json`

Use these with `scripts/validate-wannabuild-artifacts.sh`.

## `.wannabuild/state.json`

### Required core keys
- `project` (string): Friendly project label
- `mode` (`standard`): Workflow mode
- `current_phase` (string): Current phase name
- `phase_status` (`pending` | `in_progress` | `complete`)
- `artifacts` (object): Paths to generated artifacts
- `started_at`, `updated_at` (ISO timestamps)
- `phase_history` (array): Chronological phase status records

### Update rule
- Use merge updates, never full replacement.
- Preserve unknown keys and nested metadata.

Example:

```json
{
  "project": "my-app",
  "mode": "standard",
  "current_phase": "review",
  "phase_status": "in_progress",
  "artifacts": {
    "requirements": ".wannabuild/spec/requirements.md",
    "design": ".wannabuild/spec/design.md",
    "tasks": ".wannabuild/spec/tasks.md"
  },
  "started_at": "2026-02-21T02:00:00Z",
  "updated_at": "2026-02-21T02:30:00Z",
  "phase_history": [
    {"phase": "requirements", "status": "complete", "timestamp": "2026-02-21T02:05:00Z"},
    {"phase": "design", "status": "complete", "timestamp": "2026-02-21T02:12:00Z"}
  ]
}
```

## `.wannabuild/loop-state.json`

### Required core keys
- `mode` (`standard`)
- `current_iteration` (integer)
- `max_iterations` (integer)
- `base_reviewer_count` (integer)
- `status` (`in_progress` | `approved` | `escalated` | `blocked`)
- `iterations` (array)

### Iteration record
Each item must include:
- `iteration`
- `timestamp`
- `active_reviewers` (array)
- `verdicts` (map of reviewer → verdict object)
- `pass_count`, `fail_count`
- `feedback_sent` (string, optional)

### `status` meanings
- `approved`: unanimous PASS in final required review iteration
- `blocked`: routing cannot proceed without explicit user action
- `escalated`: loop hit max iterations or hard block condition

## Reviewer verdict JSON

Agents in `review` write files to:
`.wannabuild/review/<agent>-iter-<N>.json`

### Required fields
- `agent`
- `status` (`PASS` | `FAIL`)
- `summary`
- `issues` (array with `severity`, `file`, `line`, `issue`, `recommendation`)

### Integration tester extras
- `hard_gate: true`
- `test_execution` with `total`, `passed`, `failed`, `errored`, `duration_ms`
- `coverage_map` with `criterion`, `test_file`, `test_name`, `status`

## `.wannabuild/checkpoints/*.md`

Checkpoint files are evidence logs, not pure JSON.
Recommended metadata lines at top:
- `Task:`, `Step:`
- `Changed Files:`
- `Verify:`
- `Result:`
- `Next:`

## `.wannabuild/outputs/*.md` and `review/*.json`

Agents always write full output to files and return one-line status to the orchestrator.
Only synthesis logic consumes these files for deterministic state transitions.
