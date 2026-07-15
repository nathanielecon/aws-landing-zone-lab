# Single-account Landing Zone lab evidence

| Field | Value |
| --- | --- |
| Account | `283077380808` |
| Region | `us-east-1` |
| Mode | Collapsed single-account lab |
| Status | `APPLIED` — cloud-validated via **GitHub OIDC → Terraform CI** |
| Captured | `2026-07-14T20:33:19Z` |
| Apply run | [29366105164](https://github.com/nathanielecon/cloud/actions/runs/29366105164) (success) |
| Branch tip | `cursor/single-account-lz-lab-b6ce` @ `43972ec` (evidence/docs closeout) |
| Control plane | IAM role `project-a-lzlab-gha` via `ci-bootstrap/` — **not** Cursor Cloud Agent assume-role |

## Caller (non-root CI)

```json
{
    "UserId": "AROAUD2F2BLEIGHQLZJJ4:gha-lzlab-apply-29366105164",
    "Account": "283077380808",
    "Arn": "arn:aws:sts::283077380808:assumed-role/project-a-lzlab-gha/gha-lzlab-apply-29366105164"
}
```

## Live resources (verified)

| Resource | Evidence |
| --- | --- |
| CloudTrail `project-a-lzlab-trail` | `IsLogging: true`, multi-region, log-file validation on, KMS key `a25950f1-…` |
| Archive `project-a-lzlab-archive-283077380808` | SSE-KMS, versioning Enabled, all public access blocks true |
| VPC `vpc-0d9b3dae7a4c31563` | Flow log `fl-0dfa827ed78974a93` ACTIVE → archive `/vpc-flow-logs` (`DeliverLogsStatus: SUCCESS`) |
| Workload role `workload-audit-writer` | Permission boundary `workload-audit-boundary` |
| GitHub OIDC provider | `arn:aws:iam::283077380808:oidc-provider/token.actions.githubusercontent.com` |
| Operator IAM | User/role `project-a-lzlab-operator` present |
| Remote state | `project-a-lzlab-tfstate-283077380808` / `lab/landing-zone-lab.tfstate` |

Full CLI dump: [`EVIDENCE.capture.md`](EVIDENCE.capture.md) (from apply artifact `lz-lab-evidence`).

## What this proves

- Non-root CI apply identity (`assumed-role/project-a-lzlab-gha`, not account root)
- Live identity (OIDC provider + workload role + permission boundary)
- Live private VPC + flow logs to encrypted archive
- Live CloudTrail / Config / KMS Log Archive in one account
- GitOps delivery: plan/apply via `.github/workflows/landing-zone-lab.yml`

## What this does not prove

- Multi-account Organizations member creation or cross-account assume-role
- Production / enterprise Landing Zone readiness
- Azure / Azure Government implementation
- That A-001…A-007 harness evidence is cloud-backed (those remain repo-only)
- Cursor Cloud Agent AWS apply (explicitly not the control plane)

## Organization interface

Member accounts were **not** created. See [`ORGS_INTERFACE.md`](ORGS_INTERFACE.md).

## Reconciliation with `aws-proof`

Prior audit-only sandbox under `platform/sandbox/aws-proof` remains historical
evidence. CI cleared a stale aws-proof Config recorder (account limit = 1) so
the lab recorder could apply. Lab resources use the distinct `project-a-lzlab-*`
prefix.
