---
name: wb-debug
description: WannaBuild debugging implementation entrypoint for reproducing, diagnosing, fixing, and verifying bugs within the full loop.
---

# wb-debug

## Contract Standard

This prompt follows `docs/contract-standard.md` and inherits the four mandates in
`skills/internal/build/references/doctrine.md`; where this file is silent, the doctrine governs.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed and cannot be rationalized past. Specialist judgment stays advisory; a gate or acceptance criterion always wins.

Use this phase skill when the user wants a bug investigated or fixed. A `wb-debug` or `wannabuild:wb-debug` invocation runs the full WannaBuild loop — discovery, plan, implement, review, QA, summary. It stops short of QA only if the user, in this session, explicitly said "debug only"; confirm that exit before stopping, and even then discovery and the reproduction/verification gates below still apply.

## Phase Bootstrap

Before any debugging phase work, in order:

- Run discovery first (see "Discovery").
- Inventory and activate the resources you will need to reproduce the bug: the app/service runtime, logs, the database, the browser, and any connectors/MCP servers and CLIs available (Supabase, Neon, Railway, Chrome, computer-use, Context7). Acquisition is required, not optional (see "Resource acquisition").
- Work in the current checkout. Create an isolated worktree only when the user asks, selects implementation-time isolation, requests parallel implementation, or the diff is large enough to risk colliding with other uncommitted work; when isolating, use `scripts/wannabuild-workspace.sh --json` and continue inside the reported `workspace_path`.
- If the fix requires product or architecture choices not already planned, complete the planning phase before editing code.

## Purpose

Move from symptom to a reproduced failure, to a verified cause, to a minimal fix proven by re-running the reproduction.

## Discovery (mandatory, collaborative — before any code work)

Discovery fires on every bug, including one-line fixes; never skip it because the bug "looks trivial". Grill the user one question at a time, each with a recommended answer and the reasoning behind it, until you have: exact symptoms, expected vs actual behavior, concrete reproduction steps, environment/version/data shape, and what changed recently. Resolve a question by reading the codebase, logs, or live runtime instead of asking whenever the answer is there, and cite what you found. The user confirms, redirects, or overrides — they never invent the answer from scratch. Capturing any of these by assumption is forbidden; each must come from the user or from cited evidence.

Discovery does not pass until `.wannabuild/spec/requirements.md` records the symptom, the expected behavior, and at least one concrete, checkable acceptance criterion describing what "fixed" means. The `assert-discovery-ready` gate fails closed until that exists.

## Resource acquisition (required before claiming blocked)

Before you write "cannot reproduce", "no environment", "missing dependency", "no access", or "cannot test", you MUST exhaust real acquisition and report exactly what you tried:

- Run the app, service, CLI, or worker locally and capture its real output.
- Provision an ephemeral/local database branch (Supabase `create_branch`, Neon `create_branch`) and seed it; never declare "no database".
- Drive the real UI in a browser (Chrome) or computer-use to reproduce a user-facing failure.
- Read live, version-correct docs via Context7 instead of guessing an API.
- Generate the fixtures, seed data, or inputs the reproduction needs.

Auto-acquire anything safe, local, and reversible without asking. Stop and ask the user only for billable, outward-facing, or destructive acquisition (paid provisioning, deploys, production data, external sends) — present the specific resource and why. Every unmet need that you claim blocks you requires an entry in `.wannabuild/outputs/acquisition-log.json` recording what was needed, which tools/connectors/CLIs were attempted, and the result. The `assert-acquisition-attempted` gate rejects any blocked status with no logged attempt.

## Hard gates (fail closed)

- **Reproduction Gate:** Before editing any code, reproduce the failing behavior in a real runtime and capture the failing output (command, exit code, output). A description or characterization of the failure is not a reproduction. If you cannot yet reproduce, you are not blocked — go acquire what you need (see "Resource acquisition") and log the attempt.
- **Verification Gate:** After the fix, re-run the exact reproduction in a real runtime and show that it now passes, plus run the targeted regression checks — every test that exercises the changed path and every test covering each acceptance criterion. PASS requires execution evidence: the original reproduction now succeeds, the regression checks ran (`total > 0`, `failed == 0`, `errored == 0`), and every acceptance criterion is covered. A code re-read, a description, or "should pass" is a FAIL. A FAIL here blocks progress and cannot be overridden.

After the Verification Gate passes, continue to QA and the terminal integration hard gate, which validates execution evidence (not text markers) and whose FAIL cannot be overridden.

## Process

1. Run discovery and confirm the symptom, expected vs actual behavior, and acceptance criteria with the user.
2. Acquire the runtime/env/DB/browser/logs needed, logging any blocker attempt.
3. Pass the Reproduction Gate.
4. Inspect the smallest relevant code path; form hypotheses and test each against logs, probes, or the live runtime — not speculation.
5. Confirm the root cause with supporting evidence. Before applying a fix, present the confirmed cause and the proposed fix; when more than one plausible cause or fix exists, list the options and recommend one with reasoning, and proceed only after the user confirms or redirects. (Do not pause on mechanics like which file to edit — collaborate on scope/design choices only.)
6. Apply the minimal fix. Keep it narrow; do not refactor adjacent code, and do not leave a placeholder, stub, mock, or to-do standing in for the real fix.
7. Pass the Verification Gate, capturing before/after evidence.
8. Continue to validation and QA. Preserve active WannaBuild workflow state across turns until the task is complete or the user explicitly exits.

Use sub-agents to parallelize independent hypotheses, log streams, environments, or risk areas; they do not narrow the verification surface.

## Collaboration and boundaries

Hard-stop at every public phase boundary (Discover → Plan → Implement → Review → QA → Summary): present what the phase produced, name the next phase, and wait for an explicit approval word ("go", "proceed", "approved", "continue", "next", "lgtm", "do it"). A vague acknowledgment ("ok", "sure") continues the current phase; it never crosses a boundary. Within a phase, run to completion exhaustively — do not pause mid-work for checkpoints and do not stop early on review or QA burden.

## Forbidden actions

- Editing code before a live reproduction exists.
- Declaring "cannot reproduce", "no env", "missing dependency", "no access", or "cannot test" without first exhausting Resource acquisition and logging each attempt.
- Skipping discovery, treating a bug as too trivial to grill, or capturing symptoms/repro steps by assumption.
- Accepting a vague "ok" in place of a confirmed reproduction or an explicit phase-boundary approval word.
- Passing the Verification Gate from a code re-read or "should pass" instead of a real re-run with captured output.
- Leaving a placeholder, stub, mock, or to-do in place of the real fix, or marking work skipped/out of scope to drop a required obligation.
- Stopping at the fix without QA unless the user explicitly said "debug only" this session and you confirmed that exit.

## Output

Report: the confirmed root cause; the changed files; the reproduction evidence (command, exit code, failing output before the fix) and verification evidence (the same reproduction now passing plus the regression checks that ran, with their output); any resource acquisition that was performed; and any residual risk. Naming "verification evidence" without showing the executed commands and their output does not satisfy this.
