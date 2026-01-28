# WannaBuild - Conversational Development Framework

> "What do you wanna build?"

WannaBuild is a 6-phase development framework that meets you where you are. No commands to memorize, no rigid processes — just a conversation about what you're building.

## Philosophy

See [references/philosophy.md](references/philosophy.md) for the full manifesto.

**TL;DR:** Build like an indie hacker, ship like a pro. Flexibility over dogma.

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

### Why This Matters

| Traditional Review | WannaBuild Quality Loop |
|-------------------|------------------------|
| Review once, ship with comments | Iterate until excellent |
| "LGTM" culture | Unanimous specialist approval |
| One generalist reviewer | 5 parallel specialists |
| Issues become tech debt | Issues fixed before merge |
| Human bottleneck | Automated refinement |

| Phase | Skill | Purpose |
|-------|-------|---------|
| 1. Brainstorm | `wannabuild-brainstorm` | Explore ideas, analyze codebase, produce lightweight spec |
| 2. Plan | `wannabuild-plan` | Break into tasks, identify risks, estimate effort |
| 3. Implement | `wannabuild-implement` | Write code, run tests, commit incrementally |
| 4. Review | `elite-code-review` | 5 parallel specialist reviewers (existing skill) |
| 5. Ship | `wannabuild-ship` | Prepare PR, run checks, handle merge |
| 6. Document | `wannabuild-document` | Update README, changelog, API docs |

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
| Review | Review report | `.wannabuild/review.md` |
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

## When NOT to Use WannaBuild

- **Quick fixes:** Just make the change, don't invoke a whole framework
- **Exploration:** Just exploring code? Don't need phases
- **Learning:** Trying to understand code? Just ask directly
- **One-liner changes:** Overkill for trivial edits

## Handoff Protocol

When handing off to a phase-specific skill:

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

Each phase skill can operate independently but reads shared state.
