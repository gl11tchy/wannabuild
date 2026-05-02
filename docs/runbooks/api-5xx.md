# Runbook: API 5xx rate is elevated

> Canonical "your service is throwing 5xx" runbook. The alerting and
> error-to-insight docs link here as the worked example. If you fork this
> runbook into a target project, keep the structure and adapt the specifics.

## Symptom

- The "API 5xx rate high" alert fired in PagerDuty / Opsgenie.
- Sentry reports a sudden spike in `HTTPException 5xx` events for the API
  project.
- Customer reports of "the site is broken" or "I keep getting an error page".
- Synthetic uptime check (`/healthz`, `/status`) failed.
- A dashboard shows `error_rate = 5xx_responses / total_responses` rising
  above the warning threshold (see severity matrix below).

## Severity matrix

Severity is set by the **sustained** error rate over a 5-minute window. Spikes
that recover within one alert evaluation cycle (typically 1-2 min) do not
require paging.

| 5xx rate (sustained 5m) | Severity | Response                                                              |
|---|---|---|
| `< 1%`             | Warning   | Triage during business hours. Open an issue. No paging.                       |
| `1% – 5%`          | SEV-3     | On-call acknowledges within 15 min. Triage immediately. No customer comms yet.|
| `5% – 25%`         | SEV-2     | On-call acknowledges within 5 min. Page the service owner. Status page TBD.   |
| `> 25%`            | SEV-1     | Page on-call + manager. Update status page within 10 min. Mitigate first, RCA later. |

If the alert is firing on a single endpoint (not the whole API), drop one
severity level — but only if the affected endpoint is non-critical (e.g. an
admin-only path). Auth, billing, and core read paths stay at the matrix
severity regardless of scope.

## Triage

Work the steps in order. Stop when you have a clear cause; don't keep
collecting data after you've found it.

1. **Check the status page of every upstream you depend on.** Cloud provider,
   payment processor, identity provider, CDN, database-as-a-service. A single
   provider outage explains most "everything is on fire" alerts. If an upstream
   is down, jump to **Mitigation → Traffic shed / degrade gracefully** and skip
   the rest of triage.

2. **Check the most recent deploy.** In your deploy dashboard (or
   `git log --since='2 hour ago' --first-parent main`), find the last release
   to production. If it landed within the alert window, this is almost
   certainly the cause — move to **Mitigation → Rollback** immediately and
   investigate after.

3. **Open the error tracking dashboard** (Sentry / Rollbar / Datadog Errors).
   Group the 5xx errors by `exception.type` and `transaction`. Look for:
   - One exception type dominating → likely a code bug from the recent deploy
     or a newly exposed code path.
   - Many different exceptions across many endpoints → infrastructure problem
     (database down, network partition, exhausted connection pool).
   - Errors only on one host / pod / container → bad node; cordon and replace.

4. **Check infrastructure metrics** for the API tier:
   - CPU saturation (`> 85%` sustained)
   - Memory pressure / OOM kills in the last 30 min
   - Database connection pool utilisation (`pool_in_use / pool_max > 0.9`)
   - Disk usage on stateful nodes (`> 90%`)
   - Network errors / retransmits

   A saturated dependency (DB, cache, queue) often surfaces as 5xx in the API
   tier. If you see saturation, jump to **Mitigation → Scale**.

5. **Check the load balancer / ingress logs** for a non-app-layer error
   (e.g. 502 from the LB itself, TLS handshake failures, upstream timeouts).
   These bypass your application logging entirely and are easy to miss.

6. **Sample a few recent failing requests end-to-end** using your tracing
   system (Tempo, Honeycomb, X-Ray, Datadog APM). Pick 3 random failed
   `trace_id`s and walk the spans. If the failure is in a downstream span
   (DB, RPC), the root cause is there, not in the API.

7. **Check rate limiting and bot traffic.** A sudden traffic spike from a
   single ASN, user-agent, or IP range can manifest as 5xx if you're
   capacity-bound. If confirmed, jump to **Mitigation → Traffic shed**.

## Common causes

- **Bad deploy.** New code path crashes; missing migration; a config change
  invalidated cached values.
- **Database overload.** N+1 query introduced; missing index; runaway
  analytics query holding a lock; connection pool exhausted.
