# Runbook: CI is failing

## Symptom

- A PR check is red.
- A workflow on `main` failed (email or Slack alert).
- A scheduled security/release job failed overnight.

## Triage (≤ 5 min)

1. Open the failing run in **GitHub Actions** UI for this repo.
2. Identify the **failing job name**:
   - `lint` — formatter / linter / shell-format drift.
   - `test` — bats tests or coverage gate.
   - `validate-contracts` — `scripts/validate-wannabuild-artifacts.sh` against
     the dry-run fixtures.
   - `pre-commit` — a hook in `.pre-commit-config.yaml` rejected the diff.
   - `quality` — jscpd / lizard / coverage threshold.
   - `release-please` — see
     [`release-failure.md`](release-failure.md) instead.
   - `security` — see [`secret-leak-incident.md`](secret-leak-incident.md)
     if the secret scanner fired.
3. Click the failing step. Read the **last 50 lines** of output. Most CI
   failures are obvious from the tail.

For details on what each job does, see [`../ci.md`](../ci.md).

## Reproduce locally

In the dev container (or with the local fallback toolchain):

```bash
# Lint the whole repo:
bash scripts/lint.sh

# Run all tests with coverage:
bash tests/run.sh

# Validate the dry-run fixtures (same as CI):
for fx in skills/build/dry-runs/*.json; do
  bash scripts/validate-wannabuild-artifacts.sh "$fx"
done

# Run pre-commit on the diff CI is checking:
pre-commit run --from-ref origin/main --to-ref HEAD
```

If any of these fails locally, you've reproduced the CI failure. Fix
locally, then push.

## Common causes & fixes

| Cause | Symptom | Fix |
|---|---|---|
| Format drift | `prettier --check` or `shfmt -d` shows a diff. | `bash scripts/format.sh` (or `shfmt -w` / `prettier --write`), commit. |
| New shellcheck warning | `lint` job fails on a `.sh` file. | Read the SC code; either fix the script or `# shellcheck disable=SCxxxx` with a justifying comment. |
| Markdownlint regression | `lint` fails on a `.md` file. | Run `markdownlint-cli2 --fix .` and inspect. |
| Schema/contract change without validator update | `validate-contracts` fails on a fixture that previously passed. | Either revert the schema change or update the fixture; update `skills/build/schemas/*.json` in lockstep. |
| Missing tool in CI image | Step fails with `command not found`. | Add the tool to `.devcontainer/Dockerfile` AND to the workflow's `setup` step. They must match. |
| Pre-commit cache stale | `pre-commit` fails on a file not in the diff. | `pre-commit clean && pre-commit run --all-files` locally. |
| Coverage drop below threshold | `test` step fails with `Coverage X% < threshold Y%`. | Add tests; or, with justification in the PR, raise/lower `COVERAGE_THRESHOLD` in `.env.example` (and the CI vars). |
| Flaky test | Same test passes on rerun. | File an issue with `kind:flake` label; quarantine the test (skip with a `TODO(#NN)` referencing the issue) within 1 sprint. |

## Escalation

- **Owner**: PR author for PR checks; repo maintainers for `main` failures.
- **Where to ask**: `#wannabuild-ci` (or your team's equivalent) Slack
  channel. If you don't have one, open a GitHub Issue with `area:ci`.
- **When to escalate**:
  - CI has been broken on `main` for > 1 hour.
  - Cause is not obvious from the local repro.
  - Failure correlates with a third-party outage (GitHub Actions, registry,
    Sentry).
- **Incident filing**: SEV-2 if `main` has been red for > 2 hours blocking
  releases.

## Post-incident

For a CI outage worth a post-mortem:

- What broke, when, root cause.
- Why CI didn't catch it earlier (pre-commit gap? test gap?).
- Action items: improve the gate or remove the toil.

## Cross-references

- [`../ci.md`](../ci.md) — CI job map.
- [`../build.md`](../build.md) — local commands.
- [`../alerting.md`](../alerting.md) — alert configuration.
