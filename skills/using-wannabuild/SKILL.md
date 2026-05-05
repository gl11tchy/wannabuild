---
name: using-wannabuild
description: Intro skill for starting WannaBuild full-loop mode or a focused toolbox skill in Codex or Claude Code
---

# Using WannaBuild

Use this skill when the user wants to work with WannaBuild itself or asks how to start.

## What To Do

Tell the agent to use `wannabuild` for the full workflow entrypoint, or a `wb-*` toolbox skill for one focused step. Commands are optional shortcuts; skills should be selected automatically when the request plausibly matches.

WannaBuild runs a vision-first workflow:

1. Discover the user's vision, flows, feel, and feature priorities
2. Plan, with bounded research when needed
3. Implement with an adaptive single-owner or parallel shape
4. Validate with the right specialists for the change, autofixing actionable findings
5. QA
6. Summary

Toolbox mode is for lighter, step-level work:

- `wb-discover` — clarify vision and requirements direction
- `wb-plan` — produce design direction and task slices
- `wb-build` — implement a concrete task or plan
- `wb-debug` — reproduce, diagnose, fix, and verify a bug
- `wb-review` — review code or specs without fixing
- `wb-qa` — validate acceptance and integration behavior
- `wb-ship` — prepare a verified handoff, commit, or PR summary

## Start Prompt

If the user needs a starting point, suggest:

```text
$wannabuild   (Codex)
/wannabuild   (Claude Code)

I want to build:
[describe the feature or project]
```

For a single-step toolbox request, use:

```text
$wb-plan
Plan this change:
[describe the task]
```
