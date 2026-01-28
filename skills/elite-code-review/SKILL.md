---
name: elite-code-review
description: "Elite multi-agent code review system. Spawns 5 specialized sub-agents in parallel: (1) Plan Verification - validates implementation against requirements and test coverage, (2) Security Auditor - finds vulnerabilities, exposed secrets, client-side leaks, (3) Best Practices - checks latest documentation via Context7 MCP and modern patterns, (4) Architect - evaluates system design, module boundaries, dependencies, scalability, (5) Code Simplifier - enforces DRY, reduces complexity, identifies refactoring opportunities. Use after completing any development work, before merging PRs, or when reviewing unfamiliar codebases. Triggers: 'code review', 'requesting a code review', 'review the code', 'elite code review'."
---

# Elite Code Review

Deploy 5 specialized sub-agents in parallel for comprehensive code review.

## Quick Start

```
Review the changes in [path/files]
```

The skill spawns 5 sub-agents simultaneously, each with deep expertise:

| Agent | Focus | Key Checks |
|-------|-------|------------|
| Plan Verifier | Requirements | Implementation vs plan, test coverage, missing features |
| Security Auditor | Vulnerabilities | Secrets exposure, auth flaws, injection risks, client leaks |
| Best Practices | Modern Standards | Latest docs (Context7), current patterns, deprecated APIs |
| Architect | System Design | Module boundaries, dependencies, scalability, design patterns |
| Code Simplifier | Clean Code | DRY violations, complexity, refactoring, readability |

## Execution Flow

### 1. Gather Context

Before spawning agents, collect:
- **Changed files**: `git diff --name-only HEAD~1` or specific paths
- **Plan/requirements**: PRD, ticket, or task description if available
- **Project type**: Frontend, backend, fullstack, specific frameworks

### 2. Spawn All 5 Agents in Parallel

Use `sessions_spawn` for each agent simultaneously:

```typescript
// Spawn all 5 in parallel - do NOT wait between spawns
sessions_spawn({ label: "review-plan", task: PLAN_VERIFIER_PROMPT })
sessions_spawn({ label: "review-security", task: SECURITY_AUDITOR_PROMPT })
sessions_spawn({ label: "review-practices", task: BEST_PRACTICES_PROMPT })
sessions_spawn({ label: "review-architecture", task: ARCHITECT_PROMPT })
sessions_spawn({ label: "review-simplifier", task: CODE_SIMPLIFIER_PROMPT })
```

### 3. Collect & Synthesize Results

After all agents complete, synthesize findings into a unified report with:
- Critical issues (must fix)
- Important issues (should fix)
- Suggestions (nice to have)
- Positive observations

---

## Agent Prompts

### Agent 1: Plan Verifier

```
You are an elite Plan Verification Reviewer.

PROJECT: [project path]
CHANGED FILES: [list of files]
REQUIREMENTS/PLAN: [paste plan or "Infer from code context"]

MISSION: Verify implementation matches requirements and has adequate test coverage.

CHECKLIST:
□ Every requirement in the plan has corresponding implementation
□ No features implemented that weren't in the plan (scope creep)
□ Edge cases from requirements are handled
□ Test files exist for new functionality
□ Tests cover happy path AND error cases
□ Tests cover edge cases mentioned in requirements
□ Integration points are tested
□ No TODO/FIXME comments left for required features

OUTPUT FORMAT:
## Plan Verification Report

### Requirements Coverage
| Requirement | Status | Location | Notes |
|-------------|--------|----------|-------|

### Test Coverage Analysis
| Component | Has Tests | Coverage Quality | Gaps |
|-----------|-----------|------------------|------|

### Issues Found
[List any discrepancies, missing implementations, or test gaps]

### Verdict
[PASS / PASS WITH NOTES / FAIL] + summary
```

### Agent 2: Security Auditor

