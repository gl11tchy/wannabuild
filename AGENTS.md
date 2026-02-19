# AGENTS.md

This document provides essential information for autonomous AI agents working with the WannaBuild framework.

## Overview

WannaBuild is a Spec-Driven Development framework packaged as a Claude Code plugin. It has 20 specialist AI agents across 7 phases. The orchestrator is a skill (main conversation context) that spawns specialist agents via Claude Code's native Task tool. Each specialist is a standalone agent file in `agents/`.

## Architecture

```
Orchestrator (skill: wannabuild-build) → spawns agents via Task tool
├── Phase 1: Requirements  → wb-scope-analyst, wb-ux-perspective
├── Phase 2: Design        → wb-tech-advisor, wb-architect, wb-risk-assessor
├── Phase 3: Tasks         → wb-task-decomposer, wb-dependency-mapper, wb-scope-validator
├── Phase 4: Implement     → wb-implementer
├── Phase 5: Review        → wb-security-reviewer, wb-performance-reviewer, wb-architecture-reviewer,
│                            wb-testing-reviewer, wb-integration-tester, wb-code-simplifier
├── Phase 6: Ship          → wb-pr-craftsman, wb-ci-guardian
└── Phase 7: Document      → wb-readme-updater, wb-api-doc-generator, wb-changelog-writer
```

## Project Structure

```
wannabuild/
├── .claude-plugin/              # Plugin manifest
│   └── plugin.json
├── agents/                      # 20 specialist agent files (wb-*.md)
├── skills/                      # Phase skills (SKILL.md per phase)
│   ├── build/                   # Orchestrator skill
│   │   └── references/          # SDD principles, philosophy
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
├── state.json            # Current phase, timestamps
├── spec/
│   ├── requirements.md   # User stories, acceptance criteria, test scenarios
│   ├── design.md         # Architecture, tech stack, data models, testing strategy
│   └── tasks.md          # Ordered tasks with deps, acceptance criteria, required tests
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
   - Spawns wb-implementer in foreground
   - Writes code + integration tests, commits atomically

5. **Review Phase** — Use `wannabuild-review` skill
   - Spawns all 6 reviewers in parallel
   - Quality loop: iterate until unanimous 6/6 PASS
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

- 6 specialist agents run in parallel
- Each returns PASS or FAIL with structured JSON verdict
- If ANY fails, aggregated feedback goes back to implementer
- Loop continues until UNANIMOUS APPROVAL (6/6)
- Max 3 iterations before escalation
- **Integration tester FAIL blocks shipping — no override path**

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
- No unit tests required
- No build commands needed
- Skills and agents are validated by running them in Claude Code against real projects

## Committing Changes

Use conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`.

## Dependencies

No external dependencies — pure markdown documentation repository.
