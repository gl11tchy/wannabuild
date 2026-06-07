---
name: wb-plan
description: WannaBuild planning phase entrypoint for turning a brief or concrete task into architecture direction, implementation slices, and verification expectations.
---

# wb-plan

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed. Specialist judgment stays advisory unless a gate or acceptance criterion requires evidence.

Use this phase skill when the user invokes planning or the active WannaBuild workflow is in Plan. A `wb-plan` or `wannabuild:wb-plan` invocation starts or resumes the full WannaBuild loop unless the user explicitly says plan only or do not implement.

## Phase Bootstrap

Before any planning phase work:

- If no concrete task exists, ask for the actual goal first.
- Work in the current checkout by default.
- Do not create an isolated worktree for planning.

## Purpose

Produce a concrete, verifiable plan from a completed discovery brief and its requirements (`.wannabuild/spec/requirements.md`). Discovery is the only valid input to Plan: a bare "clear task" never substitutes for it. If discovery artifacts do not exist, planning is blocked until `wb-discover` produces them. Per `skills/internal/build/references/doctrine.md` Mandate 1.

## Hard Gates

Gates fail closed. A runtime-unavailable result is a hard stop, not permission to proceed.

- Discovery precedence (fail-closed): Before producing any plan in a WannaBuild workspace, `scripts/wannabuild-session.sh assert-discovery-ready .` MUST succeed. If `.wannabuild/spec/requirements.md`, the five discovery artifacts, or the requirements **Acceptance Criteria** section are missing or empty, STOP and route to `wb-discover` — never plan against an undiscovered or unmeasurable goal, and never improvise the missing discovery yourself.
- Plan completeness (fail-closed): Before any handoff to Implement, every acceptance criterion in requirements.md MUST map to at least one slice; every slice MUST carry an executable, real verification step (a concrete command or check, never a placeholder such as "verify it works"); every impacted surface (call site, schema, config, migration, error/edge path) MUST be named. If any of these is missing, the plan is incomplete and the handoff is forbidden.
- Plan-ready (fail-closed): In full-loop mode, cross Plan → Implement only after `scripts/wannabuild-session.sh assert-plan-ready .` succeeds and the plan artifacts are written.

## Defaults

- Plan the minimum that fully satisfies the goal. "Minimum" MUST still cover every acceptance criterion in requirements.md, every impacted call site, schema, config, and migration, and the error and edge paths of each slice. "Smallest" never licenses omitting a necessary slice or skipping a risky surface.
- Inspection floor (deterministic): read requirements.md and all five discovery artifacts; read every file the plan will direct an implementer to change; read every call site of each symbol the plan changes; read the schema, config, and migration touched by each slice; read the tests covering the changed surface. Inspection scope is set by this floor, not by what feels "needed".
- Prefer existing architecture, conventions, and helper APIs. When the plan introduces a new pattern instead, name the existing option it rejected and why.
- Document every tradeoff that affects architecture, scope, data model, external dependencies, or risk. Tradeoffs are recorded for all material decisions, never only the ones that "matter" by self-judgment.
- Preserve active WannaBuild workflow state across turns until the task is complete or the user explicitly exits or stops.
- Do not treat vague acknowledgments like "ok" or "uh ok" as permission to cross any phase boundary — Discover → Plan or Plan → Implement — or to skip discovery, planning, or any completeness gate. Only an explicit approval word crosses a boundary.

## Resource Acquisition

Per `skills/internal/build/references/doctrine.md` Mandate 2. "Missing env", "no access", or "can't check" is never grounds to drop a feasibility claim or stop planning — it is grounds to obtain the resource or ask the user.

- Every feasibility, capability, or constraint claim in the plan MUST be backed by a real check, not memory: read current library/API docs via Context7; inspect the actual schema via the Supabase/Neon MCP; check platform and runtime limits via the Railway/Vercel MCP or CLI; read the live code being integrated against. A claim with no backing check may not enter the plan.
- Auto-acquire (no permission needed) anything safe, local, and reversible: read live docs, inspect connected services read-only, spin local/ephemeral database branches, stand up preview environments, generate fixtures. Do this before recording any unknown.
- Stop and ask the user only for billable, outward-facing, or destructive acquisition (paid provisioning, deploys, production data, external sends). Present the specific resource needed and why.
- A residual unknown or "blocked" claim is allowed only with a logged acquisition attempt in `.wannabuild/outputs/acquisition-log.json` (what was needed, which tools/connectors/CLIs were tried, the result). `assert-acquisition-attempted` rejects any blocked status without a logged attempt.

