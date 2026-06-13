# Metrics

Two scopes: framework runtime, and target projects. Concrete instrumentation
patterns below.

## Framework runtime metrics

[`scripts/wb-metrics.sh`](../scripts/wb-metrics.sh) is the single emission
primitive. Every function emits a `# METRIC …` line to stderr (so it survives
in CI logs) and, when `WB_METRICS_ENDPOINT` is set, POSTs the same data as
JSON.

### Metric inventory

| Name | Kind | Emitter | Meaning |
|---|---|---|---|
| `ci_job_complete` | event | [`scripts/ci-metrics-collect.sh`](../scripts/ci-metrics-collect.sh) | One row per CI job. Attributes: `name`, `workflow`, `run_id`, `repo`, `ref`, `sha`, `result`, `duration_ms`. |
| `lint_duration_ms` | timing | (future) lint script | Total lint runtime. |
| `test_duration_ms` | timing | (future) test runner wrapper | Total test runtime. |
| `coverage_pct` | gauge | (future) coverage step | Aggregate kcov coverage. |
| `validator_violations_total` | counter | `scripts/validate-wannabuild-artifacts.sh` (future hook) | Number of contract violations found during a run. |

Scripts owned by other batches will call into `wb-metrics.sh` to populate the
"future" rows once those scripts land. The emitter is stable and additive: new
metrics may be added without changing existing ones.

### Recommended SLOs (framework CI)

Keep CI fast or contributors stop running it locally.

| Job | p95 target | Hard fail |
|---|---|---|
| Lint (shellcheck + markdownlint + prettier) | < 60s | 180s |
| Test (bats) | < 90s | 300s |
| Validator (`validate-wannabuild-artifacts.sh` against fixtures) | < 30s | 120s |
| Doctor (`wannabuild-doctor.sh`) | < 5s | 30s |
| Full CI run (default branch) | < 5min | 15min |

### Reading metrics from CI logs

```bash
# Pull every metric line from a job log saved as `job.log`:
grep '^# METRIC ' job.log
```

Or with `jq` after a Datadog-style sink ingests them:

```bash
curl -fsS "$DD_QUERY_URL" | jq '.series[] | {name: .metric, p95: .pointlist[-1][1]}'
```

### Wiring to a backend

The simplest sink is a tiny HTTP receiver that converts JSON events to your
backend's protocol. Two examples:

**Datadog** (DogStatsD over HTTP via the events API):

```bash
WB_METRICS_ENDPOINT="https://api.datadoghq.com/api/v1/events"
WB_METRICS_TOKEN="$DD_API_KEY"  # Datadog accepts the API key as a Bearer token via a small adapter
```

**OpenTelemetry Collector** (preferred, vendor-neutral):

```yaml
# otel-collector-config.yaml
receivers:
  otlphttp:
    endpoint: 0.0.0.0:4318
exporters:
  prometheusremotewrite:
    endpoint: https://<your-prom>/api/v1/write
service:
  pipelines:
    metrics:
      receivers: [otlphttp]
      exporters: [prometheusremotewrite]
```

Then point `WB_METRICS_ENDPOINT` at a small forwarder that converts the
`# METRIC` JSON to OTLP metrics. (A future repo task will ship a reference
forwarder; tracked as TODO(@gl11tchy).)

---

## Target-project metrics guide

For applications built with WannaBuild, follow well-known taxonomies.

### RED method (request-driven services)

For every endpoint / RPC / job:

- **Rate** — requests per second.
- **Errors** — error count or error rate.
- **Duration** — latency distribution (p50/p95/p99).

### USE method (resources)

For every resource (CPU, memory, disk, queue, connection pool):

- **Utilization** — % busy.
- **Saturation** — queue depth or wait time.
- **Errors** — error events on the resource.

### Instrumentation patterns

#### Node / Express (prom-client)

```js
import express from "express";
import client from "prom-client";

const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpDuration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "HTTP request duration",
  labelNames: ["method", "route", "status"],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
  registers: [register],
});

const app = express();
app.use((req, res, next) => {
  const end = httpDuration.startTimer({ method: req.method });
  res.on("finish", () => end({ route: req.route?.path ?? "unknown", status: res.statusCode }));
  next();
});

app.get("/metrics", async (_req, res) => {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
});
```

#### Python / FastAPI (prometheus_client)

```python
from prometheus_client import Counter, Histogram, make_asgi_app
from fastapi import FastAPI, Request
import time

REQ = Counter("http_requests_total", "HTTP requests", ["method", "route", "status"])
DUR = Histogram("http_request_duration_seconds", "HTTP duration", ["method", "route"])

app = FastAPI()

@app.middleware("http")
async def instrument(request: Request, call_next):
    start = time.monotonic()
    response = await call_next(request)
    elapsed = time.monotonic() - start
    route = request.scope.get("route").path if request.scope.get("route") else "unknown"
    REQ.labels(request.method, route, response.status_code).inc()
    DUR.labels(request.method, route).observe(elapsed)
    return response

app.mount("/metrics", make_asgi_app())
```

#### Go (prometheus client_golang)

```go
import (
    "net/http"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var httpDur = promauto.NewHistogramVec(prometheus.HistogramOpts{
    Name:    "http_request_duration_seconds",
    Help:    "HTTP request duration",
    Buckets: prometheus.DefBuckets,
}, []string{"method", "route", "status"})

func main() {
    http.Handle("/metrics", promhttp.Handler())
    // wrap your handlers with httpDur.WithLabelValues(...).Observe(elapsed)
    http.ListenAndServe(":8080", nil)
}
```

### Backends — quick comparison

| Backend | Pro | Con |
|---|---|---|
| **Prometheus** (self-hosted) | Free, well-understood, OSS, alerting via Alertmanager. | Operational burden, retention/scaling work. |
| **Grafana Cloud** | Managed Prometheus + Loki + Tempo, generous free tier. | Lock-in to Grafana stack. |
| **Datadog** | Best-in-class UX, agent integrations everywhere. | Expensive at scale. |
| **New Relic** | Full APM + logs + RUM bundled, free 100GB/mo tier. | Less Kubernetes-native than Datadog. |
| **OpenTelemetry Collector → anywhere** | Vendor-neutral, future-proof. | Requires running the collector. |

For new projects, default to OpenTelemetry SDK + Collector with
`prometheusremotewrite` exporter. You can re-point the exporter without
re-instrumenting code.

### From CI to backend

Two patterns:

1. **Push from runners**: each CI job runs `ci-metrics-collect.sh`, which
   POSTs to `WB_METRICS_ENDPOINT` (set as a repo secret in CI vars).
2. **Pull from logs**: a scheduled job parses `# METRIC …` lines out of
   archived run logs and writes them into the backend. Slower but doesn't
   require runner egress permissions.

Pick based on your security posture. (1) is simpler when allowed; (2) avoids
giving CI runners credentials to your metrics backend.

## Cross-references

- [`observability.md`](observability.md) — overview.
