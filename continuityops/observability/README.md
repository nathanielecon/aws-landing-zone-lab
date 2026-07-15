# ContinuityOps observability (S4)

OpenTelemetry collector config, trace/correlation instrumentation, RED/USE
dashboards, actionable alerts, and SLO catalog with error-budget burn rates.

## Layout

| Path | Purpose |
| --- | --- |
| `otel/collector-config.yaml` | OTLP receiver; batch, resource, and redaction-hint processors; logging + OTLP/HTTP exporters |
| `otel/instrumentation.md` | `correlation_id` and W3C tracecontext across ingress → k8s → SQS → Lambda |
| `dashboards/service.json` | RED panels for HTTP service |
| `dashboards/kubernetes.json` | USE-style pod/node panels (Prometheus placeholders) |
| `dashboards/serverless.json` | Lambda, primary queue, and DLQ panels |
| `alerts/alerts.yaml` | Alert catalog with owner, severity, runbook, dedupe, recovery |
| `slo-catalog.json` | SLIs/SLOs, error budgets, burn-rate thresholds |

## Quick start (repo-only)

1. Read `otel/instrumentation.md` for header and message-attribute propagation.
2. Import dashboard JSON into Grafana or map metrics to CloudWatch dashboards.
3. Wire `alerts/alerts.yaml` rules to your paging stack (SNS, PagerDuty, etc.).
4. Validate alert schema:

```powershell
pwsh -NoLogo -NoProfile -File continuityops/tests/observability/Test-AlertSchema.ps1
```

## Correlation

- HTTP: `X-Correlation-Id` + W3C `traceparent`
- SQS: `correlation_id` message attribute (see `serverless/worker.contract.json`)
- Logs: JSON with `correlation_id` and optional `trace_id`

Never log secrets, tokens, or full message bodies in traces or dashboards.

## SLO and alerting

`slos-catalog.json` defines 28-day objectives and burn-rate notes (fast 1h / slow 6h).
Alerts in `alerts/alerts.yaml` reference the same thresholds and include
`recovery_condition` so pages auto-resolve when metrics normalize.

Severity follows `docs/decisions/severity-model.md` (SEV-1 … SEV-4).

## Related slices

| Slice | Link |
| --- | --- |
| S2 | `kubernetes/chart/` — workload under observation |
| S3 | `serverless/` — event worker and DLQ |
| S5 | `operations/runbooks/` — incident procedures |

## Terraform

CloudWatch log group and baseline alarm scaffold live in
`terraform/modules/observability/`. This folder holds portable config and
dashboards independent of a single cloud account.
