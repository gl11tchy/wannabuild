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

WannaBuild bridges the gap: structure when helpful, freedom when not.

## Core Principles

### 1. Conversation Over Commands

**Other tools:** "Run `tool plan --spec=file.md --output=plan.json --format=detailed`"

**WannaBuild:** "I want to add payments to my app"

You shouldn't need to read docs to start building. Just talk about what you want. WannaBuild infers intent from natural conversation.

### 2. Flexibility Over Dogma

We don't enforce:
- TDD (write tests when they help, not because we said so)
- Specific commit formats (though we suggest conventional commits)
- Coverage thresholds (ship working code, not vanity metrics)
- PRD-style specs (a paragraph often beats a 50-page doc)

We *do* encourage:
- Thinking before coding
- Breaking work into manageable chunks
- Testing the tricky bits
- Documenting the non-obvious

The difference: encouragement, not enforcement.

### 3. Depth Through Specialists

Generic AI code review: "Looks good to me!"

WannaBuild's review phase (elite-code-review): 5 parallel specialists, each obsessed with their domain:
- Security reviewer (vulnerabilities, auth issues)
- Performance reviewer (N+1 queries, memory leaks)
- Architecture reviewer (patterns, coupling)
- Testing reviewer (coverage gaps, edge cases)
- DX reviewer (readability, maintainability)

This isn't a gimmick. Specialists catch what generalists miss.

### 4. Phases, Not Stages

Traditional: Linear stages with gates. Can't proceed until approved.

WannaBuild: Fluid phases you can enter, exit, and skip.

```
"I already know what I want, let's just build it"
→ Skip brainstorm, go to implement

"Actually, we should rethink the approach"
→ Jump back to brainstorm from anywhere

"It's a one-line fix"
→ Skip everything, just fix it
```

Phases are tools, not rules.

### 5. State Without Ceremony

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
| "Code review meeting" | "5 specialists in parallel" |

### vs. Obra Superpowers

Obra's approach: Fast, parallel, 2-stage (write + review).

WannaBuild's approach: Deeper, conversational, 6-phase with specialist depth.

| Aspect | Obra | WannaBuild |
|--------|------|------------|
| Entry | Commands | Conversation |
| Review | 2-stage | 5 parallel specialists |
| Process | Fast iteration | Thoughtful + fast |
| Audience | Power users | Indie hackers |
| Philosophy | Speed | Depth with speed |

Both are good. WannaBuild is for people who want to think a bit more before they code, without sacrificing speed.

### vs. Cursor / Copilot

They're great for:
- Autocomplete
- Quick fixes
- Understanding code

WannaBuild is for:
- Knowing *what* to build
- Breaking it into phases
- Shipping complete features

Use both. They complement each other.

## The Indie Hacker Test

Every WannaBuild feature must pass this test:

> Would a solo developer at 11 PM, excited about their side project, actually use this?

If it feels like ceremony, paperwork, or bureaucracy → cut it.
If it helps them ship faster without cutting corners → keep it.

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

## The Phases in Brief

1. **Brainstorm** — "What are we building? What could go wrong? What's the simplest version?"

2. **Plan** — "How do we break this down? What's risky? What order makes sense?"

3. **Implement** — "Let's build it. Test the tricky parts. Commit often."

4. **Review** — "5 specialists tear it apart. Fix what matters."

5. **Ship** — "PR looks good. CI passes. Merge it."

6. **Document** — "What would confuse future-me? Write that down."

## Anti-Patterns We Reject

### ❌ The 50-Page PRD
Nobody reads it. Half of it's wrong by the time you start coding. A focused paragraph beats a bloated doc.

### ❌ Mandatory TDD
Tests are great. *Mandatory* tests before you even understand the problem? Cargo cult. Write tests when they help: complex logic, edge cases, integration points.

### ❌ 100% Coverage
A false god. 80% coverage of the right things beats 100% coverage of getters and setters.

### ❌ Process for Process's Sake
"We do standups because teams do standups." No. Every process must earn its place.

### ❌ Gatekeeping
"You can't ship until the architect approves." WannaBuild is your architect, and it's here to help, not block.

## The Trust Model

WannaBuild trusts you to:
- Know when to skip phases
- Ignore suggestions that don't apply
- Override recommendations with judgment
- Ship without asking permission

In return, WannaBuild gives you:
- Honest feedback (no "LGTM" when there are issues)
- Deep expertise (5 specialists, not 1 generalist)
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
