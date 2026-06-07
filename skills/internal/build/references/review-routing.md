# Review Routing Rules

This file defines how WannaBuild assigns reviewers for each review iteration. Per
[doctrine.md](doctrine.md) Mandate 3, the **full reviewer set runs on every iteration** —
routing assigns focus, it never selects a subset.

## Reviewer set (always all of these, every iteration)

- `wb-security-reviewer`
- `wb-performance-reviewer`
- `wb-architecture-reviewer`
- `wb-testing-reviewer`
- `wb-code-simplifier`
- `wb-integration-tester`

There is no impacted-only subset, no fast-track, and no fixed count below the full set.
`assert-review-ready` requires a PASS verdict from every reviewer for the latest iteration.
`loop-state.active_reviewers` records who ran but never shrinks who is required.

## Coverage responsibility (focus within the full diff)

Every reviewer covers the **entire changed surface**. The map below tells each reviewer where
to look hardest; it does not let any reviewer skip files.

- `wb-security-reviewer`: auth/session/authz/crypto/secret/input-validation changes
- `wb-performance-reviewer`: query loops, joins, pagination, caching, render loops, background jobs
- `wb-architecture-reviewer`: module boundaries, API contracts, state-shape changes, route wiring
- `wb-testing-reviewer`: test harness, fixtures, assertions, test config
- `wb-code-simplifier`: broad refactors, file removals, duplicated logic
- `wb-integration-tester`: executes the test suite against real (acquired) resources and maps every acceptance criterion to a test — terminal hard gate

## Inputs each reviewer receives

- The full diff for the changed files (never a withheld subset)
- The relevant spec excerpts (requirements/design)
- Prior-iteration feedback for the files they own

## Resume edge case

If the changed-file set cannot be read from the checkpoint window, reconstruct it from the
git diff against the review baseline before routing. Do not degrade to a "spec excerpt only"
review — a review without the actual diff is not a review.

## Resource acquisition

If any reviewer (especially the integration tester) needs a resource it does not have, it
acquires it (run the app, spin a DB branch, drive a browser, generate fixtures) or asks the
user for billable/outward acquisition, and logs the attempt in
`.wannabuild/outputs/acquisition-log.json`. "Couldn't verify / no env" is never an accepted
routing outcome — see doctrine Mandate 2.
