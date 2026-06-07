# Security Checklist Reference

Binding security-review contract for the Security Auditor agent. This is a
MUST-COVER contract, not a menu. It inherits the four mandates in
`skills/internal/build/references/doctrine.md`; where this file is silent, the
doctrine governs, and the `assert-review-ready` runtime gate is authoritative and
fails closed.

## How to use this checklist (binding)

The Security Auditor MUST evaluate EVERY item in EVERY section below and emit a
per-item result. Covering a sample, skipping a section as "probably fine", or
fast-tracking a small diff is a contract violation — the full checklist runs on
every review iteration regardless of diff size, and each item is reported across
the ENTIRE changed surface, never a subset.

For each item the only permitted results are:

- **PASS** — with the concrete evidence that proved it: `file:line`, the command
  run plus its exit code and output, or the request/response observed against the
  running app. A PASS with no evidence is invalid and is recorded as a BLOCKER.
- **FAIL / BLOCKER / HIGH / MEDIUM / LOW** — with the finding location and a
  reproduction or proof.
- **N/A** — permitted only with a stated reason tied to the code (e.g. "no SQL
  layer in the changed surface; no database client imported") AND only after the
  resource-acquisition mandate below has been exhausted. "N/A because I could not
  test it" is never valid — that is a BLOCKER pending verification.

A check that cannot be verified after acquisition is exhausted is recorded as a
**BLOCKER pending verification**, never a PASS and never silently dropped.

## Resource acquisition is mandatory before claiming blocked

"Missing env", "no database", "can't run it", "no access", "no fixtures" are never
grounds to skip a check or mark it PASS/N/A. They are grounds to OBTAIN the
resource (auto-acquire anything safe, local, and reversible) or to ASK the user
(only for billable, outward-facing, or destructive acquisition). Before any item
is marked N/A or BLOCKER-for-lack-of-access, the auditor MUST attempt acquisition
and record exactly what was tried in `.wannabuild/outputs/acquisition-log.json`
(per the `assert-acquisition-attempted` gate):

- **Runtime / header checks** (CSP and security headers, auth middleware, rate
  limiting, error verbosity): run the app locally and inspect live responses
  (`curl -I`), or load the page in a real browser via the Chrome / computer-use
  connector and read the response headers. Source-only inspection is insufficient
  for a PASS on a runtime check.
- **Injection / XSS** (SQL/NoSQL injection, reflected/stored/DOM XSS): exercise
  the running app — inject a payload, render it, observe the result in a browser.
  For SQL/NoSQL injection, provision a disposable database (Supabase or Neon
  branch, Railway service) and attempt the injection against it. A static read of
  the code is a starting point, not a verdict, for these dynamic categories.
- **Vulnerable components / CVEs**: this is a live-data task. Run a dependency
  scanner against the project (`npm audit`, `pip-audit`, `osv-scanner`, or the
  project's configured equivalent), record the command and its output, and pull
  current advisory data via Context7 (`resolve-library-id` → `get-library-docs`)
  when the scanner is unavailable. Asserting "no known CVEs" without a scan is a
  BLOCKER.

Record the command, exit code, and output for every acquisition. A blocked status
with no logged attempt is rejected by `assert-acquisition-attempted`.

## Secrets Detection Patterns

### Common Secret Patterns (Regex)

```regex
# API Keys
(?i)(api[_-]?key|apikey)['":\s]*[=:]\s*['"]?[a-zA-Z0-9_-]{20,}

# AWS
AKIA[0-9A-Z]{16}
(?i)aws[_-]?secret[_-]?access[_-]?key

# JWT
eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*

# Private Keys
-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----

# Database URLs
(?i)(postgres|mysql|mongodb|redis)://[^:\s]+:[^@\s]+@

# Generic Tokens
(?i)(token|secret|password|passwd|pwd)['":\s]*[=:]\s*['"]?[a-zA-Z0-9_-]{8,}
```

### Secrets scan — required execution

The auditor MUST run every regex above against ALL paths in "Files to Always
Check" AND the full repository (including git history when the repo is available,
e.g. `git log -p` or `git grep`), confirm each glob was actually scanned, and
report any path that could not be scanned and why. Each match is a finding:

- A live or plausibly-live secret committed to the repo or shipped in a
  client-side bundle is a **BLOCKER** — the review MUST FAIL.
- A match that is a confirmed test fixture, example placeholder, or rotated/dead
  value is reported as resolved with the proof of why it is inert (file:line +
  reason). "Looks fake" is not proof; confirm against the pattern and context.

### Files to Always Check

- `.env*` files (should be in .gitignore)
- `config/*.json`
- `**/config.ts`, `**/config.js`
- CI/CD files (`.github/workflows/*`, `Dockerfile`)
- Client-side bundles (`*.bundle.js`, `dist/*`)

## OWASP Top 10 — every category MUST be evaluated and reported

This is not background reading. For EACH of the ten categories below, the auditor
MUST emit PASS / FAIL / N/A with evidence — categories are never collapsed,
skipped, or covered as an arbitrary subset. For the dynamic categories
(Injection, Broken Auth, Broken Access Control, Security Misconfiguration, XSS) a
static-only review does not produce a PASS: exercise the running app per the
acquisition mandate above, or record a BLOCKER pending verification.

1. **Injection** - SQL, NoSQL, OS, LDAP injection
2. **Broken Auth** - Session management, credential stuffing
3. **Sensitive Data Exposure** - Encryption, transmission security
4. **XXE** - XML External Entities
5. **Broken Access Control** - IDOR, privilege escalation
6. **Security Misconfiguration** - Default creds, verbose errors
7. **XSS** - Reflected, stored, DOM-based
8. **Insecure Deserialization** - Object injection
9. **Vulnerable Components** - Known CVEs in dependencies (requires a live
   dependency scan — see the acquisition mandate)
10. **Insufficient Logging** - Audit trails, alerting

## Framework-Specific Checks

The auditor MUST run the matching framework block below in full. Every item is a
required check producing a per-item result.

### Next.js / React

- No secrets in `NEXT_PUBLIC_*` env vars
- API routes have proper auth middleware
- `getServerSideProps` doesn't leak sensitive data
- CSP headers configured (verified against the running app's live response
  headers, not source alone)

### Node.js / Express

- Helmet.js or equivalent security headers
- Rate limiting on auth endpoints
- Input validation on every endpoint — the auditor MUST enumerate the full
  endpoint inventory (route definitions plus mounted routers) and report a
  per-endpoint result; "validates all endpoints" without the enumeration is a
  BLOCKER
- Parameterized queries (no string concatenation)

### Database

- No raw SQL with user input (validated against a provisioned disposable DB per
  the acquisition mandate when the changed surface touches queries)
- Prepared statements used
- Connection strings from env vars
- Principle of least privilege on DB users

### Framework not listed here

If the project's framework or runtime is not enumerated above (e.g.
Django/FastAPI, Rails, Go, Rust, Spring, mobile), the auditor MUST first pull that
framework's current security guidance via Context7 (`resolve-library-id` →
`get-library-docs`), derive the equivalent checks (secrets handling, auth
middleware, injection-safe data access, security headers, input validation), and
run them with the same per-item rigor. An unlisted stack is never grounds to skip
framework checks.

## Verdict and gate

Emit a structured verdict aggregating every item above:

- **BLOCKER** — an exploitable vulnerability or an exposed live secret. The
  security review MUST FAIL; this cannot be rationalized into a PASS, and an
  unverified-after-acquisition item is a BLOCKER pending verification.
- **HIGH / MEDIUM / LOW** — findings ranked by exploitability and impact, each
  with location and proof.
- **PASS** — only when every item resolved to PASS or a justified N/A, the secrets
  scan ran clean across the full file set, every OWASP category was evaluated, and
  the matching framework block ran in full with evidence.

The auditor returns a single PASS/FAIL verdict to the orchestrator; a FAIL or any
unresolved BLOCKER blocks `assert-review-ready` for the iteration. When a finding
implies a scope or design change beyond a local fix (e.g. dropping an auth
provider, changing a data-exposure boundary), the auditor does not act silently:
it reports the finding with remediation options and a recommended option for the
orchestrator to take to the user at the phase boundary.
