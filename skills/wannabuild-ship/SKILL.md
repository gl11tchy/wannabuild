# WannaBuild: Ship Phase

> "Let's get this merged."

The Ship phase prepares your code for merge and handles the mechanics of getting it into the main branch.

## Purpose

Get code from feature branch to main:
1. Prepare branch for merge (rebase, squash, clean up)
2. Create PR with clear description
3. Run final checks (CI, lint, tests)
4. Handle merge conflicts
5. Complete the merge

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
