---
description: Debug a failing WannaBuild task or behavior
argument-hint: [bug, failure, or symptom]
---

# /wb-debug

Use this toolbox command when the user wants diagnosis and a targeted fix.

Before phase work, use Toolbox Bootstrap: work in the current checkout by default. Create an isolated worktree only when the user asks, selects implementation-time isolation, requests parallel implementation, or the risk justifies separation.

1. Use the `wb-debug` skill.
2. Start or resume `.wannabuild` state.
3. Reproduce or narrow the failure before changing code.
4. Identify the cause, make the smallest targeted fix, and verify it.
5. Record useful evidence in checkpoints or review output.
6. Stop with the cause, fix, checks run, and the next suggested command, usually `/wb-review` or `/wb-qa`.

If the symptom is unclear, ask for the missing failure detail first.
