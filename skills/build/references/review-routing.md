# Review Routing Rules

This file defines how WannaBuild selects reviewers for each review iteration.

## Routing inputs

- Changed files from latest checkpoint window
- Prior failing files from previous iteration
- `changed_files_from_last_checkpoint_window` from orchestrator handoff
- Any explicit risk tag from previous feedback

## Reviewer pool

- `wb-security-reviewer`
- `wb-performance-reviewer`
- `wb-architecture-reviewer`
- `wb-testing-reviewer`
- `wb-integration-tester`
- `wb-code-simplifier`

Select from this pool based on changed surfaces, acceptance criteria, risk, and prior failures. Do not default to a fixed count or a fixed full set.

## Impact mapping

- `wb-security-reviewer`: auth/session/session-id/state/authz/crypto/secret/input-validation changes
- `wb-performance-reviewer`: query loops, joins, pagination, caching, render loops, background jobs
- `wb-architecture-reviewer`: module boundaries, API contracts, state-shape changes, route wiring
- `wb-testing-reviewer`: test harness, fixture updates, assertions, test config changes
- `wb-code-simplifier`: broad refactors, file removals, duplicated logic cleanup
- `wb-integration-tester`: **always included** for every review iteration

## Routing algorithm

1. Infer impacted reviewers from changed files, acceptance criteria, checkpoint evidence, prior failures, and risk profile.
2. Always include `wb-integration-tester`.
3. If no impacted files can be confidently mapped, or if previous iteration failures are ambiguous, broaden the reviewer set until risk ownership is covered.
4. If no changed files can be inferred (resume edge case), use `diff summary + spec excerpt` fallback and include reviewers that cover any plausible changed surfaces.
5. In fast-track mode, if any reviewer fails, next iteration must include the failed reviewer, the integration tester, and any additional reviewers needed to cover uncertainty.

## Confidence reasons (for broadening)

- Missing checkpoint window
- Mixed risk indicators across unrelated files
- Previous iteration had parse/JSON/contract failures
- Reviewer fails with broad severity unknown classification
