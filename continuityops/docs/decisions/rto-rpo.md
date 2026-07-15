# RTO and RPO targets (recovery-lab)

Decision record for ContinuityOps **lab** recovery objectives by component.
Targets apply to `recovery-lab` and synthetic drill datasets only. Staging and
any future production tier may tighten these values after SLO review.

## Definitions

| Term | Meaning |
| --- | --- |
| **RTO** | Maximum acceptable time to restore a component to an operational state that passes verification checks |
| **RPO** | Maximum acceptable data loss measured as time since the last durable recovery point |

Lab drills measure wall-clock time from declared incident start to green
`restore-verification` artifact. Evidence binds to candidate SHA; no live customer
data or credentials appear in the repository.

## Component targets

| Component | Scope | RTO (lab) | RPO (lab) | Recovery method | Justification |
| --- | --- | --- | --- | --- | --- |
| **EKS workloads** | Helm release `continuityops-lab`, namespace `continuityops-lab` | 30 minutes | 0 (stateless pods) | Helm rollback or redeploy from pinned image digest | Pods are disposable; config lives in Git and Helm values. RTO bounded by image pull + rollout (`kubernetes/chart/`). No persistent volume claims in lab chart. |
| **EKS control plane** | AWS-managed EKS API | 60 minutes | N/A (AWS-managed) | Wait for regional recovery or rebuild cluster via Terraform | Control plane is AWS-operated. Lab accepts full cluster rebuild from `terraform/environments/recovery-lab/` when data plane is intact. RTO includes node group recreation. |
| **Lambda worker** | `continuityops-recovery-worker` | 15 minutes | 0 (stateless) | Redeploy function zip from `serverless/build/worker.zip` | Handler is stateless; idempotency keys live in message attributes. Fast rollback via Terraform or alias traffic shift. |
| **SQS primary queue** | `continuityops-recovery-worker` | 10 minutes | 4 days max loss | Recreate queue + redrive from DLQ | Message retention default 4 days (`serverless/infra/sqs-dlq.md`). RPO equals oldest unprocessed message age at failure. Lab accepts full queue loss when messages are synthetic drill traffic only. |
| **SQS DLQ** | `continuityops-recovery-worker-dlq` | 20 minutes | 14 days max loss | Redrive to primary or archive to evidence bucket | DLQ is the authoritative failed-message store during incidents. Retention 14 days gives replay window after code fixes. |
| **Terraform state** | Remote backend for recovery-lab | 45 minutes | 24 hours | Restore state object from versioned backend snapshot | Infrastructure desired state is Git-backed; state loss delays apply but does not destroy AWS resources immediately. RPO assumes daily state versioning in lab backend. |
| **CloudWatch logs** | `/continuityops/continuityops-recovery` | 30 minutes | 7 days | Re-enable log shipping; historical logs unrecoverable after retention | Log group retention from observability module. Logs support verification, not authoritative business data. |
| **VPC / network** | `continuityops-recovery` VPC, subnets, security groups | 60 minutes | N/A (declarative) | `terraform apply` from last known good commit | Network config is fully in Terraform. No user data stored in ENIs. |
| **Synthetic tenant metadata** | Drill manifests, export bundles (no secrets) | 45 minutes | 24 hours | Restore from evidence bucket snapshot tagged `synthetic-drill` | Tenant records are seeded for drills only (`docs/decisions/saas-lifecycle.md`). RPO matches nightly evidence snapshots in lab. |

## Tiering summary

| Tier | Components | Aggregate lab RTO | Notes |
| --- | --- | --- | --- |
| **T0 — user-facing HTTP** | EKS workloads, ingress (when enabled) | 30 minutes | Drives availability SLO in `observability/slo-catalog.json` |
| **T1 — async processing** | Lambda, SQS primary, DLQ | 20 minutes | DLQ depth alarms map to SEV-2 in `docs/decisions/severity-model.md` |
| **T2 — platform** | EKS cluster, VPC, Terraform state | 60 minutes | Rebuild acceptable in lab; document in change record |
| **T3 — observability** | CloudWatch logs, alarms | 30 minutes | Degraded telemetry must not block T0/T1 recovery |

## Verification binding

Every recovery drill MUST produce a `restore-verification` JSON document conforming
to `tests/recovery/restore-verification.schema.json` and link it from
`evidence/slices/S7-resilience.md`.

## Review cadence

Revisit targets when:

- Staging composition adds persistent data stores (RDS, DynamoDB, EFS)
- SLO catalog objectives change
- A drill exceeds RTO by more than 25% (open corrective action in change record)
