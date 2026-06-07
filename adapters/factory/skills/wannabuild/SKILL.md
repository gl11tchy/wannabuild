---
name: wannabuild
description: Automatic repo-native WannaBuild full-loop workflow for natural "I want to build/add/change..." prompts and any WannaBuild phase skill entrypoint.
---

# WannaBuild

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
This skill obeys the four mandates in `skills/internal/build/references/doctrine.md`: discovery is mandatory and collaborative, resources are exhausted before any blocked claim, gates cannot be rationalized away, and every phase boundary hard-stops for an explicit approval word.
Runtime gates fail closed. Specialist judgment must be backed by evidence whenever it affects a review verdict, QA outcome, or gate decision. Evidence is the default for any pass/fail claim, not something produced only when a gate names it.

Use this skill when the user wants WannaBuild itself, not generic coding help.

## Skill-First Dispatch

Use WannaBuild skills automatically whenever they plausibly apply. Commands are optional shortcuts, not the source of truth.

- Use `wannabuild` for full-loop requests, broad build requests, or "I want X" product/change requests.
- Treat any explicit `wannabuild:*`, `wb-*`, or host UI WannaBuild skill invocation as a workflow entrypoint, not a one-turn command.
- Start or resume the full WannaBuild loop at the invoked phase by default, preserving `.wannabuild/` state across turns until the workflow is complete or the user explicitly exits or stops.
- Use the smallest matching `wb-*` phase skill for focused discovery, planning, implementation, debugging, review, QA, or ship entry, then continue through the natural next phases.
- Do not require the user to invoke a command if the intent is clear from natural language.
- Do not answer a matching natural-language request by explaining which command to run. Select the skill and begin the appropriate workflow.
- Treat natural "I want to build/add/change/create..." feature prompts as enough to start discovery automatically.
- Treat exploratory ideation prompts such as "I want to work on this some", "I was thinking of ideas", "let's brainstorm this", or "what should we add?" as enough to start Discover automatically.
- Stop at a single phase only when the user explicitly says "discovery only", "plan only", "do not implement", "QA only", "review only", or equivalent.
- Never treat vague acknowledgments like "ok", "uh ok", or "sounds good" as permission to skip required phases.
- If multiple skills might apply, choose the minimal useful set and continue.
- Keep behavior in skills; command files should only route.

WannaBuild has one default surface:

- **Full-loop mode:** use `wannabuild`, `wannabuild:*`, or `wb-*` entrypoints for Discover -> Plan -> Implement -> Validate -> QA -> Summary.

`wb-*` skills are phase entrypoints into that loop. They behave as one-phase tools only when the user explicitly limits the request to one phase.

## Invocation Guard

If the user invokes `/wannabuild` or `$wannabuild` with no concrete task, no stage intent, and no exploratory idea intent, or only asks what the workflow is:

- do **not** inspect the repo deeply
- do **not** infer the task from git diff, branch state, or uncommitted changes
- do **not** browse the web
- do **not** edit files
- do **not** start planning or implementation

Instead, respond with a short start prompt and ask for the actual goal.

Use this exact plain prompt:

```text
Tell me what you want to build or change.
```

Only use this fallback for empty or purely meta invocations. A rough goal, open-ended improvement prompt, or brainstorming prompt is actual work for Discover: start the discovery interview instead of asking the user to restate the goal.

## Workspace Behavior

Use the current checkout for Discover, Plan, Validate, QA, Summary, and explicitly phase-limited work.

Do not create an isolated workspace/worktree before discovery or planning.

Before implementation starts from an approved plan, choose the implementation workspace:

1. Continue in the current checkout
2. Create an isolated worktree under `.codex/worktrees/<repo>/...`

Use an isolated worktree only when the user selects it, explicitly asks for isolation, requests parallel implementation, or the implementation risk justifies separation. If an isolated worktree is created, use `scripts/wannabuild-workspace.sh --json` when available and then continue inside the reported `workspace_path`.

Initialize runtime artifacts in the active checkout before continuing:

1. Run `scripts/wannabuild-session.sh init <project_root>`.
2. Run `scripts/wannabuild-session.sh assert-workflow-active <project_root>`.

If either command fails, stop and report the runtime failure. Do not continue with host-only planning, implementation, or workflow claims.

## Workflow

Run this condensed workflow:

1. Discover
2. Plan
3. Implement
4. Validate
5. QA
6. Summary

In full-loop mode, Discover always runs an interview before any planning, even when the prompt looks detailed and even for a one-line change. There is no "detailed enough" or "trivial" exception. Discover cannot end until each of these dimensions is explicitly resolved with the user: vision, target audience, primary user flows, constraints, scope boundaries, and success signals. Only when all six are resolved may you stop and ask the user for an explicit approval word before handing off to Plan.

The Discover interview is a Grill. It is mandatory — full-loop discovery cannot progress to research or planning without it — and it follows the same contract as `wb-discover`:

- Ask one question at a time. Do not batch.
- For every question, propose a recommended answer with the reasoning. The user confirms, redirects, or overrides — they should never have to invent the answer from scratch.
- Walk the decision tree depth-first; resolve each decision before asking ones that depend on it.
- If a question can be answered by exploring the codebase, explore instead of asking. Cite what you found and move on.
- A question is "single-recommendation" only when you offered exactly one recommended answer and no alternatives; anything presenting two or more choices is "multi-option" and requires an explicit selection. State which type each question is when you ask it.
- Within Discover, treat short affirmatives ("ok", "sure", "fine") to a single-recommendation question as accepting that recommendation and advance. Multi-option questions require an explicit choice. Phase boundaries (Discover → Plan, etc.) require an explicit approval word ("go", "proceed", "approved", "lgtm", "do it", "continue", "next") regardless of question shape.

Before crossing the Discover → Plan boundary, verify a discovery record exists in `.wannabuild/outputs/` that enumerates each covered dimension (vision, audience, flows, constraints, scope, success signals) and the user's confirmed answer, and that `.wannabuild/spec/requirements.md` carries an Acceptance Criteria section with at least one concrete, checkable criterion. If any dimension is unresolved or acceptance criteria are absent, the boundary is blocked — this mirrors the fail-closed `assert-discovery-ready` gate. The Grill claim is not satisfied by asserting it ran; it is satisfied only by this record.

## Defaults

- Discover is a vision-first Grill before it is a requirements document, and the Grill runs on every task, including one-line changes. It is verified by the Discover → Plan record, not by assertion.
- Keep Discover, Plan, QA, and Summary single-lane unless parallel specialists materially improve quality.
- Default to guided execution: pause at every phase boundary and require explicit user approval before advancing.
- Research is mandatory whenever the change touches an external dependency, an unfamiliar API, or an architecture decision not already settled in the codebase; depth scales with the change but is never zero. See the Research section for the deterministic triggers.
- Default implementation to the smallest shape that can implement the plan well; this scales depth, never coverage.
- For explicit phase-limited work, do only the requested step and keep exploratory work bounded to the decision at hand.
- Scale sub-agents from task evidence, not fixed counts.
- Choose capability tier and reasoning effort from complexity, coupling, risk, uncertainty, and required expertise; do not name concrete model IDs in core workflow decisions.
- Record delegation rationale in `.wannabuild/decisions.md` or checkpoints.
- Review covers every changed surface and every acceptance criterion on every iteration; adapt the depth and reviewer hats to risk, but never the coverage. Partial review is a FAIL, not a style choice.
- The integration tester is the terminal hard gate. Its FAIL cannot be overridden at any escalation level — there is no override path — and a PASS is valid only with execution evidence that tests actually ran and that every acceptance criterion is covered.

## Internal References

Use these contracts as needed. If installed via the Claude Code marketplace, these are available at their relative paths within the plugin. If working directly from the repo, they are at the same relative paths.

