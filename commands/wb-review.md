---
description: Run WannaBuild review on current changes
argument-hint: [scope]
---

# /wb-review

Use this toolbox command when the user wants review, not implementation.

Before phase work, use Toolbox Bootstrap: work in the current checkout by default. Do not create an isolated worktree for review.

1. Use the `wb-review` skill.
2. Start or resume `.wannabuild` state.
3. Select reviewer hats that match the change and risk.
4. Review for bugs, regressions, missing tests, security, performance, architecture, and simplicity as relevant.
5. Capture actionable findings in `.wannabuild/review/` when the workflow state is active.
6. Stop with findings first, then residual risk and the next suggested command, usually `/wb-qa`.

Do not change code unless the user asks you to address findings.
