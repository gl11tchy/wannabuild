# Alerting

## Framework alerting

For WannaBuild itself, the baseline alert path is:

1. **GitHub Actions failure email** — every CI failure on `main` emails the
   commit author and watchers. This is the floor; it's free and built-in.
2. **Scheduled security workflow failure** — the security workflow (owned by
   the CI batch; see [`ci.md`](ci.md)) runs nightly. A failure indicates the
   secret scanner, dependency audit, or supply-chain check broke. Treat as
   high-priority.
3. **Recommended additions** (not yet wired):
   - Slack webhook on `workflow_run` failure events for `main`. A 5-line
     `if: failure()` step is enough — see the snippet below.
   - Branch-protection-required-checks failures should page on-call (only
     once you have an on-call rotation).

### Slack webhook snippet

```yaml
- name: Notify Slack on failure
  if: failure() && github.ref == 'refs/heads/main'
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": ":x: ${{ github.workflow }} failed on `main`",
        "blocks": [
          {"type":"section","text":{"type":"mrkdwn","text":"*${{ github.workflow }}* failed on `${{ github.ref_name }}`.\nCommit: <${{ github.event.head_commit.url }}|${{ github.sha }}>\nRunbook: <https://github.com/${{ github.repository }}/blob/main/docs/runbooks/ci-failure.md|ci-failure.md>"}}
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

Every alert message **must** link to a runbook. No exceptions. Without a
runbook, the alert is noise.

### Alert → runbook table (framework)

| Alert | Runbook |
|---|---|
| CI workflow failed on `main` | [`runbooks/ci-failure.md`](runbooks/ci-failure.md) |
| `release-please` PR failed | [`runbooks/release-failure.md`](runbooks/release-failure.md) |
| Secret scanner found a leak | [`runbooks/secret-leak-incident.md`](runbooks/secret-leak-incident.md) |
| Dependabot/Renovate update broke CI | [`runbooks/dependency-update-failed.md`](runbooks/dependency-update-failed.md) |
| Devcontainer build failed in CI | [`runbooks/devcontainer-broken.md`](runbooks/devcontainer-broken.md) |
| Orchestrator misbehaved (target project report) | [`runbooks/agent-misbehavior.md`](runbooks/agent-misbehavior.md) |

---

## Target-project alerting

### Backends

| Backend | When to choose |
|---|---|
| **PagerDuty** | Standard for on-call rotations. |
| **OpsGenie** | Alternative to PD; Atlassian-stack alignment. |
| **Slack alerts** | Low-severity / FYI alerts. Never page-only Slack. |
| **Datadog Monitors** | If already on Datadog; skip a separate alerting layer. |
| **Grafana Alertmanager** | If on Prometheus/Grafana; routes to Slack/PD. |

### Policy

1. **Every alert has a runbook link.** If you can't write one, the alert
   isn't actionable; reconsider whether to page.
2. **Severity levels**:
   - `SEV-1` — pages 24/7. Reserved for outages and data loss.
   - `SEV-2` — pages business hours. Reserved for major degradation.
   - `SEV-3` — Slack only. Things to look at next business day.
3. **Alert hygiene**:
   - Track alert volume per service. Drop or silence noisy alerts within a
     week of noise.
   - Alerts should rarely be tied to a single metric — prefer composites
     (e.g., `error_rate > 1% AND request_rate > 10rps`).
   - Burn-rate alerts on SLOs are better than absolute thresholds.

### SLOs and error budgets

Pick one **availability SLO** and one **latency SLO** per critical user
journey. Common defaults:

| SLO | Target |
|---|---|
| Availability | 99.9% successful responses over 30d. |
| Latency | 95% of requests < 500ms over 30d. |

Burn-rate alerts (recommended): page when 2% of the monthly budget is burned
in 1 hour, or 5% in 6 hours. See
[Google's SRE workbook chapter on alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)
for the formulas.

### On-call rotation guidance

- Two engineers per rotation (primary + secondary).
- 1-week shifts.
- Hand-off doc: open Sentry list, recent deploys, known-flapping alerts.
- Post-incident: every SEV-1/2 gets a written post-mortem within 5 business
  days.

### Alert → runbook table template (target projects)

Copy this table into your project's `docs/alerts.md`:

| Alert | Severity | Trigger | Runbook |
|---|---|---|---|
| API 5xx rate high | SEV-1 | `error_rate > 1%` for 5m | `runbooks/api-5xx.md` |
| DB pool saturated | SEV-2 | `pool_in_use / pool_max > 0.9` for 10m | `runbooks/db-pool.md` |
| Queue backlog growing | SEV-2 | `queue_depth` ↑ 30m | `runbooks/queue-backlog.md` |
| Login failure rate | SEV-3 | `login_failures` > 5σ vs 7d baseline | `runbooks/login-anomaly.md` |

## Cross-references

- [`metrics.md`](metrics.md) — what to alert on.
- [`error-tracking.md`](error-tracking.md) — error rate alerts.
- [`observability-runbook.md`](observability-runbook.md) — runbook index.
- [`runbooks/ci-failure.md`](runbooks/ci-failure.md), etc.
