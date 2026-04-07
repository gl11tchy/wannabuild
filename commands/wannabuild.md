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

Use the `wannabuild` skill for the full workflow contract.
