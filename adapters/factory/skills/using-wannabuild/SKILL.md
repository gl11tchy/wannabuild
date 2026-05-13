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
If you were dispatched as a subagent to execute a specific task, skip this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a WannaBuild skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. This is not optional. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

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

## The Rule

**Invoke the relevant WannaBuild skill BEFORE any response or action when the user's request plausibly matches one.** Even a 1% chance a skill applies means you should invoke it. If it turns out wrong, drop it.

```text
User message received
        │
        ▼
Might any wb-* / wannabuild skill apply?
        │
   yes (even 1%)        definitely not
        │                       │
        ▼                       ▼
Invoke skill            Respond directly
        │                  (including
        ▼                clarifications)
Announce: "Using [skill] for [purpose]"
        │
        ▼
Has a checklist? ──── yes ──▶ TodoWrite per item
        │ no                       │
        └─────────────┬────────────┘
                      ▼
              Follow skill exactly
```

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
- Local environment fixes (e.g., "my shell PATH is broken")
- Pure conversation, opinion, or recall with no edit ("what's the diff between X and Y")
- The user explicitly said "do not use wannabuild" / "skip the workflow" / equivalent

If you are not certain a skill is inapplicable, **invoke the skill anyway**. The skill itself decides whether to continue or hand back.

## The Public Loop

WannaBuild runs a vision-first workflow:

1. **Discover** — vision, flows, desired feel, feature priorities, scope
2. **Plan** — design direction, tasks, bounded research when needed
3. **Implement** — adaptive single-owner or parallel slices with checkpoints
4. **Validate** — the right specialists for the change, autofixing actionable findings
5. **QA** — acceptance and integration behavior; integration tester is the hard gate
6. **Summary** — verified handoff, commit, or PR

Phase entrypoints (each enters the active loop, does not run in isolation by default):

- `wb-discover` — clarify vision and requirements
- `wb-plan` — produce design and task slices
- `wb-build` — implement a concrete planned slice
- `wb-debug` — reproduce, diagnose, fix, and verify a bug
- `wb-review` — targeted review without fixing
- `wb-qa` — acceptance and integration validation
- `wb-ship` — prepare verified handoff, commit, or PR

## Phase Limiting

Stop at one phase **only** when the user explicitly says one of:

- "discovery only", "discover only", "requirements only", "brainstorm only"
- "plan only", "planning only", "do not implement", "don't implement"
- "review only", "qa only", "debug only", "build only"
- equivalent unambiguous limits

Vague acknowledgments — "ok", "okay", "k", "sounds good", "sure", "yep" — continue the active workflow. They are **not** permission to skip Plan, Implement, Validate, QA, or Summary.

## Skill Priority

When multiple skills could apply, pick the smallest set that covers the request:

1. **Process skills first** (`wannabuild`, `wb-discover`, `wb-plan`, `wb-debug`) — these decide HOW to approach the task.
2. **Implementation skills second** (`wb-build`) — these guide execution after Plan is satisfied.

"Let's build X" → `wannabuild` (Discover first, then Plan, then Build).
"Fix this bug" → `wb-debug` (reproduce/diagnose first, then fix, then verify).
"Plan a refactor" → `wb-plan` (design + tasks; no implementation).

## Skill Types

- **Rigid** (`wb-build` plan gate, `wb-qa` integration tester): follow exactly. Don't adapt away the discipline.
- **Flexible** (Discover prompts, Validate reviewer selection): adapt to context.

The skill itself states which it is.

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

User instructions say WHAT, not HOW. "Add X", "Fix Y", "Clean this up", or "Do the thing" do not mean skip the workflow. Invoke the skill, announce it, and follow it.
