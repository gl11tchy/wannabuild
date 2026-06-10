---
name: wannabuild
description: Automatic repo-native WannaBuild full-loop workflow for natural "I want to build/add/change..." prompts and any WannaBuild phase skill entrypoint.
---

# WannaBuild

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
This skill obeys the four mandates in `skills/internal/build/references/doctrine.md`: discovery is mandatory and collaborative, resources are exhausted before any blocked claim, gates cannot be rationalized away, and every phase boundary hard-stops for an explicit approval word.
Runtime gates fail closed. Evidence is the default for any pass/fail claim — specialist judgment that affects a review verdict, QA outcome, or gate decision must be backed by it, not produced only when a gate names it.

Use this skill when the user wants WannaBuild itself, not generic coding help.

## Skill-First Dispatch

Use WannaBuild skills automatically whenever they plausibly apply. Commands are optional shortcuts, not the source of truth: keep behavior in skills, let command files only route, and never require a command when intent is clear from natural language.

- Natural "I want to build/add/change/create..." prompts — and exploratory ideation like "I want to work on this some", "I was thinking of ideas", "let's brainstorm this", or "what should we add?" — are enough to start Discover automatically under `wannabuild`.
- Do not answer a matching natural-language request by explaining which command to run. Select the skill and begin the appropriate workflow.
- Treat any explicit `wannabuild:*`, `wb-*`, or host UI WannaBuild skill invocation as a workflow entrypoint, not a one-turn command: start or resume the full loop at the invoked phase and preserve `.wannabuild/` state across turns until the workflow completes or the user explicitly exits or stops.
- Use the smallest matching `wb-*` phase skill for focused discovery, planning, implementation, debugging, review, QA, or ship entry, then continue through the natural next phases. If multiple skills might apply, choose the minimal useful set and continue.
- Stop at a single phase only when the user explicitly says "discovery only", "plan only", "do not implement", "QA only", "review only", or equivalent. For explicit phase-limited work, do only the requested step and keep exploratory work bounded to the decision at hand.

WannaBuild has one default surface — full-loop mode: Discover -> Plan -> Implement -> Validate -> QA -> Summary, entered via `wannabuild`, `wannabuild:*`, or any `wb-*` entrypoint. `wb-*` skills are phase entrypoints into that loop and behave as one-phase tools only under an explicit single-phase limit.

## Startup and Invocation Guard

Keep startup text plain and brief. Do not emit machine-readable start or resume banners in user-visible output. If resuming from `.wannabuild/state.json`, say in ordinary prose that WannaBuild is resuming from the current phase. Do not ask the user to choose between Full, Light, or Spark — run the one standard full-loop workflow unless the user explicitly limits the request to one phase.

If the user invokes `/wannabuild` or `$wannabuild` with no concrete task, no stage intent, and no exploratory idea intent — or only asks what the workflow is — do not inspect the repo deeply, infer the task from git diff, branch state, or uncommitted changes, browse the web, edit files, or start planning or implementation. Respond with exactly this plain prompt and wait for the actual goal:

```text
Tell me what you want to build or change.
```

Use this fallback only for empty or purely meta invocations. A rough goal, open-ended improvement prompt, or brainstorming prompt is actual work for Discover: start the discovery interview instead of asking the user to restate the goal.

Never emit identical assistant messages back-to-back. If the command layer already emitted a startup note this turn, or a checkpoint question is awaiting an answer, wait instead of repeating; when repetition genuinely aids clarity, reword it.

## Workspace Behavior

Use the current checkout for Discover, Plan, Validate, QA, Summary, and explicitly phase-limited work. Do not create an isolated workspace/worktree before discovery or planning.

Before implementation starts from an approved plan, choose the implementation workspace:

1. Continue in the current checkout
2. Create an isolated worktree under `.codex/worktrees/<repo>/...`

Use an isolated worktree only when the user selects it, explicitly asks for isolation, requests parallel implementation, or the implementation risk justifies separation. If one is created, use `scripts/wannabuild-workspace.sh --json` when available, then continue inside the reported `workspace_path`.

Initialize runtime artifacts in the active checkout before continuing:

1. Run `scripts/wannabuild-session.sh init <project_root>`.
2. Run `scripts/wannabuild-session.sh assert-workflow-active <project_root>`.

If either command fails, stop and report the runtime failure. Do not continue with host-only planning, implementation, or workflow claims.

## Workflow

Run: Discover -> Plan -> Implement -> Validate -> QA -> Summary.

In full-loop mode, Discover always runs an interview before any planning — even when the prompt looks detailed, even for a one-line change. There is no "detailed enough" or "trivial" exception. Discover cannot end until each of six dimensions is explicitly resolved with the user — vision, target audience, primary user flows, constraints, scope boundaries, and success signals — and only then may you stop and ask for the explicit approval word that hands off to Plan.

The interview is a Grill. It is mandatory — discovery cannot progress to research or planning without it — and it follows the `wb-discover` contract:

