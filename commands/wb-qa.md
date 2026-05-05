---
description: Run WannaBuild QA against acceptance criteria
argument-hint: [scope]
---

# /wb-qa

Use this toolbox command when the user wants QA validation.

Before phase work, use Toolbox Bootstrap: work in the current checkout by default. Do not create an isolated worktree for QA.

1. Use the `wb-qa` skill.
2. Start or resume `.wannabuild` state.
3. Validate acceptance criteria, integration behavior, and required checks.
4. Treat failed tests, missing coverage, or unverified acceptance criteria as blockers.
5. Record QA evidence in checkpoints or `.wannabuild/review/` when the workflow state is active.
6. Stop with pass/fail status, evidence, blockers, and the next suggested command, usually `/wb-ship`.

Do not mark the work complete while QA is failing.
