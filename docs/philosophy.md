# WannaBuild Philosophy

## Why WannaBuild Exists

Most AI coding frameworks feel like enterprise software shrunk down for solo developers. Heavy documentation, rigid phases, lots of commands to memorize.

WannaBuild is different. It's built ground-up for indie builders who need to ship quality code fast — with specs as the backbone, not bureaucracy.

## Core Principles

### 1. Specs Are the Backbone

Every line of code traces back to a specification. This isn't enterprise documentation theater — it's the recognition that writing down what you're building before you build it saves more time than it costs.

The SDD pipeline ensures:
- **Requirements** define what to build (user stories, acceptance criteria)
- **Design** defines how to build it (architecture, data models, risks)
- **Tasks** define the work (ordered, atomic, with test requirements)
- **Implementation** follows the tasks
- **Review** validates against the specs
- **Integration tests** prove the specs are met

When you're working with AI agents, specs become critical. An agent with a clear spec produces focused, verifiable work. An agent without a spec produces plausible-looking code that may or may not solve your actual problem.

### 2. Talk Like a Human

**Bad:**
```
/framework:init --template=saas --phases=brainstorm,plan,implement --strict
```

**Good:**
```
I wanna build a subscription billing system
```

You shouldn't need documentation to start a conversation.

### 3. Specialists Beat Generalists

One AI trying to do security review AND architecture review AND code simplification will do all three poorly.

WannaBuild deploys **21 core specialists**, each with focused expertise:
- Scope analyst who only thinks about boundaries and risks
- Architect who only thinks about system design
- Integration tester who only thinks about test coverage
- Security reviewer who only thinks about vulnerabilities
- Code simplifier who only thinks about readability

Each expert does one thing exceptionally well.

### 4. Integration Tests Are Non-Negotiable

Unit tests verify components in isolation. Integration tests verify that **the thing you built actually works as a whole**.

For indie builders shipping real products, integration tests catch the bugs that matter — API endpoints returning wrong data, auth flows breaking on edge cases, database queries failing with real data.

WannaBuild enforces this through every phase:
- Requirements include test scenarios for every user story
- Tasks specify required integration tests
- The implementer writes tests alongside feature code
- A dedicated integration tester agent hard-gates shipping on test completeness

This isn't optional. Code without integration tests doesn't ship.

### 5. Quality is a Loop, Not a Gate

Traditional review:
```
Code → Review → "Looks good" → Ship (with known issues)
```

WannaBuild:
```
Code → Review → Feedback → Fix → Review → ... → Unanimous 6/6 → Ship
```

Code doesn't leave the loop until 6 specialists agree it's ready. The integration tester ensures every acceptance criterion has a passing test. No hand-waving.

### 6. Flexibility Over Dogma

WannaBuild recommends best practices but respects that:
- Sometimes you spike first, then test
- Sometimes the fix is obvious and doesn't need full specs
- Sometimes you're refactoring, not building new

Enter at any phase, skip phases that don't apply. Guidelines, not handcuffs.

## The Quality Loop

This is WannaBuild's killer feature.

After implementation, 6 specialist agents review in parallel:

1. **Security Reviewer** — Any vulnerabilities? Exposed secrets?
2. **Performance Reviewer** — N+1 queries? Memory issues? Scalability?
3. **Architecture Reviewer** — Matches the design spec? Good boundaries?
4. **Testing Reviewer** — Test quality? Coverage? Antipatterns?
5. **Integration Tester** — Every acceptance criterion has a passing test? (HARD GATE)
6. **Code Simplifier** — DRY? Readable? Over-engineered?

Each agent votes PASS or FAIL.

If **any** agent fails, feedback goes back to the implementer. The loop continues until **all 6 agents vote PASS**.

After 3 iterations without approval, it escalates to a human. Integration test failures cannot be overridden — missing tests must be written.

## Who WannaBuild Is For

- Indie hackers building SaaS
- Solo developers shipping side projects
- Small teams without dedicated reviewers
- Anyone who wants AI assistance with spec-driven quality

## Who WannaBuild Isn't For

- Teams that need audit trails and compliance docs beyond what SDD provides
- People who prefer fully rigid, manual processes
- Projects that can't tolerate the overhead of specs (though WannaBuild specs are minimal)

## The Name

"WannaBuild" comes from the first question you'll hear:

> "What do you wanna build?"

It's casual. It's approachable. It's how you'd start a conversation with a friend who happens to be a great engineer.

---

*Build like you mean it.*
