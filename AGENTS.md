# AGENTS.md

This document provides essential information for autonomous AI agents working with the WannaBuild framework.

## Overview

WannaBuild is a Spec-Driven Development framework packaged as a Claude Code plugin. It has 20 core specialist agents across 7 phases, plus an escalation implementer profile for remediation/high-complexity runs. The orchestrator is a skill (main conversation context) that spawns specialist agents via Claude Code's native Task tool. Each specialist is a standalone agent file in `agents/`.

## Architecture

```
Orchestrator (skill: wannabuild-build) → spawns agents via Task tool
├── Phase 1: Requirements  → wb-scope-analyst, wb-ux-perspective
├── Phase 2: Design        → wb-tech-advisor, wb-architect, wb-risk-assessor
├── Phase 3: Tasks         → wb-task-decomposer, wb-dependency-mapper, wb-scope-validator
├── Phase 4: Implement     → wb-implementer (default), wb-implementer-escalated (retry/high-complexity)
├── Phase 5: Review        → wb-security-reviewer, wb-performance-reviewer, wb-architecture-reviewer,
│                            wb-testing-reviewer, wb-integration-tester, wb-code-simplifier
├── Phase 6: Ship          → wb-pr-craftsman, wb-ci-guardian
└── Phase 7: Document      → wb-readme-updater, wb-api-doc-generator, wb-changelog-writer
```

## Project Structure

```
wannabuild/
├── .claude-plugin/              # Plugin manifest
│   ├── plugin.json
│   └── marketplace.json
├── scripts/                     # Validation and runtime helper scripts
├── agents/                      # 21 agent profiles (20 specialists + 1 implementer escalation profile)
├── skills/                      # Phase skills (SKILL.md per phase)
│   ├── build/                   # Orchestrator skill
│   │   ├── references/          # SDD principles, philosophy, contracts, routing, transitions
│   │   ├── schemas/             # Contract schemas used by transition validator
│   │   └── dry-runs/            # Edge-case fixture payloads
│   ├── requirements/            # Phase 1: Requirements (2 agents)
│   ├── design/                  # Phase 2: Design (3 agents)
│   ├── tasks/                   # Phase 3: Tasks (3 agents)
│   ├── implement/               # Phase 4: Implement (1 agent)
│   ├── review/                  # Phase 5: Review (6 agents)
│   │   └── references/          # Security checklist, architecture patterns
│   ├── ship/                    # Phase 6: Ship (2 agents)
│   └── document/                # Phase 7: Document (3 agents)
├── docs/
│   └── philosophy.md
├── README.md
└── CONTRIBUTING.md
```

When installed as a plugin, skill directories are prefixed with `wannabuild-`:
- `skills/build/` → installed as `wannabuild-build`
- `skills/requirements/` → installed as `wannabuild-requirements`
- `skills/review/` → installed as `wannabuild-review`

## Spec Artifacts

All phases read from and write to `.wannabuild/spec/` in the target project:

```
.wannabuild/
├── state.json            # Current phase, mode, timestamps
├── spec/
│   ├── requirements.md   # User stories, acceptance criteria, test scenarios
│   ├── design.md         # Architecture, tech stack, data models, testing strategy
│   └── tasks.md          # Ordered tasks with deps, acceptance criteria, required tests
├── outputs/               # Agent file-first outputs
├── checkpoints/           # Micro-step evidence
├── review/                # Reviewer verdict JSON
├── loop-state.json       # Review voting history
└── decisions.md          # Architecture decision log
```

## Development Workflow

### Starting a New Feature

1. **Requirements Phase** — Use `wannabuild-requirements` skill
   - Spawns wb-scope-analyst + wb-ux-perspective in parallel
   - Produces `spec/requirements.md` with user stories and test scenarios

2. **Design Phase** — Use `wannabuild-design` skill
   - Spawns wb-tech-advisor + wb-architect + wb-risk-assessor in parallel
   - Produces `spec/design.md` with architecture and testing strategy

3. **Tasks Phase** — Use `wannabuild-tasks` skill
   - Spawns wb-task-decomposer first, then wb-dependency-mapper + wb-scope-validator in parallel
   - Produces `spec/tasks.md` with ordered, testable tasks

