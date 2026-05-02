# Observability

WannaBuild observability has **two scopes**:

1. **Framework runtime** — observability for the framework's own scripts and
   CI runs. The framework itself is not a long-running application, but its
   shell scripts and CI workflows do execute, emit logs, fail in known ways,
   and benefit from real signals.
2. **Target projects using WannaBuild** — observability that any team using
   WannaBuild's orchestrator should set up in *their* application. This guide
   provides concrete patterns rather than hand-wavy advice.

Both scopes matter. AI agents can only verify their changes if they can read
real signals — logs, metrics, traces, errors, and analytics. This page is the
top of the observability tree; follow the links below for specifics.

---

## Scope 1 — Framework runtime observability

The framework's runtime surfaces are:

- Repo scripts under `scripts/` (linting, validation, install, doctor).
- The orchestrator running inside a target project (`skills/build/`).
- GitHub Actions workflows (CI, release, security).

### Primitives

| Primitive | Script | What it provides |
|---|---|---|
| Structured logs | [`scripts/wb-log.sh`](../scripts/wb-log.sh) | `wb_log_info`, `wb_log_warn`, `wb_log_error`, etc. Honors `WB_LOG_LEVEL` and `WB_LOG_FORMAT` (text/JSON). |
| Metrics | [`scripts/wb-metrics.sh`](../scripts/wb-metrics.sh) | `wb_metric_counter`, `wb_metric_gauge`, `wb_metric_timing`, `wb_metric_event`. POSTs to `WB_METRICS_ENDPOINT` if set; always emits `# METRIC …` lines to stderr. |
| Traces | [`scripts/wb-trace.sh`](../scripts/wb-trace.sh) | `wb_trace_start`, `wb_trace_end`. Emits OTLP/HTTP spans to `OTEL_EXPORTER_OTLP_ENDPOINT` if set; otherwise emits `# TRACE …` lines to stderr. |
| CI job metrics | [`scripts/ci-metrics-collect.sh`](../scripts/ci-metrics-collect.sh) | Emits `ci_job_complete` events at the end of every CI job. Always exits 0. |

### Configuration

All optional. Set in a local `.env` (gitignored) or in CI secrets/vars. See
[`../.env.example`](../.env.example) for the canonical list.

| Var | Effect |
|---|---|
| `WB_LOG_LEVEL` | `debug`/`info`/`warn`/`error`. Default `info`. |
| `WB_LOG_FORMAT` | `text` or `json`. Default `text`. |
| `WB_METRICS_ENDPOINT` | If set, metrics are POSTed there as JSON. |
| `WB_METRICS_TOKEN` | Bearer token for the metrics endpoint. |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | If set, traces are POSTed to `<endpoint>/v1/traces`. |
| `OTEL_EXPORTER_OTLP_HEADERS` | Comma-separated `k=v` pairs added as headers. |
| `OTEL_SERVICE_NAME` | Service name attached to spans. Default `wannabuild`. |
| `SENTRY_DSN` | Forwarded to error reporters when set. |

### Self-tests

```bash
bash scripts/wb-metrics.sh --self-test
bash scripts/wb-trace.sh --self-test
```

Both scripts ship with self-tests that exercise every public function.

### Supplementary docs

- [`metrics.md`](metrics.md) — what each metric means, recommended SLOs.
- [`distributed-tracing.md`](distributed-tracing.md) — span model, OTLP wiring.
- [`error-tracking.md`](error-tracking.md) — `trap ERR` patterns, Sentry hook.
- [`alerting.md`](alerting.md) — what to alert on for the framework's CI.
- [`code-quality-metrics.md`](code-quality-metrics.md) — shellcheck/markdownlint/coverage trends.
- [`deployment-observability.md`](deployment-observability.md) — releases as deploy events.
- [`error-to-insight.md`](error-to-insight.md) — error → issue automation.

---

## Scope 2 — Target-project observability

If you're a team using WannaBuild's orchestrator to build a real application,
the docs below give you concrete patterns, not aspirational generalities. Each
covers Node, Python, Go (where relevant), and the major SaaS backends.

| Concern | Doc |
|---|---|
| Metrics taxonomy & instrumentation | [`metrics.md`](metrics.md) |
| Distributed tracing & OpenTelemetry | [`distributed-tracing.md`](distributed-tracing.md) |
| Error capture (Sentry, Bugsnag, …) | [`error-tracking.md`](error-tracking.md) |
| Alerting policy & SLOs | [`alerting.md`](alerting.md) |
| Product analytics | [`product-analytics.md`](product-analytics.md) |
| Code quality metrics | [`code-quality-metrics.md`](code-quality-metrics.md) |
| Deployment observability | [`deployment-observability.md`](deployment-observability.md) |
| Error → insight pipeline | [`error-to-insight.md`](error-to-insight.md) |

---

## Why this matters for AI agents

An AI agent that can write code but can't *see* the consequences of running it
in production is operating blind. Real observability gives the agent — and the
human reviewing it — a feedback loop:

- Logs tell the agent which branches actually ran.
- Metrics tell it whether throughput, latency, or error rates moved.
- Traces let it pinpoint which call path a regression came from.
- Error tracking lets it see which exception classes spiked after a change.
- Product analytics let it see whether anyone used the new feature.

The contracts in WannaBuild's [`AGENTS.md`](../AGENTS.md) treat the integration
tester as a hard gate, but real production signal is what catches the things
unit and integration tests miss. Set up the items above before letting agents
ship to production.

## Runbooks

Operational runbooks live under [`runbooks/`](runbooks/). Start at
[`observability-runbook.md`](observability-runbook.md) for the index.
