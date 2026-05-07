---
name: wb-discover
description: WannaBuild discovery phase entrypoint for clarifying vision, audience, flows, constraints, scope, and success signals before continuing the full loop.
---

# wb-discover

Use this phase skill when the user invokes discovery or the active WannaBuild workflow is in Discover. A `wb-discover` or `wannabuild:wb-discover` invocation starts or resumes the full WannaBuild loop unless the user explicitly says discovery only.

## Phase Bootstrap

Before any discovery phase work:

- If no concrete task or exploratory idea intent exists, ask for the actual goal first.
- Work in the current checkout by default.
- Do not create an isolated worktree for discovery.

## Purpose

Turn a rough idea or unclear request into a crisp problem brief and requirements direction.

## Defaults

- Keep the interview lightweight and conversational.
- Ask only for missing information that changes scope, design, or acceptance.
- Use bounded repo reconnaissance only when the codebase materially affects discovery.
- Do not infer intent from git diff or uncommitted changes.
- Preserve active WannaBuild workflow state across turns until the task is complete or the user explicitly exits or stops.
- Do not treat vague acknowledgments like "ok" or "uh ok" as permission to skip planning, implementation, QA, or summary.
- Proceed to planning automatically after the requirements direction is crisp enough unless the user explicitly requested discovery only.
- Use sub-agents only for distinct discovery perspectives that materially improve the brief.

## Flow

1. Identify the vision, audience, desired feel, core flows, features, constraints, and success signals.
2. State assumptions explicitly.
3. Surface meaningful ambiguity instead of resolving it silently.
4. Synthesize a concise brief with scope, non-goals, acceptance signals, and open questions.
5. If the user did not explicitly request discovery only, hand off to Plan automatically.

## Output

Return the brief directly, or write it to `.wannabuild/spec/requirements.md` when the user is in a WannaBuild workspace and asks for an artifact. In full-loop mode, continue to planning after the brief unless user judgment is required.
