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

Before phase work, use Toolbox Bootstrap: work in the current checkout by default. Do not create an isolated worktree for discovery.

1. Use the `wb-discover` skill.
2. Start or resume `.wannabuild` state.
3. Run Discover only: vision, audience, desired feel, core flows, features, constraints, scope, non-goals, and success signals.
4. Write or update `.wannabuild/spec/requirements.md`.
5. Stop with a short summary and the next suggested command, usually `/wb-plan`.
