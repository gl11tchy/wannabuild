# WannaBuild — Project State

## Current Shape

WannaBuild is a repo-native framework for spec-driven AI development. The repo is being aligned around a condensed public workflow:

1. Discover
2. Control mode gate
3. Optional research gate
4. Plan
5. Implement
6. Review
7. QA
8. Summary

Internally, the framework still uses 7 execution phases, structured prompts, and `.wannabuild/` artifacts.

## Positioning

- Co-primary: Codex repo-first usage
- Co-primary: Claude Code usage
- Secondary: Cursor adapter usage

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
- Codex + Claude Code onboarding and host capability docs exist.
- Cursor now has a repo-local rules surface.
- Claude packaging remains present and aligned with the co-primary contract.

## Remaining Structural Work

- `skills/build/SKILL.md` is still larger than ideal for a thin orchestrator spec.
- Several reference/dry-run files still require periodic alignment when contracts evolve.
- The next simplification step is structural extraction, not more copy cleanup.

## Last Updated

2026-04-07
