# WannaBuild: Plan Phase

> "Let's break this into pieces you can actually build."

The Plan phase transforms a spec into a concrete task list with clear order, dependencies, and risk callouts.

## Purpose

Take the lightweight spec from Brainstorm and produce:
1. Ordered list of concrete, implementable tasks
2. Dependency graph (what blocks what)
3. Risk assessment (where might we get stuck?)
4. Rough effort estimates (not hours, just T-shirt sizes)
5. Clear "done" criteria for each task

## Trigger Conditions

### Explicit Triggers
- "Let's plan this out"
- "Break this into tasks"
- "How should we approach this?"
- "What's the order of operations?"

### Implicit Triggers
- Spec exists (`.wannabuild/spec.md`) but no plan
- User finished brainstorm and wants to proceed
- User has clear requirements and wants structure

### Handoff from Brainstorm
```json
{
  "from": "wannabuild-brainstorm",
  "to": "wannabuild-plan",
  "state": ".wannabuild/state.json",
  "spec": ".wannabuild/spec.md"
}
```

## Behavior

### 1. Spec Analysis

Read and internalize the spec:
```
- What's the core goal?
- What are the explicit scope items?
- What technical decisions were made?
- What's explicitly out of scope?
- What gotchas were identified?
```

### 2. Task Decomposition

Break work into tasks that are:
- **Atomic:** One clear thing to do
- **Testable:** You know when it's done
- **Ordered:** Dependencies are clear
- **Sized:** Roughly estimable (S/M/L)

#### Task Granularity Guide

**Too big:** "Implement authentication"
**Too small:** "Import useSession hook"
**Just right:** "Set up NextAuth with Prisma adapter"

Rule of thumb: Each task should be 15-60 minutes of focused work.

### 3. Dependency Mapping

Identify what blocks what:

```
Task 1: Set up NextAuth         [No dependencies]
Task 2: Add OAuth providers     [Depends on: 1]
Task 3: Create auth middleware  [Depends on: 1]
Task 4: Build navbar auth UI    [Depends on: 1, 3]
Task 5: Write integration tests [Depends on: 1, 2, 3, 4]
```

Visualize when helpful:
```
[1] NextAuth Setup
 ├── [2] OAuth Providers
 └── [3] Auth Middleware
      └── [4] Navbar UI
           └── [5] Tests
```

### 4. Risk Assessment

For each significant task, ask:
- **Complexity risk:** Is this straightforward or tricky?
- **Unknown risk:** Have we done this before?
- **Integration risk:** Does this touch many parts of the codebase?
- **External risk:** Does this depend on third-party services?

Flag high-risk tasks:
```
⚠️ Task 3 (Middleware): Tricky — Next.js 14 middleware has quirks 
   with App Router. May need experimentation.
   
⚠️ Task 2 (OAuth): External dependency — Requires setting up OAuth 
   apps in GitHub/Google. User needs credentials ready.
```

### 5. Specialist Sub-Agents (Optional)

For complex plans, spawn specialist analyzers:

#### Scope Creep Detector
```
Compares plan to original spec. Flags:
- "Task 6 (email notifications) wasn't in the spec. Add to scope or remove?"
- "Task 4 has grown to include profile settings. Intentional?"
```

#### Tech Debt Forecaster
```
Analyzes planned approach against codebase. Flags:
- "This adds a third auth pattern. Consider consolidating after ship."
- "The User model is getting heavy. Plan a refactor soon."
```

#### Parallel Path Finder
```
Identifies tasks that can run in parallel:
- "Tasks 2 and 3 are independent. Could work on both simultaneously."
```

Spawn these when:
- Plan has > 8 tasks
- Significant codebase changes
- User asks for deeper analysis

### 6. Effort Estimation

T-shirt sizes, not hours:

| Size | Meaning | Roughly |
|------|---------|---------|
| S | Straightforward, done this before | 15-30 min |
| M | Clear but requires focus | 30-60 min |
| L | Complex or unfamiliar | 1-2 hours |
| XL | Significant, consider splitting | 2+ hours |

```
Task 1: Set up NextAuth — S (boilerplate, done many times)
Task 2: OAuth providers — S (just config)
Task 3: Auth middleware — M (App Router quirks)
Task 4: Navbar auth UI — M (UI + state management)
Task 5: Integration tests — L (multiple flows to cover)
```

## Artifacts Produced

### Primary: Plan Document (`.wannabuild/plan.md`)

```markdown
# Plan: User Authentication

## Overview
Implement OAuth authentication with protected routes.
Based on: [spec.md](spec.md)

## Tasks

### 1. Set up NextAuth with Prisma adapter
**Size:** S | **Risk:** Low | **Dependencies:** None

- Install next-auth, @next-auth/prisma-adapter
- Create app/api/auth/[...nextauth]/route.ts
- Add NextAuth schema to Prisma (Account, Session, etc.)
- Run migration

**Done when:** NextAuth initializes without errors, Prisma tables created

---

### 2. Configure OAuth providers (GitHub, Google)
**Size:** S | **Risk:** Medium (external) | **Dependencies:** Task 1

- Add GitHub provider with credentials from env
- Add Google provider with credentials from env
- Test sign-in flow for each

**Done when:** Can sign in with both GitHub and Google

⚠️ **Note:** User needs to create OAuth apps and add credentials to .env

---

### 3. Create auth middleware for protected routes
**Size:** M | **Risk:** Medium | **Dependencies:** Task 1

- Create middleware.ts in project root
- Configure matcher for /dashboard/* routes
- Redirect to /login if no session
- Handle edge cases (expired session, etc.)

**Done when:** Unauthenticated users redirected from /dashboard/*

⚠️ **Note:** Next.js 14 App Router middleware has specific patterns. Reference docs.

---

### 4. Build navbar authentication UI
**Size:** M | **Risk:** Low | **Dependencies:** Tasks 1, 3

- Add auth state to existing Navbar component
- Show avatar + name when logged in
- Show "Sign In" button when logged out
- Add dropdown with "Sign Out" action

**Done when:** Navbar reflects auth state correctly

---

### 5. Write integration tests
**Size:** L | **Risk:** Low | **Dependencies:** Tasks 1-4

- Test: Unauthenticated user redirected from protected route
- Test: Authenticated user can access dashboard
- Test: Sign out clears session
- Mock OAuth providers for test environment

**Done when:** All auth flows have test coverage

---

## Dependency Graph

```
[1] NextAuth Setup
 ├── [2] OAuth Providers
 └── [3] Auth Middleware
      └── [4] Navbar UI
           └── [5] Tests