- Ask one question at a time. Do not batch.
- Propose a recommended answer with the reasoning for every question; the user confirms, redirects, or overrides — never invents the answer from scratch.
- Walk the decision tree depth-first; resolve each decision before asking ones that depend on it.
- If a question can be answered by exploring the codebase, explore instead of asking; cite what you found and move on.
- A question is "single-recommendation" only when you offered exactly one recommended answer and no alternatives; anything presenting two or more choices is "multi-option" and requires an explicit selection. State which type each question is when you ask it.
- Within Discover, short affirmatives ("ok", "sure", "fine") to a single-recommendation question accept that recommendation and advance; multi-option questions require an explicit choice. Phase boundaries always require an explicit approval word per Control Mode below, regardless of question shape.

Discovery budget: while the Grill runs, keep inspection bounded and relevant to the stated task — a few high-signal reads, not broad repo spelunking. Do not anchor to unrelated in-flight diffs unless the user explicitly says the current diff is the task. If the task is still unclear, ask instead of continuing to infer.

The Grill claim is never satisfied by asserting it ran — only by its record. Before crossing Discover -> Plan, verify a discovery record in `.wannabuild/outputs/` enumerates each dimension (vision, audience, flows, constraints, scope, success signals) with the user's confirmed answer, and that `.wannabuild/spec/requirements.md` carries an Acceptance Criteria section with at least one concrete, checkable criterion. Any unresolved dimension or missing criteria blocks the boundary, mirroring the fail-closed `assert-discovery-ready` gate.

## Defaults

- Keep Discover, Plan, QA, and Summary single-lane unless parallel specialists materially improve quality; scale sub-agents from task evidence, not fixed counts.
- Choose capability tier and reasoning effort from complexity, coupling, risk, uncertainty, and required expertise; do not name concrete model IDs in core workflow decisions. Record delegation rationale in `.wannabuild/decisions.md` or checkpoints.
- When implementation shape, research scope, or review scope materially affects the outcome, present the options with a recommended answer and proceed once confirmed — never choose silently. Mechanical choices (formatting, file ordering, agent count within a settled shape) proceed without asking.
- Within a phase, run to completion exhaustively: no mid-execution pauses for checkpoints, no stopping early on review or QA burden.

## Control Mode After Discover

Default to guided mode (`control_mode: "guided"`): gate every transition — Discover -> Plan, Plan -> Implement, Implement -> Validate, Validate -> QA, QA -> Summary — and wait for explicit user approval before crossing. At each gate, present what the phase produced, state the next phase, and ask for approval. An explicit approval word — "go", "proceed", "approved", "continue", "next", "lgtm", "do it" — advances exactly one boundary; vague acknowledgments ("ok", "uh ok", "sounds good") never cross a boundary and are never permission to skip required phases. If the user invoked a `wb-*` phase skill, complete that phase, then stop at its boundary and ask before entering the next.

Switch to `control_mode: "autonomous"` only when the user explicitly asks for autonomous or unattended execution. In autonomous mode, continue through every phase — including Validate and QA — without per-boundary approval, asking only when ambiguity changes product direction or scope, when an acquisition is billable, outward-facing, or destructive (paid provisioning, deploys, production data, external sends), or when merge/push/PR strategy is needed. Missing env, missing dependency, no access, or can't-test is never a reason to ask or stop until Resource Acquisition below has been exhausted and logged — and even then only the billable/outward-facing/destructive subset stops for the user.

## Resource Acquisition

This contract applies to Research, Validate, and QA. Before any phase may report blocked, missing-env, missing-dependency, no-access, or can't-test, it MUST first attempt to obtain the resource through every available channel and record what it tried.

Standard acquisition order:

1. project CLIs and scripts
2. connected MCP servers and connectors (live docs via Context7; database branches via Supabase/Neon; environments and deploys via Railway; browser drive via Chrome or computer-use)
3. generate fixtures, seed data, and local/ephemeral environments
4. run the app locally and exercise it directly

Auto-acquire — no permission needed — anything safe, local, and reversible: running the app, spinning ephemeral or local database branches, driving a real browser, reading live docs, generating fixtures, standing up preview environments. Stop and ask only for billable, outward-facing, or destructive acquisition — paid provisioning, deploys, production data, external sends, anything hard to reverse — presenting the specific resource you need and why.

A blocker claim is valid only with proof you tried: record, per unmet need, what was needed, which tools/connectors/CLIs were attempted, and the result in `.wannabuild/outputs/acquisition-log.json`. The fail-closed `assert-acquisition-attempted` gate rejects any blocked or failed status that lacks that entry. Never mark work skipped or blocked without it.

## Research

After discovery, run the research bundle. Research is never zero: depth is proportionate — terse for trivial changes, thorough for features — but the check always runs and is always recorded.

Run a research burst whenever any of these fires. They are deterministic triggers, not judgment calls:

- the change touches an external dependency
- the change uses an API not already exercised in this codebase
- the change makes an architecture decision not already settled in the codebase
- codebase reconnaissance for the changed surface is incomplete

