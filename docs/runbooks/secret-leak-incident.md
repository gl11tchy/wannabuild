# Runbook: we leaked a secret

## Symptom

- gitleaks / detect-secrets fired in CI on a commit that's already on `main`
  (or worse, in a public release).
- A user / partner / scanner notified you of a leaked credential.
- A grep of your git history finds something that looks like a real key.

## Triage (≤ 5 min)

**Stop reading. Revoke first.** Scrubbing git history while the credential
is still live is a wasted effort.

1. Identify the credential.
2. Identify the issuer (AWS, GitHub, OpenAI, Stripe, …).
3. Revoke at the issuer immediately.

For background on how secrets are scanned and managed in this repo, see
[`../secrets-management.md`](../secrets-management.md).

## Step-by-step

### Step 1 — Revoke at the issuer (do this NOW)

| Issuer | How to revoke |
|---|---|
| AWS IAM key | IAM Console → Users → key → Make inactive → Delete. Then rotate the user's permissions. |
| GitHub PAT | <https://github.com/settings/tokens> → Delete. |
| GitHub App / installation token | Tokens auto-rotate; revoke the installation if compromise spans broader. |
| OpenAI API key | Platform → API keys → Delete. |
| Stripe key | Dashboard → Developers → API keys → Roll. |
| Sentry DSN | Sentry → Project → Client Keys → Disable, then create a new one. |
| Slack token | api.slack.com/apps → token → Revoke. |
| Database credentials | Rotate the password at the DB; restart connecting services. |

If you cannot reach the issuer's UI in 1 minute, file an internal ticket
with whoever can.

### Step 2 — Audit access logs

Check the issuer's logs for the leaked credential:

- **AWS**: CloudTrail; filter by access key ID.
- **GitHub**: org audit log; filter by token / IP.
- **Stripe**: events log filtered to API key.
- **OpenAI**: usage page per key.
- **DB**: connection logs; sessions held by the rotated user.

Note any unfamiliar IPs / actions. If anything looks malicious, treat as a
breach: file a SEV-1 incident.

### Step 3 — Rotate related credentials

If the leaked credential could have been used to obtain other credentials
(e.g., an AWS key that could read Secrets Manager), rotate those too.
Assume blast radius is bigger than it looks.

### Step 4 — Scrub git history

Only after revocation. Scrubbing alone is not a fix.

```bash
# Install git-filter-repo (preferred over git filter-branch):
brew install git-filter-repo  # or: pip install git-filter-repo

# Mirror-clone (mandatory; filter-repo refuses to run on a regular clone):
git clone --mirror git@github.com:<owner>/<repo>.git
cd <repo>.git

# Build a replacements file:
cat > expressions.txt <<'EOF'
literal:AKIA<the-key-id>==>REVOKED-AKIA
regex:sk_live_[A-Za-z0-9]{24,}==>REVOKED-STRIPE
EOF

# Rewrite history:
git filter-repo --replace-text expressions.txt --force

# Force-push the rewritten history:
git push --force --all
git push --force --tags
```

Then:

- Notify all collaborators to re-clone.
- Open a fresh PR that adds the leaked literal to `.gitleaks.toml` /
  `.secrets.baseline` so the scanner doesn't re-flag the now-redacted history.
- Invalidate any forks (open issues asking maintainers to delete and re-fork).

### Step 5 — File a private security advisory

If the leak affected production credentials or user data, file a GitHub
[Security Advisory](https://docs.github.com/en/code-security/security-advisories)
in the repo. Coordinate disclosure timeline with stakeholders.

### Step 6 — Post-mortem

Inline template — copy into the post-mortem doc.

```markdown
# Post-mortem: secret leak YYYY-MM-DD

## Summary
One paragraph: what leaked, blast radius, time to revoke, any abuse seen.

## Timeline
- HH:MM — leak introduced (commit sha)
- HH:MM — leak detected (alert / scanner / external report)
- HH:MM — credential revoked
- HH:MM — history scrubbed
- HH:MM — incident closed

## Root cause
Why did the leak happen and why didn't existing guards catch it?

## Action items
- [ ] (preventive) hook/rule that would have blocked this
- [ ] (detective) faster-firing scanner / on-call alert
- [ ] (procedural) docs/runbooks/secrets-management.md update
- [ ] (responsive) faster revocation playbook
```

## Escalation

- **Owner**: the contributor who pushed the commit, plus repo maintainers.
- **When**: ALWAYS file an incident for any production credential leak.
- **Channel**: `#wannabuild-security` Slack; security advisory in repo.

## Cross-references

- [`../secrets-management.md`](../secrets-management.md) — prevention.
- [`../security.md`](../security.md) — broader security posture.
- [`../log-scrubbing.md`](../log-scrubbing.md) — preventing leaks in logs.
- [`../supply-chain.md`](../supply-chain.md) — leaks via dependencies.