- `AGENTS.md` (repo root) — primary operator contract
- `skills/internal/build/SKILL.md` — full orchestrator contract
- `skills/wb-discover/SKILL.md` — discovery phase entrypoint
- `skills/wb-plan/SKILL.md` — planning phase entrypoint
- `skills/wb-build/SKILL.md` — implementation phase entrypoint
- `skills/wb-debug/SKILL.md` — debugging implementation entrypoint
- `skills/wb-review/SKILL.md` — review phase entrypoint
- `skills/wb-qa/SKILL.md` — QA phase entrypoint
- `skills/wb-ship/SKILL.md` — ship/summary phase entrypoint
- `skills/internal/requirements/SKILL.md`
- `skills/internal/design/SKILL.md`
- `skills/internal/tasks/SKILL.md`
- `skills/internal/implement/SKILL.md`
- `skills/internal/review/SKILL.md`
- `skills/internal/build/references/ship-phase.md`
- `skills/internal/document/SKILL.md`

> **Optional scripts (repo install only):** `scripts/validate-wannabuild-artifacts.sh` can be used for artifact validation if the WannaBuild repo is accessible. It is not required for normal skill execution.

## Startup

Do not emit machine-readable start or resume banners in user-visible output.
Keep startup text plain and brief.

If starting without a concrete task, ask:

```text
Tell me what you want to build or change.
```

If resuming from `.wannabuild/state.json`, say that WannaBuild is resuming from the current phase in ordinary prose.

Do not ask the user to choose between Full, Light, or Spark. Run one standard full-loop workflow unless the user explicitly limits the request to one phase.

## Message De-duplication Guard

To prevent duplicate user-visible outputs:

- Never emit identical assistant messages back-to-back.
- If a startup or resume note was already emitted in the current turn by the command layer, do not emit the same note again.
- If the user explicitly chooses guided mode, ask each checkpoint question once per unresolved stage.
- If the most recent assistant message already contains the exact question and the user has not answered yet, do not repeat it; wait for user input.
- If repetition is necessary for clarity, restate with new wording instead of sending the exact same message text.

## Control Mode After Discover

Default to guided mode. Pause at every phase boundary and require explicit user approval before advancing.

Use:

- `control_mode: "guided"`

Gate each of these transitions and wait for explicit user approval before crossing it:

- Discover -> Plan
- Plan -> Implement
- Implement -> Validate
- Validate -> QA
- QA -> Summary

At each gate, present what the phase produced, state the next phase, and ask for approval to proceed. A vague acknowledgment ("ok", "sounds good") is not approval to skip a phase, but an explicit "go", "proceed", "continue", or "approved" advances exactly one boundary.

If the user invoked a `wb-*` phase skill, complete that phase, then stop at its boundary and ask before entering the next phase.

Switch to `control_mode: "autonomous"` only when the user explicitly asks for autonomous or unattended execution. In autonomous mode, continue through the phases without per-boundary approval, asking only when ambiguity changes product direction or scope, or when an acquisition is billable, outward-facing, or destructive (paid provisioning, deploys, production data, external sends), or merge/push/PR strategy is needed. Missing env, missing dependency, no access, or can't-test is never a reason to ask or stop in autonomous mode until Resource Acquisition has been exhausted and logged; only the billable/outward/destructive subset stops for the user.

## Resource Acquisition

This contract applies to Research, Validate, and QA. Before any phase may report blocked, missing-env, missing-dependency, no-access, or can't-test, it MUST first attempt to obtain the resource through every available channel and record what it tried.

Standard acquisition order:

1. project CLIs and scripts
2. connected MCP servers and connectors (live docs via Context7; database branches via Supabase/Neon; environments and deploys via Railway; browser drive via Chrome or computer-use)
3. generate fixtures, seed data, and local/ephemeral environments
4. run the app locally and exercise it directly

Auto-acquire — no permission needed — anything safe, local, and reversible: running the app, spinning ephemeral or local database branches, driving a real browser, reading live docs, generating fixtures, standing up preview environments. Stop and ask the user only for billable, outward-facing, or destructive acquisition: paid provisioning, deploys, production data, external sends, anything hard to reverse — and present the specific resource you need and why.

