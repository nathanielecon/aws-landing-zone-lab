# Single-account Landing Zone lab

Collapsed composition of **identity + private network + audit** for one
commercial AWS account. **Control plane: GitHub OIDC → Terraform CI** (not
Cursor Cloud Agent AWS assume-role).

| Field | Value |
| --- | --- |
| Mode | Single-account lab (honest claims boundary) |
| Account | `<AWS_ACCOUNT_ID>` |
| Region | `us-east-1` |
| Status | **READY TO APPLY** / `PENDING_APPLY` until CI/local apply updates evidence |
| CI | [`.github/workflows/landing-zone-lab.yml`](../../../.github/workflows/landing-zone-lab.yml) |
| Lab modules | `terraform/identity`, `terraform/network`, `terraform/audit` |
| Design-only | `terraform/organization` (OU/SCP interface; members not created) |

## Apply path (preferred)

1. **One-time local bootstrap** (human `aws login`):
   - [`github-oidc/`](github-oidc/) — OIDC provider + `GitHubActionsLZLab` role
   - [`state-bootstrap/`](state-bootstrap/) — S3 + KMS remote state
   - Set GitHub repo variable `AWS_LZLAB_ROLE_ARN` (optional; workflow has default ARN)
   - Create GitHub Environment `landing-zone-lab` (recommended for apply approval)
2. **CI** — PR → `terraform plan`; `main` push or `workflow_dispatch` apply →
   updates [`EVIDENCE.md`](EVIDENCE.md)
3. Optional local full apply: [`apply-lab.sh`](apply-lab.sh) (same bootstrap + lab)

Optional [`operator/`](operator/) creates lab-scoped IAM user/role resources.
Organization member accounts are **not** applied — see
[`ORGS_INTERFACE.md`](ORGS_INTERFACE.md).

## Stop doing

- Chasing `CURSOR_AWS_ASSUME_IAM_ROLE_ARN` / Cloud Agent External ID for this lab
- Long-lived AWS access keys in Cursor secrets (unless a deliberate one-off)

## Claims

Supported resume bullet (**target / after-exit wording** — use only after
successful apply + evidence update):

> Designed a multi-account AWS Landing Zone (Orgs/OU/SCP interfaces) and
> cloud-validated a single-account lab composition of identity, private
> network, and audit (CloudTrail/KMS Log Archive) in `us-east-1` with
> Terraform, evidence, and CI-gated delivery.

Banned: production/enterprise multi-account Landing Zone fully cloud-validated;
claiming this composition is cloud-validated while evidence remains
`PENDING_APPLY`.

Evidence: [`EVIDENCE.md`](EVIDENCE.md). Prior audit-only sandbox:
[`../aws-proof/EVIDENCE.md`](../aws-proof/EVIDENCE.md).
