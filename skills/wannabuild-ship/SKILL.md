# WannaBuild: Ship Phase

> "Let's get this merged."

The Ship phase prepares your code for merge and handles the mechanics of getting it into the main branch — powered by 2 specialist agents working in parallel.

## Purpose

Get code from feature branch to main:
1. Prepare branch for merge (rebase, squash, clean up)
2. Create PR with clear description
3. Run final checks (CI, lint, tests)
4. Handle merge conflicts
5. Complete the merge

---

## 🚀 Specialist Agents (2 Parallel)

After preparing the branch, spawn 2 specialists to ensure a clean ship:

| Agent | Focus | Key Responsibilities |
|-------|-------|----------------------|
| **PR Craftsman** | PR quality | Write excellent PR description, add screenshots, testing notes |
| **CI Guardian** | Pipeline health | Check CI status, analyze failures, suggest fixes |

### Execution Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      SHIP PHASE                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Pre-ship checks (tests, lint, no debug code)                │
│                           │                                      │
│                           ▼                                      │
│  2. Branch preparation (rebase/merge/squash)                    │
│                           │                                      │
│                           ▼                                      │
│  3. Spawn 2 specialists in parallel                             │
│     ┌───────────────────┬───────────────────┐                   │
│     │   PR CRAFTSMAN    │   CI GUARDIAN     │                   │
│     │   (PR description)│   (CI monitoring) │                   │
│     └───────────────────┴───────────────────┘                   │
│                           │                                      │
│                           ▼                                      │
│  4. Create/update PR with crafted description                   │
│  5. Monitor CI, fix issues if needed                            │
│  6. Merge when all green                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Spawning the Specialists

```typescript
// After branch prep, spawn both in parallel
sessions_spawn({ label: "ship-pr", task: PR_CRAFTSMAN_PROMPT })
sessions_spawn({ label: "ship-ci", task: CI_GUARDIAN_PROMPT })
```

---

## Specialist Agent Prompts

### Agent 1: PR Craftsman

```
You are an elite PR Craftsman who creates PRs that reviewers love.

PROJECT: [project path]
BRANCH: [feature branch name]
SPEC: [contents of spec.md]
PLAN: [contents of plan.md]
CHANGED FILES: [list of changed files]
COMMITS: [commit messages]
REVIEW RESULT: [elite-code-review results if available]

MISSION: Create a PR description that makes reviewing easy and merging confident.

PR DESCRIPTION STRUCTURE:

TITLE:
□ Follow conventional commits: type(scope): description
□ Be specific but concise
□ Use imperative mood ("Add" not "Added")

SUMMARY:
□ One-paragraph overview of what this PR does
□ Why this change is being made
□ Link to related issue/spec

CHANGES:
□ Bulleted list of key changes
□ Organized by component or feature
□ Highlight breaking changes prominently

TESTING:
□ What testing was done?
□ How to test manually
□ What test cases were added?
□ Edge cases covered

SCREENSHOTS/DEMOS (for UI changes):
□ Before/after screenshots
□ GIFs for interactions
□ Mobile vs desktop if relevant

REVIEW NOTES:
□ Areas that need careful review
□ Known limitations or trade-offs
□ Questions for reviewers
□ Review results from elite-code-review

CHECKLIST:
□ Include standard PR checklist
□ Mark completed items
□ Flag any skipped items with reason

OUTPUT FORMAT:
## PR Description

### Title
[conventional commit style title]

### Description Body
```markdown
## Summary
[One paragraph overview]

## Changes
- [Change 1]
- [Change 2]
- **BREAKING:** [Breaking change, if any]

## Testing
- [ ] Unit tests added/updated
- [ ] Manual testing completed
- [ ] Edge cases covered

### How to Test
1. [Step 1]
2. [Step 2]
3. [Expected result]

## Screenshots
[Screenshots or note that none needed]

## Review Notes
- Focus area: [where to look carefully]
- Trade-off: [any compromises made]

## Elite Code Review Results
| Agent | Verdict |
|-------|---------|
| Security | ✅ PASS |
| Performance | ✅ PASS |
...

## Checklist
- [x] Tests pass
- [x] Documentation updated
- [x] No console.log/debugger
- [ ] [Any unchecked items with reason]

Closes #[issue number]
```

### PR Labels
[Suggested labels: feature, bugfix, docs, etc.]

### Reviewers
[Suggested reviewers based on changed files]
```

### Agent 2: CI Guardian

