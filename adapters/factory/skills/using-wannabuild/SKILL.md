---
name: using-wannabuild
description: Use when starting any conversation that touches software work — establishes how to find and use WannaBuild skills, requiring skill invocation before ANY response including clarifying questions.
---

# Using WannaBuild

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed. Specialist judgment stays advisory unless a gate or acceptance criterion requires evidence.

<SUBAGENT-STOP>
Skip this skill ONLY if a WannaBuild orchestrator or parent skill dispatched you to execute one bounded, already-planned task whose Discover and Plan phases are complete. If you are the top-level responder to a user request, this skill applies. You may not self-classify your own work as "a specific task" to bypass the entry gate.
</SUBAGENT-STOP>

## The Rule

Invoke the relevant WannaBuild skill BEFORE any response or action — including clarifying questions — whenever the user's request plausibly matches one. Even a 1% chance a skill applies means you MUST invoke it; this is not negotiable, and you cannot rationalize your way out of it. On invocation, announce "Using [skill] for [purpose]", mirror any checklist the skill carries with TodoWrite (one item per step), and follow the skill exactly. If, after invoking, the skill is genuinely inapplicable, state why and what you will do instead before proceeding — never silently drop the skill or no-op the workflow. Respond directly only when no skill could possibly apply.

## Instruction Priority

WannaBuild skills override default model behavior, but **user instructions always take precedence**:

1. **User's explicit instructions** (CLAUDE.md, AGENTS.md, GEMINI.md, direct requests) — highest priority
2. **WannaBuild skills** — override default behavior where they conflict
3. **Default model behavior** — lowest priority

If `AGENTS.md` or `CLAUDE.md` says "discovery only" and a skill says "continue to plan," follow the user's instructions. The user is in control.

## How to Access Skills

- **Claude Code:** invoke via the `Skill` tool (or run `/wannabuild`, `/wb-*` as a shortcut). Never use the Read tool on skill files — let the Skill tool load them.
- **Codex:** invoke via natural language; `$wannabuild` and `$wb-*` are explicit shortcuts.
- **Factory:** the `wannabuild` and `wb-*` skills auto-route from natural language; no shortcut required.
- **Cursor:** `.cursor/rules/wannabuild.mdc` is loaded automatically.

## Red Flags

These thoughts mean STOP — you are rationalizing:

| Thought | Reality |
|---|---|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "I'll check git/files quickly" | Files lack conversation context. Check for skills. |
| "This doesn't need a formal skill" | If a matching skill exists, use it. |
| "I remember this skill" | Skills evolve. Read the current version. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "User said 'fix X' so just fix it" | "Fix X" doesn't mean skip Discover/Plan. |
| "This is repo plumbing, not a feature" | If it changes code that ships, the workflow applies. |
| "I know what they meant" | Knowing the concept ≠ running the skill. Invoke it. |

## When WannaBuild Skills Apply

A WannaBuild skill plausibly applies when the request involves any of:

- Building, adding, changing, or removing software behavior (`wannabuild` full loop)
- Open-ended ideation, "I was thinking…", "what should we add" (`wannabuild` → Discover)
- A concrete-sounding ask ("add a login page", "fix X", "change Y") — concreteness routes into `wannabuild`, never around it
- Discovery, requirements, scoping, brainstorming (`wb-discover`)
- Architecture, design direction, task decomposition (`wb-plan`)
- Implementing a concrete planned slice or task (`wb-build`)
- A bug, failure, regression, exception, or "broken" behavior (`wb-debug`)
- Reviewing code, specs, or readiness without fixing (`wb-review`)
- Acceptance criteria, integration validation, "did we cover…" (`wb-qa`)
- Ship, handoff, release, commit, PR, or final summary (`wb-ship`)

If the request **changes code that ships in this repo or a target repo**, default to invoking `wannabuild` even if no specific phase keyword matches. Repo plumbing, plugin packaging, build/release scripts, CI, and developer tooling all count.

## When WannaBuild Skills Do NOT Apply

Skip the workflow only when the request is unambiguously meta and non-shipping:

- Questions about the WannaBuild docs themselves (e.g., "explain what `wb-debug` does")
- Pure conversation, opinion, or recall with no edit ("what's the diff between X and Y")
- The user explicitly said "do not use wannabuild" / "skip the workflow" / equivalent

A broken or missing environment is NOT a skip category: a broken shell, PATH, or tool that blocks the user's request is a resource to repair under the acquisition contract below, never a reason to drop the workflow or stop. If you are not certain a skill is inapplicable, invoke it — the skill itself decides whether to continue or hand back.

## The Public Loop

WannaBuild runs a vision-first workflow:

1. **Discover** — collaborative grill plus proportionate research
2. **Plan** — design direction, tasks, and a research bundle (feasibility, alternatives, failure forecast) sized to the change but never zero
3. **Implement** — adaptive single-owner or parallel slices, run to completion without mid-work pauses
4. **Validate** — full reviewer set every iteration; findings fixed before exit
5. **QA** — acceptance and integration behavior validated by execution
6. **Summary** — verified handoff, commit, or PR

Phase entrypoints — each enters the active loop, none runs in isolation by default:

- `wb-discover` — clarify vision and requirements
- `wb-plan` — produce design and task slices
- `wb-build` — implement a concrete planned slice
- `wb-debug` — reproduce, diagnose, fix, and verify a bug
- `wb-review` — targeted review without fixing
- `wb-qa` — acceptance and integration validation
- `wb-ship` — prepare verified handoff, commit, or PR

The full operating contract behind these phases is `skills/internal/build/references/doctrine.md`. Its four mandates govern this entry gate; the sections below are how they bind here.

## Discovery Is Mandatory

