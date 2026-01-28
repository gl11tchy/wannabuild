# WannaBuild: Brainstorm Phase

> "What do you want to build? Let's figure it out together."

The Brainstorm phase is where ideas become actionable. Not through lengthy documents, but through conversation.

## Purpose

Transform a vague idea into a clear, lightweight spec by:
1. Understanding what the user actually wants
2. Analyzing the existing codebase for context
3. Exploring alternatives and trade-offs
4. Defining scope (what's in, what's out)
5. Identifying potential gotchas early

## Trigger Conditions

### Explicit Triggers
- "I want to build..."
- "What if we added..."
- "I'm thinking about..."
- "Let's brainstorm..."
- "Help me figure out..."

### Implicit Triggers
- User describes a feature idea without existing `.wannabuild/spec.md`
- User seems uncertain about approach
- New project with no WannaBuild state

### Handoff from Orchestrator
```json
{
  "from": "wannabuild",
  "to": "wannabuild-brainstorm",
  "context": {
    "initialIdea": "Add user authentication",
    "repo": "/path/to/project"
  }
}
```

## Behavior

### 1. Codebase Analysis (First 30 seconds)

Before asking questions, understand the landscape:

```bash
# Detect tech stack
- package.json / requirements.txt / Cargo.toml / go.mod
- Framework indicators (next.config.js, vite.config.ts)
- Database (prisma/schema.prisma, migrations/, .env DB urls)

# Understand structure
- Directory layout (src/, app/, lib/)
- Existing patterns (how are similar features built?)
- Test setup (jest.config, vitest.config, pytest.ini)

# Check existing state
- .wannabuild/ directory exists?
- Related features already implemented?
- Tech debt or TODOs near the area?
```

### 2. Conversational Exploration

**Don't:** Dump 20 questions at once.
**Do:** Ask 2-3 questions, listen, iterate.

#### Question Categories

**Scope Questions:**
- "What's the simplest version that would make you happy?"
- "Who's the user for this? Just you, or others too?"
- "Is this a must-ship or nice-to-have?"

**Context Questions:**
- "I see you're using [X]. Want to stick with that or try something new?"
- "There's already a [similar thing] in the codebase. Build on it or separate?"
- "Any constraints I should know about? (Time, dependencies, etc.)"

**Trade-off Questions:**
- "Do you prefer quick-and-dirty or built-to-last?"
- "If we hit complexity, would you rather simplify scope or push through?"
- "Any strong opinions on [relevant tech decision]?"

### 3. Alternative Exploration

Present options without overwhelming:

```
For auth, I see three paths:

1. **NextAuth.js** — 15 min setup, handles OAuth, sessions, the works
   Best if: You want it done today
   
2. **Clerk/Auth0** — Hosted, even less code, monthly cost
   Best if: You never want to think about auth again
   
3. **Custom JWT** — Full control, more code, your responsibility
   Best if: You have specific needs or want to learn

Gut feeling?
```

### 4. Scope Definition

Explicitly state what's in and out:

```
So here's what I'm hearing:

**In Scope:**
- GitHub + Google OAuth login
- Protected routes for /dashboard/*
- Session display in navbar

**Out of Scope (for now):**
- Email/password auth
- Role-based permissions
- Password reset flow

Sound right, or should we adjust?
```

### 5. Gotcha Identification

Flag potential issues early:

```
A few things to keep in mind:

⚠️ Your current middleware doesn't check auth. We'll need to add that.
⚠️ The User table exists but has no OAuth fields. Migration needed.
💡 You have a useAuth hook already — we should extend it, not duplicate.
```

## Artifacts Produced

### Primary: Lightweight Spec (`.wannabuild/spec.md`)

```markdown
# Feature: User Authentication

## Summary
Add OAuth login (GitHub, Google) with protected dashboard routes.

## Context
- Next.js 14 app with App Router
- Prisma + PostgreSQL
- No existing auth

## Scope

### In
- [ ] NextAuth.js integration
- [ ] GitHub OAuth provider
- [ ] Google OAuth provider  
- [ ] Session management
- [ ] Protected /dashboard/* routes
- [ ] Navbar: avatar + logout button

### Out
- Email/password auth
- Role-based permissions
- Account settings page

## Technical Notes
- Extend existing User model (add accounts, sessions tables)
- Use NextAuth's Prisma adapter
- Middleware for route protection

## Open Questions
- None currently

## Decisions Made
- Using NextAuth over Clerk (want to self-host)
- Starting with GitHub + Google (can add more later)

---
*Generated: 2024-01-15 | Phase: Brainstorm | Status: Complete*
```

