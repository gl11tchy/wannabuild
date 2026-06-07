# Edge-Case Dry-Run Scenarios

Use these scenarios when validating production readiness of the orchestrator flow.
They are the production-readiness bar: the orchestrator is not ready until every
scenario below passes.

Every dry-run is a hard pass/fail gate. Each scenario MUST assert all of its listed
conditions explicitly, and a scenario passes only when every condition is verified
against real `scripts/validate-wannabuild-artifacts.sh` output (real exit code, real
emitted text). No scenario may be skipped, abbreviated, sampled, or marked "best
effort". These scenarios enforce the four mandates in
[`doctrine.md`](doctrine.md) — discovery is mandatory and collaborative, resources
are exhausted before any "blocked" claim, the full reviewer set runs every iteration
with the integration tester as a terminal hard gate, and every public phase boundary
hard-stops for an explicit approval word. Where a scenario assertion and the doctrine
appear to conflict, the doctrine governs and the scenario MUST be tightened, never
loosened.

## 0a) Discovery is mandatory before plan or build

Fixture: `skills/internal/build/dry-runs/wb-discover-entrypoint-full-loop.json`
(see also `exploratory-discovery-invocation.json` for the no-concrete-task entry).

Expected behavior:

- The discovery stage MUST be present and selected first; `expected_public_step`
  MUST be `discover` and `expected_skill` MUST be `wb-discover` (or `wannabuild`
  routing into discovery). A concrete one-line task does NOT bypass discovery.
- `current_phase` MUST NOT be `design`, `tasks`, or `implement` until discovery is
  complete: the five discovery artifacts are non-empty and
  `.wannabuild/spec/requirements.md` contains an **Acceptance Criteria** section with
  at least one concrete, checkable criterion.
- The recorded grill MUST be one question at a time, each carrying a recommended
  answer; `expected_next_action` is `start_discovery_interview` or
  `produce_requirements_then_plan`, never an immediate plan or implementation.
- Every `must_not` entry in the fixture (`stop_after_discovery`,
  `ask_user_to_invoke_wb_plan`, `ask_user_to_invoke_wb_build`,
  `generic_codex_implementation`, `implement_before_plan`, `plan_before_discovery`)
  MUST hold.

Use case:

1. Stage the fixture as `.wannabuild/state.json` (or pass it to the routing check).
2. Run:

   ```bash
   scripts/validate-wannabuild-artifacts.sh . requirements
   ```

3. Verify:
   - `assert-discovery-ready` is the gate that governs the plan transition, and it
     fails closed when discovery is incomplete or requirements has no acceptance
     criteria
   - no `must_not` behavior is taken
   - validation FAILS if discovery is absent, skipped, or classified away as "trivial"

## 0b) Vague acknowledgment does not cross a phase boundary

Fixture: `skills/internal/build/dry-runs/vague-acknowledgment-no-phase-skip.json`

Expected behavior:

- A vague acknowledgment ("ok", "uh ok", "sounds good") MUST be treated as
  continuation of the current phase, not as the explicit approval word that crosses a
  boundary. `expected_next_action` MUST be `continue_current_phase`.
- Only an explicit approval word ("go", "proceed", "approved", "continue", "next",
  "lgtm", "do it") crosses a public phase boundary; `phase_limit_requires_explicit_user_text`
  MUST be `true`.
- Every `must_not` entry (`treat_as_approval_to_skip_plan`,
  `start_implementation_without_plan`, `stop_workflow`,
  `ask_user_to_invoke_next_phase`) MUST hold.

Use case:

1. Stage the fixture as `.wannabuild/state.json`.
2. Run:

   ```bash
   scripts/validate-wannabuild-artifacts.sh . design
   ```

3. Verify:
   - `current_phase` stays `design` and `public_stage` stays `plan`
   - validation FAILS if a vague acknowledgment is recorded as boundary approval
   - validation FAILS if implementation starts without a completed plan

## 1) Resume mid-cycle from checkpoint

Fixture: `skills/internal/build/dry-runs/resume-state.json`

Expected behavior:

