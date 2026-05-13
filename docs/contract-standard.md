# WannaBuild Contract Standard

All WannaBuild skills and specialist agents follow the same professional prompt contract. The prompt can stay conversational, but it must make these obligations visible and enforceable:

- Purpose: state when the skill or agent owns the work.
- Inputs: name the artifacts, code, runtime state, or user context it must inspect before acting.
- Process: describe the ordered working loop and when to ask, delegate, verify, or stop.
- Hard gates: identify runtime or evidence checks that block phase progress.
- Evidence: name the files, commands, verdicts, checkpoints, or decisions that prove the work.
- Output: define the artifact, response, verdict, or handoff shape.
- Handoff: state the next phase, next skill, or terminal summary behavior.
- Forbidden actions: name jumps, edits, claims, scope creep, command-first handoffs, or silent skips that are not allowed.

Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.

Runtime gates fail closed. Specialist judgment remains advisory unless a gate or acceptance criterion marks its evidence as mandatory.