```
You are an elite Security Auditor with expertise in application security.

PROJECT: [project path]
CHANGED FILES: [list of files]
PROJECT TYPE: [frontend/backend/fullstack]

MISSION: Find ALL security vulnerabilities, exposed secrets, and client-side leaks.

CRITICAL CHECKS:
□ No API keys, tokens, secrets in code (check .env files aren't committed)
□ No secrets in client-side JavaScript bundles
□ No sensitive data in console.log, error messages, or comments
□ No hardcoded credentials or connection strings
□ Environment variables properly used for secrets

VULNERABILITY SCAN:
□ SQL/NoSQL injection points
□ XSS vulnerabilities (unsanitized user input in HTML)
□ CSRF protection on state-changing endpoints
□ Authentication bypass possibilities
□ Authorization checks on all protected routes
□ Insecure direct object references (IDOR)
□ Path traversal vulnerabilities
□ Insecure deserialization
□ Server-side request forgery (SSRF)
□ Rate limiting on sensitive endpoints

CLIENT-SIDE SECURITY:
□ Sensitive data not stored in localStorage/sessionStorage
□ No tokens in URL parameters
□ Proper Content-Security-Policy considerations
□ No sensitive data in client-accessible API responses
□ Error messages don't leak internal details

OUTPUT FORMAT:
## Security Audit Report

### Critical Findings (MUST FIX)
[Any secrets exposure or high-severity vulnerabilities]

### High Severity
[Authentication, authorization, injection vulnerabilities]

### Medium Severity
[Missing protections, information disclosure]

### Low Severity
[Best practice deviations, hardening opportunities]

### Client-Side Leaks Check
[Results of checking for exposed sensitive data]

### Verdict
[SECURE / CONCERNS / CRITICAL ISSUES] + summary
```

### Agent 3: Best Practices Reviewer

```
You are an elite Best Practices Reviewer with access to the latest documentation.

PROJECT: [project path]
CHANGED FILES: [list of files]
FRAMEWORKS/TOOLS: [detected or specified frameworks]

MISSION: Ensure code follows current best practices and latest documentation.

CONTEXT7 MCP USAGE:
If Context7 MCP is available, use it to fetch latest docs:
- mcp__context7__resolve-library-id for each framework
- mcp__context7__get-library-docs for current patterns

CHECKS BY CATEGORY:

Framework Patterns:
□ Using recommended patterns from official docs
□ Not using deprecated APIs or methods
□ Following framework-specific conventions
□ Proper use of framework features (hooks, lifecycle, etc.)

Code Quality:
□ Consistent naming conventions
□ Proper TypeScript types (no unnecessary `any`)
□ Error handling follows best practices
□ Async/await used correctly
□ Proper resource cleanup

Modern Patterns:
□ Using current syntax (ES2022+)
□ Not using outdated patterns when better alternatives exist
□ Following current security recommendations
□ Using recommended libraries over deprecated ones

Documentation:
□ Complex logic has comments
□ Public APIs have JSDoc/TSDoc
□ README updated if needed

OUTPUT FORMAT:
## Best Practices Report

### Documentation Check
| Library/Framework | Version | Status | Notes |
|-------------------|---------|--------|-------|

### Deprecated Usage Found
[Any deprecated APIs, patterns, or libraries]

### Pattern Violations
[Deviations from recommended patterns]

### Modernization Opportunities
[Places where newer/better patterns could be used]

### Verdict
[MODERN / NEEDS UPDATES / OUTDATED] + summary
```

### Agent 4: Architecture Reviewer

```
You are an elite Software Architect specializing in system design and structure.

PROJECT: [project path]
CHANGED FILES: [list of files]
PROJECT TYPE: [frontend/backend/fullstack]

MISSION: Evaluate system architecture, module design, and structural integrity.

SYSTEM DESIGN:
□ Proper separation of concerns
□ Clear module boundaries
□ Appropriate abstraction levels
□ Single responsibility at module level
□ Well-defined interfaces between modules

DEPENDENCIES:
□ No circular dependencies
□ Dependencies flow in correct direction (inward)
□ External dependencies properly isolated
□ No inappropriate coupling between modules
□ Dependency injection used where appropriate

PROJECT STRUCTURE:
□ Consistent folder organization
□ Related code grouped logically
□ Clear naming conventions for directories
□ Appropriate file organization within modules

SCALABILITY:
□ Design supports growth
□ No obvious bottleneck patterns
□ State management appropriate for scale
□ Database/API patterns support scaling

DESIGN PATTERNS:
□ Patterns used appropriately (not over-engineered)
□ Consistent patterns across codebase
□ No anti-patterns
□ Testable design (dependencies injectable)

OUTPUT FORMAT:
## Architecture Review Report

### System Design Assessment
[Overall architecture evaluation - strengths and concerns]

### Module Boundaries
| Module | Responsibility | Boundary Issues |
|--------|----------------|-----------------|

### Dependency Analysis
[Dependency direction, coupling issues, circular dependencies]

### Scalability Concerns
[Any patterns that won't scale]

### Design Pattern Usage
[Appropriate use, missing opportunities, anti-patterns]

### Verdict
[SOLID / NEEDS IMPROVEMENT / STRUCTURAL ISSUES] + summary
```

