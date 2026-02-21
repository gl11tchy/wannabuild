# Phase Exit and Escalation Conditions

## Transition conditions

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
  - active-set unanimous PASS in latest loop iteration
  - `wb-integration-tester` must be PASS

- `ship` phase complete:
  - PR ready metadata and CI check summary exists
  - user acknowledges merge strategy or no-remote equivalent is accepted

## Fast-track and fallback
- Fast-track can run reduced reviewer set only if matrix criteria are met and explicit confidence is high.
- Any fail in fast-track forces full base set next iteration.
- Any malformed verdict or ambiguous routing -> fallback to base set.

## Escalation
- If max iterations reached: surface blocked state with issue summary.
- If integration gate remains `FAIL`: do not offer ship-with-known-issues.
- Otherwise, user may choose: continue loop, pause/manual fix, or abort.