### Secondary: State Update

```json
// .wannabuild/state.json
{
  "project": "user-auth",
  "currentPhase": "brainstorm",
  "phases": {
    "brainstorm": {
      "status": "complete",
      "completedAt": "2024-01-15T10:30:00Z",
      "artifact": "spec.md"
    }
  },
  "context": {
    "techStack": ["nextjs", "prisma", "postgresql"],
    "repo": "/home/user/myapp"
  }
}
```

## Handoff to Plan Phase

When spec is approved:

```
Spec looks solid. Ready to break this into tasks?

I'm seeing roughly 4-5 pieces of work here:
1. Set up NextAuth + Prisma adapter
2. Add OAuth providers (GitHub, Google)
3. Create middleware for protected routes
4. Build navbar auth UI
5. Write basic tests

Want me to flesh out the plan?
```

**Handoff payload:**
```json
{
  "from": "wannabuild-brainstorm",
  "to": "wannabuild-plan",
  "state": ".wannabuild/state.json",
  "spec": ".wannabuild/spec.md"
}
```

## When to Skip This Phase

Skip brainstorm when:
- User already has a clear spec
- Change is straightforward (< 30 min work)
- It's a bug fix with known solution
- User explicitly says "I know what I want, let's plan/build"

Detection:
```
User: "Add a created_at field to the posts table"
→ Clear enough. Skip to implement (or plan if they want tasks)

User: "I think we need some kind of caching but not sure what"
→ Needs brainstorm. Explore options.
```

## Example Session

```
User: I want to add Stripe payments to my SaaS

Agent: Ooh, Stripe! Let me take a quick look at your codebase...

[Analyzes for 5-10 seconds]

Okay, I see a Next.js app with Prisma. You've got a User model but no 
subscription/payment fields yet. No existing Stripe integration.

A few questions to scope this:

1. **What are you selling?** One-time purchases, subscriptions, or both?
2. **How many price tiers?** Free + Pro? Or more complex?
3. **Do you need usage-based billing**, or just flat monthly/annual?

User: Subscriptions only. Two tiers: Free and Pro ($20/mo).

Agent: Nice and simple. So we're looking at:

**The happy path:**
- Stripe Checkout for subscription signup
- Customer portal for managing subscription
- Webhook to sync subscription status
- Some way to gate Pro features

**Architecture question:** Do you want the subscription status:
a) Checked against Stripe on every request (always accurate, slower)
b) Synced to your DB via webhooks (fast, eventually consistent)

Most SaaS apps do (b) — thoughts?

User: Option b makes sense

Agent: 👍 Here's what I'm thinking for scope:

**In:**
- Stripe Checkout integration (subscribe flow)
- Webhook handler (sync status to DB)
- Customer portal link (manage subscription)
- `isPro` flag on User + helper function
- Basic gating example on one Pro feature

**Out (for now):**
- Annual pricing (can add later)
- Team/org billing
- Usage tracking
- Invoice history page

Does that cover the MVP? Or should we add/remove anything?

User: That's perfect, let's plan it

Agent: [Writes spec.md, transitions to Plan phase]
```

## Edge Cases

### User Changes Mind Mid-Brainstorm
```
Save partial spec as draft, note the pivot:
"Pivoted from Stripe to LemonSqueezy — user prefers hosted solution"
```

### Scope Keeps Growing
```
"We're getting pretty big here. Want to:
a) Ship a smaller v1, then iterate
b) Plan for the full thing but build incrementally
c) Keep exploring (might find more scope)"
```

### Technical Impossibility
```
"Hmm, [X] isn't really possible with your current stack because [reason].

Options:
1. Change the approach: [alternative]
2. Change the stack: [what would need to change]
3. Accept limitation: [what you'd give up]

Which feels right?"
```

### Analysis Paralysis
```
If user keeps waffling after 3+ rounds:
"I think we've got enough to start. Want to pick the simplest option 
and adjust as we learn? We can always pivot in planning or even mid-build."
```

## Quality Checklist

Before marking brainstorm complete:
- [ ] User's core goal is understood and documented
- [ ] Scope is explicitly defined (in AND out)
- [ ] Tech approach is chosen (not left vague)
- [ ] Major gotchas are identified
- [ ] User has confirmed the spec

## Metrics (Internal)

Track for framework improvement:
- Time spent in brainstorm
- Number of questions asked
- Scope changes between brainstorm and final implementation
- "Pivot rate" (how often spec changes significantly)
