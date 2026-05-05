---
description: Start the full WannaBuild vision-first, spec-driven development loop
argument-hint: [what you want to build]
---

# /wannabuild

Route to the full WannaBuild vision-first, spec-driven development loop:

```text
Discover -> Control mode -> optional Research -> Plan -> Implement -> Review -> QA -> Summary
```

Use the `wannabuild` skill for the full workflow contract.

Command-layer constraints:

- Do not emit start or resume banners from this command.
- Do not ask control, research, implementation, review, QA, or summary gate questions from this command.
- Do not produce the no-task fallback text from this command.
- Let the `wannabuild` skill own all user-visible workflow output, workspace bootstrap, state updates, and de-duplication.

For phase-specific toolbox work, prefer `/wb-discover`, `/wb-plan`, `/wb-build`, `/wb-debug`, `/wb-review`, `/wb-qa`, or `/wb-ship`.
