# Post-build partition notes

ContinuityOps is partitioned by **operational capability**, not by which worker or construction stream produced a path.

| ID | Capability | Rationale |
|----|------------|-----------|
| `P_authority` | Authority / harness | Plan, status, harness policies/schemas/tasks, orchestration scripts, integration locks, and phase-0 / accuracy evidence manifests that govern the build. |
| `P_foundation` | Foundation / Terraform + delivery | Bootstrap and environment Terraform, shared modules, app release contracts, and GitHub workflow delivery stubs. |
| `P_kubernetes` | Kubernetes | Helm chart, admission-style policies, failure scenarios, and chart tests for the cluster runtime. |
| `P_serverless` | Serverless | Worker source/tests/contracts, SQS/DLQ notes, and SaaS lifecycle / opportunity decision docs. |
| `P_observability` | Observability | SLO catalog, alerts, dashboards, OTel config, and alert-schema tests. |
| `P_operations` | Operations / incidents | Runbooks, drills, incident and postmortem templates (day-2 ops), excluding change/DR paperwork. |
| `P_security` | Security / agentic | Agentic prompts and mutation/safety policies plus IAM, secrets, and supply-chain guardrails. |
| `P_resilience` | Resilience / DR / FinOps | Backup/teardown changes, recovery and performance tests, RTO/RPO and FinOps decisions, resilience evidence slices. |
| `P_portfolio` | Portfolio / evidence / docs | Architecture and claims docs, language policy, interview walkthrough, and remaining evidence index/events. |

**Coverage rule:** every git-tracked file under `continuityops/` except paths under `.terraform/` appears in exactly one partition. Capability-specific docs (for example `docs/guardrails/*` or `docs/decisions/rto-rpo.md`) stay with the owning capability rather than the generic docs bucket. This partition does not score quality.
