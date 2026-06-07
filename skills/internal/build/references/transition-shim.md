# Runtime Transition Shim (Orchestrator Guardrail)

This shim defines what the orchestrator must enforce at each phase transition before spawning any phase-specific agent. It inherits the four mandates in `skills/internal/build/references/doctrine.md`; where this shim is silent, the doctrine governs, and where a runtime gate exists the gate is authoritative and fails closed.

## 1) Single source of validation truth

- Validate contracts via:
  - `skills/internal/build/references/artifact-contracts.md`
  - `skills/internal/build/schemas/*.json`
  - `scripts/validate-wannabuild-artifacts.sh`
- The transition MUST fail if any required artifact is invalid or missing.
- Structural validity is necessary but not sufficient. A structurally valid artifact whose content is a placeholder, stub, mock, `to-do`, or otherwise hollow MUST be treated as missing. The shim MUST reject:
  - `requirements.md` without a non-empty **Acceptance Criteria** section containing at least one concrete, checkable criterion.
  - any review verdict whose covered-surface list is empty, or whose union of covered surfaces does not cover every changed file and spec section in scope.
  - any integration verdict that claims PASS without execution evidence (`test_execution` with `total > 0`, `failed == 0`, `errored == 0`, and a `coverage_map` in which every acceptance criterion is `covered`).

## 2) Transition sequence

For each requested transition (`current_phase -> target_phase`):

1. Load `.wannabuild/state.json`.
2. Read `mode` from state. Valid values are `guided` (default) and `standard`. Any other value, or an absent value, is a hard fail that routes to the user for an explicit mode choice — the shim MUST NOT pick a default silently.
3. Enforce the discovery precondition (mandatory, fail-closed). Before validating any `target_phase` in `{design, tasks, implement, review, ship, document}`, the shim MUST verify that `.wannabuild/spec/requirements.md` exists, contains a non-empty **Acceptance Criteria** section with at least one concrete criterion, and that `state.discovery` is complete with `state.discovery.user_confirmed === true`. If any of these is absent, the shim MUST block the transition and route the user into the discovery (`wb-discover`) phase. Discovery is never optional, never auto-skipped, and is not bypassed by a "trivial" classification. This precondition is also enforced by the `assert-discovery-ready` gate.
4. Validate the target phase contract before spawning any agents:
   - required spec artifacts (see section 3).
   - For `target_phase` in `{review, ship, document}`, the following are REQUIRED and validated: the latest checkpoint metadata, all `review/*.json` verdicts for the current loop iteration, and the integration verdict with execution evidence. These are the only transitions that read review/checkpoint artifacts; every other transition does not, so the set validated is fixed per `target_phase` and identical on every run.
5. Validate all JSON artifacts in scope:
   - `state.json`.
   - `loop-state.json` (REQUIRED for `target_phase` in `{review, ship, document}`; absent for `{requirements, design, tasks, implement}` is expected and not a failure).
   - `review/*.json` — for `target_phase` in `{review, ship, document}`, every reviewer verdict for the current loop iteration is REQUIRED. A missing reviewer verdict is a missing-required failure, not a skipped validation. The full reviewer set (security, performance, architecture, testing, code-simplifier, integration) MUST be present every iteration; there is no impacted-only subset and no reviewer may self-select out.
6. Validate checkpoint metadata for `target_phase` in `{review, ship, document}` (the transitions whose routing reads the latest checkpoint window). For other transitions this step does not run.
7. Write a transition result:
   - success at a mechanical (non-decision) boundary: proceed and include the full validation evidence in handoff notes; do not add user friction.
   - success at a decision-bearing boundary (`plan -> implement`, `review -> ship`, and every public phase boundary in `guided` mode): present a one-screen summary of what was validated and the recommended next action, then hard-stop and wait for an explicit approval word (`go`, `proceed`, `approved`, `continue`, `next`, `lgtm`, `do it`). A vague acknowledgment (`ok`, `sure`) does not cross the boundary. In `guided` mode the shim pauses at every public phase boundary; in `standard` mode only at `plan -> implement` and `review -> ship`.
   - failure: first apply the acquisition-before-blocked sequence in section 4a. Only after a logged acquisition attempt has failed may the shim summarize the exact missing/malformed contract failures and ask the user for direction — and only when the unmet need is billable, outward-facing, or destructive (per doctrine Mandate 2). A regenerable artifact is never grounds to pause on the user before attempting acquisition.
8. Only after successful validation, update `state.json` (merge — write only this transition's fields, preserve all others) and continue.

## 3) Required spec artifacts and missing-design handling

- `design.md` is REQUIRED for `tasks`, `implement`, and `review` transitions. There is no assumption-note bypass and no "may be allowed" path.
- If `design.md` is missing, the shim MUST NOT transition and MUST NOT record an assumption note in its place. It MUST first re-run the design phase agent to regenerate `design.md` from the confirmed `requirements.md` (an auto-acquisition step that needs no permission because it is local and reversible), and log the attempt in `.wannabuild/outputs/acquisition-log.json`.
- If regeneration still cannot produce a valid `design.md`, the shim MUST surface the gap to the user and present the explicit options with a recommended answer — recommended: regenerate design with the user clarifying the missing decision; alternative: the user explicitly directs a narrower scope — and wait for an explicit choice. The shim MUST NOT proceed on a missing design unilaterally, whether or not the user asked for architecture-sensitive validation.

## 4) Fail-closed behavior

- Any malformed verifier output (bad JSON, missing required keys, type mismatch) is treated as a hard fail.
- A hard fail MUST block spawning. Routing to the user is gated behind section 4a — the shim acquires first, asks only when acquisition is exhausted or the unmet need is billable/outward/destructive.
- No file writes from phase agents may occur when pre-flight validation fails.

## 4a) Acquisition before blocked (mandatory)

- The shim MUST NOT declare a transition failed or blocked due to a missing or malformed regenerable artifact until it has re-run the producing phase agent or verifier at least once.
- For environment or data dependencies (a running app, a database, live docs, fixtures), the shim MUST attempt safe local acquisition before stopping: run the app locally, spin an ephemeral or local database branch, drive a real browser, generate fixtures, or read live docs via Context7. "Missing env", "no database", "no access", or "can't test" is never grounds to skip a transition — only grounds to obtain the resource or, for billable/outward/destructive needs, to ask the user.
- Every blocker claim requires a logged entry in `.wannabuild/outputs/acquisition-log.json` recording, per unmet need: what was needed, which tools/connectors/CLIs were attempted, and the result. The `assert-acquisition-attempted` gate rejects any blocked/failed status without a logged attempt.

## 5) Required command in orchestrator context

Before each transition, run:

```bash
scripts/validate-wannabuild-artifacts.sh . <target_phase>
```

Where `<target_phase>` is one of:
`requirements`, `design`, `tasks`, `implement`, `review`, `ship`, `document`.

The transition is successful ONLY when `scripts/validate-wannabuild-artifacts.sh . <target_phase>` exits with code `0`. A non-zero exit is a hard fail and MUST NOT be overridden at escalation or by any assumption note.

For QA transitions, exit `0` from the validator is necessary but not sufficient: the `wb-integration-tester` verdict is the terminal hard gate. A `wb-integration-tester` FAIL MUST NOT be overridden at any escalation level — there is no override path — and a PASS counts only with execution evidence (tests ran with `total > 0`, `failed == 0`, `errored == 0`, and every acceptance criterion `covered`). A "Status: PASS" with zero tests executed is a FAIL. These checks are enforced by the `assert-review-ready` and `assert-qa-ready` gates.
