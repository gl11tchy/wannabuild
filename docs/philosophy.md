# WannaBuild Philosophy

## Why WannaBuild Exists

Most AI coding frameworks feel like enterprise software shrunk down for solo developers. Heavy documentation, rigid phases, lots of commands to memorize.

WannaBuild is different. It's built ground-up for indie hackers who need to ship quality code fast.

## Core Principles

### 1. Talk Like a Human

**Bad:**
```
/framework:init --template=saas --phases=brainstorm,plan,implement --strict
```

**Good:**
```
I wanna build a subscription billing system
```

You shouldn't need documentation to start a conversation.

### 2. Specialists Beat Generalists

One AI trying to do security review AND architecture review AND code simplification will do all three poorly.

WannaBuild deploys **specialists**:
- Security auditor who only thinks about security
- Architect who only thinks about system design
- Code simplifier who only thinks about readability

Each expert does one thing exceptionally well.

### 3. Quality is a Loop, Not a Gate

Traditional review:
```
Code → Review → "Looks good" → Ship (with known issues)
```

WannaBuild:
```
Code → Review → Feedback → Fix → Review → Feedback → Fix → ... → Unanimous Approval → Ship
```

Code doesn't leave the loop until 5 specialists agree it's ready.

### 4. Flexibility Over Dogma

Some frameworks enforce strict TDD to the point of deleting code written before tests. That's dogma.

WannaBuild recommends best practices but respects that:
- Sometimes you spike first, then test
- Sometimes the fix is obvious and doesn't need a spec
- Sometimes you're refactoring, not building new

Guidelines, not handcuffs.

### 5. Skip What You Don't Need

Not every change needs 6 phases:
- Fixing a typo? Just fix it.
- Quick bug fix? Implement → Review → Ship.
- Documentation? Write → Ship.

Enter at any phase, skip phases that don't apply.

## The Quality Loop

This is WannaBuild's killer feature.

After implementation, 5 specialist agents review in parallel:

1. **Plan Verifier** — Does this match what we said we'd build?
2. **Security Auditor** — Any vulnerabilities? Exposed secrets?
3. **Best Practices** — Modern patterns? Deprecated APIs?
4. **Architect** — Sound structure? Good boundaries?
5. **Code Simplifier** — DRY? Readable? Can this be cleaner?

Each agent votes PASS or FAIL.

If **any** agent fails, feedback goes back to the implementer. The loop continues until **all 5 agents vote PASS**.

After 3-5 iterations without approval, it escalates to a human. "These issues keep recurring — need your input."

## Who WannaBuild Is For

✅ Indie hackers building SaaS
✅ Solo developers shipping side projects
✅ Small teams without dedicated reviewers
✅ Anyone who wants AI assistance without enterprise overhead

## Who WannaBuild Isn't For

❌ Teams that need audit trails and compliance docs
❌ Projects requiring formal specifications
❌ People who prefer rigid, documented processes

## The Name

"WannaBuild" comes from the first question you'll hear:

> "What do you wanna build?"

It's casual. It's approachable. It's how you'd start a conversation with a friend who happens to be a great engineer.

---

*Build like you mean it.*
