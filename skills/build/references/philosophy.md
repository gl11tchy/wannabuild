# WannaBuild Philosophy

> Build like an indie hacker, ship like a pro.

## The Problem We're Solving

Most development frameworks are built for enterprises. They assume:
- Large teams with specialized roles
- Formal requirements documents
- Mandatory process gates
- Time to spare for ceremony

Indie hackers have none of that. They have:
- An idea they're excited about
- Limited time (often nights/weekends)
- A need to ship, not document
- A distaste for bureaucracy

WannaBuild bridges the gap: specs as backbone (not bureaucracy), structure when helpful, freedom when not.

## Core Principles

### 1. Specs Are the Backbone

Writing down what you're building before you build it saves more time than it costs. This isn't enterprise documentation theater — it's practical clarity.

WannaBuild's SDD pipeline uses three lightweight specs:
- **Requirements** — what to build (user stories, acceptance criteria, test scenarios)
- **Design** — how to build it (architecture, tech stack, risks)
- **Tasks** — the work (ordered, atomic, with test requirements)

When you're working with AI agents, specs become critical. An agent with a clear spec produces focused, verifiable work. An agent without a spec produces plausible-looking code that may or may not solve your problem.

### 2. Conversation Over Commands

**Other tools:** "Run `tool plan --spec=file.md --output=plan.json --format=detailed`"

**WannaBuild:** "I want to add payments to my app"

You shouldn't need to read docs to start building. Just talk about what you want. WannaBuild infers intent from natural conversation.

### 3. Flexibility Over Dogma

We don't enforce:
- Specific commit formats (though we suggest conventional commits)
- Coverage thresholds (ship working code, not vanity metrics)
- PRD-style specs (a focused paragraph often beats a 50-page doc)

We *do* enforce:
- Integration tests for every acceptance criterion (this is the one non-negotiable)

We *encourage*:
- Thinking before coding
- Breaking work into manageable chunks
- Testing the tricky bits
- Documenting the non-obvious

The difference: encouragement for most things, enforcement only for what matters (integration tests).

### 4. Depth Through Specialists

Generic AI code review: "Looks good to me!"

WannaBuild's review phase: 6 parallel specialists, each obsessed with their domain:
- Security reviewer (vulnerabilities, secrets, auth issues)
- Performance reviewer (N+1 queries, memory leaks, scalability)
- Architecture reviewer (design compliance, separation of concerns)
- Testing reviewer (test quality, coverage gaps, antipatterns)
- Integration tester (acceptance criteria → test mapping, runs the suite — **hard gate**)
- Code simplifier (readability, DRY, over-engineering)

This isn't a gimmick. Specialists catch what generalists miss. And the integration tester ensures every acceptance criterion has a passing test — no hand-waving.

### 5. Phases, Not Stages

Traditional: Linear stages with gates. Can't proceed until approved.

WannaBuild: Fluid phases you can enter, exit, and skip.

```
"I already know what I want, let's just build it"
→ Skip requirements, go to implement

"Actually, we should rethink the approach"
→ Jump back to requirements from anywhere

"It's a one-line fix"
→ Skip everything, just fix it
```

Phases are tools, not rules.

### 6. State Without Ceremony

WannaBuild remembers where you are without you managing it:
- Picked up mid-project? We know the context
- Switching between features? We track both
- Came back after a week? State is waiting

All in simple files you can read/edit yourself (`.wannabuild/`).

## What Makes WannaBuild Different

### vs. Traditional Dev Workflows

| Traditional | WannaBuild |
|-------------|------------|
| "Create a ticket" | "I want to build X" |
| "Write requirements" | "Let's figure out scope" |
| "Get approval" | "Does this cover it?" |
| "Assign to sprint" | "Let's break it down" |
| "Code review meeting" | "6 specialists in parallel" |

### vs. Obra Superpowers

Obra's approach: Fast, parallel, 2-stage (write + review).

WannaBuild's approach: Deeper, spec-driven, 7-phase with specialist depth.

| Aspect | Obra | WannaBuild |
|--------|------|------------|
| Entry | Commands | Conversation |
| Backbone | Process | Spec-driven development |
| Review | 2-stage | 6 parallel specialists |
| Testing | Optional | Integration tests non-negotiable |
| Process | Fast iteration | Thoughtful + fast |
| Audience | Power users | Indie hackers |

Both are good. WannaBuild is for people who want specs to drive their development without sacrificing speed.

### vs. Cursor / Copilot

They're great for:
- Autocomplete
- Quick fixes
- Understanding code

WannaBuild is for:
- Knowing *what* to build (requirements spec)
- Designing *how* to build it (design spec)
- Breaking it into *tasks* (task spec)
- Shipping complete features with integration tests

Use both. They complement each other.

## The Indie Hacker Test

Every WannaBuild feature must pass this test:

> Would a solo developer at 11 PM, excited about their side project, actually use this?

If it feels like ceremony, paperwork, or bureaucracy → cut it.
If it helps them ship faster without cutting corners → keep it.

Exception: integration tests. They're the one thing we mandate because shipping untested code wastes more time than writing the tests.

## When to Use WannaBuild

**Good fit:**
- Building a new feature
- Refactoring something complex
- Adding to unfamiliar codebase
- Want structure without bureaucracy
- Solo or small team

**Not necessary:**
- One-line bug fixes
- Typo corrections
- Just exploring code
- Following existing detailed spec
- Emergency hotfixes (just ship it)

## The 7 Phases in Brief

1. **Requirements** — "What are we building? What are the user stories? What are the test scenarios?"

2. **Design** — "How do we architect this? What tech stack? What are the risks?"

3. **Tasks** — "How do we break this down? What order? What tests does each task need?"

4. **Implement** — "Let's build it. Write integration tests. Commit often."

5. **Review** — "6 specialists validate against the spec. Fix what fails. Loop until 6/6."

6. **Ship** — "PR references specs. CI passes. Integration tests green. Merge."

7. **Document** — "What would confuse future-me? Write that down."

## Anti-Patterns We Reject

### The 50-Page PRD
Nobody reads it. Half of it's wrong by the time you start coding. A focused requirements spec beats a bloated PRD.

### Mandatory TDD for Everything
Tests are great. Writing tests for getters and setters? Cargo cult. Write tests where they matter: integration tests for acceptance criteria, unit tests for complex logic.

### 100% Coverage
A false god. Meaningful integration tests that prove acceptance criteria beats 100% line coverage of trivial code.

### Process for Process's Sake
"We do standups because teams do standups." No. Every process must earn its place.

### Skipping Integration Tests
"The code works, I tested it manually." Famous last words. Integration tests are the one thing we don't compromise on.

## The Trust Model

WannaBuild trusts you to:
- Know when to skip phases
- Ignore suggestions that don't apply
- Override recommendations with judgment
- Ship without asking permission

In return, WannaBuild gives you:
- Honest feedback (no "LGTM" when there are issues)
- Deep expertise (6 specialists, not 1 generalist)
- Spec-driven validation (reviews against requirements, not vibes)
- Context awareness (remembers your project)
- Zero guilt trips (it's your code)

## The Future

WannaBuild will evolve based on what indie hackers actually need. Current ideas:
- **Learn from your patterns** — Adapt to your coding style
- **Team mode** — Coordinate multiple agents on larger features
- **Integration plugins** — Connect to Linear, Notion, etc.
- **Custom specialists** — Add domain-specific reviewers

But only if they pass the 11 PM test.

---

*"Ship it. Learn. Iterate. That's the way."*