## Collaboration

Per `skills/internal/build/references/doctrine.md` Mandate 4. Decide *with* the user at decision points; execute autonomously within the phase.

- When a decision changes architecture, scope, data model, external dependencies, or risk, present the viable directions as explicit options — each with a one-line tradeoff, exactly one marked as the recommended answer with its reasoning — and let the user confirm, redirect, or override before committing. Never pick such a direction silently.
- Stop and ask (options + recommendation) whenever any of these is unresolved: the target architecture or pattern, a new external dependency or service, a data-model or migration choice, a security- or privacy-affecting decision, or a tradeoff with no clearly dominant option.
- Within the phase, run to completion exhaustively. Do not pause mid-plan for "checkpoints" and do not stop early on plan size. Collaboration happens at decision points and the phase boundary, not in the middle of mechanical work.

## Sub-agents (deterministic triggers)

Where the host supports sub-agents, spawn one per trigger that is present; otherwise produce the same analysis directly. The set that runs is determined by these triggers, never by self-judgment, so identical input plans identically every run.

- architecture — the change introduces or alters a module boundary, data flow, or cross-cutting pattern.
- risk — the change touches auth, payments, PII, secrets, or destructive/irreversible operations.
- dependency — the plan adds or upgrades an external dependency, service, or MCP connector.
- task-decomposition — the plan contains more than three slices or any slice spans more than one subsystem.

## Flow

1. Run the discovery-precedence Hard Gate. If it fails, route to `wb-discover` and stop.
2. Confirm the goal, assumptions, constraints, and success criteria against requirements.md. Surface meaningful ambiguity as options instead of resolving it silently; resolve every ambiguity that changes architecture, scope, or risk via the Collaboration rules before proceeding.
3. Map every affected surface against the inspection floor and exhaust Resource Acquisition for each feasibility and constraint claim before recording it.
4. Choose the design direction. Where the choice changes architecture, scope, data model, external dependencies, or risk, present options-with-recommendation and get the user's decision first. Document every material tradeoff.
5. Break work into ordered slices. Every acceptance criterion maps to at least one slice, and every slice carries an executable, real verification step.
6. Run the plan-completeness Hard Gate. If any acceptance criterion, verification step, or impacted surface is missing, complete the plan before continuing.
7. Hard-stop at the Plan → Implement boundary. Present the plan summary (slices, impacted surfaces, verification per slice, tradeoffs, residual unknowns with the acquisition attempt that failed to resolve each), name the next phase (Implement), and wait for an explicit approval word ("go", "proceed", "approved", "lgtm", "do it", "continue", "next"). A vague acknowledgment never crosses this boundary. After approval, continue to Implement only once `assert-plan-ready` passes.

## Evidence

In a WannaBuild workspace, Planning must produce:

- `.wannabuild/spec/design.md` — design direction, options considered with the recommended choice, and every material tradeoff.
- `.wannabuild/spec/tasks.md` — ordered slices, each mapped to acceptance criteria and carrying an executable verification step.

These artifacts are the contract handoff to Implement and are always written in full-loop/workspace mode — never gated on the user explicitly asking for them. Record completed planning evidence in `.wannabuild/state.json` under the plan/design and tasks fields (merge-update only; never replace the file wholesale).

## Forbidden Actions

- Producing a plan when `assert-discovery-ready` has not passed, or improvising the missing discovery in place of routing to `wb-discover`.
- Recording a feasibility or constraint claim from memory instead of a real acquisition check.
- Marking any need "blocked" or "unknown" without a logged attempt in `.wannabuild/outputs/acquisition-log.json`.
- Choosing an architecture, dependency, data model, or risk-bearing direction unilaterally instead of presenting options-with-recommendation.
- Leaving a slice with a placeholder verification step ("verify it works"), a stub, or a to-do standing in for a real check.
- Crossing Plan → Implement on a vague acknowledgment, before the plan-completeness gate passes, or before `assert-plan-ready` succeeds.
- Implementing code while planning.

## Output

Hand off to `wb-build` / Implement automatically after the plan-completeness and `assert-plan-ready` gates pass and the plan artifacts are written — unless the user explicitly requested plan-only, or an options-with-recommendation decision is still awaiting the user's choice.
