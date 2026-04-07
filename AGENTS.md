# AGENTS.md

Primary operator contract for WannaBuild.

## Overview

WannaBuild is a spec-driven development framework designed to be used repo-first, with Codex and Claude Code as co-primary experiences and Cursor as a secondary adapter.

The intended user-facing workflow is compact:

1. Discover
2. Control mode gate
3. Research gate
4. Plan
5. Implement gate
6. Review
7. QA
8. Summary

Internally, the framework still uses structured artifacts, specialist prompts, checkpoints, and adaptive review routing. Those internals exist to improve execution quality, not to force the user through an overly ceremonial workflow.

## Public Workflow

```text
Discover -> Control mode -> Research? -> Plan -> Implement -> Review -> QA -> Summary
```

### Step Contract

- `Discover`: clarify goals, constraints, scope, and flavor.
- `Control mode gate`: ask once whether to continue in guided mode or switch to autonomous mode.
- `Research gate`: if uncertainty remains high, ask whether to kick off research agents or move to planning.
- `Plan`: generate the plan and verify architecture and direction.
- `Implement`: offer solo-owner mode or parallel mode, with checkpoints and verification.
- `Review`: run the reviewer hats that add real signal for the change.
- `QA`: validate acceptance criteria and integration behavior.
- `Summary`: report what changed, what passed, and what remains.

If WannaBuild is invoked with no concrete task:

- do not infer intent from git diff or uncommitted changes
- do not start planning or implementation
- do not browse externally
- ask for the actual goal first

If WannaBuild is invoked with a concrete task inside a git repo:

- create an isolated workspace/worktree first
- initialize `.wannabuild` state in that workspace
- continue only inside the isolated workspace
- do not continue in the original checkout

## Parallelization Defaults

- Keep Discover, Plan, QA, and Summary single-lane by default.
- Default to guided mode until the user explicitly opts into autonomous mode after Discover.
- Use bounded multi-agent research only when it materially improves planning quality.
- Use parallelism mainly for disjoint implementation slices and reviewer hats that inspect the same finished work.
- If the work does not split cleanly, stay single-owner.

## Internal Execution Model

WannaBuild still uses 7 internal phases:

```text
Requirements -> Design -> Tasks -> Implement -> Review -> Ship -> Document
```

Public-to-internal mapping:

| Public Step | Internal Execution |
|---|---|
| Discover | Requirements |
| Research gate | Optional research burst using specialist agents |
| Plan | Design + Tasks |
| Implement | Implement after solo/parallel choice |
| Review | Review |
| QA | Integration hard gate + final verification |
| Summary | Ship / Document / handoff synthesis |

## Project Structure

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

Key surfaces:

- `AGENTS.md`: primary Codex/operator contract
- `skills/`: workflow and phase contracts
- `agents/`: specialist prompt files
- `scripts/`: validation and runtime helper scripts
- `docs/`: onboarding, philosophy, and host capability docs
- `adapters/`: host-specific packaging and install surfaces

## Artifact Contract

Target projects use `.wannabuild/` as the workflow state directory:

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

- `requirements.md`: goals, scope, acceptance criteria, test scenarios.
- `design.md`: architecture, contracts, risks, and testing direction.
- `tasks.md`: ordered implementation slices with verification expectations.
- `checkpoints/`: implementation evidence and resume anchors.
- `review/`: structured reviewer verdicts.

## Execution Defaults

- Implementation runs in micro-steps by default.
- Checkpoints are the source of execution evidence for resume and review routing.
- Review uses adaptive reruns rather than full fan-out every iteration.
- The integration tester is the hard gate.
- VCS commits are optional during implementation and expected before ship-oriented packaging.
- Review and QA are distinct stages after implementation, not implementation-time self-checks.

## Quality Loop

- Iteration 1 uses the base reviewer set for the selected mode.
- Later iterations rerun only impacted reviewers plus the integration tester.
- Fast-track review is allowed only for tiny, low-risk changes.
- Integration tester failure blocks completion.

## Model Defaults

- Spec-quality specialists use stronger models.
- Default implementation uses the standard implementer.
- Escalated implementers handle high-complexity work and post-review remediation.

## Host Positioning

- Codex and Claude Code are co-primary experiences.
- Cursor is the secondary adapter.

For Claude Code: marketplace install via `/plugin install wannabuild@gl11tchy` or repo install via `scripts/install-claude-skill.sh`.
For Codex: install via `scripts/install-codex-skill.sh`.

For host-specific details, see:

- [README.md](README.md)
- [docs/codex-getting-started.md](docs/codex-getting-started.md)
- [docs/host-capability-matrix.md](docs/host-capability-matrix.md)

## Validation Notes

Since this is a documentation/framework repository:

- unit and integration validation primarily happen in target projects
- the long-term validation target is repo-native usage in Codex first, then Cursor
- Claude plugin compatibility should be checked separately from the core repo-native path

## Dependencies

No external runtime dependencies are required for the framework itself.
