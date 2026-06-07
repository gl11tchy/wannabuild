# Architecture & Clean Code Reference

Binding rules for the Architecture Reviewer agent. This file governs under the four
mandates in `skills/internal/build/references/doctrine.md`; where it is silent, that
doctrine governs. Every threshold below is a hard limit, every breach is a mandatory
finding, and no item may be skipped, sampled, or rationalized away.

## Required before judging (no exceptions)

You MUST run real analysis and paste the actual output into your verdict before
asserting any architecture finding. Naming a metric without measuring it is a FAIL,
not a PASS — "missing tool" / "no access" / "can't run it" is never grounds to skip;
it is grounds to obtain the tool or log the blocker (Mandate 2):

1. **Complexity:** run the project's complexity analyzer (`scripts/check-complexity.sh`,
   or `lizard` per `.lizardrc`) across the entire changed surface. Report the actual
   numbers per function/file.
2. **Duplication:** run `jscpd` per `.jscpd.json` across the changed surface. Report
   the actual duplicate clones it reports.
3. **Testability:** prove each Testability gate item by running the test suite,
   instantiating the unit with a fake dependency, or grepping the source — never by
   asserting it from inspection alone.

If a required analyzer cannot run, you may not proceed to a PASS. Auto-acquire the
tool (install/invoke it locally), or — only when acquisition is genuinely impossible —
record the blocker in `.wannabuild/outputs/acquisition-log.json` (what was needed,
which tools were attempted, the result) so `assert-acquisition-attempted` can see it.
A blocked metric without a logged acquisition attempt is a FAIL.

## Coverage contract (mandatory)

Before returning any verdict you MUST:

1. Enumerate every file/module in scope of this change.
2. For each, record `inspected: yes/no` and which rules below were checked against it.
3. Include an explicit "not inspected and why" list — an empty list is the expected
   outcome. A verdict that examined part of the diff and stopped has not completed its
   job and may not PASS (Mandate 3 — each reviewer covers the entire changed surface).

## DRY checks — run duplicate detection (jscpd) first, then verify each below against the report

Run `jscpd` (per `.jscpd.json`) across the changed surface first; do not detect
duplication by eye. Any clone the report flags above the configured threshold is a
mandatory finding. Then verify each pattern below against the actual report:

- Same logic in multiple files with slight variations
- Copy-pasted error handling
- Repeated validation logic
- Similar API calls with different endpoints
- Duplicate utility functions across modules

### Solutions

| Pattern | Solution |
|---------|----------|
| Repeated logic | Extract to shared utility |
| Similar components | Create base component + variants |
| Duplicate API calls | Create API client abstraction |
| Repeated validation | Create validation schemas |
| Magic strings/numbers | Extract to constants file |

## Clean Code Principles

### Function Guidelines (hard limits — every breach is a mandatory finding)

These are the single authoritative limits for this file. There is no "approximate"
bound and no open-ended exception list; the same number applies on every run.

- **Single Responsibility**: One function, one job. A function that does two jobs is a
  finding.
- **Max Length**: 40 lines. No exceptions. A switch/config block that pushes a function
  past 40 lines is extracted, or the verdict states the function name, its line count,
  and the concrete reason extraction was rejected.
- **Max Parameters**: 3. A fourth parameter requires a parameter object.
- **Max Nesting**: 2 levels. Deeper nesting is extracted to a named function.
- **Naming**: Verb + noun (e.g., `getUserById`, `validateEmail`).

### Complexity limits — every breach is a mandatory finding

Measure these with the analyzer from "Required before judging"; do not eyeball them.
Crossing any limit MUST be reported as a finding and cannot be silently passed. Two
reviewers hitting the same breach must reach the same verdict.

```text
❌ Nested callbacks > 2 levels
❌ if/else chains > 3 branches
❌ Functions > 40 lines
❌ Files > 500 lines
❌ Classes > 10 methods
❌ Cyclomatic complexity > 10
```

### Refactoring Patterns

#### Extract Method

```typescript
// Before
function processOrder(order) {
  // 20 lines validating
  // 20 lines calculating
  // 20 lines saving
}

// After
function processOrder(order) {
  validateOrder(order)
  const total = calculateTotal(order)
  saveOrder(order, total)
}
```

##### Replace Conditional with Polymorphism

```typescript
// Before
function getPrice(type) {
  if (type === 'basic') return 10
  if (type === 'premium') return 20
  if (type === 'enterprise') return 50
}

// After
const pricing = { basic: 10, premium: 20, enterprise: 50 }
const getPrice = (type) => pricing[type]
```

###### Introduce Parameter Object

```typescript
// Before
function createUser(name, email, age, role, dept, manager)

// After
function createUser({ name, email, age, role, dept, manager })
```

## Architecture Patterns

### Frontend (React/Next.js)

```text
src/
├── components/     # Reusable UI components
│   ├── ui/        # Primitives (Button, Input)
│   └── features/  # Feature-specific components
├── hooks/         # Custom hooks
├── lib/           # Utilities, API clients
├── stores/        # State management
└── types/         # TypeScript types
```

### Backend (Node.js)

```text
src/
├── routes/        # Route handlers
├── controllers/   # Business logic
├── services/      # External integrations
├── models/        # Data models
├── middleware/    # Express middleware
├── utils/         # Helpers
└── types/         # TypeScript types
```

### Separation of Concerns

- **Presentation**: UI rendering only
- **Business Logic**: Domain rules, calculations
- **Data Access**: Database queries, API calls
- **Infrastructure**: Logging, caching, auth

## Testability gate (ALL items required; any unmet item is a FAIL)

For each item, state PASS or FAIL and cite the `file:line` or command output that
proves it. An item proven only by inspection, or left unstated, counts as FAIL. The
only way an unmet item does not fail the verdict is an explicit justification in the
verdict naming the unit and why the property is impossible here.

- **Dependencies injectable** — name the injection point (constructor/param/factory).
- **No global state mutation** — cite the search you ran (e.g. `grep` for global
  assignment) and its result.
- **Pure functions** — for every function that performs I/O or mutation, name it and
  state why the side effect cannot be isolated. "Could not make it pure" without that
  named reason is a FAIL, not a pass.
- **Side effects isolated and mockable** — name the seam (interface/port) a test fakes.
- **Clear input/output contracts** — cite the type signature or schema that defines them.
