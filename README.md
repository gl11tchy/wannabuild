<div align="center">

# ⚡ WannaBuild

Spec-Driven Development for indie builders. 20 specialist AI agents. 7 phases. Zero ceremony.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)
![Agents](https://img.shields.io/badge/specialists-20-blueviolet?style=flat-square)
![Phases](https://img.shields.io/badge/phases-7-blue?style=flat-square)
![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-orange?style=flat-square)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)

</div>

```
/plugin marketplace add gl11tchy/wannabuild
/plugin install wannabuild@gl11tchy
```

<div align="center">

[How it works](#how-it-works) · [The agents](#the-20-agents) · [Quality loop](#the-quality-loop) · [Usage](#usage)

</div>

---

## The problem with AI-assisted dev

You describe a feature. The AI writes something. It works... kind of. Edge cases get missed. Tests are an afterthought. Docs never happen. You ship anyway.

Two weeks later you're debugging something that should have been caught in design.

**WannaBuild fixes this** by treating specs as the backbone of everything. Requirements drive design. Design drives tasks. Tasks drive implementation. Implementation is validated against the original requirements — by 6 specialist reviewers — before a single line ships.

Talk like a human, build like a professional.

---

## How It Works

```
  REQUIREMENTS          DESIGN            TASKS
  ─────────────        ────────          ────────
  2 agents run    →   3 agents run   →   3 agents run
  in parallel         in parallel        (sequentially
                                         + parallel)
       │
       ▼ .wannabuild/spec/requirements.md
                  │
                  ▼ .wannabuild/spec/design.md
                             │
                             ▼ .wannabuild/spec/tasks.md
                                        │
                                        ▼

                           IMPLEMENT
                           ─────────
                           1 agent, full tool access
                           writes code + integration tests
                                        │
                      ┌─────────────────┘
                      ▼
                   REVIEW ◄──────────────────────┐
                   ──────                         │
                   6 specialists in parallel      │
                   validate against spec          │
                        │                         │
                     6/6 PASS? ─── NO ────────────┘
                        │                 (feedback → implement)
                     YES
                        │
                        ▼
              SHIP           DOCUMENT
              ─────           ────────
              PR + CI         3 agents run in parallel
              2 agents        README · API docs · changelog
```

Every spec artifact lives in `.wannabuild/spec/` and is the source of truth for every phase that follows.

---

## The 20 Agents

Organized by phase. Every agent is a focused specialist — no generalists allowed.

| Phase | Agent | Role |
|-------|-------|------|
| **Requirements** | `wb-scope-analyst` | MVP boundaries, scope risks, codebase analysis |
| | `wb-ux-perspective` | User journeys, stories, integration test scenarios |
| **Design** | `wb-tech-advisor` | Stack evaluation, tradeoff analysis |
| | `wb-architect` | Architecture, data models, API contracts, test strategy |
| | `wb-risk-assessor` | Risk register with mitigations |
| **Tasks** | `wb-task-decomposer` | Atomic task decomposition from design spec |
| | `wb-dependency-mapper` | Dependency graphs, critical path analysis |
| | `wb-scope-validator` | Validates 100% of requirements have task coverage |
| **Implement** | `wb-implementer` | Executes tasks, writes code + integration tests |
| **Review** | `wb-security-reviewer` | OWASP top 10, secret detection, auth flows |
| | `wb-performance-reviewer` | N+1 queries, memory leaks, scale issues |
| | `wb-architecture-reviewer` | Design compliance, separation of concerns |
| | `wb-testing-reviewer` | Test quality, coverage, edge case coverage |
| | `wb-integration-tester` | **HARD GATE** — acceptance criteria → test mapping |
| | `wb-code-simplifier` | DRY violations, complexity, dead code |
| **Ship** | `wb-pr-craftsman` | PR creation with spec references |
| | `wb-ci-guardian` | CI monitoring, integration test verification |
| **Document** | `wb-readme-updater` | README updates from spec artifacts |
| | `wb-api-doc-generator` | API documentation from code + design spec |
| | `wb-changelog-writer` | Keep a Changelog format, accurate history |

---

## The Quality Loop

The review phase isn't a checkbox. It's a loop.

```
6 specialists run in parallel — each votes PASS or FAIL

  wb-security-reviewer    ─┐
  wb-performance-reviewer  │
  wb-architecture-reviewer ├──► aggregate results
  wb-testing-reviewer      │
  wb-integration-tester   ─┤      6/6 PASS?
  wb-code-simplifier      ─┘         │
                                   YES → proceed to Ship
                                    NO → consolidated feedback
                                         back to Implement
                                         (max 3 iterations,
                                          then escalate to human)
```

**The hard gate:** `wb-integration-tester` checks that every acceptance criterion from the requirements spec has a corresponding, passing integration test. This is the only unoverridable gate in the system. No tests → no ship. Full stop.

---

## Installation

### As a Claude Code Plugin *(recommended)*

```
/plugin marketplace add gl11tchy/wannabuild
/plugin install         wannabuild@gl11tchy
```

All 8 skills and 20 agents are immediately available across every project.

### Manual

```bash
git clone https://github.com/gl11tchy/wannabuild.git
cp -r wannabuild/skills/* your-project/.claude/skills/
cp -r wannabuild/agents/* your-project/agents/
```

---

## Usage

### Start with natural language

```
I wanna build a user authentication system with OAuth and magic links
```

WannaBuild detects intent, starts at Requirements, and walks through every phase.

### Or jump to any phase

```
Let's design the auth system — requirements are done
```
```
Review the code in src/auth/
```
```
Ship it — all tests are passing
```

### Slash commands

Once installed as a plugin, these are available everywhere:

| Command | Phase |
|---------|-------|
| `/wannabuild:build` | Start full pipeline |
| `/wannabuild:requirements` | Phase 1 — requirements spec |
| `/wannabuild:design` | Phase 2 — architecture spec |
| `/wannabuild:tasks` | Phase 3 — task breakdown |
| `/wannabuild:implement` | Phase 4 — write the code |
| `/wannabuild:review` | Phase 5 — 6-specialist review |
| `/wannabuild:ship` | Phase 6 — PR + CI |
| `/wannabuild:document` | Phase 7 — README, API docs, changelog |

### Skip phases freely

Not every change needs all 7 phases. Quick bug fix? Jump to Implement. Docs-only? Skip Review. WannaBuild meets you where you are.

---

## Spec Artifacts

WannaBuild creates structured specs in `.wannabuild/spec/` — the source of truth for everything.

| File | Created by | Contents |
|------|-----------|----------|
| `requirements.md` | Requirements | User stories, acceptance criteria, test scenarios, scope boundaries |
| `design.md` | Design | Architecture, tech stack, data models, API contracts, test strategy |
| `tasks.md` | Tasks | Ordered atomic tasks with deps, acceptance criteria, required integration tests |

Plus state files: `state.json`, `loop-state.json`, `decisions.md`.

---

## Philosophy

**Specs are the backbone.** Every line of code traces back to a requirement. Reviewers validate against specs, not intuition. Nothing ships without spec coverage.

**Conversation over commands.** No syntax to memorize. Talk like a human, get professional-grade output.

**Specialists over generalists.** A security reviewer who only does security. An architect who only thinks about architecture. Deep expertise beats broad capability.

**Integration tests are non-negotiable.** Tests flow through every phase — from user stories with test scenarios, through tasks with test requirements, to an integration tester that hard-gates shipping.

**Quality loops, not quality gates.** Code doesn't get checked once and shipped. It gets iterated until 6 specialists unanimously vote PASS.

**Built for indie builders.** Not enterprise methodology shrunk down. Built ground-up for solo devs and small teams who need to ship fast *and* ship right.

---

## What Makes WannaBuild Different

| | Traditional AI Coding | WannaBuild |
|--|----------------------|------------|
| **Backbone** | Vibes | Spec-driven development |
| **Entry point** | Commands & templates | Natural conversation |
| **Review** | 1-2 passes, ship it | 6 specialists, loop until 6/6 PASS |
| **Testing** | Afterthought | Integration tests are a hard gate |
| **Docs** | Never written | Auto-generated from spec artifacts |
| **Install** | Manual setup | One command, works everywhere |
| **Built for** | Enterprise teams | Indie builders & small teams |

---

## Contributing

Issues, PRs, and new agent ideas are welcome.

1. Fork → branch (`git checkout -b feat/your-idea`)
2. Edit agents in `agents/`, skills in `skills/`
3. Validate by running against a real project in Claude Code
4. PR with conventional commit message (`feat:`, `fix:`, `docs:`)

---

<div align="center">

**What do you wanna build?**

```bash
claude plugin install gh:gl11tchy/wannabuild
```

[Issues](https://github.com/gl11tchy/wannabuild/issues) · [Discussions](https://github.com/gl11tchy/wannabuild/discussions) · [MIT License](LICENSE)

</div>
