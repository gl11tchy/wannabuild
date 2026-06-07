# WannaBuild Research Burst

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed. Specialist judgment stays advisory unless a gate or acceptance criterion requires evidence.

> Mandatory multi-agent research before planning.

This burst is governed by `skills/internal/build/references/doctrine.md`. Research is
the proportionate-investigation half of discovery (Mandate 1): it **fires whenever any
trigger below evaluates true**, and at least one trigger evaluates true on every task
that reaches this step. It is never optional, never auto-skipped, never waived by the
orchestrator, and never waived by a vague user "ok". The user shortens it only by
answering quickly; they cannot waive it.

## Purpose

Research is not a permanent public phase. It is a pre-planning burst that resolves every
open uncertainty with real acquired evidence before planning begins. Depth is
proportionate to the change (terse for a one-line fix, thorough for a feature) but
**never zero**: every triggered uncertainty MUST be investigated and resolved or
explicitly handed to the user as a decision. Planning is blocked until the hard gate
below passes.

## Trigger Evaluation (mandatory)

Before planning, evaluate EACH trigger below and record its value (true/false) plus the
evidence basis in the trigger table of `research-summary.md`. This evaluation is
required on every run; the conditions are observable, not judgment calls, so two
identical runs reach the same verdict. A trigger is **true** when:

1. **Architecture** — more than one viable system shape, contract, or integration
   boundary exists for the change.
2. **Dependencies** — any external dependency, framework, or build-vs-buy choice
   relevant to the change is unresolved.
3. **Codebase** — any source file, schema, or config the change will touch or depend on
   has not yet been read in this loop.
4. **Domain/API/auth/billing/infra** — any API contract, auth flow, billing path, or
   infra resource the change relies on is not yet confirmed against the real system.
5. **Risk** — the change has a blast radius beyond a single isolated file (touches
   shared state, security, migrations, money, or external surfaces).

If zero triggers are true, record the table with all five false and their basis, then
proceed; otherwise the burst MUST spawn coverage for every true trigger (see below).

## Research Agents

Spawn at least one specialist for EVERY trigger that evaluated true. A single
uncertainty axis may not be left uncovered, and the agent count may not be minimized
below full trigger coverage — under-coverage is a gate failure, not a judgment call.
Each trigger maps to its specialist by the deterministic table below:

| True trigger | Required specialist | Owns |
|---|---|---|
| 1. Architecture | `wb-architect` | system shape, contracts, integration boundaries |
| 2. Dependencies | `wb-tech-advisor` | technology choice, dependency, build-vs-buy |
| 3. Codebase | `wb-architect` | live reconnaissance of the touched code surface |
| 4. Domain/API/auth/billing/infra | `wb-tech-advisor` | the real external/infra surface |
| 5. Risk | `wb-risk-assessor` | blast radius, security, migration, compliance, ops |

Additionally spawn `wb-scope-analyst` whenever scope boundaries or MVP priority are
unresolved, and `wb-ux-perspective` whenever a user journey or experience risk is
unresolved. Each specialist covers its ENTIRE assigned uncertainty, not a sample, and
its finding must enumerate what it covered.

Record, per specialist, why it was spawned (which true trigger), what it owned, and the
acquired-evidence log it produced (tools invoked + outputs). Do not use fixed agent
counts or concrete model IDs.

## Acquisition (mandatory)

No finding, comparison, or open question may be reported from assumption. Before any
uncertainty is recorded as unresolved, you MUST exhaust real acquisition and log exactly
what was attempted and the result. "Missing env", "no access", or "can't test" are never
grounds to stop — they are grounds to obtain the resource or, only for
billable/outward/destructive needs, to ask the user. Per Mandate 2:

- **Codebase facts** — read the actual files and run real searches; never infer file
  contents, schemas, or call sites.
- **Library/framework facts** — pull live authoritative docs (Context7
  `get-library-docs`, official docs via WebFetch) before any comparison.
- **API/auth/billing/infra** — confirm against the real system: introspect the
  Supabase/Neon/Railway/Vercel project, spin an ephemeral/local DB branch, stand up a
  preview, or drive the real UI in a browser. Auto-acquire anything safe, local, and
  reversible without asking.
- **Stop-and-ask** only for billable, outward-facing, or destructive acquisition (paid
  provisioning, deploys, production data, external sends). Present the specific resource
  and why, with a recommended option.

Every blocker recorded as unresolved REQUIRES a corresponding entry in
`.wannabuild/outputs/acquisition-log.json` naming what was needed, which
tools/connectors/CLIs were attempted, and the result. The `assert-acquisition-attempted`
gate rejects any blocked status without a logged attempt.

## Output

Write a synthesis into `.wannabuild/outputs/research-summary.md`. Every section is
required and none may be empty:

- **Trigger table** — each of the five triggers with its true/false value and basis.
- **Per-specialist findings** — for each spawned specialist, what it covered and its
  acquired-evidence log (tools invoked + outputs). Speculation may not be recorded as
  evidence; evidence must come from real acquisition.
- **Recommended direction** — the chosen direction AND the alternatives it was chosen
  over, with the reasoning.
- **Open questions** — each annotated with the acquisition that was attempted and why it
  remains unresolved. An open question with no logged acquisition attempt is a gate
  failure.
- **Risks requiring explicit user choice** — each stated as a decision with options and
  a recommended option.

## Collaborate Before Handoff (mandatory)

Before handing off, present to the USER: the recommended direction with the alternatives
it was chosen over, each open question with a recommended answer, and each
risk-requiring-choice as an explicit decision with a recommended option. Decisions that
affect scope, design, or product are surfaced as options with a recommended answer — the
burst never resolves them silently. This is a hard-stop boundary: proceed to planning
only after the user gives an explicit approval word ("go", "proceed", "approved",
"continue", "next", "lgtm", "do it"). A vague acknowledgment ("ok", "sure") does not
cross the boundary.

## Hard Gate (fails closed)

Research may hand off to planning ONLY when all of the following hold:

- every true trigger has a corresponding specialist finding backed by acquired evidence;
- every open question records the acquisition that was attempted;
- every risk requiring user choice has been put to the user and resolved;
- the user has given an explicit approval word at the boundary.

This is consistent with the discovery half of `assert-discovery-ready` (Plan stays
blocked until requirements carry concrete acceptance criteria). If any condition above
is unmet, the burst is incomplete — it may not declare itself done and may not route to
planning.
