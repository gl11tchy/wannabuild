# AGENTS.md

Primary operator contract for WannaBuild.

## Working Principles

Apply in order of precedence — #1 trumps #2, etc.

### 1. Think Before Coding

- State assumptions explicitly. If uncertain, ask — don't guess.
- When ambiguity exists, surface the interpretations; don't pick silently.
- Push back when a simpler approach exists.
- If confused, name what's unclear and stop. Don't paper over it.

### 2. Simplicity First

- Minimum code that solves the problem. Nothing speculative.
- No features, abstractions, flexibility, or error handling beyond what was asked.
- No abstractions for single-use code.
- If 200 lines could be 50, rewrite it.
- Test: would a senior engineer call this overcomplicated? If yes, simplify.

### 3. Surgical Changes

- Touch only what the task requires. Every changed line should trace to the request.
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor what isn't broken. Match existing style even if you'd do it differently.
- Remove imports/variables your changes orphaned. Don't delete pre-existing dead code — mention it instead.

### 4. Goal-Driven Execution

- Define success criteria up front. Loop until verified.
- Translate imperative tasks into verifiable ones: "add validation" → tests for invalid inputs; "fix the bug" → a reproduction test; "refactor X" → tests pass before and after.
- For multi-step work, state a brief plan: 1. [step] → verify: [check].

## Executor Assumptions

These contracts are written for frontier-class executors. Every rule is stated once and is binding without repetition; referenced contract files govern wherever a contract is silent. Read referenced files before acting on them, apply them without being re-reminded, and treat "the contract doesn't restate it here" as inheritance, not permission.

## Purpose

WannaBuild is a repo-first, spec-driven development framework with a compact user-facing loop and rigorous internal execution. Codex and Claude Code are co-primary experiences; Cursor is a secondary adapter. The framework should feel lightweight to the user while still enforcing real planning, implementation, validation, and QA internally.

## Golden Path

```text
Discover -> Plan -> Implement -> Validate -> QA -> Summary
```

## Doctrine

Four mandates govern every skill, agent, and gate. They are defined in full in
[skills/internal/build/references/doctrine.md](skills/internal/build/references/doctrine.md)
and they override any softer wording elsewhere:

1. **Discovery is mandatory and collaborative.** The grill fires on every task; research is proportionate but never zero; Plan is blocked until discovery produces a requirements brief with acceptance criteria.
2. **Exhaust resources before declaring blocked; never silent-skip.** "Missing env"/"can't test" is grounds to obtain (run the app, spin a DB branch, drive a browser, read live docs) or to ask — never to skip. Every blocker requires a logged acquisition attempt.
3. **Completeness; gates cannot be rationalized away.** The full reviewer set runs every iteration (no impacted-only, no fast-track); the integration tester is terminal with no override and PASS requires runtime-recorded execution evidence: the runtime executes the configured integration test command itself (`wb-runtime record-test-evidence`) and signs the record — a hand-written verdict cannot satisfy the gate.
4. **Collaboration and determinism.** Hard-stop at every boundary for an explicit approval word; fixed pipeline with adaptive depth only, so the experience is identical every run.

## Skill-First Dispatch

- Skills own behavior. Commands are optional shortcuts; keep command files thin and route to the owning skill.
- If a natural-language request plausibly matches a WannaBuild skill, use the skill automatically. Do not tell the user to invoke a slash command or `$skill` first.
- "I want to build...", "plan this", "debug this failure", "review this change", "QA this" trigger the matching skill. Exploratory prompts ("I was thinking of ideas", "let's brainstorm") are concrete enough to trigger Discover.
- Use `wannabuild` for broad product or feature requests; use the focused `wb-*` phase skill to enter at a specific phase, then continue the full loop by default.
- Stop at a single phase only when the user explicitly says "discovery only", "plan only", "do not implement", "QA only", or equivalent. A vague acknowledgment ("ok") is never permission to skip phases.
- Treat any explicit `wannabuild:*` or `wb-*` invocation as a workflow entrypoint, not a one-turn command, and preserve workflow state across turns until the task completes or the user exits.

