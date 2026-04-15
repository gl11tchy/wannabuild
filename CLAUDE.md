# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

WannaBuild is a **documentation and framework repository** — there is no application to build or run. The deliverables are prompt files, schema files, shell scripts, and markdown contracts. Runtime verification happens in target projects, not here.

## Commands

**Check repo readiness** (verifies all required surfaces exist and install symlinks are wired):
```bash
scripts/wannabuild-doctor.sh
```

**Validate `.wannabuild/` artifacts in a target project** (run before phase transitions):
```bash
scripts/validate-wannabuild-artifacts.sh <target_project_root> [target_phase]
# target_phase: requirements | design | tasks | implement | review | ship | document
# Exit 0 = valid, non-zero = contract violation
```

**Install into Codex** (symlinks `skills/wannabuild` and `skills/using-wannabuild` into `~/.codex/skills/`):
```bash
scripts/install-codex-skill.sh
```

**Install into Claude Code** (wires the plugin under `~/.claude/plugins/`):
```bash
scripts/install-claude-skill.sh
```

## Architecture

### Workflow model

Public (user-facing): `Discover → Control Mode Gate → Research Gate → Plan → Implement Gate → Implement → Review → QA → Summary`

Internal (7 execution phases): `Requirements → Design → Tasks → Implement → Review → Ship → Document`

Every file in the repo is organized around this mapping. Public steps map to one or more internal phases — Plan = Design + Tasks, QA = integration hard gate + verification, Summary = Ship + Document. The public model is what users see; the internal model is what the orchestrator executes.

### Layer model

The repo has three layers:

1. **Operator contract** — `AGENTS.md` is the canonical source of truth for what the orchestrator must do. It defines the golden path, step contracts, gate prompts, parallelization defaults, and model tiering. Read this first when understanding any behavior.

2. **Orchestrator spec** — `skills/build/SKILL.md` is the execution contract: start banners, phase routing logic, the quality loop, advisor escalation as a stateful primitive, state management rules, pre-flight validation, and transition guardrails. It is deliberately the largest file. Changes here ripple everywhere.

3. **Specialist agents** — `agents/wb-*.md` files each contain YAML frontmatter (name, description, model, tools) and a focused system prompt. They write full output to `.wannabuild/outputs/` or `.wannabuild/review/` and return a single status line to the orchestrator. The 21 agents map to 7 internal phases.

### Reference documents and schemas

`skills/build/references/` holds bounded reference files that the orchestrator consults before spawning phase agents:

| File | Governs |
|---|---|
| `artifact-contracts.md` | Required fields for every `.wannabuild/` JSON artifact |
| `advisor-escalation.md` | Trigger matrix, invocation contract, report schema |
| `review-routing.md` | How impacted reviewers are selected for iterations 2+ |
| `loop-state.md` | Loop state schema and terminal status semantics |
| `exit-conditions.md` | Phase transition and escalation conditions |
| `sdd-principles.md` | Spec-driven development philosophy and artifact formats |
| `transition-shim.md` | Shim check logic before phase transitions |
| `dry-run-checks.md` | Validation behavior for dry-run fixture testing |

`skills/build/schemas/` contains JSON schemas (`state.schema.json`, `loop-state.schema.json`, `review-verdict.schema.json`, `checkpoint.schema.json`, `config.schema.json`, `workspace.schema.json`) consumed by `scripts/validate-wannabuild-artifacts.sh`.

### Host adapters

The same core contracts are surfaced three ways:

| Host | Entry point | Install |
|---|---|---|
| Claude Code (co-primary) | `/wannabuild` slash command | `scripts/install-claude-skill.sh` or marketplace |
| Codex (co-primary) | `$wannabuild` | `scripts/install-codex-skill.sh` |
| Cursor (secondary) | `.cursor/rules/wannabuild.mdc` | Manual |

Adapter-specific packaging lives under `.claude-plugin/`, `.cursor-plugin/`, and `adapters/`. If a behavior only works via adapter packaging, it is not part of the core architecture.

### Dry-run fixtures

`skills/build/dry-runs/` holds JSON fixtures used to validate orchestrator behavior against known states (ambiguous review loop, resume-from-state, missing design state). These are reference fixtures, not executable tests.

## Key Invariants for Editing

- **`state.json` is always merge-updated, never replaced wholesale.** Each phase writes only its own fields; all other fields are preserved. The validator enforces this.
- **The orchestrator never fixes code.** It routes, aggregates feedback, and manages state. Implementers fix; orchestrators route.
- **`wb-integration-tester` is the hard gate.** Its FAIL cannot be overridden at escalation. Do not add an override path.
- **Advisor is read-only.** The advisor droid/subagent may not call tools, edit files, run commands, or produce user-facing output. This must remain model-agnostic (no Claude-only dependency in the core contract).
- **Co-primary positioning is non-negotiable.** Codex and Claude Code have equal standing. Do not subordinate either.

## Editing Guidance

- Prefer tightening existing contracts over adding new layers or files.
- When a contract changes, update `AGENTS.md`, the relevant `skills/*/SKILL.md`, the matching reference file in `skills/build/references/`, and the schema/validator if artifact shape changes — in that order.
- Claude-specific packaging (`.claude-plugin/`) may reference Claude-specific tooling; the core `AGENTS.md` and `skills/` must not.
