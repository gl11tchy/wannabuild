# WannaBuild: Implement Phase

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
This phase inherits the four mandates in `skills/internal/build/references/doctrine.md`; where this file is silent, the doctrine governs and its runtime gates fail closed.
Runtime gates fail closed. Every completion claim, blocker claim, and "tests pass" claim MUST carry bound evidence (a checkpoint file path, a captured command + exit code, or a test runner output file). Self-attestation without bound evidence counts as incomplete.

> "Let's build this thing."

Phase 4 of 7 in the WannaBuild SDD pipeline. The implementer works through the task spec in micro-steps, writing feature code and integration tests with checkpoint evidence after each verified step.

## Agent

| Agent | File | Role |
|-------|------|------|
| Implementer (default) | `wb-implementer` | Executes tasks from spec using the parent session model, writes code + integration tests, checkpoints |
| Implementer (escalated) | `wb-implementer-escalated` | Same implementation role, but inherits parent model for high-complexity work and review-loop remediation |

This phase runs single-owner or parallel implementation, selected by a fixed rule so the shape is reproducible run to run.

- Run **parallel implementation ONLY** when `tasks.md` declares non-overlapping file/module write ownership per slice. If any two slices can write the same file or module, the choice is single-owner — there is no judgment call.
- Run **single-owner** in every other case (coupled work, shared write surface, or ownership not declared in `tasks.md`).
- Set capability tier and reasoning effort from explicit signals, not feel: a task that touches auth, payments, migrations, money movement, or security boundaries → strong tier + high effort; a remediation iteration ≥ 2 → strong tier + high effort; otherwise standard tier + medium effort.
- Do not hard-code concrete model IDs or fixed implementer counts.
- Record the selected execution shape and the signal that drove tier/effort in `.wannabuild/decisions.md` and in each checkpoint.

Advisor escalation assists the implementer on the fixed triggers listed under Handling Review Feedback (unclear fix path, conflicting reviewer findings, a fix that changes architecture or validation strategy, or risk of worsening on continued attempts) — it does not replace the implementer. The implementer remains the foreground executor with full tool ownership; the advisor is read-only and only provides bounded guidance, correction, risk assessment, or a stop signal. It may not call tools, edit files, run commands, or produce user-facing output.

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

The implementer MUST read all three spec artifacts in full before writing any code.

Before writing any code, run the hard discovery gate, the hard planning gate, and the artifact validator — in this order:

```bash
scripts/wannabuild-session.sh assert-discovery-ready .
scripts/wannabuild-session.sh assert-plan-ready .
scripts/validate-wannabuild-artifacts.sh . implement
```

`assert-discovery-ready` confirms discovery actually fired and `requirements.md` carries a user-validated **Acceptance Criteria** section with ≥1 concrete, checkable criterion. If it fails — or if requirements are marked assumed/unconfirmed, or contain no acceptance criteria — STOP and return to Discover/Plan. Do not implement against an unmeasurable or unconfirmed goal.

Resolve every contract violation before proceeding; a runtime-unavailable gate result is a hard stop, not permission to proceed. If the planning gate fails, return to Plan; do not edit implementation files.

## Execution Flow

0. Pass `assert-discovery-ready` and `assert-plan-ready` (see Input). A failure here is a hard stop, not a degraded-mode proceed.
1. Read `spec/requirements.md`, `spec/design.md`, and `spec/tasks.md` in full.
2. Read the task plan's Delegation Guidance.
3. Select implementation shape by the fixed rule in the Agent section: parallel only when `tasks.md` declares non-overlapping write ownership, single-owner otherwise; tier/effort from the explicit signals listed there.
4. Study existing code and local conventions.
5. Implement in micro-steps. Each step ends with a real executed verification and a checkpoint — never a deferred or assumed result.
6. Write checkpoints with bound evidence for each completed micro-step.
7. Integrate parallel slices before Review.
8. Run transition validation and hand off to Review only when it passes.

## Agent Spawning

```text
# Single-owner path
Task(subagent_type="<selected implementer>")
  capability_tier: <standard or strong>
  reasoning_effort: <medium or high>
  ownership: <all tasks or specific remediation slice>
  prompt: "Implement owned tasks from .wannabuild/spec/tasks.md.
           Read the full spec chain at .wannabuild/spec/ first.
           Codebase at: {codebase_path}.
           Write checkpoints and delegation rationale."

# Parallel path
for each independent slice:
  Task(subagent_type="<selected implementer>", run_in_background=true)
    capability_tier: <standard or strong>
    reasoning_effort: <medium or high>
    ownership: <disjoint files/modules/acceptance criteria>
    prompt: "Implement only your owned slice.
             You are not alone in the codebase; do not revert others' edits.
             Write checkpoints and return a compact completion summary."
```

Use background implementers only when the host supports safe parallel editing and the slices have disjoint write ownership. Otherwise keep the foreground implementer as the single tool-using owner.

## Integration Tests Are Non-Negotiable

Every task with an "Integration Test" field MUST have corresponding test code. The implementer agent's prompt enforces this:

