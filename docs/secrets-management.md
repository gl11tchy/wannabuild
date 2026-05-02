# Secrets Management

This document covers two audiences:

1. **WannaBuild maintainers**: how the framework itself handles (and avoids) secrets.
2. **Target projects using WannaBuild**: recommended secrets practices for the
   downstream repos that adopt the framework.

## WannaBuild framework's own secrets posture

WannaBuild is a documentation/framework repository. It has **no runtime secrets**:

- No databases, no external API calls at install time, no auth tokens stored.
- No build artefacts that need signing keys.
- No runtime services that need credentials.

The only credential a maintainer ever needs is a `GH_TOKEN` for publishing a
release or pushing to the marketplace namespace. That token:

- Lives on the maintainer's machine (typically via `gh auth login`) or in
  GitHub Actions as `${{ secrets.GITHUB_TOKEN }}` / a fine-grained PAT.
- Is **never** echoed in logs (workflows route shell output through
  [`scripts/wb-log.sh`](../scripts/wb-log.sh) where applicable; ad-hoc commands
  rely on the GitHub Actions log scrubber and our `scrub-log.sh`).
- Is fine-grained, short-lived (90 day max), and limited to the minimum required
  scopes (typically `contents:write` and `actions:read`).

If you find yourself wanting to add a secret to this repo, stop and reconsider.
WannaBuild's value proposition is that it ships only text and shell — that
property is worth preserving.

## For target projects using WannaBuild

Downstream projects that adopt WannaBuild commonly **do** have real secrets:
database URLs, third-party API keys, service-to-service tokens, etc. WannaBuild
does not impose a particular secrets backend, but the orchestrator's checkpoints
and reviewer outputs can encounter secret material if it leaks into prompts.
Apply the practices below to keep that surface safe.

### Local development

- Keep secrets in a `.env` file at the project root.
- Add `.env` to `.gitignore` (the WannaBuild template does this by default).
- Commit `.env.example` with the variable names and dummy values; never the
  actual values.
- Use [`direnv`](https://direnv.net/) or your shell's `dotenv` support to load
  `.env` automatically when entering the project.

### Cloud secrets managers

For deployed environments, store secrets in a dedicated manager rather than
environment variables on the host:

| Manager                | Strengths                                                | Watch-outs                                                |
| ---------------------- | -------------------------------------------------------- | --------------------------------------------------------- |
| AWS Secrets Manager    | Tight IAM integration, automatic rotation hooks          | Per-secret cost; rotation requires Lambda code            |
| GCP Secret Manager     | Simple versioning, cheap, IAM via service accounts       | Rotation is manual; no native cross-project replication   |
| Azure Key Vault        | HSM-backed option, broad SDK coverage                    | Soft-delete defaults can surprise; access policies vs RBAC|
| HashiCorp Vault        | Cloud-agnostic, dynamic secrets, fine-grained policy     | Operational burden of running it well                     |
| 1Password / Doppler    | Excellent DX for small teams                             | Vendor lock-in; cost per seat                             |

Pick one and standardise on it. Mixing managers in the same project is a common
source of "where does this secret actually live?" incidents.

### GitHub Actions

- Use `${{ secrets.NAME }}` references; never echo them.
- Mark sensitive variables in the workflow logs by piping suspicious commands
  through `scripts/scrub-log.sh` if you cannot avoid printing.
- Use [environment-scoped secrets](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)
  with required reviewers for production deploys.
- See [`docs/log-scrubbing.md`](log-scrubbing.md) for the scrubbing patterns.

### Rotation cadence

| Credential type                          | Maximum lifetime |
| ---------------------------------------- | ---------------- |
| Personal access tokens, OAuth refresh    | 90 days          |
| CI deploy keys                           | 180 days         |
| Long-lived service-account keys          | 365 days         |
| Database passwords (rotated via manager) | 90 days          |
| Encryption keys at rest                  | 365 days         |

Automate rotation where the manager supports it. Manual rotations are fine
provided they actually happen — file a calendar event, not a wiki note.

## What to do if a secret leaks

In order. Do not skip steps and do not start with git history.

1. **Revoke immediately at the issuer.** Rotate the token, password, or key at
   the originating service (GitHub, AWS, Stripe, etc.) before doing anything
   else. Public mirrors and CI caches mean the secret is already out of your
   control; revocation is the only thing that stops abuse.
2. **Audit usage logs at the issuer.** Pull access logs for the credential since
   its earliest possible exposure. Look for unexpected source IPs, user agents,
   or actions.
3. **Scrub git history (if needed).** Use [`git filter-repo`](https://github.com/newren/git-filter-repo)
   to strip the secret from history, then force-push. Be aware that:
   - Any clone made before the rewrite still contains the secret.
   - Forks on GitHub keep the original objects until aggressively garbage-collected.
   - Caches like GitHub Codespaces, JetBrains, and CI runner caches may retain it.
4. **File a security advisory.** Open one via `gh security advisory new` (or the
   web UI). Even if the impact was contained, a public record helps downstream
   users assess their exposure.
5. **Post-incident review.** Document what leaked, how it leaked, what the
   detection-to-revocation latency was, and what process change prevents a repeat.

## Pre-commit hooks for secrets

The repo's `.pre-commit-config.yaml` (Batch A) wires gitleaks as a local hook so
that secret-shaped strings are caught before they leave a developer's machine.
That config and this document are intentionally redundant: belt and braces.

If the hook misfires, see "Allowlisting false positives" below before disabling it.

## Allowlisting false positives

Gitleaks and detect-secrets both have allowlist mechanisms.

### `.gitleaks.toml`

Add path or regex entries to the `[allowlist]` block:

```toml
[allowlist]
paths = [
  '''^tests/fixtures/.*''',
]
regexes = [
  '''(?i)EXAMPLE_TOKEN''',
]
```

Prefer **regex** allowlists for stable patterns (e.g., known dummy tokens) and
**path** allowlists for fixtures that intentionally contain secret-shaped data.

### `.secrets.baseline`

When a flagged secret is genuinely safe (e.g., a documentation example), audit
the baseline interactively:

```bash
detect-secrets audit .secrets.baseline
```

That records the human decision and prevents future scans from re-flagging the
same line. Commit the updated baseline.

## See also

- [`docs/security.md`](security.md) — overall threat model
- [`docs/supply-chain.md`](supply-chain.md) — dependency hygiene
- [`docs/log-scrubbing.md`](log-scrubbing.md) — runtime log redaction
- [`SECURITY.md`](../SECURITY.md) — vulnerability reporting policy
