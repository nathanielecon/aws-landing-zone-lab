# CH-teardown — recovery-lab teardown inventory

| Field | Value |
| --- | --- |
| Change ID | `CH-teardown` |
| Slice | S7 |
| Environment | `recovery-lab` |
| Data class | Synthetic drill data only |
| Owner | ContinuityOps resilience |

## Purpose

Inventory AWS and Kubernetes resources torn down after recovery-lab drills, and
define what evidence to retain without storing secrets or customer data.

## When to use

- End of quarterly resilience drill cycle
- Cost idle-detection alert (`docs/decisions/finops.md`) for unused lab stack
- Corrupted lab environment requiring clean rebuild
- Pre-migration to new Terraform module version

**Do not** run against staging or any account outside the recovery-lab partition.

## Teardown inventory

### Terraform-managed (recovery-lab root module)

| Resource | Module | Teardown action | Evidence to retain |
| --- | --- | --- | --- |
| EKS cluster | `modules/eks` | `terraform destroy` target or full destroy | Last `terraform plan` hash, cluster version |
| EKS node group | `modules/eks` | Destroy with cluster | Node instance type, count |
| Lambda worker | `modules/serverless` | Destroy function + event source mapping | Function version, zip SHA-256 |
| SQS primary queue | `modules/serverless` | Destroy queue (messages lost) | Final depth metrics screenshot or JSON export |
| SQS DLQ | `modules/serverless` | Destroy queue | DLQ message count at teardown |
| IAM roles/policies | `modules/serverless`, `modules/eks` | Destroy with dependents | Role names only (no ARNs with account id in public evidence) |
| CloudWatch log group | `modules/observability` | Destroy or let retention expire | Log retention setting, sample query id |
| CloudWatch alarm | `modules/observability` | Destroy with module | Alarm name, last state |
| VPC, subnets, IGW | `modules/network` | Destroy networking | CIDR block used |
| NAT gateway (if enabled) | `modules/network` | Destroy | `enable_nat_gateway` flag value |

### Kubernetes (Helm)

| Resource | Teardown action | Evidence to retain |
| --- | --- | --- |
| Helm release `continuityops-lab` | `helm uninstall -n continuityops-lab` | Final revision number |
| Namespace `continuityops-lab` | Delete if empty | — |
| ConfigMaps / Secrets | Removed with release | Secret **names** only; never values |

### Local / CI artifacts (repo)

| Artifact | Action | Retention |
| --- | --- | --- |
| `serverless/build/worker.zip` | Keep in Git LFS/CI cache policy | Reproducible from source |
| Drill logs under `/tmp` | Delete after upload | N/A |
| Terraform plan files | Upload to evidence bucket | 90 days lab policy |

## Teardown procedure

### 1. Pre-teardown checks

- [ ] Confirm environment tag `Environment=recovery-lab` on all targeted resources
- [ ] Export final metrics snapshot (queue depth, error rate, cost dashboard)
- [ ] Complete or cancel in-flight drill tickets
- [ ] Notify on-call — teardown causes intentional outage

### 2. Drain async work

1. Disable Lambda event source mapping (console or Terraform `enabled = false`)
2. Wait until primary queue depth = 0 or timeout (30 minutes)
3. Archive DLQ message **counts** and sample `correlation_id` list to evidence

### 3. Remove Kubernetes workloads

```bash
helm uninstall continuityops-lab -n continuityops-lab
kubectl delete namespace continuityops-lab --wait=true
```

### 4. Destroy cloud infrastructure

Execute via approved OIDC workflow or local destroy with lab credentials:

```bash
cd continuityops/terraform/environments/recovery-lab
terraform destroy
```

Require explicit `confirm_destroy` variable or manual approval gate in CI.

### 5. Verify empty inventory

| Check | Pass criteria |
| --- | --- |
| EKS clusters named `continuityops-recovery-*` | None in account/region |
| SQS queues `continuityops-recovery-*` | None |
| Lambda `continuityops-recovery-worker` | None |
| VPC `10.43.0.0/16` (lab default) | None or documented exception |

## Evidence retention (no secrets)

Retain the following in `evidence/slices/S7-resilience.md` or linked object
storage prefix `synthetic-drill/teardown/`:

| Artifact | Contents allowed | Contents forbidden |
| --- | --- | --- |
| Teardown manifest JSON | Resource types, counts, timestamps, candidate SHA | Access keys, tokens |
| Terraform destroy log (redacted) | Resource addresses, destroy order | Account IDs if policy requires redaction |
| Queue metrics export | Depth, age of oldest message | Message bodies |
| Cost report snapshot | Service-level USD (synthetic labels OK) | Payer account credentials |
| Verification record | `restore-verification` or teardown completion JSON | Private keys, webhook URLs with secrets |

Retention period: **90 days** for lab teardown evidence unless legal hold ticket
references the drill id.

## Post-teardown

1. Update `evidence/slices/S7-resilience.md` with teardown event link
2. Record idle-cost baseline reset in FinOps notes
3. Schedule rebuild if next drill is within 30 days

## Related documents

- `operations/changes/CH-backup-restore.md` — restore before teardown when testing recovery
- `docs/decisions/finops.md` — idle detection and cost alerts
- `docs/decisions/rto-rpo.md` — RTO/RPO no longer applicable while environment is down
