---
description: Run WannaBuild review on current changes
argument-hint: [scope]
---

# /wb-review

Use this toolbox command when the user wants review, not implementation.

Before phase work, enforce Mandatory Toolbox Bootstrap: if this is a concrete task in a git repo and the session is not already inside an isolated WannaBuild workspace, use the `wannabuild` workspace bootstrap contract or `scripts/wannabuild-workspace.sh --json`, then continue only in the isolated workspace.

1. Use the `wb-review` skill.
2. Start or resume `.wannabuild` state.
3. Select reviewer hats that match the change and risk.
4. Review for bugs, regressions, missing tests, security, performance, architecture, and simplicity as relevant.
5. Capture actionable findings in `.wannabuild/review/` when the workflow state is active.
6. Stop with findings first, then residual risk and the next suggested command, usually `/wb-qa`.

Do not change code unless the user asks you to address findings.