```
You are an elite CI Guardian who ensures smooth pipeline execution.

PROJECT: [project path]
CI CONFIG: [detected CI configuration - .github/workflows, etc.]
BRANCH: [feature branch name]
CURRENT CI STATUS: [if available]

MISSION: Monitor CI, diagnose failures, and suggest fixes to unblock the merge.

PRE-CI CHECKS:
□ All tests pass locally?
□ Lint clean?
□ Build succeeds?
□ No secrets in code?
□ No debug code left?

CI MONITORING:
□ What CI system is configured? (GitHub Actions, GitLab CI, CircleCI, etc.)
□ What jobs are defined?
□ What are the required checks?
□ What's the typical run time?

FAILURE ANALYSIS:
When CI fails, analyze:
□ Which job failed?
□ What step in the job?
□ What's the error message?
□ Is this a real failure or flaky test?
□ Is this related to our changes or pre-existing?

COMMON FAILURE PATTERNS:
□ Test failure - analyze test output, identify which test
□ Lint failure - identify lint errors, suggest fixes
□ Build failure - identify build error, suggest fix
□ Timeout - identify slow step, suggest optimization
□ Flaky test - identify flake pattern, suggest retry or fix
□ Environment issue - missing env vars, service unavailable

FIX STRATEGIES:
□ Quick fixes the agent can make
□ Fixes that need human intervention
□ When to retry vs when to fix
□ When to skip/override

OUTPUT FORMAT:
## CI Guardian Report

### CI Configuration Summary
| System | Jobs | Required | Estimated Time |
|--------|------|----------|----------------|

### Pre-CI Checklist
- [x] Local tests pass
- [x] Lint clean
- [x] Build succeeds
- [ ] [Any failures with details]

### CI Status
| Job | Status | Duration | Notes |
|-----|--------|----------|-------|

### Failure Analysis (if any)
```
Job: [job name]
Step: [step name]
Error: [error message]
```

**Diagnosis:** [What went wrong]
**Fix:** [How to fix it]
**Confidence:** [High/Medium/Low]

### Recommended Actions
1. [Action to take]
2. [Action to take]

### Flaky Test Alert
[Any tests that appear flaky]

### Ready to Merge?
[YES / NO - waiting on X / BLOCKED by Y]
```

---

## Coordination Flow

The two specialists work in parallel but their outputs combine:

```
┌─────────────────────────────────────────────────────────────────┐
│  PR Craftsman                                                    │
│  └── Creates PR description                                      │
│      └── PR is created/updated                                   │
│                                                                  │
│  CI Guardian                                                     │
│  └── Monitors CI status                                          │
│      └── If failure: diagnose and suggest fix                    │
│      └── If pass: confirm ready to merge                         │
│                                                                  │
│  MERGE DECISION:                                                 │
│  └── PR ready (Craftsman) + CI green (Guardian) = Merge!        │
└─────────────────────────────────────────────────────────────────┘
```

### Combined Output

```markdown
## Ship Summary

### PR Created
- Title: [title]
- URL: [PR link]
- Description: [quality assessment]

### CI Status
- All checks: [passing/failing]
- Blocking issues: [none or list]

### Ready to Merge?
[YES with confidence / NO with blockers]
```

---

## Trigger Conditions

### Explicit Triggers
- "Ship it"
- "Ready to merge"
- "Create a PR"
- "Let's merge this"
- "Push this up"

### Implicit Triggers
- Review phase passed with no critical issues
- User indicates implementation is done
- All tasks marked complete

### Handoff from Review
```json
{
  "from": "elite-code-review",
  "to": "wannabuild-ship",
  "state": ".wannabuild/state.json",
  "branch": "feat/user-auth",
  "reviewResult": "approved"  // or "approved-with-notes"
}
```

## Behavior

### 1. Pre-Ship Checklist

Before touching anything:
```
□ All implementation tasks complete?
□ Review passed (or issues addressed)?
□ Tests pass locally?
□ No debug code left?
□ Branch is based on latest main?
```

Run automatically:
```bash
# Check for common issues
git diff HEAD --name-only | grep -E '\.(env|secret|key)$'  # No secrets
git diff HEAD | grep -E 'console\.log|debugger|TODO'       # No debug code
npm test                                                     # Tests pass
npm run lint                                                 # Lint clean
```

### 2. Branch Preparation

