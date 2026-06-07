---
name: wb-discover
description: WannaBuild discovery phase entrypoint that grills the user — one question at a time, each with a recommended answer — to clarify vision, audience, flows, constraints, scope, and success signals before continuing the full loop. Also triggers on "grill me" or "grill this idea".
---

# wb-discover

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed. Specialist judgment stays advisory unless a gate or acceptance criterion requires evidence.

Use this phase skill when the user invokes discovery or the active WannaBuild workflow is in Discover. A `wb-discover` or `wannabuild:wb-discover` invocation starts or resumes the full WannaBuild loop. Discovery is mandatory before Plan, Implement, QA, or Summary for any build/add/change/fix request; there is no skip-discovery path. If the user asks to skip it, explain that Plan cannot start without a confirmed requirements direction and offer a proportionate grill (fewer questions on a trivial change, same mandatory checklist) rather than dropping the phase. If the user explicitly asks for discovery only, stop after the Discover → Plan boundary instead of handing off.

## Phase Bootstrap

Before any discovery phase work:

- If no concrete task or exploratory idea intent exists, ask for the actual goal first.
- Work in the current checkout by default.
- Do not create an isolated worktree for discovery.

## Purpose

Turn a rough idea or unclear request into a deeply qualified problem brief and requirements direction.

## Defaults

- Discovery fires on every build/add/change/fix request, including one-line changes. It is never optional, never auto-skipped, and never bypassed by a "trivial" classification. Only the user shortens it, by answering quickly. Per `skills/internal/build/references/doctrine.md` Mandate 1.
- Interview until the Discovery Exit Checklist (see Grill) is fully resolved and recorded. The exit is the checklist, not a self-judged sense that intent is "clear".
- Ask for every piece of missing information that changes scope, design, acceptance, or success. Do not defer such a question as a "later" detail.
- Run bounded repo reconnaissance to resolve any question the codebase can answer factually before asking the user (see Grill).
- Do not infer intent from git diff or uncommitted changes.
- Preserve active WannaBuild workflow state across turns until the task is complete or the user explicitly exits or stops.
- Do not treat vague acknowledgments like "ok" or "uh ok" as permission to cross any phase boundary — including Discover → Plan — or to skip discovery, planning, implementation, QA, or summary.
- Do not advance to Plan until the user confirms the synthesized requirements direction with an explicit approval word (see Flow step 7). Discovery never auto-advances.
- After initial intent is clear, run the required research bundle before Plan: feasibility, alternatives/competition, and Failure Forecast. Depth is proportionate to the change (terse for trivial, thorough for features) but never zero.
- Run every adaptive research track whose trigger is present (see Flow step 4). The set of tracks that run is determined by triggers, never by self-judgment.
- Use sub-agents where the host supports them for distinct discovery perspectives; otherwise produce the same artifacts directly.

## Grill

Discovery requires a grill pass. It is mandatory — skipping it is forbidden, even when the user sounds eager to move on. The grill is how vague intent becomes a resolved Discovery Exit Checklist.

### Discovery Exit Checklist (deterministic)

The grill is complete ONLY when every item below is resolved and recorded — in this order. There is no "looks clear enough" exit; advancing with any item unresolved is forbidden.

1. Vision / problem being solved.
2. Target user and their primary job-to-be-done.
3. The three core flows.
4. Must-haves vs. explicit non-goals.
5. Hard constraints (budget, time, stack, hosting).
6. Success signals and at least one concrete acceptance criterion.
7. Every tradeoff that affects scope, design, acceptance, or success — each one decided, not deferred.

A question whose answer is recorded in the codebase counts as resolved once you have read and cited it. Every item above must show as resolved before Flow step 3 begins.

### Grill rules

- Ask one question at a time. Do not batch.
- For every question, propose a recommended answer with the reasoning behind it. The user confirms, redirects, or overrides — they never invent the answer from scratch.
- Walk the decision tree depth-first. Resolve each decision before asking ones that depend on it; answering a downstream question before its parent wastes the answer.
- If a factual question (what exists, how something is wired) can be answered by reading the codebase, read it instead of asking, cite what you found, and record the item as resolved. If the codebase only suggests what the user *wants* (a product or intent decision), state your inference as the recommended answer and ask the user to confirm or override — never substitute a code reading for an intent decision.
- Within the Discover phase, treat short affirmatives ("ok", "sure", "fine", "uh ok") to a single-recommendation question as accepting that recommendation, and advance to the next checklist item.
- Phase boundaries are different. A short affirmative never crosses Discover → Plan (or any other phase boundary) on its own — an explicit approval word ("go", "proceed", "approved", "lgtm", "do it", "continue", "next") is required regardless of how the prior question was shaped.
- Multi-option questions never accept a short affirmative. Present each option with a one-line tradeoff, mark exactly one as the recommended default with its reasoning, and if the reply does not map to a specific option, restate the options and ask for the explicit choice.

