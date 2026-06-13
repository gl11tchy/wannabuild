# Build Artifact Contracts

WannaBuild runtime data in `.wannabuild/` is interpreted from these contracts.

## Schema Sources

- `skills/internal/build/schemas/state.schema.json`
- `skills/internal/build/schemas/loop-state.schema.json`
- `skills/internal/build/schemas/review-verdict.schema.json`
- `skills/internal/build/schemas/checkpoint.schema.json`
- `skills/internal/build/schemas/config.schema.json`
- `skills/internal/build/schemas/workspace.schema.json`

Use these with `scripts/validate-wannabuild-artifacts.sh`.

## Discovery artifacts (Mandate 1)

Discovery is mandatory and gated by `assert-discovery-ready`, which fails closed until all of these exist and are non-empty:

- `.wannabuild/outputs/discovery/feasibility.md`
- `.wannabuild/outputs/discovery/alternatives-competition.md`
- `.wannabuild/outputs/discovery/failure-forecast.md`
- `.wannabuild/outputs/discovery/followup-questions.md`
- `.wannabuild/spec/requirements.md` — must contain an **Acceptance Criteria** section with at least one concrete criterion (an unmeasurable brief does not pass)

State records discovery progress under `state.discovery` (`interview`; `research.{feasibility,alternatives_competition,failure_forecast}`; `followup_questions`; `synthesis`), each with `status: "complete"` and the artifact path. Plan is blocked until these are present.

## `.wannabuild/outputs/plan/` (Plan phase — adversarial options)

Optional, produced during Plan by the `wb-plan-options` agent and rendered by `scripts/wb-render-plan-html.sh`:

- `plan-options.json` — N (2–5, default `plan_adversarial_count`) adversarial plan options. Schema: `plan-options.schema.json`. Required: `goal`, `recommended_id` (matching one plan id), and `plans[]`; each plan requires `id`, `title`, `stance`, `summary`, `slices[]`, `impacted_surfaces[]`, `verification[]`, and a non-empty `critique_of_others`. Optional `chosen_id` (a plan id) records the user's selection. `validate-wannabuild-artifacts.sh` validates it whenever it exists.
- `adversarial-plans.html` — a self-contained render of `plan-options.json` (inline CSS, no network references), best-effort opened in the browser at the Plan boundary; non-blocking.

State records the chosen option under `state.plan_options` (`artifact`, `html`, `chosen_id`).

## `.wannabuild/state.json`

### Required core keys

- `project` (string): Friendly project label
- `mode` (`standard`): Workflow mode
- `current_phase` (string): Current internal phase name
- `phase_status` (`pending` | `in_progress` | `complete`): Current internal phase status
- `public_stage` (string): Current public-facing stage (`discover` | `research` | `plan` | `implement` | `review` | `qa` | `summary`)
- `workflow_status` (`in_progress` | `complete`): Current public workflow status
- `control_mode` (`guided` | `autonomous`): Execution preference; defaults to `guided`
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

- `approved`: unanimous PASS from the FULL reviewer set in the latest iteration, with integration execution evidence
- `blocked`: routing cannot proceed without explicit user action; a resource blocker requires a logged acquisition attempt (`assert-acquisition-attempted`)
- `escalated`: loop hit max iterations or hard block condition

## Reviewer verdict JSON

Agents in `review` write files to:
`.wannabuild/review/<agent>-iter-<N>.json`

### Required fields

- `agent`
- `status` (`PASS` | `FAIL`)
- `summary`
- `issues` (array with `severity`, `file`, `line`, `issue`, `recommendation`)

Each reviewer covers the entire changed surface, and its `summary` states what it covered. A verdict that examined only part of the diff is incomplete and must not be returned as PASS.

### Integration tester extras

- `hard_gate: true`
- `test_execution` with `total`, `passed`, `failed`, `errored`, `duration_ms`
- `coverage_map` with `criterion`, `test_file`, `test_name`, `status`

## Runtime-recorded test evidence

`.wannabuild/review/wb-integration-tester-iter-<N>.evidence.json` (schema:
`schemas/test-evidence.schema.json`) is written ONLY by
`wb-runtime record-test-evidence` (or `hooks/wannabuild-route.py
record-test-evidence` on installs without the binary). The recorder executes
`config.integration_test_command` itself and records the command, exit code,
output SHA-256 (full output in the sidecar `.evidence.log`), timing, a hash of
the current spec files, and an HMAC computed with a machine-local key stored
outside the project tree (`~/.wannabuild/evidence.key`).

