# /wannabuild

Use the `$wannabuild` skill for this request.

If invoked with no task:

- do not inspect deeply
- do not infer the task from git state
- do not plan
- do not implement

Reply with:

`[WB-START] WannaBuild STARTED | intent=build | mode=standard`

Then ask:

`Tell me what you want to build or change.`

If invoked with a concrete task inside a git repo:

1. create an isolated workspace first
2. initialize WannaBuild session state there
3. continue only inside that workspace

Workflow:

1. Discover
2. Control mode gate
3. Optional research gate
4. Plan
5. Implement
6. Review
7. QA
8. Summary

Use the standard workflow. Do not ask the user to choose between Full, Light, or Spark.

After Discover, ask exactly once:

1. Continue in guided mode
2. Switch to autonomous mode

Guided mode:

- ask at each later gate

Autonomous mode:

- choose adaptively after that point

After discovery, if uncertainty is still materially high, ask:

1. Kick off research agents
2. Move to planning

After planning, ask:

1. Implement in solo-owner mode
2. Implement with parallel agents

After implementation:

- run the distinct Review gate with the named reviewer agents
- then run the distinct QA gate
- only then summarize
