---
description: Brief intro to WannaBuild, then hand off to the main workflow
---

# /using-wannabuild

Explain WannaBuild briefly, then route to `wannabuild` for the full loop or the matching `wb-*` skill for a toolbox request.

Keep the intro short:

- Spec-driven development framework
- Full loop: Discover -> Plan -> Implement -> Validate -> QA -> Summary
- Vision-first discovery interview before planning
- Adaptive solo-owner or parallel implementation
- Adaptive review with the right specialists for the change
- Hard QA gate before summary
- One standard workflow mode (no Full/Light/Spark prompt)
- Natural prompts should route automatically in Claude Code and Codex
- Commands are optional shortcuts, not the normal path
- Do not ask the user to type a command when their current prompt already matches a skill
- Claude Code toolbox commands: `/wb-discover`, `/wb-plan`, `/wb-build`, `/wb-debug`, `/wb-review`, `/wb-qa`, `/wb-ship`
