# ContinuityOps Terraform (S1)

Terraform modules and environment compositions for the ContinuityOps isolated AWS
lab. Separated from Project A state. No credentials stored in-repo.

Apply in lab accounts uses GitHub OIDC workflows (draft under
`continuityops/.github/workflows/`). Local validation:

```bash
cd continuityops/terraform/environments/staging   # or recovery-lab
terraform init -backend=false
terraform validate
```

## Module tree

```text
continuityops/terraform/
  bootstrap/                    # Remote state bucket + DynamoDB lock (optional create)
  modules/
    network/                    # VPC, public/private subnets, IGW, NAT, route tables
    eks/                        # EKS cluster, node group, OIDC issuer scaffold
    serverless/                 # SQS primary + DLQ, Lambda worker, IAM execution role
    observability/              # CloudWatch log group + baseline error alarm
  environments/
    staging/                    # Non-destructive integration composition
    recovery-lab/               # Destructive drill composition (synthetic data only)
```

## Environment compositions

Both `staging/` and `recovery-lab/` wire the same four modules with
environment-specific `name_prefix` and tags:

| Module | Purpose |
| --- | --- |
| `network` | Lab VPC and subnet layout |
| `eks` | Managed Kubernetes for Helm workloads |
| `serverless` | Async worker queue + Lambda |
| `observability` | Log retention and baseline alarms |

## Bootstrap

`bootstrap/` provisions versioned S3 state storage and a DynamoDB lock table when
`create_bootstrap_resources = true`. See `bootstrap/README.md`.

## Backend configuration

Each environment ships `backend.tf.example` and `terraform.tfvars.example`.
Copy and fill `REPLACE_ME` placeholders before OIDC apply; do not commit live
backend credentials.

## Related documents

- `environments/staging/README.md` — hosted integration tier
- `environments/recovery-lab/README.md` — destructive rollback/restore drills
- `docs/decisions/rto-rpo.md` — per-component recovery targets
- `operations/changes/CH-backup-restore.md` — restore procedure
