# WannaBuild Doctrine

The non-negotiable operating contract for every WannaBuild skill, agent, and runtime
gate. Every other contract file in this repo inherits these four mandates. Where a
phase skill or agent prompt is silent, this file governs. Where a runtime gate exists,
the gate is authoritative and **fails closed** — prose may not override it, and an
executor may not rationalize past it.

These mandates exist because soft prose ("when possible", "if you can't", "optional",
"add real signal", "impacted reviewers", "best effort") was rationalized past in
practice: discovery got skipped, reviewers covered a fraction of the surface, and QA
declared "missing env" and stopped. Each mandate below replaces a class of escape
hatch with a fixed rule and machine-checkable evidence.

---

## Mandate 1 — Discovery is mandatory and collaborative

Discovery (the grill + proportionate research) **fires on every task**, including
one-line changes. It is never optional, never auto-skipped, and never bypassed by a
"trivial" classification. Only the user shortens it, by answering quickly.

- **Grill:** one question at a time, each with a recommended answer and the reasoning
  behind it, walking the decision tree depth-first. The user confirms, redirects, or
  overrides — they never invent an answer from scratch. Resolve a question by reading
  the codebase instead of asking whenever the codebase holds the answer; cite what you
  found.
- **Research bundle:** feasibility, alternatives/competition, and Failure Forecast
  always produce an artifact. Depth is proportionate (terse for trivial changes,
  thorough for features) — but **never zero**.
- **Gate (`assert-discovery-ready`, fail-closed):** Plan is blocked until
  `state.discovery.*` is complete, the five discovery artifacts exist and are
  non-empty, and `.wannabuild/spec/requirements.md` contains an **Acceptance Criteria**
  section with at least one concrete, checkable criterion. A requirements file without
  acceptance criteria does not pass — you cannot plan against an unmeasurable goal.

## Mandate 2 — Exhaust resources before declaring blocked; never silent-skip

"Missing env", "no database", "can't run it", "no access", "no fixtures" are **never**
grounds to skip review, testing, or any obligation. They are grounds to **obtain the
resource or ask the user** — never to silently drop the work.

- **Auto-acquire (no permission needed)** everything safe, local, and reversible:
  run the app locally; spin ephemeral/local database branches (Supabase/Neon); drive
  the real UI with a browser (Chrome) or computer-use; read live docs (Context7);
  generate fixtures and seed data; stand up preview/ephemeral environments.
- **Stop-and-ask** only for billable, outward-facing, or destructive acquisition:
  paid cloud provisioning, deploys, production data, external sends, anything
  hard to reverse. Present the specific resource you need and why.
- **Never** mark work "skipped" or "blocked" without proof you tried. A blocker claim
  requires an entry in `.wannabuild/outputs/acquisition-log.json` recording, per
  unmet need: what was needed, which tools/connectors/CLIs were attempted, and the
  result. The `assert-acquisition-attempted` gate rejects any blocked/failed status
  that lacks a logged attempt.
- All validation and QA evidence must record **exactly what was executed** — real
  commands, real exit codes, real output — not assertions that work "should" pass.

## Mandate 3 — Completeness; gates cannot be rationalized away

- **Review runs the full reviewer set every iteration.** All of
  `wb-security-reviewer`, `wb-performance-reviewer`, `wb-architecture-reviewer`,
  `wb-testing-reviewer`, `wb-code-simplifier`, and `wb-integration-tester` produce a
  verdict on every review iteration. There is no "impacted-only" subset, no
  "fast-track for tiny changes", no reviewer self-selecting out. The `assert-review-ready`
  gate requires a PASS verdict from every one of them.
- **Each reviewer covers the entire changed surface**, not a sample. A reviewer that
  examined part of the diff and stopped has not completed its job; its verdict must
  enumerate what it covered.
- **The integration tester is the terminal hard gate.** Its FAIL cannot be overridden
  at any escalation level — there is no override path. A PASS is only valid with
  execution evidence: `test_execution` showing tests actually ran
  (`total > 0`, `failed == 0`, `errored == 0`) and a `coverage_map` in which every
  acceptance criterion is `covered` (none `missing` or `partial`). "Status: PASS" with
  zero tests executed is a FAIL.
- **QA validates execution, not markers.** The `assert-qa-ready` gate requires the
  QA summary's positive markers **and** the integration tester's execution evidence.
  Text markers alone never pass QA.

## Mandate 4 — Collaboration and determinism

- **Hard-stop at every public phase boundary** (Discover → Plan → Implement → Review
  → QA → Summary). At each boundary, present what the phase produced, name the next
  phase, and **wait for an explicit approval word** ("go", "proceed", "approved",
  "continue", "next", "lgtm", "do it"). A vague acknowledgment ("ok", "sure", "uh ok")
  continues the *current* phase; it never crosses a boundary.
- **Collaborate on decisions, execute autonomously.** Within a phase, run to
  completion exhaustively — do not pause mid-execution for "checkpoints", and do not
  stop early on review/QA burden. Collaboration means deciding *with* the user at
  boundaries and surfacing real ambiguity; it does not mean interrupting mechanical
  work.
- **Fixed pipeline, adaptive depth only.** The sequence of phases, the gates, the
  grill structure, and the full reviewer/QA set are identical on every run. Only the
  *depth* of work inside a phase scales with the change (more findings, more tests on
  a larger diff). The user gets the same experience every time; runs never differ in
  which steps occur, only in how much work each step contains.

---

## Evidence artifacts (what each gate reads)

| Gate | Required evidence | Fails closed when |
|---|---|---|
| `assert-discovery-ready` | `state.discovery.*` complete; 5 discovery artifacts non-empty; `requirements.md` has an Acceptance Criteria section with ≥1 criterion | any missing/empty, or no acceptance criteria |
| `assert-plan-ready` | `.wannabuild/spec/design.md` + `tasks.md` (or completed design+tasks phase history) | either missing |
| `assert-review-ready` | PASS verdict from **all** required reviewers for the latest iteration; integration verdict carries execution evidence | any reviewer missing or non-PASS; integration evidence absent or shows 0 tests / failures / missing criteria |
| `assert-qa-ready` | `qa-summary.md` PASS + acceptance + integration markers; integration execution evidence; no `qa_failed` as latest QA event | markers absent, execution evidence absent, or QA blocked without an acquisition log |
| `assert-acquisition-attempted` | `.wannabuild/outputs/acquisition-log.json` with ≥1 attempt per unmet need | a blocked/failed status exists with no logged acquisition attempt |
| `assert-summary-ready` | review + QA gates pass; workflow not blocked | either gate fails or workflow is blocked |

Gates are fail-closed at the runtime boundary: if the runtime cannot execute, the
transition does not happen. Skills must treat a runtime-unavailable result as a hard
stop, not as permission to proceed.
