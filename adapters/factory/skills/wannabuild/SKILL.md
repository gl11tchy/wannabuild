---
name: wannabuild
description: Automatic repo-native WannaBuild full-loop workflow for natural "I want to build/add/change..." prompts and any WannaBuild phase skill entrypoint.
---

# WannaBuild

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

Initialize `.wannabuild/state.json` in the active checkout before continuing:

```json
{
  "project": "<project folder name>",
  "mode": "standard",
  "current_phase": "requirements",
  "phase_status": "pending",
  "public_stage": "discover",
  "workflow_status": "in_progress",
  "control_mode": "autonomous",
  "started_at": "<RFC3339 timestamp, e.g. 2026-04-06T14:23:45Z>",
  "updated_at": "<RFC3339 timestamp, e.g. 2026-04-06T14:23:45Z>",
  "artifacts": {},
  "phase_history": [],
  "public_stage_history": [
    {
      "stage": "discover",
      "status": "in_progress",
      "timestamp": "<RFC3339 timestamp, e.g. 2026-04-06T14:23:45Z>"
    }
  ]
}
```

## Workflow

Run this condensed workflow:

1. Discover
2. Plan
3. Implement
4. Validate
5. QA
6. Summary

In full-loop mode, Discover should interview until the goal is crisp enough to form requirements, then hand off to Plan automatically unless user judgment is needed.

## Defaults

- Discover is a vision-first interview before it is a requirements document.
- Keep Discover, Plan, QA, and Summary single-lane unless parallel specialists materially improve quality.
- Default to autonomous execution after discovery.
- Run optional research before planning when uncertainty is materially high.
- Choose implementation shape adaptively.
- For explicit phase-limited work, do only the requested step and keep exploratory work bounded to the decision at hand.
- Scale sub-agents from task evidence, not fixed counts.
- Choose capability tier and reasoning effort from complexity, coupling, risk, uncertainty, and required expertise; do not name concrete model IDs in core workflow decisions.
- Record delegation rationale in `.wannabuild/decisions.md` or checkpoints.
- Keep review adaptive rather than maximal by default.
- The integration tester is the hard gate.

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

## Autonomy After Discover

After Discover, continue autonomously by default. Do not ask whether to stay guided or switch to autonomous.

Use:

- `control_mode: "autonomous"`

Continue through planning, implementation, validation, QA, and summary unless user judgment is required.

If the user invoked a `wb-*` phase skill, continue from that phase into the next natural phase once its completion signal is met. A vague acknowledgment is not an exit, approval to skip planning, or instruction to stop.

Ask only when:

- ambiguity changes product direction or scope materially
- credentials, paid services, production data, or destructive actions are involved
- merge, push, PR, or direct-to-main strategy is needed
- the user explicitly requested guided mode

If the user requests guided mode, set `control_mode: "guided"` and pause at natural checkpoints.

## Research

After discovery, decide whether research would materially improve planning quality.

Run research only when at least one of these is true:

- architecture direction is still unclear
- external dependency choice matters
- codebase reconnaissance is incomplete
- domain or API uncertainty is high
- risk is high enough that parallel investigation would help

If research is warranted:

- run a bounded research burst using the smallest useful set of specialist agents
- assign each agent a distinct question, ownership area, capability tier, and reasoning effort
- avoid fixed agent counts and concrete model IDs
- record why this research shape was chosen
- synthesize findings into a concise research summary
- then proceed to planning
- update stage to `research`

If research is not warranted:

- say that you have enough context to plan
- move directly to planning
- update stage to `plan`

Do not ask before research unless it needs external browsing, paid APIs, credentials, or materially changes scope.

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

## Validate

After implementation completes, validate the change.

Choose reviewer hats and checks from changed surfaces, risk, acceptance criteria, and prior failures. Fix actionable bugs, regressions, and missing required tests automatically, then rerun impacted checks.

Write verdicts into `.wannabuild/review/`.

Update `.wannabuild/state.json` — set `public_stage: "review"`, `workflow_status: "in_progress"`, `updated_at: <RFC3339 timestamp, e.g. 2026-04-06T14:23:45Z>`.

Do not stop for validation approval unless a blocker requires user judgment.

## QA

After validation passes, move to QA.

QA must:

- confirm acceptance criteria coverage
- confirm integration behavior
- write `.wannabuild/outputs/qa-summary.md`

Update `.wannabuild/state.json` — set `public_stage: "qa"`, `workflow_status: "in_progress"`, `updated_at: <RFC3339 timestamp, e.g. 2026-04-06T14:23:45Z>`.

Do not collapse QA into implementation verification.

Proceed through QA automatically unless it requires user-controlled systems, credentials, paid services, or destructive actions.

## Summary Guard

Do not emit the final Summary until Review and QA are both complete.

Before summarizing, verify:

- `.wannabuild/review/` exists and contains at least one `*.json` verdict file
- All verdict files have `"status": "PASS"` — any other status value blocks the summary
- `.wannabuild/outputs/qa-summary.md` exists

If any check fails, block the summary and report what is missing.

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
2. `research` when bounded research is warranted
3. `plan`
4. `implement`
5. `review` for the Validate step
6. `qa`
7. `summary`

When entering or completing a stage, update `.wannabuild/state.json` — set `public_stage: "<stage>"`, `workflow_status: "in_progress"` or `workflow_status: "complete"`, `updated_at: <RFC3339 timestamp, e.g. 2026-04-06T14:23:45Z>`.

Do not skip required stages silently. Research is optional; omit it when it would not materially improve the plan.
