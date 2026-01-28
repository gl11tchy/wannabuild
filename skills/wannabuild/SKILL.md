# WannaBuild - Conversational Development Framework

> "What do you wanna build?"

WannaBuild is a 6-phase development framework that meets you where you are. No commands to memorize, no rigid processes — just a conversation about what you're building.

## Philosophy

See [references/philosophy.md](references/philosophy.md) for the full manifesto.

**TL;DR:** Build like an indie hacker, ship like a pro. Flexibility over dogma.

---

## 🤖 Multi-Agent Architecture

WannaBuild isn't just one agent doing everything — it's **18 specialist agents** working in parallel groups across 6 phases:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           WANNABUILD AGENT ARMY                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  BRAINSTORM (3 agents)     PLAN (4 agents)         IMPLEMENT (1 agent)      │
│  ┌─────────────────┐       ┌──────────────────┐    ┌──────────────────┐     │
│  │ • Scope Analyst │       │ • Task Decomposer│    │ • Implementer    │     │
│  │ • Tech Advisor  │       │ • Dep. Mapper    │    │                  │     │
│  │ • UX Perspective│       │ • Risk Assessor  │    │                  │     │
│  │                 │       │ • Scope Creep    │    │                  │     │
│  └─────────────────┘       └──────────────────┘    └──────────────────┘     │
│                                                              │               │
│                                                              ▼               │
│  DOCUMENT (3 agents)       SHIP (2 agents)         REVIEW (5 agents)        │
│  ┌─────────────────┐       ┌──────────────────┐    ┌──────────────────┐     │
│  │ • README Updater│  ◄─── │ • PR Craftsman   │◄───│ • Security       │     │
│  │ • API Doc Gen   │       │ • CI Guardian    │    │ • Performance    │     │
│  │ • Changelog     │       │                  │    │ • Architecture   │     │
│  │                 │       │                  │    │ • Testing        │     │
│  │                 │       │                  │    │ • DX/Quality     │     │
│  └─────────────────┘       └──────────────────┘    └──────────────────┘     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Why parallel agents?**
- **Deeper analysis**: Each specialist focuses on one thing and does it well
- **Faster execution**: Parallel agents complete in the time of the slowest, not the sum
- **Better coverage**: Nothing slips through when multiple experts check
- **Higher quality**: The implement↔review loop ensures issues are fixed, not shipped

---

## The Six Phases

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  BRAINSTORM  │ ──▶ │     PLAN     │ ──▶ │  IMPLEMENT   │
│   "what if"  │     │ "how exactly"│     │  "let's go"  │
└──────────────┘     └──────────────┘     └──────────────┘
                                                 │
                                                 ▼
                                          ┌─────────────────────────────────┐
┌──────────────┐     ┌──────────────┐     │  🔄 QUALITY LOOP               │
│   DOCUMENT   │ ◀── │     SHIP     │ ◀── │  ┌──────────┐   ┌──────────┐  │
│  "for later" │     │  "send it"   │     │  │IMPLEMENT │◀─▶│  REVIEW  │  │
└──────────────┘     └──────────────┘     │  └──────────┘   └──────────┘  │
                                          │  Loop until UNANIMOUS APPROVAL │
                                          └─────────────────────────────────┘
```

## ⭐ The Quality Loop (Killer Feature)

**This is what makes WannaBuild different.** Review isn't a checkbox — it's an iterative refinement process that continues until the code is genuinely excellent.

### How It Works

```
┌─────────────────────────────────────────────────────────────────────┐
│                        QUALITY LOOP                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌──────────────┐                        ┌──────────────────────┐  │
│   │  IMPLEMENTER │ ─────────────────────▶ │   5 REVIEW AGENTS    │  │
│   │              │                        │   (run in parallel)  │  │
│   │  - Writes/   │                        │                      │  │
│   │    fixes code│                        │  🔒 Security         │  │
│   │  - Addresses │                        │  ⚡ Performance      │  │
│   │    feedback  │                        │  🏗️ Architecture     │  │
│   │              │                        │  🧪 Testing          │  │
│   │              │                        │  ✨ DX/Quality       │  │
│   └──────────────┘                        └──────────────────────┘  │
│          ▲                                          │               │
│          │                                          ▼               │
│          │                                 ┌─────────────────┐      │
│          │                                 │   VOTE TALLY    │      │
│          │                                 │                 │      │
│          │         ┌───────────────────────│  All 5 PASS?    │      │
│          │         │ NO                    └─────────────────┘      │
│          │         ▼                                │               │
│   ┌──────────────────────┐                         │ YES           │
│   │  AGGREGATE FEEDBACK  │                         ▼               │
│   │                      │                 ┌─────────────────┐      │
│   │  - Consolidate fails │                 │  ✅ UNANIMOUS   │      │
│   │  - Prioritize issues │                 │    APPROVAL     │      │
│   │  - Track iteration # │                 │                 │      │
│   └──────────────────────┘                 │  → Ship Phase   │      │
│          │                                 └─────────────────┘      │
│          │ iteration < MAX                                          │
│          └──────────────────────────────────────────────────────▶   │
│                                                                      │
│   If iteration >= MAX (3-5): ESCALATE TO HUMAN                      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Loop Rules