A blocker claim is valid only with proof you tried. Record, per unmet need, what was needed, which tools/connectors/CLIs were attempted, and the result in `.wannabuild/outputs/acquisition-log.json`. This mirrors the fail-closed `assert-acquisition-attempted` gate, which rejects any blocked or failed status that lacks a logged attempt. Never mark work skipped or blocked without that entry.

## Research

After discovery, run the research bundle. Research is never zero; depth is proportionate (terse for trivial changes, thorough for features) but always produces a synthesized summary.

Run research whenever any of these is true — these are deterministic triggers, not judgment calls:

- the change touches an external dependency
- the change uses an API not already exercised in this codebase
- the change makes an architecture decision not already settled in the codebase
- codebase reconnaissance for the changed surface is incomplete

For any external dependency or API in scope, fetching live docs via Context7 (or the provider's MCP) is MANDATORY through Resource Acquisition — uncertainty is itself a trigger, not a reason to skip. When none of the triggers fire, still record the feasibility and failure-forecast check that ruled them out; do not silently omit research.

If research is warranted:

- run a bounded research burst using the smallest useful set of specialist agents
- assign each agent a distinct question, ownership area, capability tier, and reasoning effort
- avoid fixed agent counts and concrete model IDs
- record why this research shape was chosen
- synthesize findings into a concise research summary
- then proceed to planning
- update stage to `research`

If no trigger fires (no external dependency, no unfamiliar API, no unsettled architecture decision, recon complete):

- record the terse feasibility and failure-forecast check that confirmed enough context to plan
- move directly to planning
- update stage to `plan`

Research that uses Resource Acquisition's auto-acquire channels (live docs, local recon, fixtures) proceeds without asking. Stop and ask the user only when research needs billable, outward-facing, or destructive acquisition, or when it materially changes scope or product direction — in which case present the options with a recommended answer and proceed once confirmed.

## Implementation

After planning is complete and the approach is verified:

Default to the smallest shape that can implement the plan well. Use single-owner implementation when tasks are tightly coupled. Use parallel agents only when slices are genuinely independent or when separate expertise materially improves the outcome.

Use the WannaBuild implementation path (`wb-build` and the implement contract) for implementation. Do not fall back to generic coding behavior, and do not implement before Plan has completed or been invoked to completion.

When using adaptive parallel implementation, assign each agent concrete files, risks, acceptance criteria, or questions, and stop adding agents once ownership stops being distinct.

Choose adaptively and record:

- why this execution shape was chosen
- what each agent owns
- selected capability tier and reasoning effort
- expected evidence and checkpoint paths

When the implementation shape, research scope, or review scope materially affects the outcome, present the options to the user with a recommended answer and proceed once confirmed; do not choose silently. Mechanical choices (formatting, file ordering, agent count within a settled shape) proceed without asking. Within a phase, run to completion exhaustively — do not pause mid-execution for checkpoints and do not stop early on review or QA burden.

## Validate

After implementation completes, validate the change. Validate runs the full reviewer set every iteration — security, performance, architecture, testing, code-simplifier, and integration — with no impacted-only subset, no fast-track for small or low-risk changes, and no reviewer self-selecting out.

Validate MUST:

1. list every changed surface and assign at least one reviewer hat to each; risk and prior failures raise the depth, never lower the coverage
2. for each acceptance criterion, attach pass/fail with evidence (real command output, file, or screenshot)
3. fix every bug, regression, and missing test surfaced by a reviewer — "actionable" and "required" are not self-defined opt-outs; a finding is fixed or it blocks the gate
4. after fixing findings, rerun the full relevant gate, not a hand-picked subset
5. write a per-surface verdict into `.wannabuild/review/` that enumerates what it covered and the evidence checked

Update `.wannabuild/state.json` — set `public_stage: "review"`, `workflow_status: "in_progress"`, `updated_at: <RFC3339 timestamp, e.g. 2026-04-06T14:23:45Z>`.

In guided mode, stop at the Implement -> Validate boundary and ask for approval before running validation, then stop again at the Validate -> QA boundary before continuing. In autonomous mode, do not stop for validation approval; a blocker is valid only after Resource Acquisition is exhausted and logged, and even then it stops for the user only when the unmet need is billable, outward-facing, or destructive.

## QA

After validation passes, move to QA. QA validates execution, not text markers.

QA must:

- stand up or obtain the environment under test via Resource Acquisition before any can't-test claim
- exercise the change against a running app or live integration (database branch, preview deploy, browser drive) — inspection alone does not satisfy QA
- enumerate each acceptance criterion with pass/fail and the exact evidence: the real command run, its exit code, and its output
- confirm integration behavior by execution, recording what actually ran rather than asserting it should pass
- write `.wannabuild/outputs/qa-summary.md` capturing that execution evidence

Update `.wannabuild/state.json` — set `public_stage: "qa"`, `workflow_status: "in_progress"`, `updated_at: <RFC3339 timestamp, e.g. 2026-04-06T14:23:45Z>`.

Do not collapse QA into implementation verification.

In guided mode, stop at the Validate -> QA boundary and ask for approval before running QA, then stop again at the QA -> Summary boundary before summarizing. In autonomous mode, proceed through QA automatically. Missing env, missing credentials, or no access is never grounds to skip QA until Resource Acquisition has been exhausted and logged; QA stops for the user only when the unmet need is billable, outward-facing, or destructive (paid services, production data, external sends, irreversible actions).

## Summary Guard

Do not emit the final Summary until Review and QA are both complete.

Before summarizing, verify:

- `.wannabuild/review/` contains a verdict file for every changed surface, and each verdict names the surface it covered and the evidence checked
- every required reviewer hat (security, performance, architecture, testing, code-simplifier, integration) produced a `"status": "PASS"` verdict for the latest iteration — any other status value, or a missing reviewer, blocks the summary
- every acceptance criterion appears in a verdict with pass/fail and its evidence
- the integration-tester verdict exists, reran against the latest code, and carries execution evidence: tests actually ran (total > 0, zero failed, zero errored) and every acceptance criterion is covered. "Status: PASS" with zero tests executed is a FAIL. An integration FAIL cannot be overridden here or at any escalation level — there is no override path
- `.wannabuild/outputs/qa-summary.md` exists and records what was executed (real commands, exit codes, output), and any blocked status has a matching entry in `.wannabuild/outputs/acquisition-log.json`

A PASS string alone never satisfies these checks; the substance behind it must be present. If any check fails, block the summary and report what is missing.

Then update `.wannabuild/state.json` — set `public_stage: "summary"`, `workflow_status: "complete"`, `updated_at: <RFC3339 timestamp, e.g. 2026-04-06T14:23:45Z>`.

Summarize once validation and QA pass.

## Output Contract

Always finish with:

- what changed
- what passed
- gaps or risks
- remaining work

Keep the user experience compact even if the internal machinery is deeper.

## Discovery Budget

During Discover, before the user has approved planning:

- keep inspection bounded and relevant to the stated task
- prefer a few high-signal reads over broad repo spelunking
- do not anchor to unrelated in-flight diffs unless the user explicitly says the current diff is the task
- if the task is still unclear, ask instead of continuing to infer

## Stage Machine

Persist and update these public stages in `.wannabuild/state.json`:

1. `discover`
2. `research` when a deterministic trigger fires a bounded research burst
3. `plan`
4. `implement`
5. `review` for the Validate step
6. `qa`
7. `summary`

When entering or completing a stage, update `.wannabuild/state.json` — set `public_stage: "<stage>"`, `workflow_status: "in_progress"` or `workflow_status: "complete"`, `updated_at: <RFC3339 timestamp, e.g. 2026-04-06T14:23:45Z>`.

Do not skip required stages. Research is never zero: when no trigger fires a `research` burst, the feasibility and failure-forecast check still runs and is recorded during `discover`/`plan` — it is never silently dropped.
