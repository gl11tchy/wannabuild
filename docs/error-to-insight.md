# Error → insight pipeline

Errors that disappear into a log file are not signal. The point of this doc is
the **whole pipeline**: error → captured → triaged → ticketed → fixed →
verified, with explicit handoffs.

## Framework pipeline (today)

```text
trap ERR in script
       │
       ▼
wb_log_error  ── stderr ──►  GitHub Actions log  ──►  PR check fails
       │                                              │
       ▼                                              ▼
(future) wb-log Sentry hook              runbooks/ci-failure.md
                                                       │
                                                       ▼
                                          author triages, opens PR fix
```

Today the pipeline ends at the runbook. Two future-work items extend it:

1. **Auto-issue creation on repeated CI failures.** A workflow that watches
   `workflow_run` events on `main`, dedupes by failing-step, and opens a
   GitHub Issue with labels `area:ci` + `kind:flake`. Tracked as TODO(@gl11tchy).
2. **`wb-log.sh` Sentry hook.** When `SENTRY_DSN` is set, `wb_log_error`
   POSTs a minimal envelope event so framework-runtime errors land in the
   same Sentry the team uses for everything else. Tracked as TODO(@gl11tchy); the env
   hook already exists in [`../.env.example`](../.env.example).

The trap pattern (see [`error-tracking.md`](error-tracking.md)) is the
contract that lets these future hooks attach without rewriting scripts.

---

## Target-project pipeline

This is the recommended end-to-end flow for any application built with
WannaBuild.

```text
[App throws] ──► Sentry SDK ──► Sentry issue
                                   │
                                   ▼
                           Sentry GitHub integration
                                   │
                            ┌──────┴───────┐
                            ▼              ▼
                   Auto-create GH      Link to existing PR
                   Issue (labels)      (commit ↔ release)
                            │
                            ▼
                       Linear/Jira sync
                            │
                            ▼
                  Engineer fixes, ships
                            │
                            ▼
                   Sentry release health
                   confirms resolution
                            │
                            ▼
                   Sentry auto-resolves issue
```

### 1. Capture

- Error reaches the Sentry SDK (synchronous handlers, async tasks, web
  workers, browser).
- SDK enriches with breadcrumbs, user context (PII rules permitting), tags
  (`release`, `feature_flag`, `wannabuild.task_id`).

### 2. Triage

- Sentry groups by stack-trace fingerprint.
- An "issue" in Sentry = a deduped error class; events are individual
  occurrences.
- High-volume issues page on-call (alert: `event_rate > N`); low-volume
  issues notify Slack.

### 3. Ticket

Two patterns; pick one:

- **Sentry GitHub integration**: each Sentry issue can be one-clicked into a
  GitHub Issue with full context. Set up under
  Sentry → Settings → Integrations → GitHub.
- **Sentry → Linear/Jira webhook**: use Sentry's built-in Linear or Jira
  integration. Issues sync both ways; closing in Linear closes in Sentry.

### 4. Resolution & verification

- The fixing PR description includes `Resolves SENTRY-1234` (Sentry parses
  this).
- The next release tagged with `SENTRY_RELEASE` lets Sentry confirm "no new
  events for this issue since release vN" — the issue auto-resolves.

### 5. SLA

Per-severity SLA template:

| Severity | Triage SLA | Resolution SLA |
|---|---|---|
| SEV-1 | 15 min | 4 hours |
| SEV-2 | 2 hours | 2 business days |
| SEV-3 | 1 business day | 2 weeks |

### Example workflow YAML — Sentry webhook → repo issue

```yaml
# .github/workflows/sentry-issue.yml  (pattern; not in this repo)
name: sentry-to-issue
on:
  repository_dispatch:
    types: [sentry-issue]

jobs:
  open-issue:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            const { issue_url, project, level, culprit, message } = context.payload.client_payload;
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `[Sentry/${project}] ${culprit}: ${message}`,
              body: `Auto-created from Sentry.\n\nIssue: ${issue_url}\nLevel: ${level}\n\nRunbook: docs/runbooks/api-5xx.md`,
              labels: ['area:bug', 'source:sentry', `severity:${level}`],
            });
```

Wire the Sentry side via Sentry → Project → Alerts → "Send a notification via
an integration" → custom webhook with payload `{ "event_type": "sentry-issue", "client_payload": {…} }`.

### Linking PRs back to issues

- Every PR description must include either `Resolves #N` or `Refs #N`.
- For Sentry-sourced issues, use `Resolves SENTRY-N` so Sentry auto-resolves.
- This is enforced by a PR template / a small `actions/github-script` check.

### Why this matters for AI agents

When the orchestrator creates code, the **error → insight pipeline is the
verifier of last resort**. If a specialist's change quietly broke production:

- Sentry catches it.
- The issue auto-files in GitHub.
- The next agent run sees the open issue and includes it in the next
  Discover phase.

Without this loop, agents ship and never learn from production failures.

## Cross-references

- [`error-tracking.md`](error-tracking.md) — capture layer.
- [`alerting.md`](alerting.md) — paging policy.
- [`observability-runbook.md`](observability-runbook.md) — runbook index.
- [`runbooks/agent-misbehavior.md`](runbooks/agent-misbehavior.md) — when the
  orchestrator itself is the bug.
