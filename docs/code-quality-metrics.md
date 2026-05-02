# Code quality metrics

## Framework: what we track today

| Metric | Tool | Where it surfaces | Trend tracking |
|---|---|---|---|
| Shell warnings | `shellcheck` | CI lint job; PR check. | Future-work: count → CI artifact. |
| Markdown issues | `markdownlint-cli2` (`.markdownlint-cli2.jsonc`) | CI lint job. | Future-work: count → CI artifact. |
| Format drift | `prettier` (`.prettierrc.json`) | CI format-check; pre-commit. | Pass/fail only. |
| Duplication | `jscpd` (`.jscpd.json`) | CI quality job. | jscpd HTML report → CI artifact. |
| Cyclomatic complexity | `lizard` (`.lizardrc`) | CI quality job. | lizard report → CI artifact. |
| Shell coverage | `kcov` via `tests/run.sh` | CI test job. | Coverage % → CI artifact (and gating: `COVERAGE_THRESHOLD`). |

Each of these is enforced in PR CI today (see [`ci.md`](ci.md)). They're also
runnable locally — see [`build.md`](build.md).

### Trend tracking — what we do now

CI uploads each report as a workflow artifact. Comparing across runs is
manual; the artifacts are the canonical record.

### Trend tracking — what we plan (TODO(@gl11tchy))

Push aggregated quality numbers to a SonarCloud project. Each CI run on
`main` would post: shellcheck warning count, markdownlint issue count, jscpd
duplicate %, lizard average complexity, and kcov coverage.

This is **not yet enabled**. Tracked as an explicit follow-up:

- Open an issue with label `area:observability` titled "wire SonarCloud trend
  publishing".
- Reference this doc in the issue body.

Until SonarCloud is wired, comparing trends means manually downloading
artifacts from the runs you care about.

### Recommended SLOs

| Metric | Target | Hard fail |
|---|---|---|
| Shellcheck warnings | 0 (default config) | any |
| Markdownlint errors | 0 | any |
| Format drift | none | any |
| Coverage (shell, kcov) | ≥ `COVERAGE_THRESHOLD` (default 60) | < threshold |
| jscpd duplication | < 2% | > 5% |
| Lizard CCN max | < 15 / function | > 30 |

---

## Target-project guidance

### Quality dashboards — quick comparison

| Tool | Pros | Cons |
|---|---|---|
| **SonarCloud** | Free for public repos, language coverage broad, trend graphs. | Less polished UX. |
| **Codacy** | Friendly UI, easy PR integration. | Pricier per seat. |
| **CodeClimate (Velocity)** | Maintainability score model. | Less popular today. |
| **Snyk Code** | SAST + quality bundled. | Quality is a side feature. |
| **GitHub Code Scanning** (CodeQL) | Native, free for public repos. | Security-focused, not a quality dashboard. |

Default for green-field projects: **SonarCloud + GitHub Code Scanning**. Free
for public repos and gives both quality and security signal.

### Recommended thresholds

For most languages:

| Metric | Default |
|---|---|
| Test coverage (line) | ≥ 70% |
| Test coverage (branch) | ≥ 60% |
| Cyclomatic complexity | ≤ 10 / function (warn), ≤ 15 (fail) |
| Maintainability rating (SonarCloud) | A or B |
| Code smells per kloc | < 20 |
| Duplicated lines | < 3% |
| Security hotspots | 0 unreviewed |

### Quality gate on PR (pattern)

Every PR runs the quality job. The PR is **blocked** if it:

- Adds new shellcheck/lint warnings not present on `main`.
- Drops coverage by > 1 percentage point.
- Introduces a new `code smell` of severity `MAJOR` or higher.
- Crosses the duplication threshold.

GitHub branch protection + a status check named `quality-gate` is the simplest
implementation. SonarCloud's PR decoration handles the rest.

### Local self-service

Every quality tool used in CI must also be runnable locally with one command.
The dev container image (see [`../.devcontainer/`](../.devcontainer/))
preinstalls them.

```bash
bash scripts/lint.sh     # all linters
bash scripts/check-format.sh
bash tests/run.sh        # tests + coverage
```

### Trend dashboards

For target projects:

- **SonarCloud project page** — historical line graph for every metric.
- **Grafana dashboard** — pull metrics from your CI provider's API. Useful if
  you already operate Grafana.
- **GitHub Insights → Pulse** — coarse, free, OK for activity-only views.

## Cross-references

- [`ci.md`](ci.md) — CI job layout.
- [`build.md`](build.md) — local quality commands.
- [`metrics.md`](metrics.md) — runtime metrics (different).
- [`alerting.md`](alerting.md) — quality regressions can alert.