For any request that changes code that ships, Discover MUST run first as a collaborative grill — one question at a time, each with a recommended answer and the reasoning behind it — and MUST complete before Plan, Implement, Validate, QA, or Summary begin. It fires on every task, including one-line changes, and is never auto-skipped or bypassed by a "trivial", "simple", or concrete-sounding classification — "add a login page" and "fix X" enter Discover first. Only the user shortens discovery, by answering quickly — not by acknowledging.

Discovery is not complete until `.wannabuild/spec/requirements.md` contains an **Acceptance Criteria** section with at least one concrete, checkable criterion. The `assert-discovery-ready` gate fails closed until that holds; you cannot plan against an unmeasurable goal.

## Default: Run Every Phase

Unless the user gives an explicit, unambiguous single-phase limit (see Phase Limiting), run the FULL loop — Discover → Plan → Implement → Validate → QA → Summary — with no phase skipped. Resolve ambiguity toward running more of the loop, never less. The pipeline is fixed and identical every run; only the depth of work inside a phase scales with the change.

## Never Declare Blocked Without Exhausting Resources

No phase may claim "blocked", "missing env", "no access", "missing dependency", "no fixtures", or "can't test" until it has tried to OBTAIN the resource. Acquire anything safe, local, and reversible without asking: run the app locally; spin an ephemeral or local database branch (Supabase, Neon); drive the real UI with a browser (Chrome) or computer-use; read live docs via Context7; generate fixtures and seed data; stand up a preview environment. Ask the user ONLY for billable, outward-facing, or destructive acquisition (paid provisioning, deploys, production data, external sends) — present the specific resource and why.

A blocker claim is valid only with a logged attempt in `.wannabuild/outputs/acquisition-log.json` recording what was needed, which tools or connectors were tried, and the result; the `assert-acquisition-attempted` gate rejects any blocked or failed status that lacks one. All validation and QA evidence records exactly what was executed — real commands, real exit codes, real output — never an assertion that something "should" pass.

## Review and QA Have Teeth

Validate runs the full reviewer set on every iteration — security, performance, architecture, testing, code-simplifier, and integration — with no impacted-only subset, no fast-track for tiny or low-risk changes, and no reviewer selecting itself out. Each reviewer covers ALL impacted files and surfaces and states what it covered; partial coverage with a "looks fine" verdict is a failed review. The `assert-review-ready` gate requires a PASS from every reviewer.

The wb-qa integration tester is the terminal hard gate. Its FAIL cannot be overridden, rationalized, or declared un-runnable — if it cannot run, that is a blocker to resolve by acquiring the resource, not permission to pass. A PASS is valid only with execution evidence: tests actually ran and every acceptance criterion is covered. QA validates execution, not text markers.

## Collaborate on Decisions

When a choice could change product, scope, security, or cost behavior, present the options — each with a recommended answer and a one-line rationale — and confirm before proceeding; never decide silently. Conversely, do not stop to ask about pure mechanics you can verify yourself; run those to completion. Collaboration means deciding WITH the user at phase boundaries and on real ambiguity, never interrupting mechanical work mid-phase.

## Phase Limiting

Stop at one phase **only** when the user explicitly says one of:

- "discovery only", "discover only", "requirements only", "brainstorm only"
- "plan only", "planning only", "do not implement", "don't implement"
- "review only", "qa only", "debug only", "build only"
- equivalent unambiguous limits

A phase boundary is crossed only by an explicit approval word — "go", "proceed", "approved", "continue", "next", "lgtm", "do it". Vague acknowledgments — "ok", "okay", "k", "sounds good", "sure", "yep" — continue the *current* phase; they never cross a boundary, never permit skipping a phase, and are not answers to discovery questions.

## Skill Priority

When multiple skills could apply, route by this fixed rule so the same request resolves the same way every run:

1. The request changes code that ships and the user gave no single-phase limit → invoke `wannabuild` (the full loop). This is the default whenever in doubt.
2. Invoke a single phase skill (`wb-discover`, `wb-plan`, `wb-build`, `wb-debug`, `wb-review`, `wb-qa`, `wb-ship`) only on an explicit, unambiguous single-phase limit, or when an in-progress loop is resuming at that phase.

Process skills (`wannabuild`, `wb-discover`, `wb-plan`, `wb-debug`) decide HOW to approach the task; implementation skills (`wb-build`) execute only after Plan is satisfied. "Let's build X" → `wannabuild`, Discover first, however concrete X sounds. "Fix this bug" → `wb-debug` inside the loop: reproduce and diagnose first, then fix, then verify. "Plan a refactor" → `wb-plan` (design + tasks; no implementation), entered through Discover.

## Skill Types

- **Fixed discipline** — identical on every run: the Discover grill, the acceptance-criteria plan gate (`wb-build` plan gate), full-coverage validation, the terminal `wb-qa` integration gate. These do not bend to context.
- **Adaptive depth** — only the CONTENT scales with the change: which discovery questions get asked, how many findings a reviewer raises, how many tests QA runs. "Adapt to context" never means fewer questions, a skipped surface, a dropped reviewer, or a downgraded gate.

## Start Prompt

When the user needs a starting point, prefer natural language:

```text
I want to build:
[describe the feature or project]
```

Mention explicit shortcuts only if the host requires them:

```text
/wannabuild   (Claude Code, Cursor)
$wannabuild   (Codex)
```

For a single-phase request, make the limit explicit:

```text
Plan only; do not implement:
[describe the task]
```

## Final Reminder

User instructions say WHAT, not HOW. "Add X", "Fix Y", "Clean this up", or "Do the thing" never mean skip the workflow. Invoke the skill, announce it, follow it.