`assert-review-ready` and `assert-qa-ready` accept an integration PASS only
when the matching record verifies: valid HMAC, `exit_code == 0`, `spec_hash`
equal to the current spec, and `command` equal to the current configured test
command. Agents and orchestrators never write this file by hand; a hand-written
or edited record fails verification. `WB_EVIDENCE_MODE=fixture` skips this
verification for committed example fixtures only, and every fixture-mode pass
is loudly labeled in gate output and events.

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
- `skip_phases` (array): may only contain non-core phases. Core gates (discover, plan, review, QA) cannot be skipped — the runtime gates block them regardless of this setting.
- `adaptive_review_reruns` (deprecated, ignored): the full reviewer set always runs every iteration.
- `review_rerun_policy` (deprecated, ignored): effective behavior is always `full_set`; `impacted_plus_integration` is not honored by `assert-review-ready`.
- `review_context_scope` (`diff_plus_targeted_spec` | `full_spec`): each reviewer always receives the full diff for the files it must cover; changed files are never withheld.
- `max_agent_runs_per_phase` (integer, >= 1, default 18)
- `max_total_review_runs` (integer, >= 1, default 12)
- `max_prompt_chars_per_reviewer` (integer, >= 1000, default 12000)
- `on_limit` (`pause-and-ask` | `error` | `strict-block`)
- `advisor_escalation` (boolean, default true)
- `advisor_max_uses_per_phase` (integer, >= 0, default 3)
- `advisor_context_scope` (`spec_plus_targeted_repo_summary` | `spec_only` | `full_repo`)
- `advisor_record_decisions` (boolean, default true)
- `advisor_on_limit` (`pause-and-ask` | `error` | `strict-block`)

Schema: `skills/internal/build/schemas/config.schema.json`

## `.wannabuild/workspace.json`

Created only when implementation-time worktree isolation is selected. Tracks the isolated git worktree used for the current WannaBuild session.

### Required keys

- `workspace_id` (string): Unique workspace identifier
- `source_repo` (string): Absolute path to the original git repository root
- `source_branch` (string): Branch name at time of workspace creation
- `workspace_path` (string): Absolute path to the isolated git worktree
- `branch_name` (string): Git branch name for the worktree
- `dirty_snapshot` (boolean): Whether uncommitted changes were present at creation time

Schema: `skills/internal/build/schemas/workspace.schema.json`

## `.wannabuild/outputs/*.md` and `review/*.json`

Agents always write full output to files and return one-line status to the orchestrator.
Only synthesis logic consumes these files for deterministic state transitions.

## `.wannabuild/outputs/qa-summary.md`

Written by the orchestrator during the QA stage. Required before the Summary stage may emit.

QA does not pass on this file's existence or its text markers alone. `assert-qa-ready` validates **content and execution evidence**: the summary must carry positive `status`/acceptance/integration markers AND the `wb-integration-tester` verdict must show tests actually ran (`test_execution.total > 0`, `failed == 0`, `errored == 0`) with every acceptance criterion `covered`. A summary that claims PASS without executed, covering tests is rejected.

Recommended content:

```md
# QA Summary

## Acceptance Criteria Coverage
- [ ] Criterion 1 — covered by <test_file>
- [ ] Criterion 2 — covered by <test_file>

## Integration Behavior
<summary of integration test results>

## Gaps
<any acceptance criteria without passing test coverage>

## Result
PASS | FAIL
```

## `.wannabuild/outputs/acquisition-log.json`

Records resource-acquisition attempts (doctrine Mandate 2). Required before any `blocked` or `failed` state is accepted — `assert-acquisition-attempted` rejects a blocker with no logged attempt.

An array of entries, each with:

- `need` (string): the resource that was missing (e.g. "postgres database")
- `tools_tried` (array): connectors/MCP servers/CLIs/tools attempted (e.g. `["supabase create_branch", "local docker"]`)
- `result` (string): outcome — acquired, or why it could not be and whether the user was asked

Example:

```json
[
  {
    "need": "postgres database for integration tests",
    "tools_tried": ["supabase create_branch", "local docker compose"],
    "result": "spun ephemeral Supabase branch; tests ran against it"
  }
]
```

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
