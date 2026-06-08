# AGENTS.md

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
- Translate imperative tasks into verifiable ones:
  - "Add validation" → write tests for invalid inputs, then make them pass.
  - "Fix the bug" → write a reproduction test, then make it pass.
  - "Refactor X" → ensure tests pass before and after.
- For multi-step work, state a brief plan: 1. [step] → verify: [check].

Primary operator contract for WannaBuild.

## Skill-First Dispatch

- Skills own behavior. Commands are optional shortcuts only.
- If there is any plausible chance a WannaBuild skill applies to the request, use the skill automatically.
- Do not tell the user to invoke a slash command or `$skill` when a natural-language request already matches a WannaBuild skill.
- Prefer routing to `wannabuild` or a `wb-*` phase skill over restating command instructions.
- Treat any explicit `wannabuild:*`, `wb-*`, or host UI WannaBuild skill invocation as a workflow entrypoint, not a one-turn command.
- Preserve active WannaBuild workflow state across turns until the task is complete or the user explicitly exits/stops.
- Keep command files thin: describe invocation and route to the matching skill; do not duplicate workflow policy in commands.
- If multiple skills might apply, choose the smallest set that covers the request and continue.

## Automatic Wake-Up Contract

- Natural-language prompts like "I want to build...", "add this functionality", "plan this", "debug this failure", "review this change", or "QA this" should trigger the matching WannaBuild skill without asking the user to invoke a command.
- Exploratory prompts like "I want to work on this some", "I was thinking of ideas", "let's brainstorm this", or "what should we add?" are concrete enough to trigger Discover. Treat them as discovery tasks, not as missing-task invocations.
- Use `wannabuild` for broad product, feature, or change requests that should start discovery.
- Use the focused `wb-*` phase skill as the entrypoint for the matching phase, then continue the full loop by default.
- Stop at a single phase only when the user explicitly says "discovery only", "plan only", "do not implement", "QA only", or equivalent.
- Never treat vague acknowledgments like "ok" or "uh ok" as permission to skip phases.
- Slash commands and `$skill` names are escape hatches for explicit routing, not prerequisites.

## Purpose

WannaBuild is a repo-first, spec-driven development framework with a compact user-facing loop and rigorous internal execution. Codex and Claude Code are co-primary experiences; Cursor is a secondary adapter.

The framework should feel lightweight to the user while still enforcing real planning, implementation, validation, and QA internally.

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
3. **Completeness; gates cannot be rationalized away.** The full reviewer set runs every iteration (no impacted-only, no fast-track); the integration tester is terminal with no override and PASS requires execution evidence.
4. **Collaboration and determinism.** Hard-stop at every boundary for an explicit approval word; fixed pipeline with adaptive depth only, so the experience is identical every run.

## Non-Negotiables

- If there is no concrete task, stage intent, or exploratory idea intent, ask for the actual goal first.
- Do not infer intent from git diff or uncommitted changes.
- Exception: an explicit `wb-review` or `/wb-review` invocation is itself a concrete review task; if no target is named, review the current checkout changes by default and ask only when there is no reviewable diff.
- Do not start planning or implementation without a concrete task.
- Run Discovery on every task — including small ones. The grill always fires; never skip it because the request "looks trivial" or because the user sounds eager to move on.
- Do not transition from Discover or Research to Plan until `scripts/wannabuild-session.sh assert-discovery-ready .` passes. That gate requires a requirements brief with acceptance criteria; a brief without them does not pass.
- Never declare work skipped, blocked, or untestable without first attempting to acquire the resource (run the app, spin a local/ephemeral DB branch, drive a browser, generate fixtures, read live docs via Context7) and logging the attempt. Stop and ask the user only for billable, outward-facing, or destructive acquisition.
- Do not start implementation until Plan is complete.
- Before implementation edits, run `scripts/wannabuild-session.sh assert-plan-ready .`. If it fails or the runtime cannot execute, return to Plan and do not edit implementation files.
- Do not browse externally when no concrete task exists.
- Do not create an isolated workspace/worktree during Discover, Plan, Review, QA, Summary, or explicitly phase-limited use.
- Work in the current checkout by default.
- Offer or create an isolated worktree only when entering implementation from an approved plan, when the user asks for isolation, or when parallel/risky changes need separation.

