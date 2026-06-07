---
name: wb-build
description: WannaBuild implementation phase entrypoint for implementing a concrete plan or task with focused verification and adaptive delegation.
---

# wb-build

## Contract Standard

This prompt follows `docs/contract-standard.md` and inherits the four mandates in
`skills/internal/build/references/doctrine.md` (discovery mandatory + collaborative;
exhaust resources, never silent-skip; completeness with un-rationalizable gates;
collaboration + determinism). Where this file is silent, the doctrine governs.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed and cannot be rationalized past. The runtime gate result is
authoritative: a FAIL or runtime-unavailable result is a hard stop, never permission to
proceed. Specialist judgment is advisory only; it never lowers a gate or substitutes for
execution evidence.

Use this phase skill when the user invokes implementation or the active WannaBuild workflow is ready to build. A `wb-build` or `wannabuild:wb-build` invocation starts or resumes the full WannaBuild loop. A "build only" request still requires every gate below, full self-verification evidence, and the integration hard gate; it only suppresses delivery in the Summary phase.

## Phase Bootstrap

Before any implementation phase work:

- If no concrete, discovery-backed task exists, do NOT proceed on a one-line goal. Invoke `wb-discover` and complete the mandatory collaborative grill (one question at a time, each with a recommended answer) and the proportionate research bundle before any planning or implementation. Discovery fires on every task, including one-line changes; it is never skipped on a "trivial" classification.
- Before editing code you MUST confirm both gates pass, fail-closed, in this order:
  1. `scripts/wannabuild-session.sh assert-discovery-ready <project_root>`
  2. `scripts/wannabuild-session.sh assert-plan-ready <project_root>`
- If `assert-discovery-ready` is not satisfied — discovery missing, incomplete, or based only on a vague goal, or `requirements.md` has no Acceptance Criteria section with at least one concrete checkable criterion — STOP and invoke `wb-discover`. You may not plan or build against an unmeasurable goal.
- If `assert-plan-ready` is not satisfied, STOP and invoke/complete the WannaBuild planning phase before editing code.
- If either gate cannot execute, you MUST first attempt to make it run: confirm the script exists, fix permissions, invoke via `bash`, and install missing dependencies. Log each attempt and its result. Only if it still cannot run after these attempts may you stop, and you must report every attempt and its outcome. A runtime-unavailable gate is a hard stop, never permission to proceed.
- Work in the current checkout by default. Create an isolated worktree only when the user requests it, selects implementation-time isolation, requests parallel implementation, or the change touches migrations, shared state, or release config. Record which condition applied as rationale; do not create a worktree on a judgment call absent one of these conditions.
- If an isolated worktree is selected, use `scripts/wannabuild-workspace.sh --json` and continue inside the reported `workspace_path`. If that script cannot run, attempt to repair it (path, permissions, `bash` invocation) and log the attempt before stopping.

## Purpose

Implement the requested change in micro-steps with evidence that the work satisfies the goal.

## Defaults

- Require both the discovery-ready and plan-ready gates to pass before editing.
- Keep changes surgical and consistent with the existing codebase.
- Use a single owner unless acceptance criteria map to files or modules with no shared edits; only then fan out, and record the disjoint mapping as the delegation rationale.
- Record delegation rationale whenever sub-agents are used.
- Run checks in a fixed order so two runs of the same task verify identically: (a) lint, (b) type/build, (c) the full relevant test suite, (d) the change exercised against a real running instance. There is no narrow-only stopping point; every applicable check in this set MUST run and ALL must pass. Scope adapts to the diff (more tests on a larger change), but which checks run does not.
- Preserve active WannaBuild workflow state across turns until the task is complete or the user explicitly exits or stops.
- Do not revert to generic implementation behavior; use the WannaBuild implementation contract and continue to validation and QA after build. A "build only" request still requires full self-verification evidence and the integration hard gate.

## Flow

1. Surface every assumption and success criterion that affects scope, product, data, or security as an explicit list, each with your recommended answer, and confirm them with the user before implementing. Proceed unilaterally only on purely mechanical, reversible details.
2. Inspect the relevant code and tests, and inspect or provision the live dependencies the change touches — database state, env vars, fixtures, and external services — via the available connectors, MCP servers, or CLIs. Do not assume a dependency's state; verify it.
3. Implement the smallest coherent slice. Do not leave a placeholder, stub, mock, or to-do standing in for required behavior; an unfinished dependency must be acquired or built, not faked.
4. Verify the slice. You MUST run, in fixed order, every check that applies and ALL must pass before continuing: (a) lint, (b) type/build, (c) the full relevant test suite, (d) the change exercised against a real running instance — start the app, hit the endpoint, or drive the UI in a real browser. A "manual check" is not a substitute for any of these and never satisfies this step on its own.
5. Before claiming the task blocked, untestable, or dependent on a missing resource, you MUST first exhaust real acquisition and log exactly what you tried and the result to `.wannabuild/outputs/acquisition-log.json`: provision and seed a database via the available connector or CLI (Supabase/Neon branch), run the app locally, stand up a preview environment, drive a real browser, generate fixtures, or read live docs via Context7. "Missing env", "no access", and "can't test" are grounds to obtain the resource or — only for billable, outward-facing, or destructive acquisition — to ask the user, never to stop. `assert-acquisition-attempted` rejects any blocked status with no logged attempt.
6. After implementation you MUST hand off to validation and QA. The integration tester is the terminal hard gate: its FAIL blocks completion and cannot be overridden, skipped, or rationalized away — there is no override path, and a "build only" request does not bypass it. A PASS is valid only with execution evidence: tests actually ran (`total > 0`, `failed == 0`, `errored == 0`) and every acceptance criterion is covered.

## Output

Prefer concise summaries. Write implementation artifacts to files and keep final responses focused on what changed and how it was verified, including the exact commands run, their exit codes, and output — not assertions that checks "should" pass.

In full-loop mode, continue automatically through implementation, validation, and QA without stopping for mechanical steps. Pause for the user ONLY when: an assumption with scope, product, security, or cost impact is unconfirmed; a discovery or plan gate failed; acceptance criteria conflict; or you have reached a public phase boundary. Within a phase, run to completion exhaustively — do not pause mid-execution for checkpoints and do not stop early on review or QA burden.

At each public phase boundary (Discover → Plan → Implement → Review → QA → Summary), present what the phase produced, name the next phase, and hard-stop for an explicit approval word ("go", "proceed", "approved", "continue", "next", "lgtm", "do it"). A vague acknowledgment ("ok", "sure") continues the current phase; it never crosses a boundary.
