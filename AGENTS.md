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

## Purpose

WannaBuild is a repo-first, spec-driven development framework with a compact user-facing loop and rigorous internal execution. Codex and Claude Code are co-primary experiences; Cursor is a secondary adapter.

The framework should feel lightweight to the user while still enforcing real planning, verification, and QA gates.

## Golden Path

```text
Discover -> Control mode -> Research? -> Plan -> Implement -> Review -> QA -> Summary
```

## Non-Negotiables

- If there is no concrete task, ask for the actual goal first.
- Do not infer intent from git diff or uncommitted changes.
- Do not start planning or implementation without a concrete task.
- Do not browse externally when no concrete task exists.
- For concrete tasks in a git repo, create an isolated workspace/worktree first.
- Initialize `.wannabuild` state in that isolated workspace before continuing.
- Continue only inside the isolated workspace, never the original checkout.

## Step Contract

| Step | Operator obligation | Completion signal |
|---|---|---|
| Discover | Interview for vision, audience, desired feel, core flows, features, constraints, scope, and success signals. | A crisp problem brief and synthesized requirements direction exists. |
| Control mode gate | Ask once whether to stay guided or switch to autonomous. | Mode decision recorded. |
| Research gate | If uncertainty is high, ask whether to run research agents first. | Research decision recorded. |
| Plan | Produce a concrete plan and verify architecture/direction. | Plan is actionable and internally consistent. |
| Implement | Offer or choose an adaptive execution shape; execute with owned slices, checkpoints, and verification. | Planned slices are implemented with evidence. |
| Review | Run reviewer hats that add real signal for this change. | Review verdicts captured with actionable findings. |
| QA | Validate acceptance criteria and integration behavior. | Integration hard gate passes. |
| Summary | Report changes, passed checks, risks, and remaining work. | Handoff summary is complete and honest. |

## Gate Prompts (Default Phrasing)

Use short, explicit questions at gates:

- Control mode: "Continue in guided mode, or switch to autonomous mode?"
- Research gate: "Uncertainty is still high. Run bounded research agents first, or proceed to planning?"
- Implement mode: "Use single-owner implementation, or adaptive parallel implementation for disjoint slices?"

Default to guided mode unless the user explicitly opts into autonomous mode.

## Parallelization Defaults

- Keep work single-owner when coherence matters more than fan-out.
- Use bounded multi-agent research only when it materially improves planning quality.
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
| Research gate | Optional research burst using specialist agents |
| Plan | Design + Tasks |
| Implement | Implement after solo/parallel choice |
| Review | Review |
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
├── checkpoints/
├── review/
├── loop-state.json
└── decisions.md
```

Artifact roles:

- `requirements.md`: vision brief, audience, desired feel, core flows, feature priorities, scope, assumptions, acceptance criteria, and test scenarios.
- `design.md`: architecture, contracts, risks, and testing direction.
- `tasks.md`: ordered implementation slices with verification expectations.
- `checkpoints/`: execution evidence and resume anchors.
- `review/`: structured reviewer verdicts.

## Execution and Quality Defaults

- Implement in micro-steps by default.
- Treat checkpoints as canonical execution evidence.
- Keep review adaptive: rerun impacted reviewers rather than full fan-out every iteration.
- Treat the integration tester as the hard completion gate.
- Keep Review and QA as distinct post-implementation stages.
- Allow fast-track review only for tiny, low-risk changes.
- Block completion on integration tester failure.
- Expect commits before ship-oriented packaging; during implementation, commit cadence is optional.

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

No external runtime dependencies are required for the framework itself.