For any external dependency or API in scope, fetching live docs via Context7 (or the provider's MCP) is MANDATORY through Resource Acquisition — uncertainty is itself a trigger, not a reason to skip.

When a trigger fires: update stage to `research`, run a bounded burst with the smallest useful set of specialist agents — each assigned a distinct question, ownership area, capability tier, and reasoning effort; no fixed agent counts, no concrete model IDs — record why that shape was chosen, synthesize a concise research summary, then proceed to planning.

When no trigger fires: record the terse feasibility and failure-forecast check that ruled them out — never silently omit it — and move directly to planning, updating stage to `plan`.

Research through auto-acquire channels (live docs, local recon, fixtures) proceeds without asking. Stop and ask only when research needs billable, outward-facing, or destructive acquisition, or when it materially changes scope or product direction — then present the options with a recommended answer and proceed once confirmed.

## Implementation

Implement only after Plan has completed or been invoked to completion, and only through the WannaBuild implementation path (`wb-build` and the implement contract) — never generic coding behavior.

Default to the smallest shape that can implement the plan well; shape scales depth, never coverage. Use single-owner implementation when tasks are tightly coupled; use parallel agents only when slices are genuinely independent or separate expertise materially improves the outcome. When parallel, assign each agent concrete files, risks, acceptance criteria, or questions, and stop adding agents once ownership stops being distinct.

Record why this execution shape was chosen, what each agent owns, the selected capability tier and reasoning effort, and the expected evidence and checkpoint paths.

## Validate

After implementation completes, validate the change. Validate runs the full reviewer set every iteration — security, performance, architecture, testing, code-simplifier, and integration — with no impacted-only subset, no fast-track for small or low-risk changes, and no reviewer self-selecting out. Partial review is a FAIL, not a style choice.

Validate MUST:

1. list every changed surface and assign at least one reviewer hat to each; risk and prior failures raise depth, never lower coverage
2. attach pass/fail with evidence (real command output, file, or screenshot) to every acceptance criterion
3. fix every bug, regression, and missing test surfaced by a reviewer — "actionable" and "required" are not self-defined opt-outs; a finding is fixed or it blocks the gate
4. rerun the full relevant gate after fixing findings, not a hand-picked subset
5. write a per-surface verdict into `.wannabuild/review/` enumerating what it covered and the evidence checked

## QA

After validation passes, move to QA. QA validates execution, not text markers, and is never collapsed into implementation verification.

QA must:

- stand up or obtain the environment under test via Resource Acquisition before any can't-test claim — missing env, credentials, or access is never grounds to skip QA
- exercise the change against a running app or live integration (database branch, preview deploy, browser drive) — inspection alone does not satisfy QA
- enumerate each acceptance criterion with pass/fail and the exact evidence: the real command run, its exit code, and its output
- confirm integration behavior by execution, recording what actually ran rather than asserting it should pass
- write `.wannabuild/outputs/qa-summary.md` capturing that execution evidence

## Summary Guard

Do not emit the final Summary until Review and QA are both complete. Before summarizing, verify:

- `.wannabuild/review/` contains a verdict file for every changed surface, each naming the surface it covered and the evidence checked
- every required reviewer hat (security, performance, architecture, testing, code-simplifier, integration) produced a `"status": "PASS"` verdict for the latest iteration — any other status value, or a missing reviewer, blocks the summary
- every acceptance criterion appears in a verdict with pass/fail and its evidence
- the integration-tester verdict exists, reran against the latest code, and carries execution evidence: tests actually ran (total > 0, zero failed, zero errored) and every acceptance criterion is covered. "Status: PASS" with zero tests executed is a FAIL. An integration FAIL cannot be overridden here or at any escalation level — there is no override path
- `.wannabuild/outputs/qa-summary.md` exists and records what was executed (real commands, exit codes, output), and any blocked status has a matching entry in `.wannabuild/outputs/acquisition-log.json`

A PASS string alone never satisfies these checks; the substance behind it must be present. If any check fails, block the summary and report what is missing. Once all checks pass, summarize.

## Output Contract

Always finish with:

- what changed
- what passed
- gaps or risks
- remaining work

Keep the user experience compact even if the internal machinery is deeper.

## Stage Machine

Persist and update these public stages in `.wannabuild/state.json`:

1. `discover`
2. `research` when a deterministic trigger fires a bounded research burst
3. `plan`
4. `implement`
5. `review` for the Validate step
6. `qa`
7. `summary`

When entering or completing a stage, update `.wannabuild/state.json` — set `public_stage: "<stage>"`, `workflow_status: "in_progress"`, `updated_at: <RFC3339 timestamp, e.g. 2026-04-06T14:23:45Z>`; at `summary`, set `workflow_status: "complete"`. Do not skip required stages.

## Internal References

Use these contracts as needed. If installed via the Claude Code marketplace, they are available at their relative paths within the plugin; if working directly from the repo, at the same relative paths.

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