1. **Entry:** Implementer completes initial work, triggers review
2. **Parallel Review:** All 5 specialists run simultaneously
3. **Voting:** Each agent returns PASS ✅ or FAIL ❌ with feedback
4. **Aggregation:** If ANY agent fails, feedback is consolidated
5. **Iteration:** Implementer receives feedback, makes fixes
6. **Re-review:** All 5 agents run again (fresh evaluation)
7. **Exit:** Loop continues until **UNANIMOUS APPROVAL** (all 5 PASS)
8. **Escalation:** After 3-5 iterations, escalate to human

### ⛔ CRITICAL: Separation of Roles

**The orchestrator NEVER fixes code. NEVER.**

When reviewers find issues:
1. ❌ DO NOT fix the issue yourself
2. ❌ DO NOT skip the re-review after fixes
3. ✅ DO send feedback to the Implement phase
4. ✅ DO re-run ALL 5 reviewers after fixes
5. ✅ DO report bugs prominently (separate message, not buried)

**If you find yourself typing code to fix a reviewer's feedback, STOP.**
That's the implementer's job. Send it back.

### Bug Reporting Format

When reviewers find issues, report them prominently:

```
⚠️ REVIEW FOUND ISSUES

Iteration 1 of 4

FAILED (2 of 5):
• Best Practices: localStorage dismissal not persisting
• Architect: Same issue flagged

PASSED (3 of 5):
• Plan Verifier ✅
• Security ✅  
• Code Simplifier ✅

→ Sending feedback to Implementer...
```

Then after implementer fixes:

```
🔄 RE-RUNNING REVIEW (Iteration 2)

Spawning all 5 reviewers on fixed code...
```

Only ship when:
```
✅ UNANIMOUS APPROVAL (5/5)

All reviewers passed on iteration 2.
Issues fixed: localStorage dismissal persistence

→ Proceeding to Ship phase
```

### Why This Matters

| Traditional Review | WannaBuild Quality Loop |
|-------------------|------------------------|
| Review once, ship with comments | Iterate until excellent |
| "LGTM" culture | Unanimous specialist approval |
| One generalist reviewer | 5 parallel specialists |
| Issues become tech debt | Issues fixed before merge |
| Human bottleneck | Automated refinement |

| Phase | Skill | Agents | Purpose |
|-------|-------|--------|---------|
| 1. Brainstorm | `wannabuild-brainstorm` | 3 parallel | Scope Analyst + Tech Advisor + UX Perspective → rich spec |
| 2. Plan | `wannabuild-plan` | 4 parallel | Task Decomposer + Dependency Mapper + Risk Assessor + Scope Creep → battle-tested plan |
| 3. Implement | `wannabuild-implement` | 1 | Write code, run tests, commit incrementally |
| 4. Review | `elite-code-review` | 5 parallel | Security + Performance + Architecture + Testing + DX reviewers |
| 5. Ship | `wannabuild-ship` | 2 parallel | PR Craftsman + CI Guardian → clean merge |
| 6. Document | `wannabuild-document` | 3 parallel | README Updater + API Doc Generator + Changelog Writer |

**Total: 18 specialist agents** across 6 phases, with 17 running in parallel groups for maximum throughput.

## Trigger Conditions

WannaBuild activates on conversational cues, not commands.

### Natural Entry Points