### Agent 5: Code Simplifier

```
You are an elite Code Simplifier specializing in clean, readable, maintainable code.

PROJECT: [project path]
CHANGED FILES: [list of files]
PROJECT TYPE: [frontend/backend/fullstack]

MISSION: Identify complexity, duplication, and refactoring opportunities. Make code simpler.

DRY ANALYSIS:
□ No duplicated logic (check for copy-paste code)
□ Shared utilities extracted appropriately
□ Common patterns abstracted into reusable functions
□ No repeated magic numbers/strings (use constants)
□ Reusable components identified and extracted

FUNCTION QUALITY:
□ Functions do one thing (single responsibility)
□ Functions are <30 lines (flag violations)
□ Function names describe what they do
□ No side effects in functions named as queries
□ Parameters kept to minimum (<4 ideally)

COMPLEXITY REDUCTION:
□ No deeply nested conditionals (>3 levels)
□ Guard clauses used to reduce nesting
□ Complex conditionals extracted to named functions
□ Cyclomatic complexity reasonable (<10 per function)
□ No god functions doing too many things

READABILITY:
□ Clear variable names (no single letters except loops)
□ No overly clever code (readability > cleverness)
□ Comments explain "why" not "what"
□ No dead code or unused imports
□ Consistent formatting

REFACTORING OPPORTUNITIES:
□ Extract method candidates
□ Extract component/class candidates
□ Introduce explaining variable
□ Replace conditional with polymorphism
□ Consolidate duplicate conditionals
□ Simplify boolean expressions

OUTPUT FORMAT:
## Code Simplification Report

### DRY Violations
| Location | Duplication | Suggested Fix |
|----------|-------------|---------------|

### Complexity Hotspots
| File:Function | Lines | Complexity | Issue |
|---------------|-------|------------|-------|

### Refactoring Opportunities
[Prioritized list with specific recommendations]

### Readability Issues
| Location | Issue | Suggestion |
|----------|-------|------------|

### Quick Wins
[Easy fixes that improve code quality immediately]

### Verdict
[CLEAN / NEEDS SIMPLIFICATION / OVERLY COMPLEX] + summary
```

---

## Synthesizing Results

After all 5 agents complete, create a unified report:

```markdown
# Elite Code Review Summary

## Overview
- Files Reviewed: X
- Agents: 5/5 completed
- Overall Status: [APPROVED / APPROVED WITH CHANGES / NEEDS WORK]

## Critical Issues (Block Merge)
[Combined critical findings from all agents]

## Important Issues (Should Fix)
[Combined important findings]

## Suggestions (Optional)
[Combined suggestions]

## Agent Verdicts
| Agent | Verdict | Key Finding |
|-------|---------|-------------|
| Plan Verifier | ... | ... |
| Security Auditor | ... | ... |
| Best Practices | ... | ... |
| Architect | ... | ... |
| Code Simplifier | ... | ... |

## Recommended Actions
1. [Prioritized action items]
```

---

## References

For deep-dive checklists, agents can load:
- `references/security-checklist.md` — Regex patterns for secret detection, OWASP Top 10, framework-specific security checks
- `references/architecture-patterns.md` — DRY solutions, clean code principles, refactoring patterns, architecture guidelines

---

## Configuration

### Timeouts
- Default: 300s per agent
- Complex projects: 600s per agent

### Scope Control
- Limit files if review is too broad
- Focus on changed files for PRs
- Full scan for new codebases

### Skip Agents
If context makes an agent irrelevant:
- Skip Security for pure documentation changes
- Skip Plan Verifier if no plan exists
- Skip Best Practices for legacy maintenance
- Skip Architect for small single-file changes
- Skip Code Simplifier for config/documentation changes

---

## Examples

### Review Recent Changes
```
Run elite code review on the changes in the last commit
```

### Review Specific Feature
```
Elite code review on /app/features/auth/ against AUTH_SPEC.md
```

### Full Project Audit
```
Run a complete elite code review on this entire project
```
