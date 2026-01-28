# WannaBuild: Implement Phase

> "Let's build this thing."

The Implement phase is where plans become code. Work through tasks systematically, test as you go, commit incrementally.

## Purpose

Execute the plan from the Plan phase:
1. Work through tasks in dependency order
2. Write quality code (but not perfectionist code)
3. Run tests for complex/risky bits
4. Commit incrementally with clear messages
5. Handle blockers and pivots gracefully

## Trigger Conditions

### Explicit Triggers
- "Let's build this"
- "Start coding"
- "Implement this"
- "Let's do Task 1"
- "Ready to code"

### Implicit Triggers
- Plan exists (`.wannabuild/plan.md`) with incomplete tasks
- User approved plan and wants to proceed
- Resuming from paused implementation

### Handoff from Plan
```json
{
  "from": "wannabuild-plan",
  "to": "wannabuild-implement",
  "state": ".wannabuild/state.json",
  "plan": ".wannabuild/plan.md",
  "startTask": 1
}
```

## Behavior

### 1. Setup Check

Before coding:
```bash
# Verify environment
- Is repo clean or okay to work on?
- Is the right branch checked out?
- Are dependencies up to date?
- Any uncommitted changes to stash?

# Create feature branch (if not exists)
git checkout -b feat/user-auth  # or use existing

# Read the plan
- Which task is next?
- What are its dependencies?
- What are the "done" criteria?
```

### 2. Task Execution Loop

For each task:

```
┌─────────────────────────────────────────────────┐
│  1. Announce what you're doing                  │
│  2. Write the code                              │
│  3. Verify it works (tests, manual check)       │
│  4. Commit with clear message                   │
│  5. Update task status                          │
│  6. Move to next task (or handle blocker)       │
└─────────────────────────────────────────────────┘
```

### 3. Coding Standards

**Follow existing patterns:**
- Match the codebase's style, not your preferences
- Use existing utilities rather than reinventing
- Follow naming conventions already in use

**Quality, not perfection:**
- Working code > theoretically perfect code
- Clear code > clever code
- Good enough > over-engineered

**Test strategically:**
- Complex logic → definitely test
- Edge cases → probably test
- Simple CRUD → maybe skip
- Obvious code → don't waste time

### 4. Commit Strategy

**Atomic commits:**
Each commit should be one logical change that works on its own.

**Conventional commit messages:**
```
feat(auth): set up NextAuth with Prisma adapter
feat(auth): add GitHub OAuth provider
feat(auth): add Google OAuth provider
feat(auth): create middleware for protected routes
feat(auth): add auth UI to navbar
test(auth): add integration tests for auth flows
```

**Commit frequently:**
- After each task completion
- After significant progress on larger tasks
- Before risky changes (so you can revert)

### 5. Progress Communication

Keep the user informed without overwhelming:

```
✅ Task 1 complete — NextAuth is set up with Prisma adapter
   → Committed: "feat(auth): set up NextAuth with Prisma adapter"

Starting Task 2: OAuth providers...
```

For longer tasks, checkpoint:
```
Working on Task 4 (auth middleware)...
- ✓ Created middleware.ts
- ✓ Added route matcher
- → Now handling redirect logic
```

### 6. Handling Blockers

**Discovery:** "This is more complex than expected"
```
Heads up — Task 3 is trickier than planned. The App Router middleware 
doesn't support async session checks the way I expected.

Options:
1. Use a different approach (edge-compatible session check)
2. Move auth check to server components instead
3. Spend more time figuring out the current approach

I'd suggest option 1 — it's the standard pattern for Next.js 14.
What do you think?
```

**External dependency:** "Need something from the user"
```
Hit a blocker on Task 2 — I need the OAuth credentials.

Can you:
1. Create a GitHub OAuth app → Settings → Developer settings → OAuth Apps
2. Create a Google OAuth app → Google Cloud Console → APIs → Credentials
3. Add these to your .env:
   - GITHUB_ID=
   - GITHUB_SECRET=
   - GOOGLE_ID=
   - GOOGLE_SECRET=

Let me know when ready, and I'll continue.
```

**Scope creep:** "This is becoming bigger"
```
As I'm building this, I realize we also need [X] for it to work properly.

Options:
1. Add [X] to scope (makes this bigger)
2. Simplify the feature to not need [X]
3. Note it as follow-up work, ship without

What's your preference?
```

### 7. Testing Approach

**When to write tests:**
- Complex business logic (definitely)
- Edge cases that burned you before (definitely)
- Integration points with external services (probably)
- Critical paths (login, payment, etc.) (probably)
- Simple utility functions (maybe)
- Obvious code (skip)

**Test as you go:**
```
Finished the webhook handler. Running tests...

✅ test_webhook_signature_verification — passed
✅ test_subscription_created_event — passed
✅ test_subscription_canceled_event — passed

All green. Moving to Task 5.
```

**Don't force coverage:**
If a test would be:
- Harder to write than the code it tests
- Testing framework internals more than your code
- Only catching typos, not logic bugs

→ Skip it. Write documentation instead.

### 8. When to Ask vs. Push Forward

**Ask when:**
- Architectural decisions (affects other code)
- Scope changes (deviating from plan)
- Multiple valid approaches (user preference matters)
- External setup needed (credentials, services)
- Significant trade-offs (speed vs. maintainability)

**Push forward when:**
- Implementation details (how to name a variable)
- Standard patterns (using established approach)
- Bug fixes (discovered during implementation)
- Minor improvements (cleanup as you go)
- Testing strategy (within agreed scope)

