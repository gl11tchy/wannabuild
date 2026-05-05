---
description: Implement planned WannaBuild work
argument-hint: [task or slice]
---

# /wb-build

Use this toolbox command when the user wants implementation.

Before phase work, use Toolbox Bootstrap: work in the current checkout by default. Create an isolated worktree only when the user asks, selects implementation-time isolation, requests parallel implementation, or the risk justifies separation.

1. Use the `wb-build` skill.
2. Start or resume `.wannabuild` state.
3. Confirm the build scope. If there is no plan, ask for one or suggest `/wb-plan`.
4. Choose single-owner implementation unless independent slices clearly justify parallel work.
5. Implement the requested slice, keep checkpoints, and run relevant verification.
6. Stop with changed files, checks run, risks, and the next suggested command, usually `/wb-review`.

Do not ship or summarize the whole loop unless the user asks.
