# S7 resilience evidence index

Slice **S7** — backup/restore, recovery verification, load performance, FinOps,
and lab teardown evidence. All artifacts use **synthetic data only** unless a
live drill explicitly replaces placeholders and binds candidate SHA.

## Slice scope

| Capability | Status |
| --- | --- |
| RTO/RPO targets (lab) | Documented |
| Backup/restore change procedure | Documented |
| Teardown inventory + retention | Documented |
| Restore verification schema | Published |
| Load scenario + performance schema | Published |
| Synthetic performance baseline | Published |
| Bottleneck remediation story | Documented |
| FinOps cost model + idle detection | Documented |

## Artifact index

| Artifact | Path | Purpose |
| --- | --- | --- |
| RTO/RPO decision | [docs/decisions/rto-rpo.md](../../docs/decisions/rto-rpo.md) | Per-component lab recovery targets |
| FinOps decision | [docs/decisions/finops.md](../../docs/decisions/finops.md) | Cost model, budget alerts, right-sizing, idle detection |
| Backup/restore change | [operations/changes/CH-backup-restore.md](../../operations/changes/CH-backup-restore.md) | Procedure + verification checklist |
| Teardown change | [operations/changes/CH-teardown.md](../../operations/changes/CH-teardown.md) | Resource inventory + evidence retention |
| Restore verification schema | [tests/recovery/restore-verification.schema.json](../../tests/recovery/restore-verification.schema.json) | JSON schema for drill evidence |
| Recovery tests README | [tests/recovery/README.md](../../tests/recovery/README.md) | Schema usage and example |
| Load scenario | [tests/performance/load-scenario.md](../../tests/performance/load-scenario.md) | Traffic profile and success criteria |
| Performance results schema | [tests/performance/results.schema.json](../../tests/performance/results.schema.json) | Structured load test output |
| Synthetic baseline | [tests/performance/baseline-results.json](../../tests/performance/baseline-results.json) | **Synthetic** reference numbers |
| Bottleneck story | [tests/performance/bottleneck-before-after.md](../../tests/performance/bottleneck-before-after.md) | CPU throttling remediation narrative |

## Evidence events

Format follows `harness/schemas/evidence-event.schema.json` where applicable.
Synthetic lab artifacts are labeled `synthetic_data_label: true`.

| Event id | Candidate SHA | Result | Linked artifact |
| --- | --- | --- | --- |
| `s7-restore-drill` | `90ba9818c1911d43c31cc0c87c9111f6bb87e29c` | pass (synthetic) | [restore-verification-lab.json](../events/restore-verification-lab.json) |
| `s7-load-baseline` | `90ba9818c1911d43c31cc0c87c9111f6bb87e29c` | illustrative | [baseline-results.json](../../tests/performance/baseline-results.json) (synthetic) |
| `s7-teardown` | _pending_ | _pending_ | Teardown manifest JSON |
| `s7-finops-review` | _pending_ | _pending_ | Idle candidate report |

## Cross-slice dependencies

| Upstream slice | Dependency |
| --- | --- |
| S1 | `terraform/environments/recovery-lab/` compositions |
| S2 | Helm chart `kubernetes/chart/` |
| S3 | SQS/DLQ replay `serverless/infra/sqs-dlq.md` |
| S4 | SLO catalog `observability/slo-catalog.json` |
| S5 | Severity escalation `docs/decisions/severity-model.md` |

## Claim boundary

This index supports portfolio evidence for an isolated synthetic-data lab. It is
not a claim of sustained customer-production SRE ownership or audited DR
certification.