4. **Implement Phase** — Use `wannabuild-implement` skill
   - Spawns wb-implementer in foreground by default
   - Uses wb-implementer-escalated for high-complexity or review-loop remediation
   - Writes code + integration tests through micro-step checkpoints + verification loops

5. **Review Phase** — Use `wannabuild-review` skill
   - Iteration 1 spawns the base reviewer set for mode (Full=6, Light=3)
   - Retry iterations use adaptive reruns (impacted reviewers + integration tester)
   - Quality loop continues until unanimous PASS from the active reviewer set
   - Integration tester is a hard gate (no override for missing tests)

6. **Ship Phase** — Use `wannabuild-ship` skill
   - Spawns wb-pr-craftsman then wb-ci-guardian sequentially
   - Creates PR referencing spec artifacts

7. **Document Phase** — Use `wannabuild-document` skill
   - Spawns 3 doc agents in parallel
   - Updates README, API docs, changelog

### Skill Activation

| User Says | Phase | Skill |
|-----------|-------|-------|
| "I wanna build..." | Requirements | wannabuild-requirements |
| "Let's design..." | Design | wannabuild-design |
| "Break into tasks..." | Tasks | wannabuild-tasks |
| "Let's build..." | Implement | wannabuild-implement |
| "Review this..." | Review | wannabuild-review |
| "Ship it..." | Ship | wannabuild-ship |
| "Update docs..." | Document | wannabuild-document |

### Quality Loop

- Iteration 1 runs the full base reviewer set (Full=6, Light=3)
- Iteration 2+ runs adaptive reviewer reruns (impacted reviewers + integration tester)
- Each reviewer returns PASS or FAIL with structured JSON verdict
- If ANY fails, aggregated feedback goes to `wb-implementer-escalated`
- Loop continues until unanimous approval from the active reviewer set
- Max 3 iterations before escalation
- Guardrails should pause-and-ask when run/context limits are reached (no silent fan-out)
- **Fast-Track Decision Matrix (optional):**
- Eligible only when all conditions are true:
  - `files_changed <= 2`
  - `estimated_scope` is `tiny`
  - `risk_label` is `low`
  - no `db` migration, auth/session, secret-handling, or payment/financial changes
- Reviewer set for Iteration 1: `wb-integration-tester` plus at most 2 high-confidence impacted reviewers
- Integration hard gate is always included and unchanged
- If **any** reviewer fails, impact confidence is uncertain, or gating signals conflict, next iteration switches to the full base reviewer set for that mode
- **Integration tester FAIL blocks shipping — no override path**

### Execution Defaults

- Implementation runs in micro-steps by default (one tiny step, verify, checkpoint, continue).
- `.wannabuild/checkpoints/` is the source of execution evidence for resume and review routing.
- VCS commits are optional during implementation; they are packaging concerns handled in ship workflows.

### Model Tiering Defaults

- **Spec quality first:** Requirements, Design, and Tasks specialists are pinned to `opus`.
- **Default implementation:** `wb-implementer` inherits the parent session model (recommended target in OpenClaw: Codex 5.3 spark).
- **Escalation path:** `wb-implementer-escalated` inherits the parent model (recommended parent: Codex 5.3 or Opus).
- **Escalation trigger:** use escalated implementer after the first failed review iteration, or immediately for high-complexity work.

## Agent File Format

Each agent in `agents/` follows this format:

```yaml
---
name: wb-agent-name
description: "What this agent does"
tools: Read, Grep, Glob       # Tools the agent can use
model: sonnet                  # Optional: omit to inherit parent model
---

[System prompt markdown body]
```

## Adding New Agents

1. Create `agents/wb-{name}.md` with YAML frontmatter
2. Add the agent to the relevant phase skill's agent table
3. Update the orchestrator's agent table in `skills/build/SKILL.md`
4. Update this AGENTS.md file

## Testing Framework Changes

Since this is a documentation/framework repository:
- Unit tests are expected in target projects and are required where applicable by integration-gate checks.
- No build commands are required inside this repository; skills and agents are validated by running them in Claude Code against real projects.
- Skills and agents are validated by running them in Claude Code against real projects.

## VCS Notes

During implementation, checkpoint files are the required evidence. Conventional commits (`feat:`, `fix:`, `docs:`, `refactor:`) are optional during active implementation, but code must be committed before ship/PR creation.

## Dependencies

No external dependencies — pure markdown documentation repository.
