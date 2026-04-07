# Review Routing Rules

This file defines how WannaBuild selects reviewers for retry iterations.

## Routing inputs
- Changed files from latest checkpoint window
- Prior failing files from previous iteration
- `changed_files_from_last_checkpoint_window` from orchestrator handoff
- Any explicit risk tag from previous feedback

## Base reviewer sets
- Standard mode: `wb-security-reviewer`, `wb-performance-reviewer`, `wb-architecture-reviewer`, `wb-testing-reviewer`, `wb-integration-tester`, `wb-code-simplifier`

## Impact mapping
- `wb-security-reviewer`: auth/session/session-id/state/authz/crypto/secret/input-validation changes
- `wb-performance-reviewer`: query loops, joins, pagination, caching, render loops, background jobs
- `wb-architecture-reviewer`: module boundaries, API contracts, state-shape changes, route wiring
- `wb-testing-reviewer`: test harness, fixture updates, assertions, test config changes
- `wb-code-simplifier`: broad refactors, file removals, duplicated logic cleanup
- `wb-integration-tester`: **always included** when reviewers are run in review iteration 2+

## Routing algorithm
1. Default to base set for iteration 1.
2. On iteration 2+:
   - Start with impacted reviewer set from change classification.
   - Always include `wb-integration-tester`.
   - If no impacted files can be confidently mapped, or if previous iteration fails are ambiguous -> fallback to base set.
3. If no changed files can be inferred (resume edge case), use `diff summary + spec excerpt` fallback and run base set.
4. In fast-track mode, if any reviewer fails, next iteration must fall back to full base set.

## Confidence reasons (for fallback)
- Missing checkpoint window
- Mixed risk indicators across unrelated files
- Previous iteration had parse/JSON/contract failures
- Reviewer fails with broad severity unknown classification