- `mode` MUST be preserved from prior context, not re-inferred.
- The latest checkpoint window MUST be used as input to review routing.
- Transition to `implement` or `review` MUST NOT restart task order from the
  beginning.
- Validation MUST pass only when the checkpoint window contains every required field:
  `window_id`, `phase`, `completed_tasks[]`, `pending_tasks[]`, and `coverage_map`.
  A window missing any of these fields MUST FAIL validation.

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

Fixture: `skills/internal/build/dry-runs/standard-missing-design-state.json`

Expected behavior:

- A missing `design.md` MUST block the implement transition by default. The
  `assert-plan-ready` gate requires both `design.md` and `tasks.md`; with `design.md`
  absent it fails closed and the workflow MUST NOT advance to implement.
- The orchestrator MUST NOT proceed "best effort" from requirements plus existing code
  patterns. To clear the block it MUST do exactly one of:
  1. generate the missing `design.md` artifact and re-run the plan gate, or
  2. record an explicit, user-confirmed waiver in `state.json`
     (`plan.design_waived: true` with the approving user text) — surfaced at the plan
     boundary as an option with a recommended answer (recommend: produce the design),
     never granted silently by the orchestrator.
- Transition to `tasks` MUST still require `design.md` and MUST FAIL without it.

Use case:

1. Stage the fixture as `.wannabuild/state.json`.
2. Run:

   ```bash
   scripts/validate-wannabuild-artifacts.sh . implement
   ```

3. Verify:
   - validation FAILS for implement when `design.md` is missing and no user-confirmed
     waiver is recorded
   - validation passes only after the design is produced or a recorded waiver is
     present
   - no schema errors for `mode`/`control_mode`

## 3) Reviewer routing ambiguity fallback

Fixture: `skills/internal/build/dry-runs/ambiguous-review-loop.json`

Expected behavior:

- reviewer inference confidence is `ambiguous`.
- Review routing MUST activate the full base reviewer set — all of
  `wb-security-reviewer`, `wb-performance-reviewer`, `wb-architecture-reviewer`,
  `wb-testing-reviewer`, `wb-code-simplifier`, and `wb-integration-tester`. Per
  [`doctrine.md`](doctrine.md) Mandate 3 the full set runs every iteration; no reviewer
  is ever skipped on a rerun, ambiguous routing or not.
- Each active reviewer MUST return a coverage record that enumerates every file, every
  acceptance criterion, and every risk in its scope with a verdict. A reviewer whose
  findings are empty or non-substantive MUST be recorded as INCOMPLETE, not PASS.
- Validation MUST FAIL if any reviewer in the active set is missing, is skipped, or
  lacks a complete coverage record.

Use case:

1. Stage fixture and its `loop-state` equivalent.
2. Run:

   ```bash
   scripts/validate-wannabuild-artifacts.sh . review
   ```

3. Verify:
   - any parse/contract ambiguity is surfaced as an explicit failure reason
   - routing activates the full base reviewer set (all six reviewers)
   - `wb-integration-tester` remains in the active set
   - validation FAILS if any reviewer is absent or returns no coverage record

## 4) Execution-shape selection is mode-aware

Fixture: `skills/internal/build/dry-runs/autonomous-control-mode-state.json`

This scenario asserts both modes; the experience is identical every run for a given
`control_mode`.

Expected behavior:

- When `control_mode` is `autonomous`: the `implement` stage MUST record the selected
  execution shape AND a recorded `execution_shape_rationale` explaining the choice.
  Advancing without a prompt is permitted ONLY in autonomous mode and ONLY with that
  recorded rationale.
- When `control_mode` is `guided` (the default per
  [`doctrine.md`](doctrine.md) Mandate 4): the plan→implement boundary is a hard stop.
  The orchestrator MUST present the execution-shape options, each with a recommended
  default, and MUST NOT advance until the user gives an explicit approval word. A
  vague acknowledgment MUST NOT cross this boundary.
- State MUST validate as `implement` phase only when the boundary rule for its
  `control_mode` was satisfied.

Use case:

1. Stage fixture as `.wannabuild/state.json`.
2. Run:

   ```bash
   scripts/validate-wannabuild-artifacts.sh . implement
   ```

