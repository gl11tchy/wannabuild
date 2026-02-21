# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

WannaBuild is a Spec-Driven Development framework for indie builders, packaged as a Claude Code plugin. It guides developers through 7 phases using 20 specialist AI agents plus an escalated implementer profile for remediation/high-complexity runs. This is a **pure documentation repository** — no build system, no dependencies, no tests. Skills are markdown files (SKILL.md) that define phase orchestration. Agents are markdown files (agents/wb-*.md) with YAML frontmatter that define specialist behavior.

## Repository Structure

```
.claude-plugin/
  plugin.json                          # Plugin manifest (name, version, author)
agents/                                # 21 agent profiles (20 specialists + 1 escalated implementer)
  wb-scope-analyst.md                  # Phase 1: Requirements
  wb-ux-perspective.md                 # Phase 1: Requirements
  wb-tech-advisor.md                   # Phase 2: Design
  wb-architect.md                      # Phase 2: Design
  wb-risk-assessor.md                  # Phase 2: Design
  wb-task-decomposer.md               # Phase 3: Tasks
  wb-dependency-mapper.md              # Phase 3: Tasks
  wb-scope-validator.md                # Phase 3: Tasks
  wb-implementer.md                    # Phase 4: Implement (default)
  wb-implementer-escalated.md          # Phase 4: Implement (retry/high-complexity)
  wb-security-reviewer.md             # Phase 5: Review
  wb-performance-reviewer.md          # Phase 5: Review
  wb-architecture-reviewer.md         # Phase 5: Review
  wb-testing-reviewer.md              # Phase 5: Review
  wb-integration-tester.md            # Phase 5: Review (HARD GATE)
  wb-code-simplifier.md               # Phase 5: Review
  wb-pr-craftsman.md                   # Phase 6: Ship
  wb-ci-guardian.md                    # Phase 6: Ship
  wb-readme-updater.md                # Phase 7: Document
  wb-api-doc-generator.md             # Phase 7: Document
  wb-changelog-writer.md              # Phase 7: Document
skills/
  build/SKILL.md                       # Orchestrator — SDD backbone, agent spawning, quality loop
  requirements/SKILL.md                # Phase 1: 2 agents → .wannabuild/spec/requirements.md
  design/SKILL.md                      # Phase 2: 3 agents → .wannabuild/spec/design.md
  tasks/SKILL.md                       # Phase 3: 3 agents → .wannabuild/spec/tasks.md
  implement/SKILL.md                   # Phase 4: implementer profiles execute micro-steps with integration tests
  review/SKILL.md                      # Phase 5: 6 agents validate against spec (quality loop)
  ship/SKILL.md                        # Phase 6: 2 agents — PR + CI
  document/SKILL.md                    # Phase 7: 3 agents — README, API docs, changelog
docs/philosophy.md                     # Design philosophy and principles
```

When installed as a plugin, skills are prefixed with `wannabuild-`:
- `skills/build/` → `wannabuild-build`
- `skills/requirements/` → `wannabuild-requirements`
- `skills/review/` → `wannabuild-review`
- etc.

## The 7-Phase SDD Flow

```
REQUIREMENTS → DESIGN → TASKS → IMPLEMENT ◄──┐
                                     │         │
                                     ▼         │
                                  REVIEW ──────┘  (loop until active-set unanimous pass)
                                     │
                                     ▼
                                  SHIP → DOCUMENT
```

## Critical Architectural Rules

1. **Specs are the backbone.** Every phase reads from and writes to `.wannabuild/spec/`. Implementation is validated against `spec/requirements.md`. Nothing ships without spec validation.

2. **Role separation is absolute.** The orchestrator NEVER fixes code. Reviewers find issues → feedback goes to implementer-escalated → remediation happens in micro-steps with checkpoints → adaptive reviewers re-run (+ integration tester always). This is the most important invariant in the system.

3. **Quality loop requires unanimous approval.** Iteration 1 runs the base reviewer set for mode (Full=6, Light=3). Retry iterations run impacted reviewers + integration tester (always), and the active reviewer set must unanimously PASS before shipping. Max 3 iterations before escalating to human.

4. **Integration tests are non-negotiable.** The wb-integration-tester agent is a hard gate — its FAIL blocks shipping with no override path. Every acceptance criterion must have a corresponding integration test.

5. **Agents are spawned via Task tool.** The orchestrator (a skill) spawns specialist agents (in `agents/`) via Claude Code's native Task tool. No other spawning mechanism exists.

6. **State lives in `.wannabuild/`** — `state.json` (current phase), `spec/requirements.md`, `spec/design.md`, `spec/tasks.md`, `checkpoints/` (micro-step evidence), `loop-state.json` (review voting history), `decisions.md`.

7. **Phase detection is conversational.** "I wanna build..." → Requirements. "Let's design..." → Design. "Ship it" → Ship. Users can skip or revisit any phase.

## Reference Files

- `skills/build/references/sdd-principles.md` — SDD philosophy, spec artifact formats, integration testing principles
- `skills/build/references/philosophy.md` — Design philosophy reference
- `skills/review/references/security-checklist.md` — Regex patterns for secret detection, OWASP top 10
- `skills/review/references/architecture-patterns.md` — DRY patterns, clean code, refactoring patterns

## Working With This Repo

- **Editing agents:** Each `agents/wb-*.md` file has YAML frontmatter (name, description, tools, model) and a focused system prompt.
- **Editing skills:** Each SKILL.md defines phase orchestration — agent spawning, synthesis, artifact format, handoffs.
- **Adding agents:** Create the agent file in `agents/`, update the phase SKILL.md, update the orchestrator in `skills/build/SKILL.md`, update AGENTS.md.
- **Plugin manifest:** `.claude-plugin/plugin.json` — update version on releases.
- **Validation:** No automated tests. Skills and agents are validated by running them in Claude Code against real projects.
- **Commits:** Use conventional commits (`feat:`, `fix:`, `docs:`).
