---
name: wb-qa
description: WannaBuild QA phase entrypoint for validating acceptance criteria, integration behavior, and release readiness evidence.
---

# wb-qa

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed. Specialist judgment stays advisory unless a gate or acceptance criterion requires evidence.

Use this phase skill when the user wants QA or the active WannaBuild workflow is in QA. A `wb-qa` or `wannabuild:wb-qa` invocation starts or resumes the full WannaBuild loop. "QA only" narrows the handoff, not the gates: every QA obligation below still runs in full.

The four mandates in `skills/internal/build/references/doctrine.md` govern this phase. QA enforces Mandate 2 (exhaust resources, never silent-skip), Mandate 3 (completeness; the integration gate cannot be rationalized away), and Mandate 4 (collaborate at boundaries, execute autonomously within the phase).

## Phase Bootstrap

Before any QA phase work:

- If no concrete task exists, ask for the actual goal, then route through Discover and Plan. QA does not run on un-discovered work.
- Work in the current checkout by default.
- Do not create an isolated worktree for QA.

## Preconditions

QA validates against acceptance criteria; it never invents or guesses them. Before any check:

- Confirm `.wannabuild/spec/requirements.md` exists and contains an **Acceptance Criteria** section with at least one concrete, checkable criterion. If it is missing or empty, do NOT proceed and do NOT synthesize criteria — route back to Discover (the grill is mandatory on every task, including one-liners) and Plan. The `assert-discovery-ready` gate is authoritative here.
- Confirm planning artifacts exist (`.wannabuild/spec/design.md` and `tasks.md`, per `assert-plan-ready`). If absent, route back to Plan before QA.
- Confirm review passed (`assert-review-ready`: a PASS verdict from every required reviewer for the latest iteration). QA does not substitute for review.

## Purpose

Validate by execution that the implemented behavior satisfies every acceptance criterion and integration expectation. QA verifies what was actually run — real commands, real exit codes, real output — not text markers, assertions, or inspection alone.

## Defaults

- The integration tester (`wb-integration-tester`) is the terminal hard gate. Its FAIL cannot be overridden at any escalation level; there is no override path.
- Cover EVERY acceptance criterion and EVERY changed surface. There is no smallest-set, impacted-only, fast-track, or low-risk reduction of the check set.
- Run real tests and exercise live end-to-end flows. Inspection alone never passes a criterion that is executable.
- Acquire every resource the checks need before declaring anything blocked (see Resource Acquisition). "Missing env", "no access", and "can't test" are never stopping conditions.
- Spawn a sub-agent per independent verification surface — each distinct deployment platform, each independent user flow, and each security/performance/data risk class named in requirements or design. Enumerate the surfaces explicitly before spawning so the set is reproducible across runs.
- Never ship or summarize while QA has not passed. QA passes only when every acceptance criterion is covered by an executed check with passing evidence and the integration hard gate is green.
- Preserve active WannaBuild workflow state across turns until the task is complete or the user explicitly exits or stops.

## Resource Acquisition (mandatory before any blocked claim)

QA may NEVER record a blocker, "missing env", "no access", or "can't test" until it has exhausted real acquisition. For any resource the tests or flows need, you MUST first attempt to obtain it:

- **Auto-acquire (no permission needed)** everything safe, local, and reversible: run the app locally; spin an ephemeral/local database branch (Supabase/Neon); drive the real UI with a browser (Chrome) or computer-use; read live docs via Context7; generate fixtures and seed data; stand up a preview/ephemeral environment (Railway/Vercel).
- **Stop-and-ask** only for billable, outward-facing, or destructive acquisition: paid provisioning, deploys to shared environments, production data, external sends. Present the specific resource needed and why, as a single decision with options each carrying a recommended answer (e.g. "provide secret X (recommended)", "authorize provisioning resource Y", "defer this criterion and record residual risk"). Do not stall silently and do not auto-skip.
- Every unmet need that remains after acquisition is exhausted MUST be logged in `.wannabuild/outputs/acquisition-log.json`, recording what was needed, which tools/connectors/CLIs were attempted, and the result. The `assert-acquisition-attempted` gate rejects any blocked or failed status with no logged attempt.

## Hard Gate: Integration Tests

The integration test gate is owned by `wb-integration-tester`. It PASSES only when all of the following hold and are evidenced:

- Every acceptance criterion in `.wannabuild/spec/requirements.md` maps to at least one executed integration check — a complete criterion-to-check coverage map with no MISSING or partial rows.
- `test_execution` shows tests actually ran: `total > 0`, `failed == 0`, `errored == 0`. "Status: PASS" with zero tests executed is a FAIL.
- The integration environment was actually stood up (DB branch spun, service running, real endpoints/flows exercised) — not asserted from inspection.

A FAIL is terminal: do not override it, do not route around it, and do not ship while it is red. `assert-qa-ready` requires both the QA summary's positive markers and this execution evidence; markers alone never pass.

## Flow

1. Confirm preconditions (requirements with acceptance criteria, plan, review PASS). If any is missing, route back rather than guessing.
2. Build a complete coverage matrix mapping EVERY acceptance criterion to the check(s) that verify it. Do not reduce to a smallest set; every criterion is exercised.
3. Acquire every resource the checks need (see Resource Acquisition). Log any unmet need to `.wannabuild/outputs/acquisition-log.json`.
4. For each criterion, execute the strongest applicable verification: run the automated test suite AND exercise the live end-to-end flow when the change touches a UI/service/data path. Capture real commands, exit codes, and output.
5. Run the integration hard gate (`wb-integration-tester`) and confirm its PASS criteria above are met.
6. If a genuine blocker remains after acquisition is exhausted, bring it to the user as a single decision with options and a recommended answer; do not silently skip or mark "out of scope".
7. At the QA boundary, present results and the recommended next action, and wait for an explicit approval word ("go", "proceed", "approved", "continue", "next") before crossing into ship/summary. A vague acknowledgment ("ok", "sure") does not cross the boundary. "QA only" stops here after reporting.

## Output

Report:

- the criterion-to-check coverage matrix (no MISSING rows when claiming PASS);
- commands run with exit status, and test counts (total / passed / failed / errored);
- live-flow evidence (screenshots, logs, network) wherever a UI or service was exercised;
- every blocker with its attempted-acquisition log entry, and the residual risk;
- whether the integration hard gate passed, with its execution evidence.

In full-loop mode, after QA passes and the user gives an explicit approval word at the boundary, continue to ship/summary.
