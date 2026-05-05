# WannaBuild Operator Mental Model

Use this as the one-page map for running WannaBuild reliably.

## 1) What WannaBuild Is

WannaBuild is a repo-native, spec-driven workflow for shipping code with explicit quality gates.

Public loop:

`Discover -> Plan -> Implement -> Validate -> QA -> Summary`

Internal phases:

`Requirements -> Design -> Tasks -> Implement -> Review -> Ship -> Document`

Public steps stay compact for the user; internal phases provide rigor.

## 2) Non-Negotiables

1. No concrete task: ask for the goal first.
2. In git repos: use the current checkout through discovery and planning.
3. Initialize `.wannabuild/state.json` in that workspace.
4. Before implementation, choose current checkout or an isolated worktree.
5. Integration testing is a hard gate.
6. Do not emit final summary until Review and QA both pass.

## 3) Control Flow

1. **Discover:** interview for vision, audience, desired feel, flows, features, constraints, non-goals, and success signals.
2. **Plan:** run bounded research when useful, then produce requirements/design/tasks that are implementation-ready.
3. **Implement:** choose the smallest effective execution shape and execute in micro-steps with checkpoints.
4. **Validate:** run the relevant reviewer set, fix actionable findings, and rerun impacted checks.
5. **QA:** verify acceptance criteria and integration behavior.
6. **Summary:** report changes, passes, risks, remaining work.

## 4) Artifacts (Source of Truth)

`.wannabuild/` in the target project:

- `state.json`: workflow state + stage history
- `spec/requirements.md`: vision, audience, desired feel, flows, features, scope, assumptions, acceptance criteria
- `spec/design.md`: how to build
- `spec/tasks.md`: ordered slices + verification expectations
- `checkpoints/task-*-step-*.md`: micro-step evidence
- `review/*.json`: reviewer verdicts
- `loop-state.json`: review loop history/status
- `outputs/qa-summary.md`: QA evidence
- `decisions.md`: explicit decision log

## 5) Review and QA Logic

- Reviewers are selected by changed surfaces, risk, acceptance criteria, and prior failures.
- `wb-integration-tester` is always included.
- If routing confidence is low: broaden the reviewer set.
- Any FAIL blocks shipping until fixed.
- Integration tester FAIL has no override path.

## 6) State Machine (Public Stages)

`discover -> research? -> plan -> implement -> review -> qa -> summary`

Each stage transition updates `public_stage`, `workflow_status`, and `updated_at`.

## 7) Adaptive Delegation

- Single-owner when coherence matters or work is tightly coupled.
- One focused specialist when one uncertainty dimension matters.
- Multiple parallel specialists when ownership is independent and expected evidence differs.
- Choose capability tier and reasoning effort by complexity, coupling, risk, uncertainty, and expertise required.
- Do not hard-code model IDs or agent counts in core workflow decisions.
- Record delegation rationale in `.wannabuild/decisions.md` or checkpoints.

If unclear, stay single-owner.

## 8) Operational Commands

- Optional implementation worktree: `scripts/wannabuild-workspace.sh --json`
- Artifact contract validation:
  - `scripts/validate-wannabuild-artifacts.sh <project_root> <target_phase>`
- Review/QA gate checks:
  - `scripts/wannabuild-gate-check.sh <project_root> review|qa|summary`
- Repo readiness:
  - `scripts/wannabuild-doctor.sh`

## 9) Fast Failure Signals

Stop and resolve before continuing when any of these occur:

- invalid/malformed `.wannabuild` JSON
- missing required spec artifact for target phase
- missing checkpoint evidence before review routing
- missing/invalid review verdict files
- QA summary missing at summary time

Fail closed, then ask for user direction.