3. Verify:
   - no schema failures
   - `control_mode` is `autonomous` and an `execution_shape` plus rationale are recorded
   - `implement` stage is `in_progress` with an execution shape
   - `current_phase` is `implement`
   - validation FAILS if a guided-mode state advances past the boundary without a
     recorded explicit approval word

## 5) Research burst completed before planning

Fixture: `skills/internal/build/dry-runs/research-gate-taken-state.json`

Research is only the bundle half of discovery; it never substitutes for the
collaborative grill. A completed research burst MUST NOT advance to planning on its
own.

Expected behavior:

- `research` stage is `complete` with `agents_run` and `output` populated.
- `artifacts` includes `research_summary` pointing to
  `.wannabuild/outputs/research-summary.md`.
- The collaborative grill MUST also be complete and `.wannabuild/spec/requirements.md`
  MUST contain an **Acceptance Criteria** section with at least one concrete criterion.
  The transition to `design` is governed by `assert-discovery-ready`, which fails
  closed if the grill is incomplete or acceptance criteria are absent — research alone
  never clears it.
- `current_phase` MAY be `design` (pending) only when both the research bundle AND the
  grill are complete; otherwise validation MUST FAIL.

Use case:

1. Stage fixture as `.wannabuild/state.json`.
2. Run:

   ```bash
   scripts/validate-wannabuild-artifacts.sh . design
   ```

3. Verify:
   - no schema failures
   - `research` stage is `complete` with output path recorded
   - `artifacts.research_summary` is present
   - validation FAILS if the design transition is reached with the grill incomplete or
     no acceptance criteria recorded

## 6) Implementation selection — autonomous-mode advance with recorded shape

Fixture: `skills/internal/build/dry-runs/implement-gate-denied-state.json`
(the fixture carries `control_mode: "autonomous"`; the historical "gate-denied" name
is retained only as a filename and does NOT sanction skipping a boundary in guided
mode).

Expected behavior:

- The fixture's `control_mode` is `autonomous`, so the plan→implement advance without a
  prompt is permitted ONLY because the mode is autonomous and the selected
  `execution_shape` is recorded. In guided (default) mode this same transition MUST
  hard-stop and present the execution-shape options with a recommended default,
  advancing only on an explicit approval word.
- `public_stage` is `implement` with `status: "in_progress"`.
- The latest implement stage records `execution_shape: "single-owner"`.
- `current_phase` is `implement` with `phase_status: "in_progress"`.

Use case:

1. Stage fixture as `.wannabuild/state.json`.
2. Run:

   ```bash
   scripts/validate-wannabuild-artifacts.sh . implement
   ```

3. Verify:
   - no schema failures
   - `control_mode` is `autonomous` (the only mode under which no boundary prompt is
     required)
   - `current_phase` is `implement`
   - latest `implement` stage has `execution_shape: "single-owner"`
   - validation FAILS if the same advance is recorded under `control_mode: "guided"`
     without an explicit approval word

## 7) Advisor escalation triggered during implement

Fixture: `skills/internal/build/dry-runs/advisor-escalation-triggered-state.json`

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

Fixture: `skills/internal/build/dry-runs/qa-failure-remediation-loop.json`

Expected behavior:

- Iteration 1: the full base reviewer set runs; `wb-integration-tester` FAILs on 2
  missing acceptance-criterion tests.
- Every iteration, including reruns, MUST run the full base reviewer set per
  [`doctrine.md`](doctrine.md) Mandate 3 — no "impacted-only" subset and no reviewer
  self-selecting out. A rerun targeting only `wb-integration-tester` is a contract
  violation and MUST FAIL validation.
- While `wb-integration-tester` status is `FAIL`, both `ship` and
  `ship-with-known-issues` MUST be absent regardless of iteration count. There is NO
  escalation, override, or operator-acceptance path past an integration-tester FAIL —
  not before `max_iterations`, not at `max_iterations`, not after. The hard gate is an
  absolute invariant, not an escalation protocol that "removes an option" at a
  boundary.
