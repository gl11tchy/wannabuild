---
name: wb-ship
description: WannaBuild ship/summary phase entrypoint for preparing verified work, asking for delivery mode, executing it, and cleaning up.
---

# wb-ship

## Contract Standard

This prompt follows `docs/contract-standard.md`.
Shared contract: purpose, inputs, process, hard gates, evidence, output, handoff, forbidden actions.
Runtime gates fail closed. Specialist judgment stays advisory unless a gate or acceptance criterion requires evidence.

Use this phase skill when the user wants to ship, merge, push, create a PR, or prepare final delivery. A `wb-ship` or `wannabuild:wb-ship` invocation starts or resumes the full WannaBuild loop. If the discovery baseline, review evidence, or QA evidence is missing, resume the missing phase before declaring the work ready — including discovery, which must have run with recorded acceptance criteria before anything ships. A direct jump to ship never bypasses an earlier phase.

## Phase Bootstrap

Before any ship/summary phase work:

- Confirm a discovery baseline exists. If `.wannabuild/spec/requirements.md` (or the
  recorded acceptance criteria from wb-discover) is missing or has no Acceptance
  Criteria section, do NOT proceed: invoke wb-discover and complete the mandatory
  collaborative grilling pass first. Discovery fires on every task — including a
  one-line ship — and is never skipped because the request "looks trivial". A vague
  goal or a one-word "ok" is not a baseline; shipping has no anchor without it.
- If no concrete task exists, run the mandatory collaborative grill (one question at a
  time, each with a recommended answer) to establish the goal and acceptance criteria
  before any ship work. Do not assume the goal.
- Work in the current checkout by default.
- Do not create an isolated worktree for ship/handoff.
- Hard-stop at the QA → Summary boundary before any delivery action: present what is
  ready to ship, name the delivery decision, and wait for an explicit approval word
  ("go", "proceed", "approved", "continue", "lgtm", "do it"). A vague acknowledgment
  ("ok", "sure") does not cross the boundary.

## Purpose

Turn completed, reviewed, and QA-verified work into a clear ship-ready handoff, then ask for the delivery path.

## Hard Gates (fail closed)

These gates fail closed. A FAIL or a missing artifact is a hard stop — it cannot be
acknowledged away, waived, or rationalized past. Route every FAIL back to remediation;
never proceed to a delivery action while any gate is failing.

- **Discovery baseline.** `.wannabuild/spec/requirements.md` exists with an Acceptance
  Criteria section holding ≥1 concrete, checkable criterion. If absent, STOP and resume
  wb-discover before any ship work — shipping has no anchor without it.
- **Review verdict.** `assert-review-ready` passes: a PASS verdict from every required
  reviewer (security, performance, architecture, testing, code-simplifier, integration)
  for the latest iteration, each covering the entire changed surface. If review evidence
  is missing or any verdict is non-PASS, STOP and resume wb-review.
- **QA verdict.** `assert-qa-ready` passes: QA validated execution (real tests ran, every
  acceptance criterion covered) — not text markers. If QA evidence is missing, STOP and
  resume wb-qa.
- **CI / verification evidence.** Before declaring work ready you MUST hold pass/fail
  evidence for the change. You may never declare CI "absent", "unverifiable", or
  "skipped" from a single failed lookup — exhaust the acquisition ladder below first. No
  required check may end in a "skipped" state.
- **Runtime summary gate.** `scripts/wannabuild-gate-check.sh <project_root> summary`
  (which runs `assert-summary-ready`) returns PASS. Its FAIL is terminal and
  non-overridable: there is no acknowledgment path, no user wave-through. Route to
  remediation and re-run; do not proceed.

If the runtime gate cannot execute, treat that as a hard stop, not as permission to
proceed.

## CI / Verification Acquisition Ladder

You MUST obtain pass/fail evidence for the change before declaring work ready. Never
conclude CI is absent or unverifiable from one check. Exhaust, in order, and record each
attempt in `.wannabuild/outputs/acquisition-log.json` (the `assert-acquisition-attempted`
gate rejects any blocked/unverified status with no logged attempt):

1. GitHub Actions: `gh pr checks <pr>` and `gh run list --branch <branch>`; for an
   in-progress run, wait for it to finish (`gh run watch`) rather than reporting it as
   absent.
2. The project's own test, build, and lint commands run locally, with the exact commands,
   exit codes, and output captured into the verification evidence block.
3. Platform CI/deploy status via the project's connectors and CLIs when the project
   deploys through them — Railway, Vercel, Supabase, or Neon MCP tools and CLIs — because
   for those projects "CI status" lives there, not only in GitHub Actions.

A check that would be skipped for a missing resource (missing env, missing dependency,
missing service) is not an acceptable end state: first obtain or stand up the resource
(set required env from the project, spin up an ephemeral/local DB branch, run the app),
then run the check. Only paid, outward-facing, or destructive acquisition is a
stop-and-ask — present the specific resource and why; everything safe, local, and
reversible you acquire yourself. Never silent-skip.

## Defaults

- Do not hide, omit, or soften any failed check. Report every check run and its result.
- Do not create draft PRs unless the user explicitly asks for a draft.
- Keep release notes and PR text grounded in actual changes — every claim traces to a
  real diff or a real check result. No placeholder, stub, or to-do text in shipped notes.
- Run cleanup after the selected delivery action (see Flow step 9).
- Use sub-agents only for distinct release, CI, documentation, or risk ownership.
- Preserve active WannaBuild workflow state across turns until the task is complete or the
  user explicitly exits or stops.

## Flow

1. Collect changed files, acceptance evidence, review status, and QA status.
2. Identify unresolved risks or follow-ups.
3. Always produce: commit(s); a PR body (when a PR path is chosen); and a verification
   evidence block listing every check run with its exact command, exit code, and result.
   None of these is discretionary.
4. Recommend exactly one delivery path, state why, and state each option's consequence,
   then ask the user to confirm or override (this is a phase-boundary decision — wait for
   an explicit approval word before executing):
   - merge locally — no remote review; choose when there is no remote or none is wanted.
   - push branch and create a PR — recommended default when a remote exists and review is
     desired.
   - push directly to `origin/main` — BLOCKED if the branch is protected or shared; only
     offer when the user explicitly directs it and the branch is unprotected. Surface this
     risk before proceeding.
   - stop after local preparation — hand off without touching the remote.
5. For any path that mutates a shared or protected branch (push directly to
   `origin/main`), run and PASS all Hard Gates and the CI / verification evidence BEFORE
   executing the push — the gate runs before the irreversible action, never after.
6. Execute the selected path.
7. For PR or pushed-branch paths, check CI status after the delivery action via the
   acquisition ladder and block the final summary until checks are green. Failed CI routes
   back to remediation; you may not report CI as absent or skipped without a logged
   acquisition attempt.
8. Run `scripts/wannabuild-gate-check.sh <project_root> summary`. Its FAIL is terminal and
   non-overridable: route to remediation and re-run — do not proceed, acknowledge, or wave
   it through.
9. Run cleanup: prune temporary worktrees; delete the topic branch locally and remotely
   once it is merged (retain it only if the delivery path left it unmerged); remove
   generated transient files; verify the final git status. Cleanup is mandatory after the
   delivery action.
10. Stop with a concise summary.

## Output

Return a concise ship summary with delivery action, commit/PR/merge details, verification, cleanup performed, risks, and remaining work.
