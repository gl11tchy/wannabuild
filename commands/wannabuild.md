---
description: Start the WannaBuild spec-driven development workflow
argument-hint: [what you want to build]
---

# /wannabuild

Start the WannaBuild spec-driven development workflow.

If invoked with no task or only a question about the workflow:

- do not inspect the repo
- do not infer the task from git state
- do not plan or implement anything

Respond with exactly:

```
[WB-START] WannaBuild STARTED | intent=build | mode=standard

Tell me what you want to build or change.
```

If invoked with a concrete task:

1. Check for `.wannabuild/state.json` — if it exists and is recoverable, resume with:
   `[WB-RESUME] WannaBuild RESUME | mode=standard | phase=<current_phase> | progress=<done>/<total>`
2. Otherwise emit the start banner and begin Discover.
   The `wannabuild` skill handles mandatory workspace/worktree bootstrap before phase work.

Deduplication guard:

- Never send the same user-visible line twice in a row.
- If this command already emitted `[WB-START]` or `[WB-RESUME]` in the current turn, do not emit it again when handing off to the `wannabuild` skill.
- For guided gates, if the exact gate prompt is already the latest assistant message and no new user answer was provided, wait instead of repeating the same prompt.

Use the `wannabuild` skill for the full workflow contract.
