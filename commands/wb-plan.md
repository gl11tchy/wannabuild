---
description: Produce a WannaBuild plan from requirements
argument-hint: [scope or requirements]
---

# /wb-plan

Use this toolbox command when the user wants planning, not implementation.

Before phase work, use Toolbox Bootstrap: work in the current checkout by default. Do not create an isolated worktree for planning.

1. Use the `wb-plan` skill.
2. Start or resume `.wannabuild` state.
3. Confirm there is enough discovery context. If not, ask the smallest useful follow-up or suggest `/wb-discover`.
4. Produce the Plan stage: architecture, contracts, risks, ordered implementation slices, and verification expectations.
5. Write or update `.wannabuild/spec/design.md` and `.wannabuild/spec/tasks.md`.
6. Stop before implementation and suggest `/wb-build`.

Do not implement unless the user explicitly asks.