```

## Risk Summary

| Task | Risk Level | Notes |
|------|------------|-------|
| 1 | Low | Boilerplate |
| 2 | Medium | Needs OAuth app setup |
| 3 | Medium | App Router quirks |
| 4 | Low | Standard UI work |
| 5 | Low | Well-understood patterns |

## Parallel Opportunities
- Tasks 2 and 3 can be worked in parallel after Task 1

## Total Effort
Estimated: 3-4 hours of focused work

---
*Generated: 2024-01-15 | Phase: Plan | Status: Complete*
```

### Secondary: State Update

```json
// .wannabuild/state.json
{
  "project": "user-auth",
  "currentPhase": "plan",
  "phases": {
    "brainstorm": {
      "status": "complete",
      "completedAt": "2024-01-15T10:30:00Z",
      "artifact": "spec.md"
    },
    "plan": {
      "status": "complete",
      "completedAt": "2024-01-15T11:00:00Z",
      "artifact": "plan.md",
      "tasksTotal": 5,
      "tasksComplete": 0
    }
  }
}
```

## Handoff to Implement Phase

When plan is approved:

```
Plan's ready. 5 tasks, roughly 3-4 hours total.

I'd start with Task 1 (NextAuth setup) — it unblocks everything else.

Ready to build? I'll work through the tasks in order, committing as we go.
```

**Handoff payload:**
```json
{
  "from": "wannabuild-plan",
  "to": "wannabuild-implement",
  "state": ".wannabuild/state.json",
  "plan": ".wannabuild/plan.md",
  "startTask": 1
}
```

## When to Skip This Phase

Skip planning when:
- Single, clear task (< 30 min)
- User already has detailed plan
- Emergency hotfix (just do it)
- User says "I know the steps, let's build"

Detection:
```
User: "Add created_at to posts table"
→ One clear task. Skip planning, go to implement.

User: "Build a complete notification system"
→ Complex. Definitely needs planning.
```

## Example Session

```
User: Let's plan the Stripe integration

Agent: Looking at your spec... subscription billing with two tiers, 
webhook sync, customer portal. Got it.

Here's how I'd break this down:

**Task 1: Stripe SDK + environment setup** (S)
- Install stripe package
- Add API keys to .env
- Create lib/stripe.ts helper

**Task 2: Extend User model for subscriptions** (S)
- Add stripeCustomerId, subscriptionStatus fields
- Create migration

**Task 3: Create checkout session endpoint** (M)
- POST /api/checkout
- Create Stripe customer if needed
- Redirect to Checkout

**Task 4: Webhook handler** (M) ⚠️
- POST /api/webhooks/stripe
- Handle subscription.created, updated, deleted
- Sync status to database

**Task 5: Customer portal endpoint** (S)
- POST /api/billing/portal
- Redirect to Stripe portal

**Task 6: isPro helper + feature gating** (S)
- Add isPro() utility function
- Gate one example feature

**Task 7: Basic tests** (M)
- Mock Stripe API
- Test checkout flow
- Test webhook processing

That's 7 tasks. The webhook (Task 4) is the trickiest — Stripe 
webhooks need signature verification and have specific event shapes.

Does this breakdown make sense? Want to adjust anything before we start?

User: Task 7 can be smaller, just test the webhook

Agent: Makes sense — webhook is the critical path. I'll update:

**Task 7: Webhook tests** (S)
- Test signature verification
- Test subscription sync logic
- Skip e2e checkout tests for now

Ready to implement?
```

## Plan Adjustment

Plans aren't sacred. When reality diverges:

```
[During implementation]

Agent: Heads up — Task 4 is bigger than expected. Stripe's webhook 
types are more complex than I anticipated.

Options:
1. Split Task 4 into two tasks (setup + handlers)
2. Simplify by handling fewer event types initially
3. Push through (it's just taking longer)

What's your preference?
```

Update the plan document to reflect changes:
```markdown
### 4a. Webhook endpoint setup
[split from original Task 4]

### 4b. Webhook event handlers  
[split from original Task 4]
```

## Quality Checklist

Before marking plan complete:
- [ ] Every task has clear "done" criteria
- [ ] Dependencies are explicit
- [ ] Risks are flagged
- [ ] No task is XL (split those)
- [ ] User has approved the breakdown

## Anti-Patterns

### ❌ Over-planning
10+ tiny tasks for a simple feature. Keep it pragmatic.

### ❌ Vague tasks
"Set up infrastructure" — what does that mean? Be specific.

### ❌ No "done" criteria
"Implement auth" — when is it done? Define it.

### ❌ Hidden dependencies
Task 5 secretly needs Task 2 but it's not documented. Surface these.

### ❌ Premature optimization tasks
"Add caching layer" before you know it's needed. YAGNI.
