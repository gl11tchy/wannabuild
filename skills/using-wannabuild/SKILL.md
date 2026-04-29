---
name: using-wannabuild
description: Intro skill for starting WannaBuild in Codex or Claude Code
---

# Using WannaBuild

Use this skill when the user wants to work with WannaBuild itself or asks how to start.

## What To Do

Tell the agent to use `wannabuild` for the actual workflow entrypoint.

WannaBuild runs a vision-first workflow:

1. Discover the user's vision, flows, feel, and feature priorities
2. Control mode gate
3. Optional research gate
4. Plan
5. Implement with an adaptive single-owner or parallel shape
6. Review with the right specialists for the change
7. QA
8. Summary

## Start Prompt

If the user needs a starting point, suggest:

```text
$wannabuild   (Codex)
/wannabuild   (Claude Code)

I want to build:
[describe the feature or project]
```
