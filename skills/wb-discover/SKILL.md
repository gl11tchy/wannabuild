---
name: wb-discover
description: Standalone WannaBuild discovery toolbox skill for clarifying vision, audience, flows, constraints, scope, and success signals without running the full loop.
---

# wb-discover

Use this toolbox skill when the user wants discovery only, not the full WannaBuild loop.

## Toolbox Bootstrap

Before any toolbox phase work:

- If no concrete task exists, ask for the actual goal first.
- Work in the current checkout by default.
- Do not create an isolated worktree for discovery.

## Purpose

Turn a rough idea or unclear request into a crisp problem brief and requirements direction.

## Defaults

- Keep the interview lightweight and conversational.
- Ask only for missing information that changes scope, design, or acceptance.
- Use bounded repo reconnaissance only when the codebase materially affects discovery.
- Do not infer intent from git diff or uncommitted changes.
- Do not proceed to planning unless the user asks.
- Use sub-agents only for distinct discovery perspectives that materially improve the brief.

## Flow

1. Identify the vision, audience, desired feel, core flows, features, constraints, and success signals.
2. State assumptions explicitly.
3. Surface meaningful ambiguity instead of resolving it silently.
4. Synthesize a concise brief with scope, non-goals, acceptance signals, and open questions.
5. Stop at the discovery boundary.

## Output

Return the brief directly, or write it to `.wannabuild/spec/requirements.md` when the user is in a WannaBuild workspace and asks for an artifact.
