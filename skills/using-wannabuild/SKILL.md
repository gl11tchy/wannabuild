---
name: using-wannabuild
description: Intro skill for starting or continuing the WannaBuild full-loop workflow from natural language or any phase skill entrypoint.
---

# Using WannaBuild

Use this skill when the user wants to work with WannaBuild itself or asks how to start.

## What To Do

Tell the agent to use `wannabuild` for broad natural-language build, change, or ideation prompts, and to treat any `wb-*` / `wannabuild:*` skill invocation as a phase entrypoint into the same full loop by default. Commands are optional shortcuts; skills should be selected automatically when the request plausibly matches.

Do not make the user type `$wannabuild`, `/wannabuild`, or a `wb-*` command when their natural-language request already matches a skill.

Stop after one phase only when the user explicitly says "discovery only", "plan only", "do not implement", "QA only", or equivalent. Vague acknowledgments like "ok" or "uh ok" continue the active workflow; they are not permission to skip phases.

WannaBuild runs a vision-first workflow:

1. Discover the user's vision, flows, feel, and feature priorities
2. Plan, with bounded research when needed
3. Implement with an adaptive single-owner or parallel shape
4. Validate with the right specialists for the change, autofixing actionable findings
5. QA
6. Summary

Phase skills are entrypoints into the active loop:

- `WannaBuild: Discover` (`wb-discover`) - clarify vision and requirements direction
- `WannaBuild: Plan` (`wb-plan`) - produce design direction and task slices
- `WannaBuild: Build` (`wb-build`) - implement a concrete task or plan
- `WannaBuild: Debug` (`wb-debug`) - reproduce, diagnose, fix, and verify a bug
- `WannaBuild: Review` (`wb-review`) - review code or specs without fixing
- `WannaBuild: QA` (`wb-qa`) - validate acceptance and integration behavior
- `WannaBuild: Ship` (`wb-ship`) - prepare a verified handoff, commit, or PR summary

## Start Prompt

If the user needs a starting point, suggest natural language first:

```text
I want to build:
[describe the feature or project]
```

Then mention explicit shortcuts only as fallback:

```text
$wannabuild   (Codex)
/wannabuild   (Claude Code)
```

For a single-phase request, make the limit explicit:

```text
Plan only; do not implement:
[describe the task]
```