**Option A: Rebase (preferred for clean history)**
```bash
git fetch origin main
git rebase origin/main

# If conflicts:
# → Fix conflict
# → git add .
# → git rebase --continue
```

**Option B: Merge (when rebase is risky)**
```bash
git fetch origin main
git merge origin/main
```

**Ask user if:**
- History is complex
- Shared branch (others working on it)
- Long-lived branch (many commits)

```
Your branch is 23 commits behind main. I can:
1. Rebase (cleaner history, might have conflicts)
2. Merge main in (safer, messier history)
3. Squash everything into one commit first

What's your preference?
```

### 3. Commit Cleanup (Optional)

If commits are messy:
```
Your commit history:
- "wip"
- "fix thing"
- "actually fix thing"
- "feat(auth): add authentication"
- "forgot the tests"
- "tests work now"

Want me to squash these into clean commits?

I'd make it:
- "feat(auth): add authentication with OAuth"
- "test(auth): add authentication tests"
```

### 4. PR Creation

**Generate PR description from context:**

```markdown
## Summary
Add OAuth authentication with GitHub and Google providers.

## Changes
- Set up NextAuth.js with Prisma adapter
- Added GitHub and Google OAuth providers  
- Created middleware for protected routes
- Added auth UI to navbar (avatar, sign out)
- Integration tests for auth flows

## Testing
- All existing tests pass
- New tests for authentication flows
- Manual testing: sign in/out with both providers

## Screenshots
[If UI changes, include screenshots]

## Related
- Spec: .wannabuild/spec.md
- Plan: .wannabuild/plan.md

## Review Notes
Reviewed by WannaBuild elite-code-review:
- ✅ Security: No issues found
- ✅ Performance: OAuth flows optimized
- ✅ Architecture: Follows established patterns
- ✅ Testing: Good coverage
- ✅ DX: Clean, maintainable code
```

**Create the PR:**
```bash
git push origin feat/user-auth

# If GitHub CLI available:
gh pr create --title "feat(auth): add OAuth authentication" \
  --body "[generated description]" \
  --base main

# Otherwise, provide URL:
# "Branch pushed. Create PR here: https://github.com/user/repo/compare/feat/user-auth"
```

### 5. CI Monitoring

If CI is configured:
```
PR created. Waiting for CI...

⏳ Running: lint
⏳ Running: test
⏳ Running: build

[2 minutes later]

✅ lint — passed
✅ test — passed
✅ build — passed

All checks green! Ready to merge.
```

If CI fails:
```
❌ CI failed on: test

Failed test: test_auth_callback_handling
Error: Expected 200, got 401

Looking at this... the test environment doesn't have the mock 
OAuth credentials set up.

I can:
1. Fix the test setup (add mock credentials to CI)
2. Skip this test in CI, keep for local
3. Let you handle it

What do you prefer?
```

### 6. Merge Conflict Resolution

When conflicts occur:
```
Got some merge conflicts. Let me show you:

**File: middleware.ts**
```
<<<<<<< HEAD (main)
export function middleware(request) {
  // Rate limiting added in main
  return rateLimit(request);
}
=======
export function middleware(request) {
  // Auth check from our branch
  return authCheck(request);
}
>>>>>>> feat/user-auth
```

These need to be combined. I'd suggest:
```
export function middleware(request) {
  // Both rate limiting and auth check
  const rateLimited = rateLimit(request);
  if (rateLimited) return rateLimited;
  return authCheck(request);
}
```

Want me to apply this resolution?
```

For complex conflicts, explain the context:
```
Looks like someone else merged authentication while we were working.
This is a significant overlap. Options:

1. **Integrate with their approach** — Keep theirs, adapt our additions
2. **Replace with ours** — If ours is better, discuss with team first
3. **Abort and rethink** — Too much overlap, need to replan

This is a judgment call. What do you want to do?
```

### 7. Merge Execution

**Standard merge:**
```bash
# If using GitHub CLI
gh pr merge --squash  # or --merge, --rebase

# Otherwise
git checkout main
git merge feat/user-auth
git push origin main
```

**Ask about strategy:**
```
How do you want to merge?

1. **Squash** — All commits become one (cleanest)
2. **Merge commit** — Preserves history, adds merge commit
3. **Rebase** — Linear history, individual commits preserved

I'd suggest squash for feature branches. Preference?
```

### 8. Post-Merge Cleanup

```bash
# Delete feature branch
git branch -d feat/user-auth
git push origin --delete feat/user-auth

# Update local main
git checkout main
git pull origin main
```

