# CI Runbook

A map of every GitHub Actions workflow in this repo: what it does, when it
runs, and how to debug it when it fails.

## `.github/workflows/ci.yml` — CI

**Triggers:** push and pull_request on any branch.

**Jobs:**

| Job | Runs on | Purpose |
|---|---|---|
| `lint` | ubuntu-latest | Runs `scripts/lint.sh` (shellcheck, shfmt, markdownlint-cli2, jscpd, lizard, prettier). |
| `test` | ubuntu-latest, macos-latest | Runs `tests/run.sh` (bats), uploads JUnit results, publishes a test report. |
| `coverage` | ubuntu-latest | Runs `tests/coverage.sh` with kcov; uploads coverage artifact. Requires `test` to succeed first. |
| `validate-contracts` | ubuntu-latest | Runs `scripts/wannabuild-doctor.sh` plus the validator over each fixture in `skills/build/dry-runs/`. |
| `pre-commit` | ubuntu-latest | Runs `pre-commit run --all-files` against `.pre-commit-config.yaml`. |

**Concurrency:** in-progress runs on non-default branches cancel when a newer
push lands; runs on `main` are never cancelled.

**Common failure modes:**

- *Lint job red, tests green.* A formatter (shfmt, prettier, markdownlint-cli2)
  found a fix. Run `bash scripts/format.sh` locally and commit the result.
- *Test job red on macOS only.* Almost always a Linux-only assumption — check
  for `apt-get`, `/proc`, `readlink -f`, or GNU-specific flags.
- *Validate-contracts red.* Either a required file is missing (doctor will say
  which) or one of the schemas drifted from `state.json`/`config.json` shape.
- *Pre-commit red.* Match the failing hook's name to its config in
  `.pre-commit-config.yaml`; many hooks auto-fix and require a re-commit.

## `.github/workflows/security.yml` — Security

**Triggers:** push/pull_request on `main`/`master`, plus a daily schedule.

**Jobs:**

| Job | Purpose |
|---|---|
| `gitleaks` | Scans the git history for committed secrets. |
| `dependency-review` | PR-only. Blocks risky transitive dependency changes (high-severity vulns). |
| `codeql-actions` | CodeQL run against the GitHub Actions language to flag unsafe workflow patterns (e.g., script injection via `${{ github.event.* }}`). |

**Why no shell CodeQL?** CodeQL has no first-class shell analyzer. Shell
linting is enforced by `shellcheck` in the CI lint job. CodeQL here protects
the workflow YAML itself.

**Common failure modes:**

- *Gitleaks finds a secret.* If it is a real secret, rotate it immediately and
  use `git filter-repo` to scrub history. If it is a false positive, add an
  allowlist entry to `.gitleaks.toml`.
- *Dependency review red.* Open the PR's "Dependency review" tab to see which
  package and severity. Bump or remove the dependency.

## `.github/workflows/labeler.yml` — Labeler

**Triggers:** PR opened, synchronized, reopened, or marked ready for review.

Applies labels based on changed paths using `actions/labeler` and the rules in
`.github/labeler.yml`. Uses `pull_request_target` so labels can be applied to
PRs from forks.

## `.github/workflows/release-please.yml` — Release Please

**Triggers:** push to `main`.

Opens or updates a release PR, and on merge of that PR, creates the GitHub
Release plus the git tag. See `docs/release.md` for the user-facing release
flow.

**Common failure modes:**

- *No release PR appears.* Confirm the commits since the last tag include at
  least one Conventional Commit type that triggers a bump (e.g., `feat`,
  `fix`).
- *Tag conflict.* Means a manual tag was pushed that release-please does not
  know about. Update `.release-please-manifest.json` to reflect reality.

## `.github/workflows/docs.yml` — Auto-generated docs

**Triggers:** push to `main` (regenerate + open PR), and pull_request (verify
nothing drifted).

Runs `scripts/generate-docs.sh`. On `main`, if the script changes any file
under `docs/generated/`, the workflow opens an automated PR with the diff. On
PRs, the workflow fails if regeneration would change anything — contributors
must regenerate locally and commit the result.

**Common failure modes:**

- *PR fails the docs check.* Run `bash scripts/generate-docs.sh` locally, then
  `git add docs/generated && git commit`.
- *jq parse error.* A schema under `skills/build/schemas/` is malformed JSON;
  fix the schema, not the generator.

## Debugging tips

- All jobs print timings via the runner's default summary.
- Workflow run history: `https://github.com/gl11tchy/wannabuild/actions`
- Re-run a single failed job with the "Re-run failed jobs" button (don't
  re-run the entire workflow unless you must).
- For flaky test investigations, download the JUnit artifact from the run.
