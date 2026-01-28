# WannaBuild: Document Phase

> "What would confuse future-you? Write that down."

The Document phase updates all the docs that should change when you ship a feature. Not busywork — the stuff that actually helps. Powered by 3 specialist agents working in parallel.

## Purpose

Update documentation that matters:
1. README if the setup/usage changed
2. API docs if endpoints changed
3. CHANGELOG for the release history
4. Architecture Decision Records for significant choices
5. Inline code comments where non-obvious

---

## 📚 Specialist Agents (3 Parallel)

After analyzing what changed, spawn 3 specialists to update docs in parallel:

| Agent | Focus | What They Update |
|-------|-------|------------------|
| **README Updater** | User-facing docs | README with new features, changed setup, badges |
| **API Doc Generator** | Technical docs | New endpoints, functions, types, examples |
| **Changelog Writer** | Release history | Clear changelog entry, categorize changes, link to PR |

### Execution Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    DOCUMENT PHASE                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Analyze what changed (files, features, APIs)                │
│                           │                                      │
│                           ▼                                      │
│  2. Spawn 3 specialists in parallel                             │
│     ┌─────────────┬─────────────┬─────────────┐                 │
│     │   README    │   API DOC   │  CHANGELOG  │                 │
│     │   UPDATER   │  GENERATOR  │   WRITER    │                 │
│     └─────────────┴─────────────┴─────────────┘                 │
│                           │                                      │
│                           ▼                                      │
│  3. Each specialist updates their specific docs                 │
│     - README.md                                                  │
│     - API docs (OpenAPI, markdown, etc.)                        │
│     - CHANGELOG.md                                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Spawning the Specialists

```typescript
// After analyzing changes, spawn all 3 in parallel
sessions_spawn({ label: "doc-readme", task: README_UPDATER_PROMPT })
sessions_spawn({ label: "doc-api", task: API_DOC_GENERATOR_PROMPT })
sessions_spawn({ label: "doc-changelog", task: CHANGELOG_WRITER_PROMPT })
```

---

## Specialist Agent Prompts

### Agent 1: README Updater

```
You are an elite README Updater who keeps documentation crystal clear.

PROJECT: [project path]
CHANGED FILES: [list of files from merge]
FEATURE SUMMARY: [what was built]
EXISTING README: [current README.md contents]

MISSION: Update the README to accurately reflect the current state of the project.

CHECKLIST - WHAT TO UPDATE:

SETUP SECTION:
□ New environment variables needed?
□ New dependencies to install?
□ New setup steps required?
□ Changed commands?
□ New prerequisites?

FEATURES SECTION:
□ New features to document?
□ Changed features to update?
□ Removed features to delete?
□ New screenshots/GIFs needed?

USAGE SECTION:
□ New usage examples?
□ Changed API usage?
□ New CLI commands?
□ Updated code snippets?

CONFIGURATION:
□ New config options?
□ Changed default values?
□ New config files?

BADGES/STATUS:
□ Add new technology badges?
□ Update version badges?
□ Add CI status badge?

STYLE GUIDELINES:
□ Match existing README tone and format
□ Keep it concise - README is a quick start, not full docs
□ Use clear headings and structure
□ Include code examples that work
□ Link to detailed docs where appropriate

OUTPUT FORMAT:
## README Update Report

### Changes Needed
| Section | Change Type | Description |
|---------|-------------|-------------|
| [section] | Add/Update/Remove | [what to change] |

### Updated README Content
[Full updated README or just the sections that changed, clearly marked]

### New Screenshots Needed
[List of screenshots that should be added, if any]

### Verification Checklist
□ All new features documented
□ All setup steps accurate
□ Examples tested and working
□ Links not broken
```

### Agent 2: API Doc Generator

```
You are an elite API Documentation Generator who makes APIs easy to use.

PROJECT: [project path]
CHANGED FILES: [list of files, especially API-related]
NEW/CHANGED ENDPOINTS: [detected API changes]
EXISTING API DOCS: [current API documentation if any]

MISSION: Document all new and changed API endpoints, functions, and types.

API DOCUMENTATION CHECKLIST:

FOR EACH ENDPOINT:
□ HTTP method and path
□ Description of what it does
□ Authentication requirements
□ Request parameters (path, query, body)
□ Request body schema with types
□ Response codes and their meanings
□ Response body schema with types
□ Example request
□ Example response
□ Error cases and error responses

FOR EACH FUNCTION/METHOD:
□ Function signature with types
□ Description of purpose
□ Parameters with types and descriptions
□ Return value with type
□ Exceptions/errors thrown
□ Usage example
□ Edge cases noted

FOR EACH TYPE/INTERFACE:
□ Type definition
□ Field descriptions
□ Required vs optional fields
□ Default values
□ Constraints (min, max, patterns)
□ Example instance

DOCUMENTATION FORMAT:
□ Match existing project style (OpenAPI, markdown, JSDoc)
□ Include runnable examples where possible
□ Group related endpoints logically
□ Include authentication examples
□ Show error handling

OUTPUT FORMAT:
## API Documentation Update

### New Endpoints
[Full documentation for each new endpoint]

### Changed Endpoints
| Endpoint | Change | Migration Notes |
|----------|--------|-----------------|

[Updated documentation for changed endpoints]

### New Types/Interfaces
[Type definitions with descriptions]

### Example Updates
[New or updated examples]

### Integration Notes
[How this API change affects consumers]
```

