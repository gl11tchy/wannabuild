# Spec-Driven Development (SDD) Principles

## Core Philosophy

Spec-Driven Development means **every line of code traces back to a specification**. Specs aren't documentation written after the fact — they're the source of truth that drives implementation and validates results.

## The SDD Pipeline

```
Requirements → Design → Tasks → Implement → Review → Ship → Document
     ↑            ↑        ↑         ↑          ↑
     └────────────┴────────┴──────────┴──────────┘
              Specs are the backbone
```

Every phase reads from specs. Every phase writes to specs. Nothing happens outside the spec chain.

## Three Spec Artifacts

### 1. Requirements Spec (`spec/requirements.md`)
**What** to build. Written in user language.
- User stories with acceptance criteria
- Integration test scenarios for every story
- Explicit scope boundaries (in/out)
- Success metrics

### 2. Design Spec (`spec/design.md`)
**How** to build it. Written in technical language.
- Architecture decisions with rationale
- Tech stack choices with trade-off analysis
- Data models and API contracts
- Testing strategy (framework, boundaries, mocks)
- Risk register with mitigations

### 3. Task Spec (`spec/tasks.md`)
**Do** — the ordered work. Written as atomic units.
- Each task targets specific files
- Dependencies explicitly mapped
- Every task includes required integration tests
- Complexity sized (S/M/L)
- Critical path identified

## SDD Rules

### 1. Specs Before Code
No implementation begins until requirements, design, and tasks are specified. The implementer works from `spec/tasks.md`, not from memory or conversation.

### 2. Tests Prove Specs
Integration tests are the executable form of acceptance criteria. A feature without tests is an unverified claim. Tests are non-negotiable — they're the bridge between "what we said" and "what we built."

### 3. Review Against Specs
Code review isn't subjective opinion. Reviewers validate code against `spec/requirements.md` — did we build what we specified? Did we test what we claimed? The integration-tester agent is a hard gate: no tests = no ship.

### 4. Specs Evolve
Specs aren't frozen. Discovery during implementation may reveal new requirements or design changes. When this happens, update the spec first, then the code. The spec always reflects current intent.

### 5. Minimal Viable Spec
Specs should be as detailed as needed and no more. For a weekend project, a requirements spec might be 20 lines. For a complex feature, it might be 200. The goal is clarity, not ceremony.

## Integration Testing Philosophy

### Why Integration Tests Are Non-Negotiable

Unit tests verify components in isolation. Integration tests verify that **the thing you built actually works as a whole**. For indie hackers shipping real products, integration tests catch the bugs that matter:
- API endpoints that return wrong data
- Auth flows that break on edge cases
- Database queries that work in isolation but fail with real data
- UI flows that break when components interact

### What Good Integration Tests Look Like

- **Meaningful scenarios:** Test real user workflows, not implementation details
- **Edge cases covered:** Error paths, boundary conditions, empty states
- **Isolated:** No shared mutable state between tests, no flaky dependencies
- **Fast enough to run always:** If tests are too slow, the team stops running them
- **Readable as documentation:** A test should explain what behavior it verifies

### The Test Pyramid for Indie Hackers

```
         ╱ E2E ╲          ← Few, critical paths only
        ╱────────╲
       ╱Integration╲      ← Most tests live here
      ╱──────────────╲
     ╱   Unit Tests    ╲  ← Pure logic, utilities
    ╱────────────────────╲
```

Integration tests are the sweet spot: they catch real bugs without the brittleness of E2E tests or the blindness of unit tests.

## Spec Artifact Formats

### requirements.md
```markdown
# Requirements Spec
## User Stories
- As a [user], I want [feature], so that [value]
## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
## Scope
### In Scope
### Out of Scope
## Integration Test Scenarios
### [Story Name]
- **Happy path:** [expected flow and assertion]
- **Error path:** [failure mode and expected behavior]
- **Edge cases:** [boundary conditions]
## Success Metrics
```

### design.md
```markdown
# Design Spec
## Architecture
## Tech Stack Decisions
| Decision | Choice | Rationale |
## Data Models
## API Contracts
## Testing Strategy
### Test Framework
### Integration Boundaries
| Boundary | Components | Mock Strategy |
### Test Data Strategy
### CI Pipeline Requirements
## Risks
| Risk | Probability | Impact | Mitigation |
## Constraints
```

### tasks.md
```markdown
# Task Spec
## Tasks
### Task 1: [title]
- **Status:** pending | in-progress | complete
- **Files:** [target files]
- **Dependencies:** [task numbers]
- **Acceptance:** [how to verify]
- **Integration Test:** [required test(s) — what scenarios to cover]
- **Complexity:** S/M/L
## Critical Path
## Parallelization Opportunities
```

## SDD for Indie Hackers

SDD isn't enterprise bureaucracy dressed up for solo developers. It's the recognition that **writing down what you're building before you build it** saves more time than it costs. The specs don't need to be perfect — they need to exist.

The key insight: when you're working with AI agents, specs become even more critical. An AI agent with a clear spec produces focused, verifiable work. An AI agent without a spec produces plausible-looking code that may or may not solve your actual problem.
