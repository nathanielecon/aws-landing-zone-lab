# Single-account Landing Zone lab

Collapsed composition of **identity + private network + audit** designed for
one commercial AWS account. Status: **READY TO APPLY** / `PENDING_APPLY` —
not yet cloud-validated as a completed fact. This is **not** a multi-account
Organizations apply.

| Field | Value |
| --- | --- |
| Mode | Single-account lab (honest claims boundary) |
| Account | `283077380808` |
| Region | `us-east-1` |
| Status | **READY TO APPLY** / `PENDING_APPLY` (live apply not complete) |
| Lab modules | `terraform/identity`, `terraform/network`, `terraform/audit` |
| Design-only | `terraform/organization` (OU/SCP interface; members not created) |
| Apply control plane | GitHub Actions OIDC → IAM role `project-a-lzlab-gha` |

## Delivery (GitOps)

1. One-time: apply [`ci-bootstrap/`](ci-bootstrap/) locally (creates OIDC + CI role).
2. Merge Terraform changes via PR — workflow **plans** on PR.
3. Push/merge to `main` (or `workflow_dispatch` → apply) — workflow **applies**.
4. Cursor/Cloud Agents edit the repo only; they do **not** need AWS apply creds.

Workflow: [`.github/workflows/landing-zone-lab.yml`](../../../.github/workflows/landing-zone-lab.yml).

## Roots (apply order)

1. [`ci-bootstrap/`](ci-bootstrap/) — GitHub OIDC provider + CI apply role (one-time)
2. [`operator/`](operator/) — non-root operator IAM user + scoped role
3. [`state-bootstrap/`](state-bootstrap/) — S3 + KMS remote state for the lab
4. [`lab/`](lab/) — identity + network + audit composition

Organization member accounts are **not** applied. See
[`ORGS_INTERFACE.md`](ORGS_INTERFACE.md).

## Claims

Supported resume bullet (**target / after-exit wording** — not current proof;
use only after successful live apply and evidence update):

> Designed a multi-account AWS Landing Zone (Orgs/OU/SCP interfaces) and
> cloud-validated a single-account lab composition of identity, private
> network, and audit (CloudTrail/KMS Log Archive) in `us-east-1` with
> Terraform, evidence, and CI-gated delivery.

Banned: claiming production/enterprise multi-account Landing Zone fully
cloud-validated across Orgs + network + identity. Banned: claiming the
single-account identity+network+audit composition is already cloud-validated
while evidence remains `PENDING_APPLY`.

Evidence: [`EVIDENCE.md`](EVIDENCE.md). Prior audit-only sandbox:
[`../aws-proof/EVIDENCE.md`](../aws-proof/EVIDENCE.md).
