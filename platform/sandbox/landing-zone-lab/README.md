# Single-account Landing Zone lab

Collapsed composition of **identity + private network + audit** in one
commercial AWS account. **Cloud-validated** via GitHub OIDC → Terraform CI
(not Cursor Cloud Agent AWS assume-role). This is **not** a multi-account
Organizations apply.

| Field | Value |
| --- | --- |
| Mode | Single-account lab (honest claims boundary) |
| Account | `<AWS_ACCOUNT_ID>` |
| Region | `us-east-1` |
| Status | **APPLIED** / cloud-validated ([run 29366105164](https://github.com/nathanielecon/cloud/actions/runs/29366105164)) |
| Lab modules | `terraform/identity`, `terraform/network`, `terraform/audit` |
| Design-only | `terraform/organization` (OU/SCP interface; members not created) |
| Apply control plane | GitHub Actions OIDC → IAM role `project-a-lzlab-gha` (`ci-bootstrap/`) |

## Delivery (GitOps)

1. One-time (already done): apply [`ci-bootstrap/`](ci-bootstrap/) (OIDC + `project-a-lzlab-gha`).
2. Merge Terraform changes via PR — workflow **plans** on PR.
3. Push/merge to `main` (or `workflow_dispatch` → apply) — workflow **applies**.
4. Cursor/Cloud Agents edit the repo only; they do **not** need AWS apply creds
   (`NoCredentials` in Cloud Agent pods is expected — BF-2026-010; see
   `AGENTS.md`).

Workflow: [`.github/workflows/landing-zone-lab.yml`](../../../.github/workflows/landing-zone-lab.yml).

```bash
gh workflow run landing-zone-lab.yml --repo nathanielecon/aws-landing-zone-lab -f action=plan
gh workflow run landing-zone-lab.yml --repo nathanielecon/aws-landing-zone-lab -f action=apply
```

Do **not** recreate `github-oidc/` / `GitHubActionsLZLab` — use `ci-bootstrap/`
+ `project-a-lzlab-gha`. Do **not** chase `CURSOR_AWS_ASSUME_IAM_ROLE_ARN` /
`CursorCloudAgent` injection (never assumed; lab fixed via GHA OIDC).

## Roots

1. [`ci-bootstrap/`](ci-bootstrap/) — GitHub OIDC provider + CI apply role (one-time)
2. [`operator/`](operator/) — non-root operator IAM user + scoped role
3. [`state-bootstrap/`](state-bootstrap/) — S3 + KMS remote state for the lab
4. [`lab/`](lab/) — identity + network + audit composition

Organization member accounts are **not** applied. See
[`ORGS_INTERFACE.md`](ORGS_INTERFACE.md).

## Claims

Honest resume bullet (supported after apply + evidence):

> Designed a multi-account AWS Landing Zone (Orgs/OU/SCP interfaces) and
> cloud-validated a single-account lab composition of identity, private
> network, and audit (CloudTrail/KMS Log Archive) in `us-east-1` with
> Terraform, evidence, and CI-gated delivery.

Banned: claiming production/enterprise multi-account Landing Zone fully
cloud-validated across Orgs + network + identity.

Evidence: [`EVIDENCE.md`](EVIDENCE.md). Prior audit-only sandbox:
[`../aws-proof/EVIDENCE.md`](../aws-proof/EVIDENCE.md).

## Teardown / cost

See [`TEARDOWN.md`](TEARDOWN.md) for cost notes and destroy order (not yet claimed executed here).
