# Single-account Landing Zone lab evidence

| Field | Value |
| --- | --- |
| Account | `<AWS_ACCOUNT_ID>` |
| Region | `us-east-1` |
| Mode | Collapsed single-account lab |
| Status | `PENDING_APPLY` — **READY TO APPLY**; populate after operator/state/lab applies |

## Prerequisites

- Cloud Agent AWS auth via dashboard secret `CURSOR_AWS_ASSUME_IAM_ROLE_ARN` →
  `arn:aws:iam::<AWS_ACCOUNT_ID>:role/CursorCloudAgent` (injected
  `cursor-cloud-agent` profile / default credential chain). Do **not** use
  `aws login` or `/opt/cursor/artifacts/aws-login/code.txt`.
- Status remains `PENDING_APPLY` until a session with that role injection
  successfully runs `apply-lab.sh` and captures CLI evidence below.
- Non-root operator IAM created under `operator/`
- Remote state bootstrap under `state-bootstrap/`
- Lab composition under `lab/` (identity + network + audit)

## Live verification commands (fill after apply)

Do **not** invent CLI output. Run these only after a successful apply with
credentials present:

```bash
export AWS_REGION=us-east-1
aws sts get-caller-identity
aws iam get-user --user-name project-a-lzlab-operator
aws iam get-role --role-name project-a-lzlab-operator
aws cloudtrail get-trail-status --name project-a-lzlab-trail
aws s3api get-bucket-encryption --bucket project-a-lzlab-archive-<AWS_ACCOUNT_ID>
aws ec2 describe-vpcs --filters Name=tag:Name,Values=project-a-nonproduction-vpc
aws ec2 describe-flow-logs --filter Name=resource-id,Values=<vpc-id>
aws iam get-role --role-name workload-audit-writer
```

## What this will prove (after successful apply)

Until status leaves `PENDING_APPLY`, the items below are **targets**, not
completed cloud-validated facts:

- Non-root operator posture for lab applies
- Live identity (OIDC provider + workload role + permission boundary)
- Live private VPC + flow logs to encrypted archive
- Live CloudTrail / Config / KMS Log Archive

## What this does not prove

- That identity + network + audit are already cloud-validated (status is
  `PENDING_APPLY`; credentials and live apply are still required)
- Multi-account Organizations member creation or cross-account assume-role
- Production / enterprise Landing Zone readiness
- Azure / Azure Government implementation
- That A-001…A-007 harness evidence is cloud-backed (those remain repo-only)

## Organization interface

Member accounts were **not** created. See [`ORGS_INTERFACE.md`](ORGS_INTERFACE.md).

## Reconciliation with `aws-proof`

Prior audit-only resources under `project-a/sandbox/aws-proof` remain evidence of
the first live audit apply. This lab uses a distinct `project-a-lzlab-*` name
prefix so both can coexist until an approved teardown of the older sandbox.
