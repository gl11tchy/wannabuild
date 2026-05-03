---
description: Run the WannaBuild discovery stage
argument-hint: [goal or change]
---

# /wb-discover

Use this toolbox command when the user wants discovery, not the full loop.

If no concrete goal is provided:

- ask for the actual goal
- do not inspect the repo
- do not infer intent from git state

If a concrete goal is provided:

Before phase work, enforce Mandatory Toolbox Bootstrap: if this is a concrete task in a git repo and the session is not already inside an isolated WannaBuild workspace, use the `wannabuild` workspace bootstrap contract or `scripts/wannabuild-workspace.sh --json`, then continue only in the isolated workspace.

1. Use the `wb-discover` skill.
2. Start or resume `.wannabuild` state.
3. Run Discover only: vision, audience, desired feel, core flows, features, constraints, scope, non-goals, and success signals.
4. Write or update `.wannabuild/spec/requirements.md`.
5. Stop with a short summary and the next suggested command, usually `/wb-plan`.
