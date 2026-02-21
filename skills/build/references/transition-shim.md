# Runtime Transition Shim (Orchestrator Guardrail)

This shim defines what the orchestrator must enforce at each phase transition before spawning any phase-specific agent.

## 1) Single source of validation truth

- Validate contracts via:
  - `skills/build/references/artifact-contracts.md`
  - `skills/build/schemas/*.json`
  - `scripts/validate-wannabuild-artifacts.sh`
- Fail the transition if any required artifact is invalid or missing.

## 2) Transition sequence

For each requested transition (`current_phase -> target_phase`):

1. Load `.wannabuild/state.json`.
2. Read `mode` from state and validate its value (`full` | `light`).
3. Validate the target phase contract before spawning any agents:
   - required spec artifacts
   - required checkpoints/output/review windows for review-facing transitions
4. Validate all JSON artifacts in scope:
   - `state.json`
   - `loop-state.json` (if it exists)
   - `review/*.json` files when available
5. Validate checkpoint metadata when review routing depends on the latest checkpoint window.
6. Write a transition result:
   - success: proceed and include validation evidence in handoff notes
   - failure: pause, summarize exact missing/malformed contract failures, and ask for explicit user direction
7. Only after successful validation, update `state.json` (merge) and continue.

## 3) Light-mode exception handling

- If mode is `light`, the shim allows skipping design.
- The shim must explicitly record an assumption:
  - `"design.md": missing (light mode)`.
- If `design.md` is also required for an explicit user request, the transition remains blocked with an explicit ask.

## 4) Fail-closed behavior

- Any malformed verifier output (bad JSON, missing required keys, type mismatch) is treated as a hard fail.
- A hard fail must block spawning and route to user decision immediately.
- No file writes from phase agents may occur when pre-flight validation fails.

## 5) Required command in orchestrator context

Before each transition, run:

```bash
scripts/validate-wannabuild-artifacts.sh . <target_phase>
```

Where `<target_phase>` is one of:
`requirements`, `design`, `tasks`, `implement`, `review`, `ship`, `document`.

The command should only be considered successful when it exits with code `0`.
