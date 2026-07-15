# Trace and correlation propagation (ingress → k8s → queue → Lambda)

ContinuityOps lab path for end-to-end request and event correlation. English
only; no secrets in logs or traces.

## Identifiers

| Field | Format | Scope |
| --- | --- | --- |
| `trace_id` | W3C Trace Context (32 hex) | Distributed trace span tree |
| `span_id` | W3C (16 hex) | Single hop within a trace |
| `correlation_id` | UUID v4 (recommended) | Business / incident correlation across async hops |

`correlation_id` is the human-friendly join key for dashboards, DLQ samples, and
incident records. W3C `traceparent` / `tracestate` carry the OpenTelemetry trace
for latency and dependency analysis.

## Hop-by-hop flow

```text
Client / API gateway
  │  traceparent: 00-{trace_id}-{span_id}-01
  │  X-Correlation-Id: {uuid}   (or generated at edge)
  ▼
Ingress (nginx / ALB)
  │  Preserve incoming traceparent; do not strip X-Correlation-Id.
  │  Ingress controller span: child of client span.
  ▼
Kubernetes Deployment (continuityops-lab-app)
  │  OTel SDK auto-instrumentation reads traceparent from HTTP headers.
  │  Structured logs include correlation_id + trace_id (from active span).
  │  Outbound publish to SQS sets message attribute correlation_id and
  │  injects trace context into message attributes (traceparent) when supported.
  ▼
SQS (continuityops-events)
  │  Message attributes: correlation_id, tenant_id, event_type (see worker contract).
  │  Body: JSON object only.
  ▼
Lambda (continuityops-event-worker)
  │  correlation_id := messageAttributes.correlation_id ?? messageId
  │  OTel Lambda layer continues trace from SQS carrier when present.
  │  JSON logs: level, correlation_id, message, service, timestamp (+ trace_id).
  ▼
CloudWatch Logs / OTLP backend
  │  Query by correlation_id OR trace_id for full path.
```

## Header and attribute mapping

| Hop | W3C Trace Context | correlation_id |
| --- | --- | --- |
| HTTP ingress | `traceparent`, `tracestate` | `X-Correlation-Id` request header |
| K8s pod logs | `trace_id`, `span_id` in log fields | Same as request or generated once per request |
| SQS message | `traceparent` in message attributes (optional lab) | `correlation_id` message attribute (recommended) |
| Lambda logs | Active span `trace_id` when instrumented | From SQS attribute or `messageId` fallback |

The worker fallback (`messageId`) is for lab traffic only. Producers MUST set
`correlation_id` for tenant lifecycle events (`continuityops/docs/decisions/saas-lifecycle.md`).

## Instrumentation checklist

1. **Ingress** — Forward `traceparent`, `tracestate`, and `X-Correlation-Id`; do not
   rewrite unless generating a new correlation at the edge.
2. **K8s app** — Enable OTel SDK with `OTEL_EXPORTER_OTLP_ENDPOINT` pointing at the
   in-cluster collector (`collector-config.yaml` OTLP receiver on 4317/4318).
3. **SQS publish** — Set `correlation_id` message attribute; optionally propagate
   `traceparent` for async trace linking.
4. **Lambda** — Use structured JSON logging (`worker.contract.json`); avoid logging
   message bodies that may contain PII.
5. **Collector** — `attributes/redaction_hints` processor strips auth cookies and
   hashes sensitive attributes before export.

## Query examples

- **Logs (CloudWatch Insights)** — filter `@message` like /"correlation_id":"{uuid}"/
- **Traces** — search `trace_id` from log line or Grafana Tempo trace lookup
- **DLQ triage** — read `correlation_id` from DLQ message attributes; match worker
  error logs and ingress access logs for the same value

## Related artifacts

- `continuityops/serverless/worker.contract.json` — logging and message attributes
- `continuityops/serverless/infra/sqs-dlq.md` — DLQ and replay
- `continuityops/observability/otel/collector-config.yaml` — collector pipelines
- `continuityops/observability/slo-catalog.json` — SLO and burn-rate targets
