# ContinuityOps

**Cloud reliability and recovery lab** — governed build → cloud runtime →
observable incident → verified recovery.

| | |
| --- | --- |
| Plan | `continuityops-cloud-reliability-v1` |
| Folder | `continuityops/` (independent; no Project A/C edits) |
| Orchestrator | Grok 4.5 High Fast |
| Build gates | none while building |
| Accuracy bar | multi-threaded Ralphy loops until ≥ 9.5 |

## Outcomes (Stage 1)

- Terraform modules: network, EKS, serverless, observability
- Staging + recovery-lab compositions
- Digest-pinned Helm chart with hardening defaults
- SQS/Lambda worker with idempotency, poison handling, DLQ docs + unit tests
- OTel, dashboards, alerts, SLO catalog
- Eight incident drills + runbooks with stop/escalation cautions
- Agentic proposal workflow with unsafe-proposal rejection tests
- RTO/RPO, restore, load, FinOps, teardown procedures (synthetic baselines)

## Five-minute local demo

```powershell
pwsh -NoLogo -NoProfile -File continuityops/scripts/Invoke-ContinuityOpsValidate.ps1
pwsh -NoLogo -NoProfile -File continuityops/agentic/tests/Test-UnsafeProposals.ps1
pwsh -NoLogo -NoProfile -File continuityops/tests/observability/Test-AlertSchema.ps1
cd continuityops/serverless; node --test tests/*.test.js
```

Optional (if Helm installed):

```powershell
pwsh -NoLogo -NoProfile -File continuityops/tests/kubernetes/Test-ContinuityOpsChart.ps1
```

## Technology map

| Area | Stack |
| --- | --- |
| IaC | Terraform AWS ~> 5 |
| Kubernetes | EKS + Helm |
| Serverless | Lambda + SQS + DLQ |
| Telemetry | OpenTelemetry + CloudWatch-oriented catalogs |
| Delivery | GitHub Actions OIDC drafts |
| Agentic | Evidence + proposal only |

## Evidence

- [Evidence index](evidence/INDEX.md)
- [Claims boundary](docs/claims/claims-boundary.md)
- [Architecture](docs/architecture/overview.md)

## Honest claim footer

Isolated synthetic-data cloud lab with evidence-backed runtime and recovery
drills; **not** a claim of sustained customer-production SRE ownership.