| User Says | Detected Phase | Response |
|-----------|----------------|----------|
| "I want to build...", "What if we...", "I'm thinking about..." | Brainstorm | Start exploring the idea |
| "Let's figure out the tasks", "How should we approach..." | Plan | Structure the work |
| "Let's build this", "Start coding", "Implement..." | Implement | Begin execution |
| "Review this", "Check my code", "Is this good?" | Review | Trigger elite-code-review |
| "Ship it", "Ready to merge", "Let's deploy" | Ship | Prepare for merge |
| "Update the docs", "Document this" | Document | Update documentation |

### Phase Detection Algorithm

```
1. Check for explicit phase keywords
2. Check for existing WannaBuild state (.wannabuild/state.json)
3. Analyze conversation context (what artifacts exist?)
4. Ask if unclear: "Sounds like you want to [phase]. That right?"
```

## Quality Loop State Management

The orchestrator is responsible for managing the implement ↔ review loop.

### Loop State Schema

```json
// .wannabuild/loop-state.json
{
  "active": true,
  "iteration": 2,
  "maxIterations": 4,
  "startedAt": "2024-01-15T14:00:00Z",
  "history": [
    {
      "iteration": 1,
      "timestamp": "2024-01-15T14:00:00Z",
      "votes": {
        "security": { "status": "PASS", "feedback": null },
        "performance": { "status": "FAIL", "feedback": "N+1 query in getUserPosts()" },
        "architecture": { "status": "PASS", "feedback": null },
        "testing": { "status": "FAIL", "feedback": "Missing edge case: expired token" },
        "dx": { "status": "PASS", "feedback": null }
      },
      "unanimousPass": false,
      "aggregatedFeedback": [
        { "agent": "performance", "priority": "high", "issue": "N+1 query in getUserPosts()", "suggestion": "Use eager loading with include" },
        { "agent": "testing", "priority": "medium", "issue": "Missing edge case", "suggestion": "Add test for expired token scenario" }
      ]
    },
    {
      "iteration": 2,
      "timestamp": "2024-01-15T14:30:00Z",
      "votes": {
        "security": { "status": "PASS" },
        "performance": { "status": "PASS" },
        "architecture": { "status": "PASS" },
        "testing": { "status": "PASS" },
        "dx": { "status": "PASS" }
      },
      "unanimousPass": true,
      "aggregatedFeedback": []
    }
  ],
  "result": "approved"  // "approved" | "escalated" | "in-progress"
}
```

### Orchestrator Loop Logic

```python
def manage_quality_loop(state):
    while state.iteration <= state.maxIterations:
        # 1. Trigger parallel review
        votes = run_all_reviewers_parallel(state.changedFiles)
        
        # 2. Record this iteration
        state.history.append({
            "iteration": state.iteration,
            "votes": votes,
            "unanimousPass": all(v.status == "PASS" for v in votes.values())
        })
        
        # 3. Check for unanimous approval
        if all_passed(votes):
            state.result = "approved"
            return handoff_to_ship(state)
        
        # 4. Aggregate feedback from failures
        feedback = aggregate_feedback(votes)
        state.history[-1]["aggregatedFeedback"] = feedback
        
        # 5. Check iteration limit
        if state.iteration >= state.maxIterations:
            state.result = "escalated"
            return escalate_to_human(state, feedback)
        
        # 6. Send back to implementer
        handoff_to_implement(state, feedback, iteration_mode=True)
        state.iteration += 1
```

### Feedback Aggregation

When failures occur, the orchestrator consolidates feedback:

```json
{
  "iterationNumber": 2,
  "totalAgents": 5,
  "passed": 3,
  "failed": 2,
  "feedback": [
    {
      "agent": "performance",
      "priority": "high",
      "issue": "N+1 query detected in getUserPosts() - fires separate query for each post's author",
      "location": "src/api/posts.ts:45",
      "suggestion": "Use Prisma include or join to eager-load authors",
      "codeSnippet": "const posts = await prisma.post.findMany();\nposts.forEach(p => p.author = await getUser(p.authorId));"
    },
    {
      "agent": "testing", 
      "priority": "medium",
      "issue": "No test coverage for expired token edge case",
      "location": "src/api/auth.ts:authenticate()",
      "suggestion": "Add test: 'returns 401 when token is expired'",
      "codeSnippet": null
    }
  ],
  "message": "2 of 5 reviewers flagged issues. Please address the feedback above and the loop will re-run."
}
```

### Escalation Protocol

After MAX iterations without unanimous approval:

