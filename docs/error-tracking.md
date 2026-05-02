# Error tracking

Two scopes: framework runtime, and target projects. The framework's scripts
are short-lived shell programs; target projects can be anything.

## Framework runtime error tracking

### `trap ERR` pattern for shell scripts

Every long-running repo script should attach an `ERR` trap that emits a
structured warning via `wb-log.sh`. This guarantees that even an unexpected
failure leaves a useful breadcrumb in the CI log instead of just an exit code.

```bash
#!/usr/bin/env bash
set -euo pipefail
__here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${__here}/wb-log.sh"

on_err() {
  local exit_code=$?
  local line="${BASH_LINENO[0]}"
  local cmd="${BASH_COMMAND}"
  wb_log_error "unhandled error in $(basename "${BASH_SOURCE[0]}")" \
    exit_code="${exit_code}" line="${line}" cmd="${cmd}"
  return "${exit_code}"
}
trap on_err ERR

# … your script …
```

When `SENTRY_DSN` is set in the environment, `wb-log.sh` is the single
extension point: a future PR will add a Sentry forwarder inside `wb_log_error`
that POSTs the captured frame as an event to Sentry's
[envelope endpoint](https://develop.sentry.dev/sdk/envelopes/). The hook is
already wired in [`.env.example`](../.env.example); the implementation is
tracked as TODO(@gl11tchy). The trap pattern is the contract that lets that hook work
once it lands.

### Where errors surface today

- **CI log**: the `wb_log_error` line shows up in the GitHub Actions UI.
- **CI exit code**: non-zero exit fails the job and triggers the standard
  email + Slack (if configured) notification path.
- **Runbook**: failed CI jobs link to
  [`runbooks/ci-failure.md`](runbooks/ci-failure.md).

See [`error-to-insight.md`](error-to-insight.md) for the auto-issue creation
flow on top of these signals.

---

## Target-project error tracking

### Backends — quick comparison

| Backend | Pros | Use when |
|---|---|---|
| **Sentry** | Best-in-class UX, OSS self-hostable, source maps, breadcrumbs, release health. | Default choice for most teams. |
| **Bugsnag** | Strong mobile/native support. | Mobile-heavy stack. |
| **Rollbar** | Solid Ruby/Python support, simple pricing. | Smaller orgs preferring simplicity. |
| **Honeybadger** | Friendly UX, good Ruby support. | Rails shops. |
| **Datadog Error Tracking** | Bundled with APM. | Already on Datadog. |

The rest of this doc uses Sentry as the canonical example because it's the
most common and the SDK API patterns transfer to the others.

### Setup — Node.js (Express)

```js
import * as Sentry from "@sentry/node";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.SENTRY_ENVIRONMENT,
  release: process.env.SENTRY_RELEASE,        // e.g. git sha
  tracesSampleRate: 0.1,                       // 10% APM
  profilesSampleRate: 0.1,
  integrations: [Sentry.httpIntegration(), Sentry.expressIntegration()],
});

app.use(Sentry.Handlers.requestHandler());
// …routes…
app.use(Sentry.Handlers.errorHandler());
```

### Setup — Python (FastAPI / Django / Flask)

```python
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration

sentry_sdk.init(
    dsn=os.environ["SENTRY_DSN"],
    environment=os.environ.get("SENTRY_ENVIRONMENT"),
    release=os.environ.get("SENTRY_RELEASE"),
    integrations=[FastApiIntegration()],
    traces_sample_rate=0.1,
)
```

### Setup — Go

```go
import "github.com/getsentry/sentry-go"

sentry.Init(sentry.ClientOptions{
    Dsn:         os.Getenv("SENTRY_DSN"),
    Environment: os.Getenv("SENTRY_ENVIRONMENT"),
    Release:     os.Getenv("SENTRY_RELEASE"),
    TracesSampleRate: 0.1,
})
defer sentry.Flush(2 * time.Second)
```

### Setup — browser

```js
import * as Sentry from "@sentry/browser";

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  release: process.env.SENTRY_RELEASE,
  tracesSampleRate: 0.1,
  replaysSessionSampleRate: 0.0,
  replaysOnErrorSampleRate: 1.0,
  integrations: [Sentry.browserTracingIntegration(), Sentry.replayIntegration()],
});
```

### Source maps (JS)

Upload source maps in CI — without them, browser stack traces are useless.
The official action:

```yaml
- uses: getsentry/action-release@v3
  env:
    SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
    SENTRY_ORG: my-org
    SENTRY_PROJECT: my-app
  with:
    environment: production
    sourcemaps: ./dist
    version: ${{ github.sha }}
```

### Best practices

- **User context**: call `Sentry.setUser({ id, email })` after auth so errors
  are tagged with the affected user (PII rules permitting — see
  [`secrets-management.md`](secrets-management.md)).
- **Breadcrumbs**: log domain events as breadcrumbs so the error timeline is
  rich (`Sentry.addBreadcrumb({ category: "auth", message: "login_attempt" })`).
- **Release tagging**: set `SENTRY_RELEASE` to the git sha or release tag so
  Sentry's release health view works. Pair with deploy markers (see
  [`deployment-observability.md`](deployment-observability.md)).
- **Sampling**: `tracesSampleRate` gates APM data, not error data — errors are
  always captured. Start at 0.1 and tune.
- **Filtering**: use `beforeSend` to scrub sensitive fields before sending
  events. PII rules: see [`secrets-management.md`](secrets-management.md) and
  [`log-scrubbing.md`](log-scrubbing.md).
- **Issue linkage**: enable Sentry's GitHub integration so each issue can be
  linked to a PR/commit. Combined with WannaBuild's checkpoints, an error can
  point back to the specialist agent that wrote the offending code.

### Integrating with WannaBuild checkpoints

When a target project running WannaBuild's orchestrator captures an error:

1. The orchestrator's checkpoint includes the active task ID and specialist
   name.
2. Pass these as Sentry tags:

   ```js
   Sentry.setTag("wannabuild.task_id", taskId);
   Sentry.setTag("wannabuild.specialist", specialist);
   ```

3. Errors in Sentry are now searchable by task and specialist, which closes
   the loop from production failure → specialist that produced it.

## Cross-references

- [`error-to-insight.md`](error-to-insight.md) — error → ticket pipeline.
- [`alerting.md`](alerting.md) — what to page on.
- [`secrets-management.md`](secrets-management.md) — PII filters.
- [`log-scrubbing.md`](log-scrubbing.md) — scrubbing breadcrumbs and contexts.