## Step Contract

| Step | Operator obligation | Completion signal |
|---|---|---|
| Discover | Grill the user — one question at a time, recommended answer per question, reading the codebase to answer rather than asking whenever it can — for vision, audience, desired feel, core flows, features, constraints, scope, success signals, tradeoffs, and non-goals; then always run feasibility, alternatives/competition, and Failure Forecast (depth proportionate, never zero) plus any goal-relevant adaptive research. | `assert-discovery-ready` passes: discovery artifacts non-empty and `requirements.md` has acceptance criteria. |
| Plan | Produce a concrete plan, run bounded research when needed, verify architecture/direction, and generate N (default 3, configurable) adversarial plan options rendered to a self-contained HTML the user can open before choosing one. | Plan is actionable and internally consistent; the chosen plan is recorded. |
| Implement | Offer or choose an adaptive execution shape; execute with owned slices, checkpoints, and verification. | Planned slices are implemented with evidence. |
| Validate | Run the full reviewer set (security, performance, architecture, testing, simplification, integration), each covering the entire changed surface; fix all actionable findings autonomously. Acquire any resource a check needs before declaring it un-runnable. | `assert-review-ready` passes: every required reviewer returns PASS for the latest iteration. |
| QA | Validate every acceptance criterion and integration behavior by executing real tests against real (acquired) resources — never by asserting they should pass. | `assert-qa-ready` passes: QA markers plus integration execution evidence (tests ran, every criterion covered). |
| Summary | Report changes, passed checks, risks, and remaining work. | Handoff summary is complete and honest. |

## Control Mode Defaults

Default to guided execution. Always run the Discover interview, then pause at every phase boundary (Discover -> Plan -> Implement -> Validate -> QA -> Summary) and require explicit user approval before advancing across each one.

- At each boundary, present what the phase produced, name the next phase, and wait for explicit approval ("go", "proceed", "continue", "approved"). A vague acknowledgment is not approval to advance.
- Choose research, single-owner implementation, parallel implementation, reviewer hats, and validation depth from task evidence.
- Keep user-facing summaries concise.

If the user explicitly asks for autonomous or unattended execution, switch to autonomous mode: plan, implement, validate, QA, and summarize without per-boundary approval, asking only when scope, product direction, destructive actions, credentials, paid/external services, or merge/push strategy require user judgment.

## Parallelization Defaults

- Keep work single-owner when coherence matters more than fan-out.
- The Discover/Plan research bundle (feasibility, alternatives, Failure Forecast) always runs; use bounded multi-agent parallelism for it when the perspectives are genuinely independent.
- Use parallelism for independent discovery perspectives, disjoint implementation slices, or concurrent review hats with distinct risk ownership.
- Let the orchestrator choose the number of agents from task evidence: complexity, coupling, uncertainty, blast radius, and expertise required.
- Do not hard-code agent counts. Stop adding agents when each one no longer has distinct ownership and expected evidence.
- Record delegation rationale in `.wannabuild/decisions.md` or checkpoints.

## Internal Execution Model

Internal phases remain:

```text
Requirements -> Design -> Tasks -> Implement -> Review -> Ship -> Document
```

Public-to-internal mapping:

| Public step | Internal execution |
|---|---|
| Discover | Requirements |
| Plan | Research burst using specialist agents (feasibility/alternatives/forecast always ran in Discover) |
| Plan | Design + Tasks |
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
│   ├── requirements.md
│   ├── design.md
│   └── tasks.md
├── outputs/
│   └── plan/
│       ├── plan-options.json
│       └── adversarial-plans.html
├── checkpoints/
├── review/
├── loop-state.json
└── decisions.md
```

Artifact roles:

- `requirements.md`: vision brief, audience, desired feel, core flows, feature priorities, research synthesis, qualified decisions, scope, assumptions, acceptance criteria, and test scenarios.
- `design.md`: architecture, contracts, risks, and testing direction.
- `tasks.md`: ordered implementation slices with verification expectations.
- `checkpoints/`: execution evidence and resume anchors.
- `review/`: structured reviewer verdicts.
- `outputs/plan/plan-options.json` + `adversarial-plans.html`: the N adversarial plan options (schema `plan-options.schema.json`) and their self-contained HTML render, shown — and best-effort opened — at the Plan boundary.

## Execution and Quality Defaults

- Implement in micro-steps by default.
- Treat checkpoints as canonical execution evidence.
- Run the full reviewer set on every review iteration. Never narrow to "impacted" reviewers and never fast-track or skip review for "tiny, low-risk" changes — only the depth of each reviewer's work scales, not the set.
- Treat the integration tester as the hard completion gate: its FAIL is terminal with no override path, and its PASS is valid only with execution evidence (tests actually ran, every acceptance criterion covered).
- Keep Review and QA as distinct post-implementation stages.
- Block completion on integration tester failure.
- Commit at each completed slice; always commit before ship-oriented packaging.

## Model Defaults

- Choose capability tier and reasoning effort per task, not by hard-coded model name.
- Lightweight/fast capability is appropriate for bounded lookup, formatting, simple validation, and low-risk documentation work.
- Standard capability is appropriate for normal implementation and well-scoped remediation.
- Strong/high-reasoning capability is appropriate for architecture choices, ambiguous requirements, high-risk integrations, complex debugging, and uncertain remediation.
- Host adapters map capability tiers to available models and reasoning controls.
- Use advisor escalation selectively for high-impact uncertainty: architecture choices, material ambiguity, high-risk integrations, uncertain remediation, conflicting specialist outputs, or test strategy risk. The executor remains the single tool-using owner; the advisor provides bounded guidance only and must not call tools, edit files, run commands, or produce user-facing output.

## Repo Surfaces

```text
wannabuild/
├── AGENTS.md
├── adapters/
│   ├── codex/
│   ├── cursor/
│   └── claude-code/
├── .claude-plugin/
├── agents/
├── skills/
├── scripts/
├── docs/
├── README.md
├── tests/
├── .github/
│   ├── CODEOWNERS
│   ├── ISSUE_TEMPLATE/
│   ├── pull_request_template.md
│   ├── dependabot.yml
│   ├── rulesets/
│   └── workflows/
├── .devcontainer/
├── .env.example
├── CHANGELOG.md
└── SECURITY.md
```

Primary surfaces:

- `AGENTS.md`: operator contract
- `skills/`: workflow and phase contracts
- `agents/`: specialist prompts
- `scripts/`: validation and runtime helpers
- `docs/`: onboarding, philosophy, host capability docs
- `adapters/`: host-specific packaging/install surfaces

## Host Positioning

- Codex and Claude Code are co-primary experiences.
- Cursor is the secondary adapter.

Install paths:

- Claude Code: `/plugin install wannabuild@gl11tchy` or `scripts/install-claude-skill.sh`
- Codex: `scripts/install-codex-skill.sh`

For host-specific details:

- [README.md](README.md)
- [docs/codex-getting-started.md](docs/codex-getting-started.md)
- [docs/host-capability-matrix.md](docs/host-capability-matrix.md)

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

Because this is a framework/documentation repository:

- Unit/integration validation mainly occurs in target projects.
- Long-term validation target is repo-native Codex usage first, then Cursor.
- Claude plugin compatibility should be validated separately from core repo-native flow.

## Dependencies

No external runtime dependencies are required for the framework itself. This does not relax Mandate 2 for **target-project** work: when executing a real project, acquire whatever runtime, database, browser, or fixture the task needs (or ask the user for billable/outward acquisition) — never treat a missing resource as license to skip review or QA.