- **Upstream dependency outage.** Auth provider, payment gateway, third-party
  API. Often paired with elevated latency before failures.
- **Resource exhaustion.** OOM kills, disk full, file descriptors exhausted,
  ephemeral port exhaustion under load.
- **Cache stampede.** A popular cache key expired; thundering herd hits the
  origin DB.
- **DNS / TLS / network layer.** Expired certificate; DNS provider hiccup;
  cloud provider regional networking event.
- **Traffic spike.** Marketing launch, viral content, or a misbehaving
  client/bot driving 10x normal QPS.
- **Schema drift.** A migration ran but the application pods still cache the
  old schema; rolling restart needed.

## Mitigation

Apply the *first* mitigation that addresses the cause. Don't stack
mitigations — that makes the postmortem harder.

- **Rollback** (preferred when triage step 2 found a recent deploy):

  ```bash
  # Generic; adapt to your platform.
  kubectl rollout undo deployment/api -n production
  # or
  gh workflow run deploy.yml -f ref=<previous-good-sha>
  ```

  Watch the 5xx rate for 5 min. If it doesn't recover, the rollback wasn't
  the fix — try the next mitigation.

- **Scale.** If saturation is the cause, add capacity:

  ```bash
  kubectl scale deployment/api --replicas=<2x current> -n production
  # or for managed runtimes: bump the min-instance count in the dashboard
  ```

  For DB-side saturation, scale the DB read replica pool, raise the
  connection pool limit (carefully — don't exceed the DB's `max_connections`),
  or kill long-running queries.

- **Feature-flag disable.** If the failing code path is gated behind a flag,
  flip it off. This is the cheapest mitigation when available.

  ```bash
  # Example with LaunchDarkly / Unleash / your in-house flag tool
  ld flag disable new-checkout-flow --env production
  ```

- **Traffic shed.** When the spike is from a small set of clients or you must
  buy time, shed load at the edge:
  - Block offending IP ranges / ASNs at the WAF or CDN.
  - Lower the per-IP rate limit at the edge.
  - Return `503` with `Retry-After` from the LB on a percentage of requests
    to a non-critical path.
  - For an upstream outage you can't fix, serve a **degraded read-only
    response** (last-known cache, static fallback page) instead of 5xx.

- **Hard-fail open** (last resort, only with on-call manager approval). For
  non-critical middleware (analytics, audit logging, rate limiting) that is
  itself causing the 5xx, bypass it temporarily so the core API can serve.

## Communication

Communicate as soon as the severity is known — don't wait for full
understanding.

- **SEV-1 / SEV-2:** Update the public status page within 10 min of paging.
  Use a brief, factual template:

  > *We are investigating elevated error rates on the API. We will update
  > this status within 30 minutes.*

  Post in the internal `#incidents` Slack channel with:
  - The PagerDuty incident link
  - The dashboard you're watching
  - Who is leading the response (incident commander)
  - Who is fixing (technical lead)

- **SEV-3:** Internal Slack only. Status page is updated only if the issue
  is customer-visible for `> 30 min`.

- **Customer comms threshold:** Direct email to affected customers if the
  incident exceeds 1 hour OR affects billing/auth/data integrity. CSM /
  Support owns the wording; engineering provides the facts.

- **All-clear:** When 5xx rate has been below the warning threshold for
  15 min, mark the status page resolved and post the all-clear in Slack.

## Postmortem

Required for SEV-1 and SEV-2; optional for SEV-3 unless it's a repeat
incident. Use your team's canonical postmortem template (typical sections:
*Summary*, *Timeline*, *Root cause*, *What went well*, *What didn't*,
*Action items*).

Action items must be filed as issues with owners and dates within 48 hours
of the incident closing.

## Related runbooks

- [`ci-failure.md`](ci-failure.md) — if a failed deploy was the trigger and
  CI didn't catch it, the gap belongs there.
- [`dependency-update-failed.md`](dependency-update-failed.md) — if a
  dependency bump auto-merged and broke production.
- [`secret-leak-incident.md`](secret-leak-incident.md) — if the 5xx storm
  was caused by a rotated/revoked credential.
- [`release-failure.md`](release-failure.md) — if the bad deploy came from
  a release-please-cut release.
