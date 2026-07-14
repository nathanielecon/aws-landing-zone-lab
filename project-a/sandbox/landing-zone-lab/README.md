# Single-account Landing Zone lab

Collapsed live composition of **identity + private network + audit** in one
commercial AWS account. This is **not** a multi-account Organizations apply.

| Field | Value |
| --- | --- |
| Mode | Single-account lab (honest claims boundary) |
| Account | `283077380808` |
| Region | `us-east-1` |
| Live modules | `terraform/identity`, `terraform/network`, `terraform/audit` |
| Design-only | `terraform/organization` (OU/SCP interface; members not created) |

## Roots (apply order)

1. [`operator/`](operator/) — non-root operator IAM user + scoped role
2. [`state-bootstrap/`](state-bootstrap/) — S3 + KMS remote state for the lab
3. [`lab/`](lab/) — identity + network + audit composition

Organization member accounts are **not** applied. See
[`ORGS_INTERFACE.md`](ORGS_INTERFACE.md).

## Claims

Supported resume bullet:

> Designed a multi-account AWS Landing Zone (Orgs/OU/SCP interfaces) and
> cloud-validated a single-account lab composition of identity, private
> network, and audit (CloudTrail/KMS Log Archive) in `us-east-1` with
> Terraform, evidence, and CI-gated delivery.

Banned: claiming production/enterprise multi-account Landing Zone fully
cloud-validated across Orgs + network + identity.

Evidence: [`EVIDENCE.md`](EVIDENCE.md). Prior audit-only sandbox:
[`../aws-proof/EVIDENCE.md`](../aws-proof/EVIDENCE.md).
