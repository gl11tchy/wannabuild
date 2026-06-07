# Phase Exit and Escalation Conditions

## Transition conditions

- `discover` phase complete (mandatory, collaborative — doctrine Mandate 1):
  - the grill resolved vision, scope, and success signals with the user
  - feasibility, alternatives/competition, and Failure Forecast artifacts exist and are non-empty
  - `requirements.md` has an Acceptance Criteria section with at least one concrete criterion
  - `assert-discovery-ready` passes

- `requirements` phase complete:
  - requirements spec exists and has user stories + at least one acceptance criterion per story

- `design` phase complete:
  - design spec exists and includes architecture, tech stack, testing strategy, and risks

- `tasks` phase complete:
  - tasks spec exists with dependencies and checkpoint plan

- `implement` phase complete:
  - all tasks from `tasks.md` are marked complete
  - latest checkpoint window exists for final task

- `review` phase complete:
  - the FULL reviewer set (no subset) is unanimous PASS in the latest loop iteration
  - `wb-integration-tester` is PASS with execution evidence (tests ran; every acceptance criterion covered)
  - `assert-review-ready` passes

- `ship` phase complete:
  - PR ready metadata and CI check summary exists
  - user acknowledges merge strategy or no-remote equivalent is accepted

## No fast-track

- There is no reduced-reviewer path. The full reviewer set runs every iteration regardless of change size.
- Any malformed verdict or ambiguous routing is a fail-closed block, resolved with the user — never a silent narrowing.

## Escalation

- If max iterations reached: surface the blocked state with an issue summary and collaborate with the user on next steps.
- If integration gate remains `FAIL`: it is terminal — never offer ship-with-known-issues.
- Before any `blocked` terminal status: `assert-acquisition-attempted` must pass (a logged acquisition attempt exists). "Blocked on missing env/resource" without a logged attempt is rejected.
- Otherwise, user may choose: continue loop, pause/manual fix, or abort.
