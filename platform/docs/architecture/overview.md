# Platform architecture contract

## Scope and claims

**Foundation (A-001 / multi-account design):** This repository defines a
**repo-only** AWS multi-account platform design. That foundation surface is
**not** cloud-validated: AWS multi-account Organizations member creation is
**not** implemented here, Azure is **not** implemented, and Azure Government
remains outside the implementation scope. Harness evidence for A-001…A-007
stays repo-only.

**Separate lab (not Slice 2 foundation proof):** A single-account Landing Zone
lab under `sandbox/landing-zone-lab/` is **APPLIED** / cloud-validated only for
collapsed identity + private network + audit in account `283077380808` /
`us-east-1` via GitHub OIDC CI (role `project-a-lzlab-gha`, run
[29366105164](https://github.com/nathanielecon/cloud/actions/runs/29366105164)).
See [`sandbox/landing-zone-lab/EVIDENCE.md`](../../sandbox/landing-zone-lab/EVIDENCE.md)
and [`OFFLINE_VALIDATE.md`](../../sandbox/landing-zone-lab/OFFLINE_VALIDATE.md).
Lab apply does **not** rewrite the multi-account foundation claims above.

## Account and OU taxonomy

The Management account owns AWS Organizations and billing only. The proposed
tree is:

- Security OU: Security Tooling and Log Archive accounts.
- Infrastructure OU: Network and Shared Services accounts.
- Workloads OU: Non-production Workload and Production Workload accounts.

Organizations and SCPs are guardrails, not permissions. IAM roles grant access
and permission boundaries cap delegated roles. Account emails, IDs, principals,
and organization IDs remain typed inputs until separately approved.

The single-account lab target account is explicitly `283077380808` (commercial
AWS, `us-east-1`). That account hosts the collapsed lab composition; it does
not imply Organizations member accounts were created.

## Regions and environments

Each environment declares one primary region and an optional disaster-recovery
region. No default region is safe to infer. Production and nonproduction use
different accounts, backend state keys, and access roles. A human must approve
real regions, data residency, recovery objectives, and account identifiers.

## Naming and tags

Resource names use `<project>-<environment>-<region>-<purpose>`, lowercase
ASCII, with hyphens. `environment` is one of `nonproduction` or `production`.
Names must respect the service-specific length and character limit.

Every taggable resource requires `Project`, `Environment`, `Owner`,
`CostCenter`, `ManagedBy`, and `DataClassification`. `ManagedBy` is
`terraform`; tag values must be non-secret. Exceptions require a documented
service limitation and human review.

## Ownership boundaries

The platform team owns backend bootstrap, organization interfaces, shared
guardrails, and recovery procedures. Workload teams own resources inside their
accounts subject to guardrails. Security owns audit policy and access review.
Only a designated state administrator may change backend policy or perform
state recovery.

See HashiCorp's [S3 backend documentation](https://developer.hashicorp.com/terraform/language/backend/s3).

## Orchestration and slice review

Slice partitions, judge/nixer/fixer dispatch, scoring thresholds, approval hash
pinning, and the Windows CI gate are recorded in
[orchestration.md](orchestration.md). Related architecture pages:
[accounts](accounts.md), [network](network.md), and [logging](logging.md).

## Related

- [Accounts and OU taxonomy](accounts.md)
- [S3 backend decision](../decisions/backend.md)
- [Secrets decision](../decisions/secrets.md)
- [Organizations guardrails](../guardrails/organizations.md)
- [Organization taxonomy checklist](../../terraform/organization/TAXONOMY.md)

## Delivery navigation

Zero-orphan reviewer path: README → architecture → evidence → review.

- Project README: [`platform/README.md`](../../README.md)
- Frozen rubrics: [`docs/review/rubrics/`](../review/rubrics/)
- Evidence index: [`platform/evidence-index.md`](../../evidence-index.md)
- Claims boundary: [`docs/portfolio/claims-boundary.md`](../portfolio/claims-boundary.md)
- Pushback and handoff: [`docs/review/pushback-and-handoff.md`](../review/pushback-and-handoff.md)
- Azure Government readiness (translation-only):
  [`docs/azure-government/readiness.md`](../azure-government/readiness.md)
- Consolidated Image2 figure: [`aws-landing-zone-lab.png`](../diagrams/aws-landing-zone-lab.png) · [`lab.drawio`](../diagrams/aws-landing-zone-lab.drawio)
- Section archives: [`architecture.png`](../diagrams/aws-landing-zone-architecture.png) · [`network.png`](../diagrams/aws-landing-zone-network.png)
- Graphify navigation aid (not a validation substitute):
  [`graphify-out/GRAPH_REPORT.md`](../../graphify-out/GRAPH_REPORT.md)
- Fresh-clone CI-parity gate:
  [`HARNESS.md`](../../HARNESS.md) → `Invoke-HarnessReleaseValidation.ps1` with
  `HARNESS_STRICT_PINS=1`