## Non-Negotiables

- If there is no concrete task, stage intent, or exploratory idea intent, ask for the actual goal first. Do not infer intent from git diff or uncommitted changes, and do not browse externally without a concrete task.
- Exception: an explicit `wb-review` invocation is itself a concrete review task; with no named target, review the current checkout changes by default and ask only when there is no reviewable diff.
- Do not transition Discover/Research → Plan until `scripts/wannabuild-session.sh assert-discovery-ready .` passes.
- Before any implementation edit, run `scripts/wannabuild-session.sh assert-plan-ready .`. If it fails — or the runtime cannot execute — return to Plan; do not edit implementation files.
- Work in the current checkout by default. Offer or create an isolated worktree only when entering implementation from an approved plan, when the user asks for isolation, or when parallel/risky changes need separation — never during Discover, Plan, Review, QA, or Summary.

## Step Contract

| Step | Operator obligation | Completion signal |
|---|---|---|
| Discover | Grill the user — one question at a time with a recommended answer, reading the codebase instead of asking whenever it holds the answer — across vision, audience, flows, features, constraints, scope, success signals, and non-goals; then run the research bundle (feasibility, alternatives/competition, Failure Forecast) at proportionate, never-zero depth. | `assert-discovery-ready` passes: discovery artifacts non-empty and `requirements.md` has acceptance criteria. |
| Plan | Produce a concrete plan, run bounded research when needed, verify architecture/direction, and generate N (default 3) adversarial plan options rendered to a self-contained HTML the user can open before choosing one. | Plan is actionable and internally consistent; the chosen plan is recorded. |
| Implement | Choose an adaptive execution shape; execute with owned slices, checkpoints, and verification. | Planned slices are implemented with evidence. |
| Validate | Run the full reviewer set, each covering the entire changed surface; fix all actionable findings autonomously, acquiring any resource a check needs. | `assert-review-ready` passes: every required reviewer PASS for the latest iteration. |
| QA | Validate every acceptance criterion and integration behavior by executing real tests against real (acquired) resources, recording the integration run through the runtime (`wb-runtime record-test-evidence`). | `assert-qa-ready` passes: QA markers plus runtime-recorded, signature-verified integration execution evidence. |
| Summary | Report changes, passed checks, risks, and remaining work. | Handoff summary is complete and honest. |

## Control Mode

Default to guided execution: run the Discover interview, then hard-stop at every phase boundary per Mandate 4 — present what the phase produced, name the next phase, and wait for an explicit approval word. If the user explicitly asks for autonomous or unattended execution, run the full loop without per-boundary approval, asking only when scope, product direction, destructive actions, credentials, paid/external services, or merge/push strategy require user judgment. In either mode, keep user-facing summaries concise and choose research, implementation shape, and validation depth from task evidence.

## Parallelization

- Stay single-owner when coherence matters more than fan-out; parallelize independent discovery perspectives, disjoint implementation slices, or concurrent review hats with distinct risk ownership.
- The discovery research bundle always runs; use bounded parallelism for it when the perspectives are genuinely independent.
- Choose agent count from task evidence (complexity, coupling, uncertainty, blast radius) — never a fixed recipe. Stop adding agents when one no longer has distinct ownership and expected evidence.
- Record delegation rationale in `.wannabuild/decisions.md` or checkpoints.

## Internal Execution Model

```text
Requirements -> Design -> Tasks -> Implement -> Review -> Ship -> Document
```

| Public step | Internal execution |
|---|---|
| Discover | Requirements |
| Plan | Design + Tasks (plus bounded research when the plan needs it; the discovery bundle already ran) |
| Implement | Implement after solo/parallel choice |
| Validate | Review |
| QA | Integration hard gate + final verification |
| Summary | Ship / Document / handoff synthesis |

## Artifact Contract

Target projects use `.wannabuild/` as workflow state:

```text
.wannabuild/
├── state.json
├── spec/
│   ├── requirements.md      # vision, audience, flows, scope, assumptions, acceptance criteria, test scenarios
│   ├── design.md            # architecture, contracts, risks, testing direction
│   └── tasks.md             # ordered implementation slices with verification expectations
├── outputs/
│   └── plan/
│       ├── plan-options.json        # N adversarial plan options (plan-options.schema.json)
│       └── adversarial-plans.html   # self-contained render, shown at the Plan boundary
├── checkpoints/             # execution evidence and resume anchors
├── review/                  # structured reviewer verdicts
├── loop-state.json
└── decisions.md
```

## Execution and Quality Defaults

- Implement in micro-steps; checkpoints are canonical execution evidence.
- Keep Review and QA as distinct post-implementation stages; Mandate 3 governs the reviewer set and the integration hard gate.
- Commit at each completed slice; always commit before ship-oriented packaging.

## Model Defaults

- Choose capability tier and reasoning effort per task, not by hard-coded model name: lightweight/fast for bounded lookup, formatting, and low-risk documentation; standard for normal implementation and well-scoped remediation; strong/high-reasoning for architecture, ambiguity, high-risk integrations, and complex debugging.
- Host adapters map capability tiers to the concrete models and reasoning controls available in that host (see [docs/host-capability-matrix.md](docs/host-capability-matrix.md)). Core contracts stay model-agnostic.
- Use advisor escalation selectively for high-impact uncertainty: architecture choices, material ambiguity, high-risk integrations, uncertain remediation, conflicting specialist outputs, or test strategy risk. The executor remains the single tool-using owner; the advisor provides bounded guidance only and must not call tools, edit files, run commands, or produce user-facing output.

## Repo Surfaces

```text
wannabuild/
├── AGENTS.md        # operator contract
├── skills/          # workflow and phase contracts
├── agents/          # specialist prompts
├── scripts/         # validation and runtime helpers
├── docs/            # onboarding, philosophy, host capability docs
├── adapters/        # host-specific packaging/install surfaces (codex, cursor, claude-code, factory)
├── .claude-plugin/  # Claude Code marketplace packaging
├── tests/           # bats unit + integration suite
└── .github/         # CI, governance, rulesets, release automation
```

## Host Positioning

- Codex and Claude Code are co-primary experiences; Cursor is the secondary adapter.
- Install: Claude Code via `/plugin install wannabuild@gl11tchy` or `scripts/install-claude-skill.sh`; Codex via `scripts/install-codex-skill.sh`.
- Host details: [README.md](README.md), [docs/codex-getting-started.md](docs/codex-getting-started.md), [docs/host-capability-matrix.md](docs/host-capability-matrix.md).

## Quality Gates

The framework enforces its own contracts via:

- `scripts/lint.sh` — shellcheck, shfmt, markdownlint, jscpd, lizard complexity, large-file detection, dead-ref scanning, tech-debt scanning.
- `tests/run.sh` — bats unit + integration suite (also runnable via `make -C tests test`).
- `scripts/wannabuild-doctor.sh` — required-surface presence check.
- `.pre-commit-config.yaml` — local hook surface (gitleaks, formatter, lint).
- `.github/workflows/ci.yml` — runs all of the above plus contract validation against dry-run fixtures.
- `.github/workflows/security.yml` — gitleaks, dependency-review, CodeQL on workflows.
- `.github/workflows/release-please.yml` — release automation from Conventional Commits.

The full list of CI jobs and what they verify lives in [docs/ci.md](docs/ci.md).

## Validation Notes

This is a framework/documentation repository: unit/integration validation mainly occurs in target projects, and Claude plugin compatibility is validated separately from core repo-native flow.

## Dependencies

No external runtime dependencies are required for the framework itself. This does not relax Mandate 2 for **target-project** work: acquire whatever runtime, database, browser, or fixture the task needs (or ask for billable/outward acquisition) — never treat a missing resource as license to skip review or QA.