- Write the integration test FIRST, before the feature code — for every such task, with no exceptions. The test defines "working" before the feature exists.
- A task is NOT complete until: (a) its integration test exists in-repo; (b) it executed against the real acquired resource (live DB branch, running service, real endpoint) — mocks, stubs, fakes, or in-memory doubles for the integrated boundary are forbidden; and (c) the captured command, exit code, and full pass/fail output are written into the task's checkpoint.
- If the resource the test needs is not present, acquire it via the ladder in "Resource Acquisition Is Mandatory" before writing the word "blocked." You may not defer or skip the test for a missing resource.
- This is re-validated by `wb-integration-tester` (the terminal hard gate) in the Review phase; a PASS there requires the same execution evidence.

## Checkpoint Format

Each completed micro-step writes a checkpoint file at:

- `.wannabuild/checkpoints/task-{N}-step-{M}.md`

Checkpoint content MUST include:

- changed files
- the exact verify command run, its exit code, and its real captured output (not an expected or assumed result)
- pending next micro-step
- execution shape and the signal that drove tier/effort; plus delegation rationale when the step used or integrated sub-agent work

## Task Execution Protocol

For each task in `spec/tasks.md`:

1. **Read the task** — understand files, deps, acceptance criteria, required tests
2. **Check dependencies** — verify prerequisite tasks are complete
3. **Study existing code** — read target files, match patterns and conventions
4. **Execute micro-steps in order** — one micro-step at a time (`read step -> implement minimal change -> verify -> write checkpoint -> continue`)
5. **Write the integration/acceptance test first** — derive expected behavior from the clarified acceptance criteria; the test must cover the task's acceptance criteria and must fail before the feature code exists. Test-first is mandatory for every task with an Integration Test field, not a preference.
6. **Run tests against real acquired resources** — execute the test suite (new + existing) against the live DB branch, running service, or real endpoint. If a resource is missing, acquire it via the ladder in "Resource Acquisition Is Mandatory" first. Record the real command, exit code, and output. A test that did not actually execute is not a passing test.
7. **Write checkpoint evidence** — `.wannabuild/checkpoints/task-{N}-step-{M}.md`, with the captured command and output from step 6 bound in.
8. **Report status** — mark a task complete only when every acceptance criterion has a passing executed test; record any spec divergence per the rule in Edge Cases (confirm with the user before diverging).

## Resource Acquisition Is Mandatory

"Missing env", "no database", "no access", "can't run it", "no fixtures" are never grounds to skip a task, a test, or any obligation. They are grounds to OBTAIN the resource or ASK the user — never to silently drop work. Before you may write "blocked" or "unavailable" anywhere, you MUST exhaust this ladder in order and record each attempt:

1. The relevant CLI (`supabase`, `railway`, `vercel`, `gh`, package managers, the project's own scripts).
2. The matching MCP connector to provision a real resource — e.g. Supabase/Neon `create_branch` for an ephemeral DB branch, Railway `deploy`/`create_service`, Vercel `deploy_to_vercel` for a preview, Context7 for live library docs, a browser (Chrome) or computer-use to drive a real UI.
3. Generate fixtures/seed data, or stand up a local/ephemeral environment, when a connector cannot.

Auto-acquire anything safe, local, and reversible without asking (run the app locally, spin an ephemeral DB branch, drive a real browser, generate fixtures, read live docs). STOP and ask the user ONLY for billable, outward-facing, or destructive acquisition (paid provisioning, deploys, production data, external sends).

Every blocker or "unavailable" claim requires an entry in `.wannabuild/outputs/acquisition-log.json` recording, per unmet need: what was needed, which CLIs/connectors/tools you attempted, and the exact error each returned. When asking the user, your message must enumerate every CLI, connector, and tool you tried and the error each returned. Run `scripts/wannabuild-session.sh assert-acquisition-attempted .` before reporting any blocker — it rejects a blocked status with no logged attempt.

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

The escalated implementer (`wb-implementer-escalated`) addresses each issue, runs tests again, and records checkpoint evidence per micro-step. Remediation MUST resolve every issue in the aggregated feedback — scope tightly to the listed feedback, but do not declare remediation complete until each issue has a corresponding fix plus a re-run, passing integration test recorded in a checkpoint. It does NOT skip integration test requirements — those are non-negotiable regardless of which iteration.

Use advisor escalation during remediation only when the fix path is unclear, reviewer findings conflict, the likely fix changes architecture or validation strategy, or continuing could worsen risk. The advisor must not call tools, edit files, run commands, or produce user-facing output. If the guidance changes implementation strategy, architecture, scope, or validation, record the decision in `.wannabuild/decisions.md` and, when useful, save a compact report under `.wannabuild/outputs/advisor/`.

## Coding Standards

- **Follow existing patterns.** Match the codebase's style, naming, and structure.
- **Implement the whole spec.** Implement every acceptance criterion and every error/edge case named in the spec. Do not add scope beyond the spec; do not omit anything the spec requires. No placeholders, stubs, mocks, fakes, or `to-do` markers left in place of required behavior on a delivered path.
- **Checkpoint every micro-step.**
- **VCS commits during micro-steps are at the implementer's discretion, but a commit is mandatory before ship/PR creation.**
- **Test as you go.** Run the full test suite against real acquired resources after each task and bind the captured output into the checkpoint.

## When to Collaborate vs. Proceed

This contract is deterministic: the same situation produces the same behavior on every run. The implement phase runs autonomously to completion within the phase — it does not pause for "checkpoints" or stop early on test/remediation burden — but it collaborates on the decisions below.

**Stop and collaborate** — present 2-3 options, each with a recommended answer and its trade-offs, and wait for the user — when a choice:

- affects product behavior, user-facing flows, or acceptance criteria;
- changes the data model, a public API, or any external contract;
- affects security, cost, or money movement;
- diverges from the design spec, or reveals a spec error (see Edge Cases — confirm the correction before diverging).

**Proceed without asking** (and record the decision in the checkpoint or `.wannabuild/decisions.md`) when the choice is purely internal and spec-neutral:

- naming, file layout, or local code structure with no contract impact;
- a choice between approaches that are observably equivalent under the acceptance criteria;
- any mechanical step inside an already-approved task.

A task that "seems impossible", "is larger than estimated", or appears "blocked" is NOT an ask trigger by itself — first exhaust the acquisition ladder and real execution attempts (see "Resource Acquisition Is Mandatory"), then ask only with the logged evidence of what you tried.

## Output

The implementer reports per-task progress:

```markdown
### Task [N]: [title] — COMPLETE
**Files changed:** [list]
**Tests written:** [test file: descriptions]
**Checkpoints:** [.wannabuild/checkpoints/task-{N}-step-{M}.md, ...]
**Notes:** [discoveries, deviations]
```

And a final summary:

```markdown
## Implementation Summary
- **Tasks completed:** [N/total]
- **Tests written:** [count]
- **Tests passing:** [count]
- **Blockers:** [each with its `acquisition-log.json` entry — the CLIs/connectors/tools tried and the error each returned; no blocker without a logged attempt]
- **Spec deviations:** [each one, with the user confirmation that approved it]
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
    "checkpoints": [".wannabuild/checkpoints/task-1-step-1.md", "..."]
  }
}
```

Before handing off, rerun transition validation:

```bash
scripts/validate-wannabuild-artifacts.sh . review
```

Only launch review agents when this passes.

## Edge Cases

- **Task appears blocked by an external dependency:** You may NOT skip the task. Before writing the word "blocked" you MUST exhaust the acquisition ladder in "Resource Acquisition Is Mandatory" and log each attempt in `.wannabuild/outputs/acquisition-log.json`. Only after the ladder is fully exhausted and `assert-acquisition-attempted` passes may you stop and ask the user — and only for billable, outward-facing, or destructive acquisition, enumerating every CLI/connector/tool you tried and the error each returned. "Unavailable" / "missing" is not assertable without that logged evidence.
- **Spec is wrong:** If implementation reveals a spec error, STOP, surface the error with 2-3 corrective options and a recommended answer, and confirm the correction with the user before diverging. Do not diverge-and-document on your own authority; record the confirmed decision in `.wannabuild/decisions.md`.
- **Test infrastructure is missing:** Stand it up via the acquisition ladder (CLI → MCP connector → fixtures/ephemeral env) as part of the task that needs it, then write the test first. Missing infrastructure is never grounds to defer or skip the test.
- **Resuming after interruption:** Read `spec/tasks.md` for task statuses. Pick up from the first incomplete task.

## Quality Checklist

Each item requires bound evidence (an artifact path or captured command output). An item without bound evidence counts as failing — do not check it.

- [ ] All tasks from `spec/tasks.md` are complete — list the checkpoint file per task
- [ ] Every task with an Integration Test field has a written test — list test `file:line` per task
- [ ] All tests pass (new and existing) — attach the test runner output captured under `.wannabuild/checkpoints/` with command + exit code
- [ ] Every integration test executed against a real acquired resource (no mocks/stubs/fakes on the integrated boundary)
- [ ] Checkpoint evidence exists for each completed micro-step — list the paths
- [ ] No hardcoded secrets, tokens, or credentials
- [ ] No placeholders, stubs, fakes, or `to-do` markers left on a delivered path
- [ ] Code follows existing codebase patterns
- [ ] Every spec divergence was confirmed with the user and recorded in `.wannabuild/decisions.md`
- [ ] Any blocker carries a logged acquisition attempt and a passing `assert-acquisition-attempted`

## Contract Validation

- If `design.md` is missing, STOP and return to Plan. Do not implement from `requirements + existing code patterns`. Record the gap and request the design artifact; do not proceed in a degraded mode.
- Each completed micro-step must produce one checkpoint with:
  - changed files
  - the exact command run, its exit code, and its real captured output
  - next pending step
- Any task with an `Integration Test` requirement must have a corresponding passing integration test — executed against a real acquired resource, not a mock or stub — in repo before it is marked complete.
- Handoff to review must include:
  - tasks completed count
  - checksums or file list from latest checkpoints
  - explicit test pass/fail counts
