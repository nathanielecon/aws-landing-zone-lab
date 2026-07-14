# Single-account Landing Zone lab evidence

| Field | Value |
| --- | --- |
| Account | `283077380808` |
| Region | `us-east-1` |
| Mode | Collapsed single-account lab |
| Status | `PENDING_APPLY` — apply via **GitHub OIDC → Terraform CI** (or one-off local `apply-lab.sh`) |
| Control plane | GitHub Actions role `GitHubActionsLZLab` — **not** Cursor Cloud Agent assume-role |

## Prerequisites

1. One-time local bootstrap (`aws login`):
   - Apply [`github-oidc/`](github-oidc/) (OIDC provider + CI role)
   - Apply [`state-bootstrap/`](state-bootstrap/) (remote state bucket)
2. GitHub repo variable `AWS_LZLAB_ROLE_ARN` (optional default in workflow) and
   Environment `landing-zone-lab` for apply approval
3. Run workflow plan/apply, or `./apply-lab.sh` locally

Do **not** chase `CURSOR_AWS_ASSUME_IAM_ROLE_ARN` for this lab.

## Live verification commands (after apply)

```bash
export AWS_REGION=us-east-1
aws sts get-caller-identity
aws iam get-role --role-name GitHubActionsLZLab
aws iam get-user --user-name project-a-lzlab-operator
aws cloudtrail get-trail-status --name project-a-lzlab-trail
aws s3api get-bucket-encryption --bucket project-a-lzlab-archive-283077380808
aws ec2 describe-vpcs --filters Name=tag:Name,Values=project-a-nonproduction-vpc
aws iam get-role --role-name workload-audit-writer
```

CI writes this file via `render-evidence.sh` after a successful apply job.

## What this will prove (after successful apply)

- Non-root CI apply identity (GitHub OIDC)
- Live identity + private VPC/flow logs + CloudTrail/Config/KMS archive

## What this does not prove

- Multi-account Organizations member creation
- Production / enterprise Landing Zone readiness
- Azure / Azure Government
- Cloud Agent AWS apply efficacy
- That A-001…A-007 harness evidence is cloud-backed

## Organization interface

Member accounts were **not** created. See [`ORGS_INTERFACE.md`](ORGS_INTERFACE.md).

## Reconciliation with `aws-proof`

Prior audit-only sandbox remains separate under `project-a/sandbox/aws-proof`
(`project-a-lzlab-*` prefix coexistence).
