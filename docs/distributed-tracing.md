# Distributed tracing

Two scopes: framework runtime tracing (long-running shell scripts) and target
projects (full OpenTelemetry).

> **Do not put secrets in `WB_RUN_ID`, hostnames, or script paths.** Those
> values are attached as resource/span attributes and propagate to whatever
> `OTEL_EXPORTER_OTLP_ENDPOINT` you configure. `wb-trace.sh` runs every
> outbound payload through `wb_log_scrub` to redact obvious credentials, but
> scrubbing is best-effort — keep tokens, keys, and PII out of trace inputs
> entirely. If you need a per-run identifier, use a random opaque ID.

## Framework runtime tracing

[`scripts/wb-trace.sh`](../scripts/wb-trace.sh) provides a minimal span model
that mirrors OpenTelemetry's data shape:

- Spans have `trace_id` (32 hex chars), `span_id` (16 hex chars),
  `parent_span_id`, `name`, `start_time_unix_nano`, `end_time_unix_nano`, and
  resource/scope attributes.
- Spans are pushed onto a stack via `wb_trace_start`, popped via
  `wb_trace_end`. Children inherit the parent's `trace_id`.

### When to use it

Use it inside multi-step scripts where you want to see how time is spent —
typically the orchestrator running in a target project.

### Example

```bash
source scripts/wb-trace.sh
sid_root=$(wb_trace_start "phase.implement")
  sid_child=$(wb_trace_start "task.run-tests")
    bash tests/run.sh
  wb_trace_end "$sid_child"
  sid_child2=$(wb_trace_start "task.commit")
    git commit -am "feat: x"
  wb_trace_end "$sid_child2"
wb_trace_end "$sid_root"
```

### Configuration

| Var | Purpose |
|---|---|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Base OTLP/HTTP endpoint. Spans go to `<endpoint>/v1/traces`. |
| `OTEL_EXPORTER_OTLP_HEADERS` | Comma-separated `k=v` headers (e.g., auth). |
| `OTEL_SERVICE_NAME` | Service name attached to every span. Default `wannabuild`. |
| `WB_RUN_ID` | If set, attached as a `wb.run_id` attribute on every span — useful for grouping a single run. |

Without `OTEL_EXPORTER_OTLP_ENDPOINT`, spans still emit `# TRACE …` lines to
stderr. CI logs preserve them; you can post-process them later.

### Trace context propagation

For now, propagation is intra-process (the stack file in `$TMPDIR`). Children
inherit the parent's `trace_id` automatically. Cross-process propagation is a
future enhancement (will export `traceparent` to environment vars per
[W3C Trace Context](https://www.w3.org/TR/trace-context/)).

---

## Target-project tracing — OpenTelemetry

OpenTelemetry is the right default. It's vendor-neutral; you can change
backends without re-instrumenting.

### Architecture

```text
[App SDK] -- OTLP --> [OTel Collector] -- exporter --> [Tempo / Jaeger / Honeycomb / Datadog]
```

Run a Collector close to your apps (sidecar or DaemonSet on Kubernetes). The
Collector handles:

- Batching, retries, backpressure.
- Resource detection (k8s, ec2, gcp).
- Tail-based sampling.
- Multiplexing to multiple backends during migrations.

### Setup — Node.js

```js
// instrumentation.js
import { NodeSDK } from "@opentelemetry/sdk-node";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";

const sdk = new NodeSDK({
  serviceName: process.env.OTEL_SERVICE_NAME ?? "my-app",
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT + "/v1/traces",
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});
sdk.start();
```

Run with `node --require ./instrumentation.js app.js`.

### Setup — Python

```python
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

resource = Resource.create({"service.name": os.environ.get("OTEL_SERVICE_NAME", "my-app")})
provider = TracerProvider(resource=resource)
provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
trace.set_tracer_provider(provider)
```

Add `opentelemetry-instrument` as the entrypoint to auto-instrument web frameworks.

### Setup — Go

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.21.0"
)

exp, _ := otlptracehttp.New(ctx)
tp := sdktrace.NewTracerProvider(
    sdktrace.WithBatcher(exp),
    sdktrace.WithResource(resource.NewWithAttributes(
        semconv.SchemaURL,
        semconv.ServiceName("my-app"),
    )),
)
otel.SetTracerProvider(tp)
```

### Setup — .NET

Use the `OpenTelemetry.Extensions.Hosting` + `OpenTelemetry.Exporter.OpenTelemetryProtocol`
packages. Configure in `Program.cs` via `builder.Services.AddOpenTelemetry()`.

### Sampler configs

| Strategy | When |
|---|---|
| `parentbased_always_on` | Dev. Cheap, full visibility. |
| `parentbased_traceidratio(0.1)` | Default for production (10%). |
| `parentbased_alwayson` + tail sampling at the Collector | Best — sample expensive at the edge. |

For tail-based sampling at the Collector, use the
[`tail_sampling` processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/tailsamplingprocessor)
to keep all error traces, all slow traces, and a small sample of successful
ones.

### Baggage & cross-service correlation

Use OpenTelemetry baggage for low-cardinality cross-service context (`tenant`,
`region`, `feature_flag`). Don't use baggage for high-cardinality data (user
IDs) — use span attributes instead.

### Tracing through async work

Manually link a child span to its parent context across async boundaries:

```js
import { context, trace } from "@opentelemetry/api";

const parentCtx = context.active();
queue.push(() => {
  context.with(parentCtx, () => {
    const span = trace.getTracer("worker").startSpan("job.process");
    try { /* … */ } finally { span.end(); }
  });
});
```

### Trace ↔ log correlation

Inject `trace_id` and `span_id` into every log line. Most languages have an
auto-instrumentation flag for this:

- Node: `LogProcessor` from `@opentelemetry/sdk-logs`.
- Python: `LoggingInstrumentor().instrument(set_logging_format=True)`.
- Go: helper in `otel/log/logr` (or copy `traceparent` into your zap fields).

Once injected, your log backend can pivot to the trace and back.

### Reference architectures

| Backend | Pro | Con |
|---|---|---|
| **Grafana Tempo** | Cheap (object storage), fits with Prometheus + Loki. | Search is by trace ID; needs Loki for free-text. |
| **Jaeger** | OSS, mature. | Operationally heavier than Tempo. |
| **Honeycomb** | Best UX for high-cardinality querying. | SaaS only. |
| **Datadog APM** | Bundled with metrics + logs. | Expensive, lock-in. |
| **AWS X-Ray** | First-party on AWS. | Limited cross-cloud. |

For new green-field projects, default to **OTel Collector → Tempo**. Cheap,
swap-able, no vendor lock.

## Cross-references

- [`metrics.md`](metrics.md) — paired with traces.
- [`error-tracking.md`](error-tracking.md) — Sentry tracesSampleRate ties in.
- [`observability.md`](observability.md) — overview.
