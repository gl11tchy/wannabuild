# Runbook: a dependency update PR is breaking CI

## Symptom

- A Dependabot or Renovate PR landed in the queue and CI is red on it.
- A merged dep-update broke `main` overnight.
- Tests intermittently fail since a recent dep bump.

## Triage (≤ 10 min)

1. Identify the PR (Dependabot/Renovate label) and the package being bumped.
2. Read the package's CHANGELOG for the bumped version range.
3. Determine: is this a real upstream regression, or a local incompatibility?

For background on dep automation in this repo, see
[`../supply-chain.md`](../supply-chain.md) and the `renovate.json` config.

## Reproduce locally

```bash
# Check out the dep-update branch:
gh pr checkout <pr-number>

# Re-run the failing job locally:
bash scripts/lint.sh        # or whichever job failed
bash tests/run.sh
```

If the failure reproduces locally, it's real. Move to fixes below.

## Common causes & fixes

| Cause | Symptom | Fix |
|---|---|---|
| Upstream breaking change in a "minor" bump | Tests fail in patterns CHANGELOG doesn't mention. | Pin to the previous working version; open an upstream issue; re-evaluate next quarter. |
| Bumped dev-only tool in CI image | Lint/format job fails with new rule violations. | Either fix the violations across the repo (preferred) or pin the tool version in `.devcontainer/Dockerfile` AND in the workflow. |
| Transitive update | Lockfile changed transitively; one of the transitives broke. | Use `npm overrides` / `pip constraints` / Go's `replace` to pin the transitive. |
| Renovate/Dependabot config drift | Updates clustered in unhelpful ways (e.g., grouped major updates). | Tune `renovate.json` (group rules, separateMinor/Major, schedule). |
| Test flake exposed by speedup | New version is faster; race condition in tests now triggers. | Fix the race; pinning is a stopgap, not a fix. |

## How to pin around a bad version

For npm packages:

```jsonc
// package.json
"overrides": {
  "<bad-package>": "1.2.3"
}
```

For Python:

```text
# constraints.txt
<bad-package>==1.2.3
```

```bash
pip install -r requirements.txt -c constraints.txt
```

For Go:

```text
// go.mod
replace example.com/bad/pkg v1.2.4 => example.com/bad/pkg v1.2.3
```

Then update `renovate.json` to ignore that package until the upstream fix
lands:

```jsonc
{
  "packageRules": [
    { "matchPackageNames": ["bad-package"], "enabled": false }
  ]
}
```

(Re-enable after the upstream fix; track with a `TODO(@gl11tchy)` and a calendar reminder.)

## Disabling an automated update

If a particular update is reliably broken and can't be pinned:

```jsonc
// renovate.json
{
  "packageRules": [
    {
      "matchPackageNames": ["<package>"],
      "matchUpdateTypes": ["major"],
      "enabled": false
    }
  ]
}
```

Document why in the same commit. Without justification, the next maintainer
will re-enable it and trip the same wire.

## Filing an upstream issue

When you confirm an upstream regression:

1. Minimal repro (the smallest possible repo or test).
2. Versions involved (good vs bad).
3. Link to the upstream commit you suspect.
4. Open the issue in the upstream repo; cross-link from the local PR.

## Escalation

- **Owner**: PR author / repo maintainers.
- **When**: dep update breaks `main` and rollback is non-trivial.
- **Channel**: `#wannabuild-deps` or repo issue with `area:dependencies`.

## Post-incident

- Was the failing dep covered by a test? If not, add coverage.
- Should the package be on a slower release cadence in `renovate.json`?
- Is there a CI smoke check that would have caught this earlier?

## Cross-references

- [`../supply-chain.md`](../supply-chain.md) — dependency posture.
- [`../ci.md`](../ci.md) — workflow inventory.
- [`ci-failure.md`](ci-failure.md) — generic CI triage.