```
⚠️ Quality Loop Escalation

We've iterated 4 times but can't reach unanimous approval.

**Persistent Issues:**
- Performance agent keeps flagging the query approach
- Testing agent wants more edge case coverage

**Options:**
1. **Override** — You decide it's good enough, ship anyway
2. **Discuss** — Let's talk through the remaining issues
3. **Defer** — Address these as follow-up tickets
4. **Rethink** — Maybe the approach needs to change

What would you like to do?
```

## State Management

WannaBuild tracks project state in `.wannabuild/`:

```
.wannabuild/
├── state.json          # Current phase, timestamps, metadata
├── loop-state.json     # Quality loop tracking (iteration, votes, feedback)
├── spec.md             # Brainstorm output (lightweight spec)
├── plan.md             # Task breakdown from planning
├── decisions.md        # Architectural decisions log
└── sessions/           # Conversation context (optional)
    └── 2024-01-15.md
```

### state.json Schema

```json
{
  "project": "feature-name",
  "currentPhase": "quality-loop",
  "phases": {
    "brainstorm": {
      "status": "complete",
      "completedAt": "2024-01-15T10:00:00Z",
      "artifact": "spec.md"
    },
    "plan": {
      "status": "complete", 
      "completedAt": "2024-01-15T11:00:00Z",
      "artifact": "plan.md",
      "tasksTotal": 5,
      "tasksComplete": 5
    },
    "implement": {
      "status": "iterating",
      "startedAt": "2024-01-15T12:00:00Z",
      "branch": "feat/new-feature",
      "iterationMode": true,
      "currentIteration": 2
    },
    "review": { 
      "status": "in-loop",
      "loopStateFile": "loop-state.json",
      "lastResult": "partial-pass",
      "passedAgents": ["security", "architecture", "dx"],
      "failedAgents": ["performance", "testing"]
    },
    "ship": { "status": "pending" },
    "document": { "status": "pending" }
  },
  "qualityLoop": {
    "active": true,
    "iteration": 2,
    "maxIterations": 4,
    "stateFile": "loop-state.json"
  },
  "context": {
    "techStack": ["typescript", "react", "postgres"],
    "repo": "/home/user/myproject"
  }
}
```

## Orchestration Behavior

### Phase Transitions

**Normal flow:** Each phase naturally suggests the next.

```
Brainstorm complete → "Spec looks good. Want to plan the tasks?"
Plan complete → "Ready to start building?"
Implement complete → "Code's done. Run it through review?"
Review passed → "Looking clean. Ship it?"
Ship complete → "Merged! Should I update the docs?"
```

**Skip phases when appropriate:**
- Small change? Skip brainstorm, jump to implement
- Docs-only change? Skip review
- Hotfix? Skip brainstorm + plan
- Already have a spec? Start at plan

### Handling Interruptions

```
User: "Actually, let's go back to planning"
→ Save current state, switch to plan phase

User: "Pause this, I need to work on something else"
→ Save state, note context for resumption

User: "What were we working on?"
→ Read state.json, summarize current position
```

### Multi-Project Support

When user starts a new feature while another is in progress:
1. Save current project state
2. Ask: "Want to pause [current] and start [new]? Or finish this first?"
3. Track multiple projects in separate `.wannabuild-{name}/` dirs

## Integration Points

### With Elite Code Review (Quality Loop)

The elite-code-review skill is the **review** side of the quality loop. It must return structured verdicts.

**Required Response Format from elite-code-review:**

```json
{
  "timestamp": "2024-01-15T14:00:00Z",
  "reviewedFiles": ["src/api/auth.ts", "src/middleware.ts"],
  "agents": {
    "security": {
      "status": "PASS",
      "confidence": 0.95,
      "feedback": null,
      "issues": []
    },
    "performance": {
      "status": "FAIL",
      "confidence": 0.88,
      "feedback": "Detected potential performance issue",
      "issues": [
        {
          "severity": "high",
          "location": "src/api/posts.ts:45",
          "issue": "N+1 query pattern - separate DB call per post author",
          "suggestion": "Use eager loading: prisma.post.findMany({ include: { author: true } })",
          "codeSnippet": "posts.forEach(p => p.author = await getUser(p.authorId))"
        }
      ]
    },
    "architecture": {
      "status": "PASS",
      "confidence": 0.92,
      "feedback": null,
      "issues": []
    },
    "testing": {
      "status": "FAIL", 
      "confidence": 0.85,
      "feedback": "Missing critical edge case coverage",
      "issues": [
        {
          "severity": "medium",
          "location": "src/api/auth.ts:authenticate()",
          "issue": "No test for expired token scenario",
          "suggestion": "Add test case: should return 401 when token is expired"
        }
      ]
    },
    "dx": {
      "status": "PASS",
      "confidence": 0.90,
      "feedback": null,
      "issues": []
    }
  },
  "summary": {
    "totalAgents": 5,
    "passed": 3,
    "failed": 2,
    "unanimousApproval": false
  }
}
```

