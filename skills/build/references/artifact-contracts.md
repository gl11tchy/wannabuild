# Build Artifact Contracts

WannaBuild runtime data in `.wannabuild/` is interpreted from these contracts.

## Schema Sources

- `skills/build/schemas/state.schema.json`
- `skills/build/schemas/loop-state.schema.json`
- `skills/build/schemas/review-verdict.schema.json`
- `skills/build/schemas/checkpoint.schema.json`
- `skills/build/schemas/config.schema.json`
- `skills/build/schemas/workspace.schema.json`

Use these with `scripts/validate-wannabuild-artifacts.sh`.

## `.wannabuild/state.json`

### Required core keys
- `project` (string): Friendly project label
- `mode` (`standard`): Workflow mode
- `current_phase` (string): Current internal phase name
- `phase_status` (`pending` | `in_progress` | `complete`): Current internal phase status
- `public_stage` (string): Current public-facing stage (`discover` | `control_mode_decision` | `research_decision` | `research` | `plan` | `implementation_decision` | `implement` | `review` | `qa` | `summary`)
- `workflow_status` (`in_progress` | `complete`): Current public workflow status
- `control_mode` (`guided` | `autonomous`): User's control mode preference
- `artifacts` (object): Paths to generated artifacts
- `started_at`, `updated_at` (ISO timestamps)
- `phase_history` (array): Chronological internal phase status records
- `public_stage_history` (array): Chronological public stage status records

### public_stage_history record
Each item must include:
- `stage` (string): One of the 10 valid public stages
- `status` (`in_progress` | `complete`): Stage status
- `timestamp` (ISO string): When this stage was entered or completed

### Optional advisor keys
- `advisor.enabled` (boolean): Whether advisor escalation is available.
- `advisor.max_uses_per_phase` (integer): Phase-level advisor budget.
- `advisor.uses_by_phase` (object): Counts by phase.
- `advisor.escalations` (array): Advisor report records with `phase`, `trigger`, `report`, `decision_impact`, and `recorded_in_decisions`.

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
  "public_stage": "review",
  "workflow_status": "in_progress",
  "control_mode": "guided",
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
  ],
  "public_stage_history": [
    {"stage": "discover", "status": "complete", "timestamp": "2026-02-21T02:02:00Z"},
    {"stage": "control_mode_decision", "status": "complete", "timestamp": "2026-02-21T02:04:00Z"},
    {"stage": "plan", "status": "complete", "timestamp": "2026-02-21T02:12:00Z"},
    {"stage": "implement", "status": "complete", "timestamp": "2026-02-21T02:25:00Z"},
    {"stage": "review", "status": "in_progress", "timestamp": "2026-02-21T02:30:00Z"}
  ],
  "advisor": {
    "enabled": true,
    "max_uses_per_phase": 3,
    "uses_by_phase": {
      "design": 0,
      "implement": 1,
      "review": 0
    },
    "escalations": [
      {
        "phase": "implement",
        "trigger": "uncertain remediation",
        "report": ".wannabuild/outputs/advisor/implement-escalation-1.md",
        "decision_impact": "implementation",
        "recorded_in_decisions": true
      }
    ]
  }
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

## `.wannabuild/config.json`

Optional configuration file that overrides workflow defaults. All keys are optional.

### Keys
- `max_review_iterations` (integer, >= 1, default 3)
- `auto_advance` (boolean, default false)
- `skip_phases` (array of valid phase names)
- `adaptive_review_reruns` (boolean, default true)
- `review_rerun_policy` (`impacted_plus_integration` | `full_set`)
- `review_context_scope` (`diff_plus_targeted_spec` | `full_spec` | `diff_only`)
- `max_agent_runs_per_phase` (integer, >= 1, default 18)
- `max_total_review_runs` (integer, >= 1, default 12)
- `max_prompt_chars_per_reviewer` (integer, >= 1000, default 12000)
- `on_limit` (`pause-and-ask` | `error` | `strict-block`)
- `advisor_escalation` (boolean, default true)
- `advisor_max_uses_per_phase` (integer, >= 0, default 3)
- `advisor_context_scope` (`spec_plus_targeted_repo_summary` | `spec_only` | `full_repo`)
- `advisor_record_decisions` (boolean, default true)
- `advisor_on_limit` (`pause-and-ask` | `error` | `strict-block`)

Schema: `skills/build/schemas/config.schema.json`

## `.wannabuild/workspace.json`

Created during workspace bootstrap. Tracks the isolated git worktree used for the current WannaBuild session.

### Required keys
- `workspace_id` (string): Unique workspace identifier
- `source_repo` (string): Absolute path to the original git repository root
- `source_branch` (string): Branch name at time of workspace creation
- `workspace_path` (string): Absolute path to the isolated git worktree
- `branch_name` (string): Git branch name for the worktree
- `dirty_snapshot` (boolean): Whether uncommitted changes were present at creation time

Schema: `skills/build/schemas/workspace.schema.json`

## `.wannabuild/outputs/*.md` and `review/*.json`

Agents always write full output to files and return one-line status to the orchestrator.
Only synthesis logic consumes these files for deterministic state transitions.

## `.wannabuild/outputs/advisor/*.md`

Advisor escalation reports are optional compact guidance artifacts. They are used when an executor consults a higher-capability advisor for a bounded decision.

Recommended path:
`.wannabuild/outputs/advisor/<phase>-escalation-<N>.md`

Recommended structure:

```md
# Advisor Escalation — <phase>-<N>

Phase: <phase>
Trigger: <why escalation was needed>
Question: <bounded question asked>
Context Provided:
- <spec or repo summary excerpt>
Recommendation:
- <advisor guidance>
Stop Signal: yes|no
Decision Impact: none|scope|architecture|implementation|validation
Record In Decisions: yes|no
```

Advisor reports are not user-facing output. If `Record In Decisions` is `yes`, append a concise decision to `.wannabuild/decisions.md`.
