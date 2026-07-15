# ContinuityOps architecture overview

**Flow:** Governed build → cloud runtime → observable incident → verified recovery

## Control plane

- GitHub Actions (path-filtered ContinuityOps workflows)
- Short-lived cloud identity via OIDC (draft plan workflow; apply when lab role exists)
- Human-gated mutation is a **product control** in agentic policy; build loops do
  not wait on receipts

## Runtime

- Managed Kubernetes (EKS module + Helm release for ContinuityOps lab app)
- Parallel serverless path: Queue → Worker → DLQ + Replay
- OpenTelemetry correlation across ingress, service, queue, and worker

## Operate

- Metrics, logs, traces → SLO alerts → incident + runbook → recovery verification
- Agent-assisted evidence + remediation **proposal only** (no default mutation)
- Evidence + cost retained after teardown of lab resources

## Environments

| Env | Purpose |
| --- | --- |
| local | kind/helm/unit tests |
| staging | hosted integration |
| recovery-lab | destructive drills |
| portfolio-demo | optional read-only demo |

## Orchestration

1. Stage 1 — create project via Grok orchestration (this tree)
2. Stage 2 — multi-threaded accuracy/no-error Ralphy loops until ≥ 9.5
