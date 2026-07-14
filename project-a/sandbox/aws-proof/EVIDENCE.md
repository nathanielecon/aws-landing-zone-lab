# Sandbox AWS proof evidence (2026-07-13)

Operator override of the repo-only apply stop condition, using a **separate**
root under `project-a/sandbox/aws-proof` that reuses `project-a/terraform/audit`.

| Field | Value |
| --- | --- |
| Account | `<AWS_ACCOUNT_ID>` |
| Region | `us-east-1` |
| Identity | IAM root session via `aws login` (prefer an IAM user/role for future ops) |
| Terraform | `1.15.5` apply complete — **13 resources** added |
| Trail | `project-a-sandbox-trail` — multi-region, log-file validation **on**, `IsLogging: true` |
| Archive bucket | `project-a-sandbox-archive-<AWS_ACCOUNT_ID>` — versioning **Enabled**, SSE-KMS, all public access blocks **true** |
| KMS | `alias/project-a-sandbox-audit` → `cd27223d-5d4a-432e-8f71-7eb2b3462781` |
| Config recorder | `project-a-sandbox-config` present (delivery channel created) |

## What this proves

- The Project A **audit module** can be applied live in a commercial AWS account.
- CloudTrail logging started successfully against a KMS-encrypted Log Archive bucket.

## What this does **not** prove

- Full multi-account Organizations / identity / network platform apply.
- Azure / Azure Government.
- That historical A-001…A-007 harness evidence was cloud-backed (those remain repo-only gated commits).
- Production readiness or non-root operator posture.

## Teardown

State is local to this sandbox directory (gitignored). Capture final evidence,
then from this directory run an approved `terraform destroy` when finished.
Bucket `force_destroy` is false in the module — empty/version cleanup may be
required before destroy succeeds.
