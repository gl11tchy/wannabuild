---
description: Implement planned WannaBuild work
argument-hint: [task or slice]
---

# /wb-build

Use this toolbox command when the user wants implementation.

Before phase work, enforce Mandatory Toolbox Bootstrap: if this is a concrete task in a git repo and the session is not already inside an isolated WannaBuild workspace, use the `wannabuild` workspace bootstrap contract or `scripts/wannabuild-workspace.sh --json`, then continue only in the isolated workspace.

1. Use the `wb-build` skill.
2. Start or resume `.wannabuild` state.
3. Confirm the build scope. If there is no plan, ask for one or suggest `/wb-plan`.
4. Choose single-owner implementation unless independent slices clearly justify parallel work.
5. Implement the requested slice, keep checkpoints, and run relevant verification.
6. Stop with changed files, checks run, risks, and the next suggested command, usually `/wb-review`.

Do not ship or summarize the whole loop unless the user asks.
