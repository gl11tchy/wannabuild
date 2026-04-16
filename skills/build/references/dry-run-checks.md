# Edge-Case Dry-Run Scenarios

Use these scenarios when validating production readiness of the orchestrator flow.

All dry-runs are intentionally low-effort and contract-focused.

## 1) Resume mid-cycle from checkpoint

Fixture: `skills/build/dry-runs/resume-state.json`

Expected behavior:
- `mode` is preserved from prior context.
- Latest checkpoint window is used as input to review routing.
- Transition to `implement` or `review` does not restart task order from the beginning.
- Validation must pass if the checkpoint window has valid metadata fields.

Use case:
1. Temporarily stage fixture as `.wannabuild/state.json`.
2. Run:

```bash
scripts/validate-wannabuild-artifacts.sh . implement
```

3. Verify:
   - no schema failures
   - a resume continuation message is emitted
   - `current_phase` is interpreted from state, not guessed

## 2) Standard mode with missing `design.md` before implement

Fixture: `skills/build/dry-runs/standard-missing-design-state.json`

Expected behavior:
- transition to implement should pass when requirements + tasks artifacts exist
- transition to tasks should still require `design.md`
- orchestrator writes an explicit note:
  - missing design is accepted for implement/review per contract
  - implementation should proceed with requirements + existing code patterns

Use case:
1. Stage the fixture as `.wannabuild/state.json`.
2. Run:

```bash
scripts/validate-wannabuild-artifacts.sh . implement
```

3. Verify:
   - validation passes for implement without design spec
   - no schema errors for `mode`/`control_mode`

## 3) Reviewer routing ambiguity fallback

Fixture: `skills/build/dry-runs/ambiguous-review-loop.json`

Expected behavior:
- reviewer inference confidence is `ambiguous`
- review routing falls back to full base reviewer set
- no reviewer is skipped in review reruns when ambiguity remains

Use case:
1. Stage fixture and its `loop-state` equivalent.
2. Run:

```bash
scripts/validate-wannabuild-artifacts.sh . review
```

3. Verify:
   - any parse/contract ambiguity is surfaced as an explicit failure reason
   - fallback routing recommendation is `full_set`
   - `wb-integration-tester` remains in the active set

## 4) Autonomous control mode — gate advance without prompting

Fixture: `skills/build/dry-runs/autonomous-control-mode-state.json`

Expected behavior:
- `control_mode` is `autonomous`, set at `control_mode_decision`.
- `implementation_decision` shows `autonomous_advance: true` — orchestrator selected single agent mode without waiting for user input.
- No guided gate question appears between plan completion and implement start.
- State is valid to validate as `implement` phase.

Use case:
1. Stage fixture as `.wannabuild/state.json`.
2. Run:

```bash
scripts/validate-wannabuild-artifacts.sh . implement
```

3. Verify:
   - no schema failures
   - `control_mode` is `autonomous`
   - `implementation_decision` stage is `complete` with `autonomous_advance: true`
   - `current_phase` is `implement`

## 5) Research gate taken — research burst completed before planning

Fixture: `skills/build/dry-runs/research-gate-taken-state.json`

Expected behavior:
- `research_decision` stage records `decision: "research"`.
- `research` stage is `complete` with `agents_run` and `output` populated.
- `artifacts` includes `research_summary` pointing to `.wannabuild/outputs/research-summary.md`.
- `current_phase` is `design` (pending), indicating research completed and planning is next.

Use case:
1. Stage fixture as `.wannabuild/state.json`.
2. Run:

```bash
scripts/validate-wannabuild-artifacts.sh . design
```

3. Verify:
   - no schema failures
   - `research_decision.decision` is `research`
   - `research` stage is `complete` with output path recorded
   - `artifacts.research_summary` is present

## 6) Implement gate denied — workflow paused at implementation_decision

Fixture: `skills/build/dry-runs/implement-gate-denied-state.json`

Expected behavior:
- `public_stage` is `implementation_decision` with `status: "in_progress"`.
- `gate_response` is `deferred` — user did not proceed to implement.
- `current_phase` remains `tasks` with `phase_status: "complete"` — internal phase must not advance to `implement` when the public gate is deferred.
- No implement checkpoint or implement phase entry in `phase_history`.

Use case:
1. Stage fixture as `.wannabuild/state.json`.
2. Run:

```bash
scripts/validate-wannabuild-artifacts.sh . tasks
```

3. Verify:
   - no schema failures
   - `current_phase` is `tasks` (not `implement`)
   - `implementation_decision` stage is `in_progress`, not `complete`
   - `phase_history` has no `implement` entry

## 7) Advisor escalation triggered during implement

Fixture: `skills/build/dry-runs/advisor-escalation-triggered-state.json`

Expected behavior:
- `advisor` block is present in state with one escalation recorded for `implement` phase.
- `uses_by_phase.implement` is `1`, within the `max_uses_per_phase: 3` budget.
- Escalation entry includes `trigger`, `report` path, `decision_impact`, and `recorded_in_decisions`.
- State remains valid for continued implement-phase work after advisor output was consumed.

Use case:
1. Stage fixture as `.wannabuild/state.json`.
2. Run:

```bash
scripts/validate-wannabuild-artifacts.sh . implement
```

3. Verify:
   - no schema failures
   - `advisor.escalations` has exactly one entry for `implement`
   - `decision_impact` is a valid enum value (`none|scope|architecture|implementation|validation`)
   - `recorded_in_decisions` is `true`
   - `uses_by_phase.implement` does not exceed `max_uses_per_phase`

## 8) QA failure with remediation loop — integration hard gate blocking ship

Fixture: `skills/build/dry-runs/qa-failure-remediation-loop.json`

Expected behavior:
- Iteration 1: full base reviewer set; `wb-integration-tester` FAILs on 2 missing acceptance-criterion tests.
- Iteration 2: adaptive routing targets only `wb-integration-tester` (`routing_reason: "impacted"`); hard gate still FAIL on AC-5.
- `status` is `in_progress` — loop has not yet exhausted `max_iterations`.
- Because `wb-integration-tester` is still failing, the **ship-with-known-issues** escalation option must be absent if `max_iterations` is reached before the tester passes.

Use case:
1. Stage fixture as `.wannabuild/loop-state.json`.
2. Run:

```bash
scripts/validate-wannabuild-artifacts.sh . review
```

3. Verify:
   - no schema failures
   - iteration 2 `active_reviewers` contains only `wb-integration-tester`
   - `wb-integration-tester` has `hard_gate: true` and `status: "FAIL"` in both iterations
   - `coverage_map` shows AC-3 as `covered` and AC-5 as `incomplete` in iteration 2
   - escalation protocol: if `current_iteration` reaches `max_iterations` with integration-tester still failing, ship-with-known-issues option is removed

## Expected hard-fail outputs

- malformed or missing JSON: fail with file path and missing key detail
- invalid resume state: fail with explicit contract violation
- ambiguous routing: fail-over to fallback explanation in transition report

## What to do if dry-run fails

Pause workflow and use one of:

1. Repair fixture/state/loop file structure
2. Run with corrected state fields and explicit phase choice
3. Continue in normal mode and manually accept the fallback behavior
