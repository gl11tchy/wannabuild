# Architecture & Clean Code Reference

Patterns and principles for the Architecture Reviewer agent.

## DRY Violation Patterns

### Code Duplication Signs
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

### Function Guidelines
- **Single Responsibility**: One function, one job
- **Max Length**: ~20-30 lines (exceptions: switch statements, configs)
- **Max Parameters**: 3-4 (use object param for more)
- **Max Nesting**: 2-3 levels (extract to functions)
- **Naming**: Verb + noun (e.g., `getUserById`, `validateEmail`)

### Complexity Red Flags
```
❌ Nested callbacks > 2 levels
❌ if/else chains > 3 branches
❌ Functions > 50 lines
❌ Files > 500 lines
❌ Classes > 10 methods
❌ Cyclomatic complexity > 10
```

### Refactoring Patterns

**Extract Method**
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

**Replace Conditional with Polymorphism**
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

**Introduce Parameter Object**
```typescript
// Before
function createUser(name, email, age, role, dept, manager)

// After
function createUser({ name, email, age, role, dept, manager })
```

## Architecture Patterns

### Frontend (React/Next.js)
```
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
```
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

## Testability Checklist

- [ ] Dependencies are injectable
- [ ] No global state modifications
- [ ] Pure functions where possible
- [ ] Side effects isolated and mockable
- [ ] Clear input/output contracts
