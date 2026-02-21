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

## 2) Light mode with missing `design.md`

Fixture: `skills/build/dry-runs/light-missing-design-state.json`

Expected behavior:
- transition from requirements to tasks should pass
- transition to tasks/review in Light mode must not require `design.md`
- orchestrator writes an explicit note:
  - missing design is accepted because mode is light
  - implementation should proceed with requirements + existing code patterns

Use case:
1. Stage the fixture and a `.wannabuild/state.json` with `"mode": "light"`.
2. Run:

```bash
scripts/validate-wannabuild-artifacts.sh . tasks
```

3. Verify:
   - validation passes even without design spec
   - no hard fail for missing design

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

## Expected hard-fail outputs

- malformed or missing JSON: fail with file path and missing key detail
- invalid resume state: fail with explicit contract violation
- ambiguous routing: fail-over to fallback explanation in transition report

## What to do if dry-run fails

Pause workflow and use one of:

1. Repair fixture/state/loop file structure
2. Run with corrected `mode` and explicit phase choice
3. Continue in normal mode and manually accept the fallback behavior
