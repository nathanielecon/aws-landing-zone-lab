# Single-account Landing Zone lab — retired

This repository cloud-validated a single-account composition of identity,
private networking, CloudTrail, AWS Config, KMS, S3, and GitHub Actions OIDC in
`us-east-1`. It was a lab, not a production or multi-account deployment.

The live lab was retired on 2026-09-06. Verification covered every enabled AWS
region and found no remaining Project A VPCs, subnets, route tables, security
groups, flow logs, trails, Config recorders, or Config delivery channels.
Project-specific users, roles, and policies were then removed. The shared,
account-wide GitHub OIDC provider was intentionally preserved.

## Current posture

- [`lab/`](lab/) contains no Terraform resources and cannot recreate the lab.
- [`ci-bootstrap/`](ci-bootstrap/), [`operator/`](operator/), and
  [`state-bootstrap/`](state-bootstrap/) are non-deployable retirement markers.
- [`retained-evidence/`](retained-evidence/) is the only active sandbox root. It
  owns the archive bucket, existing 90-day lifecycle, audit KMS key/alias,
  Terraform-state bucket, and state KMS key/alias.
- Reusable design modules remain under `platform/terraform/` for review and
  credential-free testing.
- The former live compositions and retirement workflow remain in Git and
  GitHub Actions history as evidence.

See [`RETIREMENT_EVIDENCE.md`](RETIREMENT_EVIDENCE.md) for the sanitized
verification record and [`EVIDENCE.md`](EVIDENCE.md) for the original lab
validation claims.

## Claims boundary

Supported: designed a multi-account landing-zone interface and cloud-validated
a single-account lab with private networking, audit controls, KMS encryption,
Terraform state, and evidence-gated CI; later transferred retained evidence to
a dedicated state and retired the billable lab resources.

Not supported: enterprise production operation, real Organizations member
accounts, or a continuously running platform.