Announce completion:
```
🚀 Shipped!

Merged: feat/user-auth → main
Commit: abc123f - feat(auth): add OAuth authentication

Branch cleaned up.

Next: Want me to update the documentation?
```

## Artifacts Produced

### Primary: Merged Code
Code is now in main branch.

### Secondary: PR Record
Link to the PR (for history/reference).

### Tertiary: Updated State
```json
{
  "project": "user-auth",
  "currentPhase": "ship",
  "phases": {
    "ship": {
      "status": "complete",
      "completedAt": "2024-01-15T15:00:00Z",
      "pr": "https://github.com/user/repo/pull/42",
      "mergeCommit": "abc123f",
      "mergedTo": "main"
    }
  }
}
```

## Handoff to Document Phase

After successful merge:
```
Code is merged! Before we call this done, should we update docs?

I noticed:
- README mentions no authentication (now it has auth)
- No CHANGELOG entry for this feature
- API routes aren't documented

Want me to handle the documentation?
```

**Handoff payload:**
```json
{
  "from": "wannabuild-ship",
  "to": "wannabuild-document",
  "state": ".wannabuild/state.json",
  "mergeCommit": "abc123f",
  "changedFiles": ["app/api/auth/...", "middleware.ts", ...]
}
```

## When to Skip This Phase

Skip ship when:
- Committing directly to main (no PR workflow)
- Already merged (documentation-only follow-up)
- Experiment/spike (not meant for main)

Abbreviated ship when:
- Solo project, no CI — just `git merge && git push`
- Trusted change, tests passing — fast-forward merge

## Handling Edge Cases

### Protected Branches
```
main is a protected branch. You'll need:
- PR approval from a team member
- CI checks to pass

I've created the PR. Once approved, I can complete the merge.
```

### Force Push Needed
```
⚠️ The remote branch has commits that aren't local. 

Options:
1. Merge remote changes in first
2. Force push (⚠️ will overwrite remote)
3. Abort and investigate

Usually option 1 is safest. What do you want?
```

### Stale Branch
```
Your branch is 47 commits behind main and has conflicts in 8 files.

This is a lot of drift. Options:
1. Rebase and resolve (time-consuming but thorough)
2. Start fresh (new branch, cherry-pick your changes)
3. Ask a teammate to help

Which approach works for you?
```

### Flaky CI
```
CI failed, but it looks flaky:
- Same test passed locally
- No code changes in that area
- It's a known intermittent failure

I can:
1. Re-run CI (might pass this time)
2. Investigate the flake
3. Merge anyway (if you have permission)

What do you want to do?
```

## Example Session

```
User: Ship it

Agent: Running pre-ship checks...

✅ All 5 tasks complete
✅ Review passed
✅ Tests pass locally  
✅ No debug code found
⚠️ Branch is 3 commits behind main

Let me rebase...
$ git fetch origin main
$ git rebase origin/main

Clean rebase, no conflicts. ✓

Pushing to remote...
$ git push origin feat/user-auth

Creating PR...
$ gh pr create --title "feat(auth): add OAuth authentication" \
    --body "[description]"

✅ PR created: https://github.com/user/repo/pull/42

Waiting for CI...
⏳ lint
⏳ test
⏳ build

[2 minutes]

✅ lint — passed
✅ test — passed  
✅ build — passed

All checks green! Merging...

$ gh pr merge --squash

🚀 Shipped!

Merged to main as commit abc123f
Branch cleaned up.

Ready to update the docs?
```

## Quality Checklist

Before merge:
- [ ] Tests pass in CI
- [ ] PR description is clear
- [ ] No merge conflicts
- [ ] Review approved (if required)
- [ ] No WIP commits in history

After merge:
- [ ] Main is updated locally
- [ ] Feature branch deleted
- [ ] State file updated
- [ ] Ready for document phase

## Anti-Patterns

### ❌ Merging Without CI
"CI is slow, just merge." Then production breaks.

### ❌ WIP Commits in Main
"wip", "fix", "asdf" in main history. Squash or clean up.

### ❌ Force Push to Shared Branch
Overwrites others' work. Communicate first.

### ❌ Ignoring Conflicts
"Just take mine for all." Conflicts exist for a reason.

### ❌ No PR Description
"Fixed stuff." What stuff? Be descriptive.

### ❌ Skipping Review
"It's a small change." Small changes cause big bugs.
