# ContinuityOps evidence index

Append-only index of Stage 1 build evidence. All artifacts are ContinuityOps lab
scope under `continuityops/`. Not Project A/C production evidence.

| Slice | Artifact | Notes |
| --- | --- | --- |
| S0 | `evidence/manifests/folder-ready.json` | Folder validators |
| S1 | `terraform/environments/staging/` | Staging composition |
| S1 | `terraform/environments/recovery-lab/` | Recovery-lab composition |
| S1 | `app-contract/release-contract.json` | Lab release contract |
| S2 | `kubernetes/chart/` | Helm chart (digest-pinned values) |
| S2 | `kubernetes/scenarios/` | Failure inject/restore drills |
| S3 | `serverless/src/worker/` | SQS worker + unit tests |
| S3 | `serverless/infra/sqs-dlq.md` | DLQ/replay procedure |
| S4 | `observability/alerts/alerts.yaml` | Actionable alerts |
| S4 | `observability/slo-catalog.json` | SLOs + error budget |
| S5 | `operations/drills/` | Eight incident drills |
| S5 | `operations/runbooks/` | Pressure-usable runbooks |
| S6 | `agentic/tests/unsafe-proposal-cases.json` | Rejected unsafe proposals |
| S6 | `docs/guardrails/` | IAM/secrets/supply-chain |
| S7 | `evidence/slices/S7-resilience.md` | RTO/RPO, load, FinOps |
| S8 | `docs/claims/claims-boundary.md` | Honest claim limits |
| S8 | `docs/architecture/overview.md` | Architecture overview |

## Claim footer

Isolated synthetic-data cloud lab with evidence-backed runtime and recovery
drills; not a claim of sustained customer-production SRE ownership.