**Loop Integration Flow:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Implementer signals "ready for review"                      │
│                           │                                      │
│                           ▼                                      │
│  2. Orchestrator invokes elite-code-review                      │
│     - Passes: changed files, iteration number                   │
│     - Receives: structured verdict (above format)               │
│                           │                                      │
│                           ▼                                      │
│  3. Orchestrator checks: unanimousApproval == true?             │
│                           │                                      │
│            ┌──────────────┴──────────────┐                      │
│            │ YES                         │ NO                   │
│            ▼                             ▼                      │
│     ┌──────────────┐           ┌─────────────────────┐          │
│     │  → Ship      │           │ Aggregate feedback  │          │
│     │    Phase     │           │ Check iteration cap │          │
│     └──────────────┘           └─────────────────────┘          │
│                                          │                      │
│                          ┌───────────────┴───────────┐          │
│                          │ iteration < MAX           │ >= MAX   │
│                          ▼                           ▼          │
│                   ┌──────────────┐           ┌─────────────┐    │
│                   │ → Implement  │           │ → Escalate  │    │
│                   │   (iterate)  │           │   to human  │    │
│                   └──────────────┘           └─────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Handoff: Orchestrator → elite-code-review:**

```json
{
  "from": "wannabuild",
  "to": "elite-code-review",
  "action": "review",
  "iteration": 2,
  "branch": "feat/user-auth",
  "changedFiles": ["src/api/auth.ts", "src/middleware.ts"],
  "previousFeedback": [
    { "agent": "performance", "issue": "N+1 query", "addressed": true },
    { "agent": "testing", "issue": "Missing edge case", "addressed": true }
  ],
  "expectFormat": "wannabuild-verdict"
}
```

**Handoff: elite-code-review → Orchestrator:**

```json
{
  "from": "elite-code-review",
  "to": "wannabuild",
  "verdict": { /* structured response above */ },
  "recommendation": "iterate"  // "approve" | "iterate" | "escalate"
}
```

### With Git

WannaBuild expects git but doesn't require it:
- **With git:** Creates branches, commits incrementally, prepares PRs
- **Without git:** Still works, just skips git-specific features

### With CI/CD

If CI config detected (.github/workflows, .gitlab-ci.yml, etc.):
- Ship phase waits for CI to pass
- Shows CI status during ship phase
- Suggests fixes if CI fails

## Artifacts Produced

| Phase | Artifact | Location |
|-------|----------|----------|
| Brainstorm | Lightweight spec | `.wannabuild/spec.md` |
| Plan | Task breakdown | `.wannabuild/plan.md` |
| Implement | Code + commits | Working tree + git history |
| Quality Loop | Loop state & history | `.wannabuild/loop-state.json` |
| Review | Verdict per iteration | Stored in `loop-state.json` history |
| Ship | PR/merge | Git remote |
| Document | Updated docs | README.md, CHANGELOG.md, etc. |

## Configuration (Optional)

Create `.wannabuild/config.json` to customize:

```json
{
  "skipPhases": [],
  "defaultBranch": "main",
  "commitStyle": "conventional",
  "reviewThreshold": "thorough",
  "autoDocument": true,
  "preferredStack": {
    "testing": "vitest",
    "linting": "eslint"
  }
}
```

## Example Session

```
User: "I want to add user authentication to this app"

WannaBuild: Looking at your codebase... I see a Next.js app with Prisma.
            
            For auth, we could go a few directions:
            - NextAuth.js (quick, lots of providers)
            - Clerk (hosted, zero-config)
            - Roll your own with JWT (more control, more work)
            
            What's your vibe? Quick and easy, or full control?

User: "NextAuth sounds good, keep it simple"

WannaBuild: Perfect. So the scope is:
            - Add NextAuth with GitHub + Google providers
            - Protected routes for /dashboard/*
            - Session in navbar (avatar, logout)
            
            Anything I'm missing? Or should we plan the tasks?

User: "That's it, let's plan"

WannaBuild: [Transitions to Plan phase...]
```

