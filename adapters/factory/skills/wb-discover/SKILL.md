---
name: wb-discover
description: WannaBuild discovery phase entrypoint that grills the user — one question at a time, each with a recommended answer — to clarify vision, audience, flows, constraints, scope, and success signals before continuing the full loop. Also triggers on "grill me" or any request to interview the user relentlessly about a design or idea.
---

# wb-discover

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed. Specialist judgment stays advisory unless a gate or acceptance criterion requires evidence.

Use this phase skill when the user invokes discovery or the active WannaBuild workflow is in Discover. A `wb-discover` or `wannabuild:wb-discover` invocation starts or resumes the full WannaBuild loop unless the user explicitly says discovery only.

## Phase Bootstrap

Before any discovery phase work:

- If no concrete task or exploratory idea intent exists, ask for the actual goal first.
- Work in the current checkout by default.
- Do not create an isolated worktree for discovery.

## Purpose

Turn a rough idea or unclear request into a deeply qualified problem brief and requirements direction.

## Defaults

- Interview until the user's intent is crisp enough to research without guessing.
- Ask only for missing information that changes scope, design, acceptance, or success.
- Use bounded repo reconnaissance only when the codebase materially affects discovery.
- Do not infer intent from git diff or uncommitted changes.
- Preserve active WannaBuild workflow state across turns until the task is complete or the user explicitly exits or stops.
- Do not treat vague acknowledgments like "ok" or "uh ok" as permission to skip planning, implementation, QA, or summary.
- Proceed to planning automatically after the requirements direction is crisp enough unless the user explicitly requested discovery only.
- After initial intent is clear, run the required research bundle before Plan: feasibility, alternatives/competition, and Failure Forecast.
- Add adaptive research only when goal evidence justifies it: UX, security/privacy, integrations, data/migration, compliance, performance, monetization, or domain research.
- Use sub-agents where the host supports them for distinct discovery perspectives; otherwise produce the same artifacts directly.

## Grill

Discovery requires a grill pass. It is mandatory — skipping it is forbidden, even when the user sounds eager to move on. The grill is how vague intent becomes crisp enough to research without guessing.

- Interview relentlessly until shared understanding. "Crisp" means every branch of the decision tree that materially affects scope, design, acceptance, or success has been resolved — not until the user sounds tired.
- Ask one question at a time. Do not batch.
- For every question, propose a recommended answer with the reasoning behind it. The user confirms, redirects, or overrides — they should never have to invent the answer from scratch.
- Walk the decision tree depth-first. Resolve each decision before asking ones that depend on it; answering a downstream question before its parent wastes the answer.
- If a question can be answered by exploring the codebase, explore instead of asking. Cite what you found and move on.
- Within the Discover phase, treat short affirmatives ("ok", "sure", "fine", "uh ok") to a single-recommendation question as accepting that recommendation, and advance.
- Phase boundaries are different. A short affirmative never crosses Discover → Plan (or any other phase boundary) on its own — guided mode requires an explicit approval word ("go", "proceed", "approved", "lgtm", "do it", "continue", "next") regardless of how the prior question was shaped.
- Multi-option questions also never accept a short affirmative. If the reply does not map to a specific option, ask for the explicit choice.

## Flow

1. Run the Grill to identify the vision, audience, desired feel, core flows, features, constraints, priorities, non-goals, success signals, budget/time tolerance, and decision tradeoffs.
2. State assumptions explicitly and surface meaningful ambiguity instead of resolving it silently.
3. Once the intent is clear enough to research, run the required research bundle:
   - feasibility: implementation path, dependencies, unknowns, and effort risk
   - alternatives/competition: direct competitors, adjacent alternatives, existing tools/libraries, and manual or do-nothing options
   - Failure Forecast: assume the project failed, identify likely causes, and turn them into questions or mitigations
4. Add adaptive specialist research only when the user's goal makes it relevant.
5. Synthesize research into sharper qualifying questions and ask only those that change scope, success, or product direction. Continue to apply the Grill rules — one question, recommended answer, codebase first.
6. Write the final requirements direction with scope, non-goals, acceptance signals, research synthesis, qualified decisions, Failure Forecast impact, and remaining open questions.
7. If the user did not explicitly request discovery only, hand off to Plan automatically after `assert-discovery-ready` passes.

## Output

In a WannaBuild workspace, Discovery must produce:

- `.wannabuild/outputs/discovery/feasibility.md`
- `.wannabuild/outputs/discovery/alternatives-competition.md`
- `.wannabuild/outputs/discovery/failure-forecast.md`
- `.wannabuild/outputs/discovery/followup-questions.md`
- `.wannabuild/spec/requirements.md`

Record completed discovery evidence in `.wannabuild/state.json` under `discovery`. In full-loop mode, continue to planning only after `scripts/wannabuild-session.sh assert-discovery-ready .` succeeds unless user judgment is required.
