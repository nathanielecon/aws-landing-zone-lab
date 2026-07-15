# IAM and RBAC guardrails (ContinuityOps lab)

Identity and access controls for the ContinuityOps synthetic-data lab. These
guardrails apply to humans, CI, and agentic workers.

## Principles

| Principle | Implementation |
| --- | --- |
| Least privilege | Roles grant minimum actions for a single job function |
| Separation of duties | Plan/apply split for Terraform; deploy vs break-glass |
| No standing admin | Elevated roles are time-bound and audited |
| Agent read-mostly | Default agent principal is read-only; mutation via H4-approved jobs |

## Role tiers (lab)

| Tier | Principal | Typical permissions | Mutation |
| --- | --- | --- | --- |
| Observer | Agent triage worker | CloudWatch/logs/traces read, runbook read | No |
| Operator | On-call engineer | Rollback, scale within service boundary | Yes, with change record |
| Infra CI | GitHub OIDC role | Terraform plan in CI; apply only on protected workflow | Yes, pipeline-gated |
| Break-glass | IC-approved session | Elevated read for forensics | Time-limited; no secret export |

## Agentic constraints

- Agent service accounts must not attach `AdministratorAccess` or wildcard `*:*`.
- `mutation-policy.json` denies apply/delete/exec by default.
- Proposals that widen IAM (new `*:*`, public S3 ACLs, open security groups) are
  rejected per `PS-MUT-02`.

## CI vs runtime

| Context | Identity | Notes |
| --- | --- | --- |
| GitHub Actions | OIDC → `project-*-lzlab-gha` pattern | No long-lived access keys in repo |
| EKS workloads | IRSA per deployment | Service account scoped to namespace |
| Local dev | SSO or assumed role | No shared root keys |

## Audit expectations

- CloudTrail enabled for API mutations in lab accounts.
- Agent proposal rejections logged without secret content.
- H4 receipts link incident/change ID to approving principal.

## Recruiter boundary

Documented for portfolio demonstration in an isolated lab — not production
multi-tenant RBAC for external customers.