## Resource Acquisition (mandatory)

"Missing env", "no access", "can't check", and "no fixtures" are never grounds to record an unknown or stop. Before writing any unknown, open question, or feasibility risk, you MUST attempt to resolve it with available tools and record exactly what you ran (command/tool and result) in `.wannabuild/outputs/acquisition-log.json`. Per `skills/internal/build/references/doctrine.md` Mandate 2.

- Library, framework, or API facts → Context7 (`resolve-library-id`, `get-library-docs`); if Context7 lacks it, WebSearch/WebFetch the live docs.
- Competitors, alternatives, market or pricing facts → WebSearch/WebFetch live sources; cite each.
- Repo facts (what exists, how it is wired, current dependencies) → read the repo directly and cite the file.
- Runtime or environment facts that are safe, local, and reversible → obtain them: run the app locally, spin an ephemeral/local database branch, drive the real UI with a browser, generate fixtures or seed data, stand up a preview environment.
- Only billable, outward-facing, or destructive acquisition (paid provisioning, deploys, production data, external sends) is grounds to stop and ask the user — present the specific resource needed and why.

An unknown or open question is permitted only after a logged acquisition attempt failed to resolve it. An unknown with no logged attempt is forbidden; the `assert-acquisition-attempted` gate rejects any blocked status that lacks a logged attempt.

## Flow

1. Run the Grill to identify the vision, audience, desired feel, core flows, features, constraints, priorities, non-goals, success signals, budget/time tolerance, and decision tradeoffs — to the Discovery Exit Checklist.
2. State assumptions explicitly and surface meaningful ambiguity instead of resolving it silently.
3. Once the Discovery Exit Checklist is resolved, run the required research bundle. Each track must first exhaust the tools in Resource Acquisition before any item is recorded as an unknown or risk:
   - feasibility: implementation path, dependencies, effort risk, and any residual unknown — each unknown recorded only with the acquisition attempt that failed to resolve it.
   - alternatives/competition: direct competitors, adjacent alternatives, existing tools/libraries, and manual or do-nothing options — names and facts must come from live sources (Context7 for library docs, WebSearch/WebFetch for competitors), not memory; cite each source.
   - Failure Forecast: assume the project failed, identify likely causes, and turn them into questions or mitigations.
4. Run every adaptive research track whose trigger is present (run all that match; never self-select out):
   - security/privacy — any auth, PII, payments, secrets, or user data.
   - integrations — any third-party API, service, or MCP connector.
   - data/migration — any schema change or change touching existing data.
   - performance — any real-time, large-dataset, or latency-sensitive flow.
   - compliance — any regulated domain (health, finance, children, GDPR/CCPA scope).
   - UX — any user-facing flow or interface.
   - monetization — any pricing, billing, or revenue surface.
   - domain — any specialized field whose rules drive correctness.
5. Synthesize research into sharper qualifying questions and ask every one that changes scope, success, or product direction. Continue to apply the Grill rules — one question, recommended answer, codebase-first for factual items.
6. Write the final requirements direction with scope, non-goals, acceptance signals (at least one concrete, checkable acceptance criterion), research synthesis, qualified decisions, Failure Forecast impact, and residual unknowns. Each residual unknown must name the acquisition attempt that failed to resolve it; an unknown with no logged attempt is not allowed.
7. Hard-stop at the Discover → Plan boundary. Present a concise summary (scope, non-goals, acceptance signals, key decisions, residual unknowns with what was tried), name the next phase (Plan), and wait for an explicit approval word ("go", "proceed", "approved", "lgtm", "do it", "continue", "next"). A vague acknowledgment never crosses this boundary. After approval, continue to Plan only once `assert-discovery-ready` passes.

## Output

In a WannaBuild workspace, Discovery must produce:

- `.wannabuild/outputs/discovery/feasibility.md`
- `.wannabuild/outputs/discovery/alternatives-competition.md`
- `.wannabuild/outputs/discovery/failure-forecast.md`
- `.wannabuild/outputs/discovery/followup-questions.md`
- `.wannabuild/spec/requirements.md`

Record completed discovery evidence in `.wannabuild/state.json` under `discovery`. Continue to planning ONLY after `scripts/wannabuild-session.sh assert-discovery-ready .` succeeds. There is no override — the gate fails closed, and a runtime-unavailable result is a hard stop, not permission to proceed.

`assert-discovery-ready` confirms `state.discovery.*` is complete, all five output files above exist and are non-empty (no stub or placeholder content), and `.wannabuild/spec/requirements.md` contains an Acceptance Criteria section with at least one concrete, checkable criterion. A requirements file without acceptance criteria does not pass — you cannot plan against an unmeasurable goal. See `skills/internal/build/references/doctrine.md` Mandate 1.
