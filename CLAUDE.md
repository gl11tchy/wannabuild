# CLAUDE.md

This file provides Claude Code guidance for this repository.

## Positioning

WannaBuild is now a repo-native framework first:

- Codex and Claude Code are co-primary experiences
- Cursor is the secondary adapter

Do not treat the Claude plugin surface as the architecture. Treat it as one adapter on top of the shared repo contracts.

## Product Model

The intended user-facing workflow is:

1. Discover
2. Plan
3. Implement
4. Review
5. QA
6. Summary

Internally, WannaBuild still uses 7 execution phases:

```text
Requirements -> Design -> Tasks -> Implement -> Review -> Ship -> Document
```

Public-to-internal mapping:

- Discover -> Requirements
- Plan -> Design + Tasks
- Implement -> Implement
- Review -> Review
- QA -> Integration hard gate + final verification
- Summary -> Ship / Document / handoff synthesis

## Core Surfaces

- [AGENTS.md](AGENTS.md): primary operator contract
- [README.md](README.md): product overview and quickstart
- [skills/build/SKILL.md](skills/build/SKILL.md): top-level orchestrator contract
- [scripts/validate-wannabuild-artifacts.sh](scripts/validate-wannabuild-artifacts.sh): artifact validator
- [scripts/wannabuild-doctor.sh](scripts/wannabuild-doctor.sh): repo readiness check

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

## Critical Rules

1. Specs remain the source of truth.
2. Integration testing remains the hard gate.
3. Parallelism is selective, not default.
4. Discover, Plan, QA, and Summary are usually single-lane.
5. Implementation and Review are the main places where fan-out helps.

## Repository Notes

- This is a documentation/framework repository.
- Runtime verification primarily happens in target projects.
- Claude-specific packaging lives under `.claude-plugin/`.
- Cursor-ready repo guidance lives in `.cursor/rules/`.

## Editing Guidance

- Prefer tightening contracts and docs over adding more layers.
- Keep co-primary positioning (Codex and Claude Code) intact.
- Do not subordinate either Codex or Claude Code to the other.
