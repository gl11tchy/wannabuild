# Security Checklist Reference

Detailed security checks for the Security Auditor agent.

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

### Files to Always Check
- `.env*` files (should be in .gitignore)
- `config/*.json`
- `**/config.ts`, `**/config.js`
- CI/CD files (`.github/workflows/*`, `Dockerfile`)
- Client-side bundles (`*.bundle.js`, `dist/*`)

## OWASP Top 10 Quick Reference

1. **Injection** - SQL, NoSQL, OS, LDAP injection
2. **Broken Auth** - Session management, credential stuffing
3. **Sensitive Data Exposure** - Encryption, transmission security
4. **XXE** - XML External Entities
5. **Broken Access Control** - IDOR, privilege escalation
6. **Security Misconfiguration** - Default creds, verbose errors
7. **XSS** - Reflected, stored, DOM-based
8. **Insecure Deserialization** - Object injection
9. **Vulnerable Components** - Known CVEs in dependencies
10. **Insufficient Logging** - Audit trails, alerting

## Framework-Specific Checks

### Next.js / React
- No secrets in `NEXT_PUBLIC_*` env vars
- API routes have proper auth middleware
- `getServerSideProps` doesn't leak sensitive data
- CSP headers configured

### Node.js / Express
- Helmet.js or equivalent security headers
- Rate limiting on auth endpoints
- Input validation on all endpoints
- Parameterized queries (no string concatenation)

### Database
- No raw SQL with user input
- Prepared statements used
- Connection strings from env vars
- Principle of least privilege on DB users