## Artifacts Produced

### Primary: Working Code

The actual implementation, committed to the feature branch.

### Secondary: Updated State

```json
// .wannabuild/state.json
{
  "project": "user-auth",
  "currentPhase": "implement",
  "phases": {
    "brainstorm": { "status": "complete", ... },
    "plan": { 
      "status": "complete",
      "tasksTotal": 5,
      "tasksComplete": 3
    },
    "implement": {
      "status": "in-progress",
      "startedAt": "2024-01-15T12:00:00Z",
      "branch": "feat/user-auth",
      "currentTask": 4,
      "commits": [
        "abc123 - feat(auth): set up NextAuth with Prisma adapter",
        "def456 - feat(auth): add GitHub OAuth provider",
        "ghi789 - feat(auth): add Google OAuth provider"
      ]
    }
  }
}
```

### Tertiary: Session Notes (Optional)

For complex implementations, maintain notes:
```markdown
<!-- .wannabuild/sessions/2024-01-15-implement.md -->

## Session: User Auth Implementation

### Decisions Made
- Used edge-compatible middleware instead of Node.js middleware
- Added both providers in one file rather than separate

### Gotchas Discovered
- NextAuth's getServerSession() has different import in App Router
- Middleware needs explicit matcher, doesn't cascade

### For Future Reference
- Auth callback URL: /api/auth/callback/[provider]
- To add new provider: update authOptions in route.ts
```

## Handoff to Review Phase

When implementation is complete:

```
All 5 tasks done! Here's what we built:

**Commits:**
- feat(auth): set up NextAuth with Prisma adapter
- feat(auth): add GitHub and Google OAuth providers
- feat(auth): create middleware for protected routes
- feat(auth): add auth UI to navbar
- test(auth): add integration tests for auth flows

**Files changed:** 12 files, +450 lines, -20 lines

Ready for review? I'll run it through the 5 specialists:
- Security review (auth is sensitive!)
- Performance review
- Architecture review
- Testing review
- DX review

Should I start the review?
```

**Handoff payload:**
```json
{
  "from": "wannabuild-implement",
  "to": "elite-code-review",
  "state": ".wannabuild/state.json",
  "branch": "feat/user-auth",
  "files": ["app/api/auth/...", "middleware.ts", ...]
}
```

## When to Skip This Phase

Skip implement when:
- Code already written, just needs review
- Documentation-only changes
- Configuration changes (might be trivial enough to just do)

## Resuming Implementation

When picking up a paused project:

```
Agent: I see we paused mid-implementation on user-auth.

Current status:
- ✅ Task 1: NextAuth setup — complete
- ✅ Task 2: OAuth providers — complete
- ⏸️ Task 3: Auth middleware — in progress
- ⏳ Task 4: Navbar UI — pending
- ⏳ Task 5: Tests — pending

Last commit: "feat(auth): add Google OAuth provider"

Pick up where we left off on Task 3?
```

## Example Session

```
User: Let's build the auth feature

Agent: Checking your repo... You're on main with a clean tree. 
Let me create a feature branch.

$ git checkout -b feat/user-auth

Starting Task 1: Set up NextAuth with Prisma adapter

Installing dependencies...
$ npm install next-auth @next-auth/prisma-adapter

Creating auth route...
[writes app/api/auth/[...nextauth]/route.ts]

Adding Prisma schema...
[updates prisma/schema.prisma]

Running migration...
$ npx prisma migrate dev --name add-auth-tables

✅ Task 1 complete
   → Committed: "feat(auth): set up NextAuth with Prisma adapter"

---

Starting Task 2: OAuth providers

Before I continue, I need the OAuth credentials. Have you set these up?
- GitHub: Settings → Developer settings → OAuth Apps
- Google: Cloud Console → APIs → Credentials

Once you have them, add to .env:
```
GITHUB_ID=your_id
GITHUB_SECRET=your_secret
GOOGLE_ID=your_id
GOOGLE_SECRET=your_secret
```

Let me know when ready!

User: Done, credentials are in .env

Agent: Perfect. Adding providers...

[updates auth configuration]

Let me test the flow real quick...
$ npm run dev

Testing GitHub sign-in... ✓ Redirects correctly
Testing Google sign-in... ✓ Redirects correctly

✅ Task 2 complete
   → Committed: "feat(auth): add GitHub and Google OAuth providers"

---

Starting Task 3: Auth middleware...

[continues through remaining tasks]
```

## Quality Checklist

For each task:
- [ ] Code follows existing patterns
- [ ] No obvious bugs introduced
- [ ] Tests pass (existing + new)
- [ ] Committed with clear message
- [ ] State file updated

For overall implementation:
- [ ] All planned tasks complete
- [ ] Feature branch is clean (no debug code)
- [ ] No unintended changes to other features
- [ ] Ready for review

## Anti-Patterns

### ❌ Big Bang Commits
"Implement entire auth feature" as one commit. Break it up.

### ❌ Silent Progress
Coding for 30 minutes with no updates. Checkpoint regularly.

### ❌ Perfectionist Loop
Refactoring the same code 5 times. Ship good enough.

### ❌ Skipping All Tests
"We'll test later." Test the risky bits now.

### ❌ Ignoring Blockers
Pushing through when stuck instead of flagging the issue.

### ❌ Scope Creep Without Acknowledgment
Adding features not in the plan without discussing.