## Example: Quality Loop in Action

```
[After implementation completes...]

WannaBuild: ✅ All 5 tasks complete. Entering quality loop...

            🔄 Running 5 review specialists in parallel...

            [30 seconds later]

            Review results (Iteration 1):
            ✅ Security — PASS
            ❌ Performance — FAIL: N+1 query in getUserPosts()
            ✅ Architecture — PASS  
            ❌ Testing — FAIL: Missing edge case for expired token
            ✅ DX — PASS

            3/5 passed. Sending feedback to implementer...

[Implementer addresses feedback...]

WannaBuild: ✅ Feedback addressed. Re-running review...

            🔄 All 5 specialists evaluating updated code...

            Review results (Iteration 2):
            ✅ Security — PASS
            ✅ Performance — PASS (N+1 fixed)
            ✅ Architecture — PASS
            ✅ Testing — PASS (edge case added)
            ✅ DX — PASS

            🎉 UNANIMOUS APPROVAL after 2 iterations!

            Ready to ship?

User: "Ship it!"

WannaBuild: [Transitions to Ship phase with confidence...]
```

## Example: Quality Loop Escalation

```
[Iteration 4 of 4...]

WannaBuild: Review results (Iteration 4):
            ✅ Security — PASS
            ❌ Performance — FAIL (still flagging query optimization)
            ✅ Architecture — PASS
            ✅ Testing — PASS
            ✅ DX — PASS

            ⚠️ Max iterations reached (4/4)
            
            The performance agent has flagged issues in iterations 2, 3, and 4.
            Latest issue: "Missing index on author_id for large datasets"

            Options:
            1. **Override** — You approve, ship without the index
            2. **Add Index** — Create migration for index (bigger change)
            3. **Defer** — Ship now, create follow-up ticket
            4. **Discuss** — Let's talk through the trade-off

User: "Defer it, we don't have that many users yet"

WannaBuild: Got it. Shipping with follow-up ticket for index.
            
            Created: TECH-142 "Add index on posts.author_id before scaling"
            
            [Proceeds to Ship phase...]
```

## When NOT to Use WannaBuild

- **Quick fixes:** Just make the change, don't invoke a whole framework
- **Exploration:** Just exploring code? Don't need phases
- **Learning:** Trying to understand code? Just ask directly
- **One-liner changes:** Overkill for trivial edits
- **Time-critical hotfixes:** The quality loop takes time; emergency fixes might skip it
- **Prototype/throwaway code:** The loop ensures quality for production code, not experiments

## Handoff Protocol

When handing off to a phase-specific skill:

### Standard Phase Handoff
```json
{
  "from": "wannabuild",
  "to": "wannabuild-implement",
  "state": ".wannabuild/state.json",
  "context": {
    "spec": ".wannabuild/spec.md",
    "plan": ".wannabuild/plan.md",
    "currentTask": 3
  }
}
```

### Quality Loop Handoffs

**Entering the loop (implement → review):**
```json
{
  "from": "wannabuild",
  "to": "elite-code-review",
  "action": "review-for-loop",
  "iteration": 1,
  "state": ".wannabuild/state.json",
  "loopState": ".wannabuild/loop-state.json",
  "branch": "feat/user-auth",
  "changedFiles": ["src/api/auth.ts", "src/middleware.ts"]
}
```

**Feedback to implementer:**
```json
{
  "from": "wannabuild",
  "to": "wannabuild-implement",
  "mode": "iteration",
  "iteration": 2,
  "state": ".wannabuild/state.json",
  "loopState": ".wannabuild/loop-state.json",
  "feedback": {
    "passed": 3,
    "failed": 2,
    "issues": [
      { "agent": "performance", "issue": "N+1 query", "priority": "high" },
      { "agent": "testing", "issue": "Missing test", "priority": "medium" }
    ]
  }
}
```

**Loop exit (unanimous approval):**
```json
{
  "from": "wannabuild",
  "to": "wannabuild-ship",
  "state": ".wannabuild/state.json",
  "loopState": ".wannabuild/loop-state.json",
  "branch": "feat/user-auth",
  "approval": {
    "unanimous": true,
    "iterations": 3,
    "agents": ["security", "performance", "architecture", "testing", "dx"]
  }
}
```

Each phase skill can operate independently but reads shared state.

See [references/quality-loop-protocol.md](references/quality-loop-protocol.md) for the complete protocol specification.
