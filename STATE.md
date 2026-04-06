# WannaBuild — Project State

## Current Shape

WannaBuild is a repo-native framework for spec-driven AI development. The repo is being aligned around a condensed public workflow:

1. Discover
2. Plan
3. Implement
4. Review
5. QA
6. Summary

Internally, the framework still uses 7 execution phases, structured prompts, and `.wannabuild/` artifacts.

## Positioning

- Primary: Codex repo-first usage
- Secondary: Cursor adapter usage
- Compatibility: Claude Code plugin packaging

## Core Files

- `AGENTS.md` — primary operator contract
- `README.md` — public overview and usage
- `skills/build/SKILL.md` — orchestrator contract
- `scripts/validate-wannabuild-artifacts.sh` — artifact validation
- `scripts/wannabuild-doctor.sh` — repo readiness check
- `.cursor/rules/wannabuild.mdc` — Cursor-ready rule surface

## Artifact Model

Target project state is stored under `.wannabuild/`:

- `state.json`
- `spec/requirements.md`
- `spec/design.md`
- `spec/tasks.md`
- `loop-state.json`
- `checkpoints/`
- `review/`
- `outputs/`
- `decisions.md`

## Readiness Notes

- Top-level docs have been tightened around the condensed workflow.
- Codex-first onboarding and host capability docs exist.
- Cursor now has a repo-local rules surface.
- Claude packaging remains present but is no longer the architectural center.

## Remaining Structural Work

- `skills/build/SKILL.md` is still larger than ideal for a thin orchestrator spec.
- Several phase skill files still reflect older, heavier wording.
- The next simplification step is structural extraction, not more copy cleanup.

## Last Updated

2026-04-05