### Agent 3: Changelog Writer

```
You are an elite Changelog Writer who makes release history clear and useful.

PROJECT: [project path]
FEATURE SUMMARY: [what was built]
CHANGED FILES: [list of files]
COMMITS: [relevant commit messages]
EXISTING CHANGELOG: [current CHANGELOG.md]
PR/ISSUE LINKS: [if available]

MISSION: Write a clear, user-focused changelog entry following Keep a Changelog format.

CHANGELOG GUIDELINES:

FORMAT (Keep a Changelog style):
- Grouped by: Added, Changed, Deprecated, Removed, Fixed, Security
- User-focused: What does this mean for users?
- Concise but complete
- Include links to PRs/issues when available

VERSION DETERMINATION:
- MAJOR (X.0.0): Breaking changes, incompatible API changes
- MINOR (0.X.0): New features, backwards compatible
- PATCH (0.0.X): Bug fixes, backwards compatible

CHANGE CATEGORIES:
□ Added: New features
□ Changed: Changes to existing functionality
□ Deprecated: Features that will be removed
□ Removed: Features that were removed
□ Fixed: Bug fixes
□ Security: Security fixes

WRITING STYLE:
□ Start with verb (Add, Fix, Change, Remove)
□ User perspective, not developer perspective
□ Be specific but concise
□ Include breaking change warnings prominently
□ Link to documentation for complex changes

OUTPUT FORMAT:
## Changelog Entry

### Version Determination
Recommended version: [X.Y.Z]
Reasoning: [why this version bump]

### Changelog Entry
```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- Add [feature] for [user benefit] (#PR)
- Add [feature] (#PR)

### Changed
- Change [thing] to [new behavior] (#PR)

### Fixed
- Fix [bug] that caused [problem] (#PR)

### Security
- Fix [vulnerability] in [component] (#PR)
```

### Breaking Changes (if any)
[Detailed migration instructions]

### Internal Changes (optional section)
[Changes that don't affect users but are worth noting]
```

---

## Output Coordination

Each specialist works independently on their docs:

```
┌─────────────────────────────────────────────────────────────────┐
│  README Updater  →  Updates README.md                           │
│  API Doc Generator  →  Updates docs/api/* or OpenAPI spec      │
│  Changelog Writer  →  Updates CHANGELOG.md                       │
└─────────────────────────────────────────────────────────────────┘
```

### Commit Strategy

Option 1: Single documentation commit
```bash
git add README.md CHANGELOG.md docs/
git commit -m "docs: update documentation for [feature]"
```

Option 2: Separate commits per doc type
```bash
git commit -m "docs(readme): add [feature] documentation"
git commit -m "docs(api): document [endpoint] endpoints"
git commit -m "docs(changelog): add [version] entry"
```

---

## Trigger Conditions

### Explicit Triggers
- "Update the docs"
- "Document this"
- "Add to changelog"
- "We should document..."

### Implicit Triggers
- Ship phase completed (natural next step)
- Significant feature merged
- API changes detected

### Handoff from Ship
```json
{
  "from": "wannabuild-ship",
  "to": "wannabuild-document",
  "state": ".wannabuild/state.json",
  "mergeCommit": "abc123f",
  "changedFiles": ["app/api/auth/...", "middleware.ts", ...]
}
```

## Behavior

### 1. Documentation Audit

Analyze what changed and what docs might need updates:

```
Scanning merged changes...

Changed files:
- app/api/auth/[...nextauth]/route.ts  (NEW)
- middleware.ts                         (NEW)
- prisma/schema.prisma                  (MODIFIED)
- components/Navbar.tsx                 (MODIFIED)

Potential doc updates:
- README.md: No mention of auth, needs "Authentication" section
- CHANGELOG.md: Should add entry for v1.2.0
- API docs: New /api/auth/* endpoints undocumented
- Inline: middleware.ts could use comments explaining the flow
```

### 2. README Updates

**When to update README:**
- New setup requirements (env vars, dependencies)
- New features users should know about
- Changed commands or workflows
- New API endpoints or usage patterns

**How to update:**
```markdown
## Authentication

This app uses NextAuth.js for authentication.

### Setup

1. Create OAuth apps:
   - [GitHub](https://github.com/settings/developers)
   - [Google](https://console.cloud.google.com)

2. Add to `.env`:
   ```
   GITHUB_ID=your_github_client_id
   GITHUB_SECRET=your_github_client_secret
   GOOGLE_ID=your_google_client_id
   GOOGLE_SECRET=your_google_client_secret
   NEXTAUTH_SECRET=random_32_char_string
   NEXTAUTH_URL=http://localhost:3000
   ```

3. Run migrations:
   ```bash
   npx prisma migrate dev
   ```

### Protected Routes

Routes under `/dashboard/*` require authentication. 
Unauthenticated users are redirected to `/login`.
```

### 3. CHANGELOG Updates

**Format:** Keep it human-readable. [Keep a Changelog](https://keepachangelog.com/) style.

```markdown
# Changelog

## [1.2.0] - 2024-01-15

### Added
- OAuth authentication with GitHub and Google providers
- Protected routes for dashboard section
- User avatar and sign-out in navbar

### Changed
- Navbar now shows auth state

### Technical
- Added NextAuth.js with Prisma adapter
- New middleware for route protection
```

**Determine version:**
- New feature → minor bump (1.1.0 → 1.2.0)
- Bug fix only → patch bump (1.1.0 → 1.1.1)
- Breaking change → major bump (1.1.0 → 2.0.0)

Ask if unclear:
```
Should this be:
- 1.2.0 (new feature, no breaking changes)
- 2.0.0 (if auth requirement is breaking for existing users)

What version fits?
```

### 4. API Documentation

**When to update:**
- New endpoints added
- Request/response format changed
- Authentication requirements changed

**Format:** Match existing style (OpenAPI, markdown, etc.)

```markdown
## POST /api/auth/signin

Initiate OAuth sign-in flow.

**Parameters:**
- `provider` (string): "github" or "google"
- `callbackUrl` (string, optional): URL to redirect after auth

**Response:**
Redirects to OAuth provider.

---

## GET /api/auth/session

Get current session information.

**Response:**
```json
{
  "user": {
    "name": "John Doe",
    "email": "john@example.com",
    "image": "https://..."
  },
  "expires": "2024-02-15T00:00:00.000Z"
}
```

Returns `null` if not authenticated.
```

### 5. Architecture Decision Records (ADRs)

For significant decisions, create an ADR:

```markdown
<!-- docs/adr/0003-authentication-approach.md -->

# ADR 0003: Authentication Approach

## Status
Accepted

## Context
We needed to add user authentication to the application.

## Decision
We chose NextAuth.js with OAuth providers (GitHub, Google) and Prisma adapter.

## Alternatives Considered
- **Clerk/Auth0**: Hosted, easier, but monthly cost and less control
- **Custom JWT**: More control, but more code and security responsibility
- **Supabase Auth**: Good option, but we're not using Supabase for other things

## Consequences
- Easy to add more OAuth providers later
- Session data is in our database (Prisma models)
- We own the auth flow, not a third party
- Need to maintain security updates for next-auth

## References
- [NextAuth.js docs](https://next-auth.js.org/)
- [WannaBuild spec](.wannabuild/spec.md)
```

**When to create ADR:**
- Chose between multiple valid approaches
- Made a trade-off that might be questioned later
- Decision is non-obvious or controversial

### 6. Inline Documentation

**What to document in code:**
- Why, not what (the code says what)
- Non-obvious behavior
- Gotchas for future developers
- TODOs with context

```typescript
// middleware.ts

/**
 * Auth middleware for protected routes.
 * 
 * Note: Using edge-compatible session check instead of getServerSession()
 * because Next.js middleware runs on the edge runtime.
 * 
 * Protected paths: /dashboard/*
 * 
 * @see https://next-auth.js.org/configuration/nextjs#middleware
 */
export function middleware(request: NextRequest) {
  // Check for session token (set by NextAuth)
  // We can't use getServerSession here (edge runtime limitation)
  const token = request.cookies.get('next-auth.session-token');
  
  if (!token && isProtectedPath(request.nextUrl.pathname)) {
    return NextResponse.redirect(new URL('/login', request.url));
  }
  
  return NextResponse.next();
}
```

### 7. Decisions Log Update

Update the WannaBuild decisions log:

```markdown
<!-- .wannabuild/decisions.md -->

# Decisions Log

## Authentication (2024-01-15)

**Decision:** Use NextAuth.js with Prisma adapter

**Why:** 
- Battle-tested library
- First-party Prisma support
- Easy to extend with more providers

**Alternatives rejected:**
- Clerk (cost, vendor lock-in)
- Custom JWT (more work, security burden)

**Trade-offs accepted:**
- Dependency on next-auth package
- Must follow their patterns for customization
```

## Artifacts Produced

### Primary: Updated Documentation
- README.md (if applicable)
- CHANGELOG.md (if applicable)
- API docs (if applicable)

### Secondary: Decision Records
- ADR files (for significant decisions)
- .wannabuild/decisions.md updates

### Tertiary: Code Comments
- Inline documentation where helpful

### State Update
```json
{
  "project": "user-auth",
  "currentPhase": "document",
  "phases": {
    "document": {
      "status": "complete",
      "completedAt": "2024-01-15T16:00:00Z",
      "updates": [
        "README.md - Added Authentication section",
        "CHANGELOG.md - Added 1.2.0 entry",
        "docs/adr/0003-authentication-approach.md - Created"
      ]
    }
  }
}
```

## Completion

When documentation is done:

```
📚 Documentation updated!

Changes:
- README.md: Added Authentication section with setup instructions
- CHANGELOG.md: Added v1.2.0 entry
- docs/adr/0003-authentication-approach.md: Documented our choice

Committed: "docs: add authentication documentation"

---

🎉 WannaBuild complete!

Project "user-auth" is done:
✅ Brainstorm — spec created
✅ Plan — 5 tasks defined
✅ Implement — all tasks complete
✅ Review — passed (5 specialists)
✅ Ship — merged to main
✅ Document — docs updated

Total time: ~4 hours
Commits: 7
Lines changed: +520, -25

Nice work! What's next?
```

## When to Skip This Phase

Skip documentation when:
- Bug fix only (no user-facing changes)
- Internal refactor (no API changes)
- Trivial changes (typo fixes)
- Already documented during implementation
- User says "skip docs, I'll handle it"

Abbreviated documentation when:
- Small feature: Just CHANGELOG entry
- API only: Just API docs
- Config only: Just README

```
This is a small internal change. Skip full documentation and just add 
a CHANGELOG entry?

User: Yes, just changelog

Agent: Added to CHANGELOG under "Internal":
- Refactored auth middleware for clarity
```

## Example Session

```
User: Update the docs

Agent: Looking at what we shipped...

Changes merged:
- New auth system (NextAuth + OAuth)
- Protected routes (/dashboard/*)  
- Auth UI in navbar

I see some docs that need updates:

1. **README.md** — No mention of auth setup
   → Add "Authentication" section with env vars, setup steps

2. **CHANGELOG.md** — No entry for this release
   → Add v1.2.0 with the new features

3. **API docs** — No auth endpoint docs
   → Add /api/auth/* documentation

Should I update all three, or skip any?

User: All three, plus can you document why we chose NextAuth?

Agent: Good call. I'll create an ADR for that too.

[Updates README.md]
→ Added Authentication section with setup instructions

[Updates CHANGELOG.md]  
→ Added v1.2.0 entry

[Creates docs/api/auth.md]
→ Documented auth endpoints

[Creates docs/adr/0003-authentication-approach.md]
→ Documented decision and alternatives

Committing...
$ git add .
$ git commit -m "docs: add authentication documentation"
$ git push origin main

📚 Documentation complete!

All docs are updated and pushed. Is there anything else for this feature?
```

## Quality Checklist

Before marking complete:
- [ ] README reflects current state (setup, usage)
- [ ] CHANGELOG has entry for this change
- [ ] API docs match actual endpoints
- [ ] Significant decisions documented (ADR if warranted)
- [ ] Code comments explain non-obvious parts
- [ ] Documentation committed and pushed

## Anti-Patterns

### ❌ Documenting Everything
Not every function needs JSDoc. Focus on the non-obvious.

### ❌ Lying Documentation
Docs that don't match the code are worse than no docs.

### ❌ Orphaned Docs
Docs in random places nobody can find. Keep it organized.

### ❌ Skipping CHANGELOG
"We'll write it before release." You won't remember.

### ❌ No Why, Only What
```javascript
// Bad: Increments counter (duh, I can see that)
counter++;

// Good: Increment before checking to include current request in rate limit
counter++;
```

### ❌ Skipping ADRs
"It's obvious why we chose X." Is it obvious in 6 months?

## Documentation Doesn't Have to Be Boring

Good docs can have personality:
- Use examples liberally
- Acknowledge edge cases and gotchas
- Write for tired-you at 11 PM
- Screenshots for UI changes
- GIFs for interactions

Bad docs are worse than no docs. Write docs you'd actually want to read.
