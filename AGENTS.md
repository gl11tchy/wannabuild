# AGENTS.md

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
| Discover | Clarify goals, constraints, scope, and flavor. | A crisp problem brief exists. |
| Control mode gate | Ask once whether to stay guided or switch to autonomous. | Mode decision recorded. |
| Research gate | If uncertainty is high, ask whether to run research agents first. | Research decision recorded. |
| Plan | Produce a concrete plan and verify architecture/direction. | Plan is actionable and internally consistent. |
| Implement | Offer solo-owner vs parallel mode; execute with checkpoints and verification. | Planned slices are implemented with evidence. |
| Review | Run reviewer hats that add real signal for this change. | Review verdicts captured with actionable findings. |
| QA | Validate acceptance criteria and integration behavior. | Integration hard gate passes. |
| Summary | Report changes, passed checks, risks, and remaining work. | Handoff summary is complete and honest. |

## Gate Prompts (Default Phrasing)

Use short, explicit questions at gates:

- Control mode: "Continue in guided mode, or switch to autonomous mode?"
- Research gate: "Uncertainty is still high. Run bounded research agents first, or proceed to planning?"
- Implement mode: "Implement in solo-owner mode, or parallel mode for disjoint slices?"

Default to guided mode unless the user explicitly opts into autonomous mode.

## Parallelization Defaults

- Keep Discover, Plan, QA, and Summary single-lane by default.
- Use bounded multi-agent research only when it materially improves planning quality.
- Use parallelism mainly for disjoint implementation slices.
- Use reviewer parallelism for concurrent inspection of the same finished work.
- If work does not split cleanly, stay single-owner.

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

- `requirements.md`: goals, scope, acceptance criteria, and test scenarios.
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

- Spec-quality specialists use stronger models.
- Standard implementation uses the default implementer.
- High-complexity or post-review remediation can escalate to stronger implementers.

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
└── README.md
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

## Validation Notes

Because this is a framework/documentation repository:

- Unit/integration validation mainly occurs in target projects.
- Long-term validation target is repo-native Codex usage first, then Cursor.
- Claude plugin compatibility should be validated separately from core repo-native flow.

## Dependencies

No external runtime dependencies are required for the framework itself.