- A `wb-integration-tester` PASS is valid only with execution evidence:
  `test_execution` showing `total > 0`, `failed == 0`, `errored == 0`, and a
  `coverage_map` in which every acceptance criterion is `covered` (none `missing` or
  `incomplete`). "Status: PASS" with zero tests executed is itself a FAIL.

Use case:

1. Stage fixture as `.wannabuild/loop-state.json`.
2. Run:

   ```bash
   scripts/validate-wannabuild-artifacts.sh . review
   ```

3. Verify:
   - no schema failures
   - the full base reviewer set is present in every iteration (validation FAILS on an
     impacted-only rerun)
   - `wb-integration-tester` has `hard_gate: true` and `status: "FAIL"` in both
     iterations
   - `coverage_map` shows AC-3 as `covered` and AC-5 as `incomplete` in iteration 2
   - validation FAILS if any `ship` or `ship-with-known-issues` option is present while
     the integration tester is FAIL, at any iteration count

## 9) QA must exhaust acquisition before declaring blocked

State: a QA/review state whose latest event is `qa_blocked` or `qa_failed` (stage the
`skills/internal/build/dry-runs/qa-failure-remediation-loop.json` loop-state together
with a `.wannabuild/outputs/acquisition-log.json`).

"Missing env", "no database", "can't run it", "no access", and "no fixtures" are never
grounds to skip QA. Per [`doctrine.md`](doctrine.md) Mandate 2 they are grounds to
obtain the resource (run the app locally; spin an ephemeral DB branch via the
Supabase/Neon/Railway connectors; drive the real UI with the Chrome or computer-use
connector; read live docs via Context7; generate fixtures and seed data) or to
stop-and-ask only for billable, outward-facing, or destructive acquisition.

Expected behavior:

- Any verdict of `blocked` or `can't-test` MUST carry an `attempts[]` log in
  `.wannabuild/outputs/acquisition-log.json` enumerating, per unmet need: what was
  needed, which tools/connectors/CLIs were attempted, and the result. The
  `assert-acquisition-attempted` gate rejects any blocked/failed status with no logged
  attempt.
- QA evidence MUST record exactly what was executed — real commands, real exit codes,
  real output — not assertions that work "should" pass. The `assert-qa-ready` gate
  requires the integration tester's execution evidence in addition to the QA summary
  markers; text markers alone never pass QA.
- Validation MUST FAIL when a blocked/failed QA status exists with no acquisition log,
  or when a QA PASS carries no execution evidence.

Use case:

1. Stage the loop-state and an `acquisition-log.json` under `.wannabuild/outputs/`.
2. Run:

   ```bash
   scripts/validate-wannabuild-artifacts.sh . qa
   ```

3. Verify:
   - `assert-acquisition-attempted` and `assert-qa-ready` both govern the qa transition
   - validation FAILS when a `blocked`/`can't-test` verdict has no matching `attempts[]`
     entry
   - validation FAILS when QA PASS is asserted without execution evidence

## Expected hard-fail outputs

- malformed or missing JSON: fail with file path and missing key detail
- invalid resume state: fail with explicit contract violation
- ambiguous routing: hard fail unless the full base reviewer set is activated AND each
  reviewer returns a complete coverage record — a fallback explanation alone does not
  satisfy the gate
- blocked/failed status without a logged acquisition attempt in
  `.wannabuild/outputs/acquisition-log.json`: hard fail (`assert-acquisition-attempted`)
- any `ship`/`ship-with-known-issues` option present while `wb-integration-tester` is
  FAIL: hard fail with no override path

## What to do if dry-run fails

A failed dry-run MUST be repaired and re-run until it passes. Proceeding past a failed
dry-run is prohibited; there is no "manually accept the fallback behavior" path.

1. Repair the fixture/state/loop file structure so it matches the contract.
2. Re-run `scripts/validate-wannabuild-artifacts.sh` with the corrected state and the
   explicit phase, and confirm a clean exit.
3. Repeat until the scenario passes. If a scenario reveals a real contract gap rather
   than a fixture defect, fix the contract (and the runtime gate it maps to) and re-run
   — never relax the scenario to make it pass.
