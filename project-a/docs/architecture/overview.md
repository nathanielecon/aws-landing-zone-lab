# Platform architecture contract

## Scope and claims

This repository defines a repo-only AWS multi-account platform **design**, plus
a separately evidenced **single-account Landing Zone lab** in AWS account
`<AWS_ACCOUNT_ID>` / `us-east-1` that is **READY TO APPLY** / `PENDING_APPLY` for
identity, private network, and audit in one account. Designed Terraform
interfaces exist; live cloud apply of that composition is **not** yet complete,
so identity + network + audit are **not** cloud-validated as a completed fact.
Azure Government remains outside the implementation scope. Multi-account
Organizations member creation is **not** cloud-validated here.

## Account and OU taxonomy

The Management account owns AWS Organizations and billing only. The proposed
tree is:

- Security OU: Security Tooling and Log Archive accounts.
- Infrastructure OU: Network and Shared Services accounts.
- Workloads OU: Non-production Workload and Production Workload accounts.

Organizations and SCPs are guardrails, not permissions. IAM roles grant access
and permission boundaries cap delegated roles. Account emails, IDs, principals,
and organization IDs remain typed inputs until separately approved.

The single-account lab target account is explicitly `<AWS_ACCOUNT_ID>` (commercial
AWS, `us-east-1`). That account hosts the collapsed lab composition when
applied; it does not imply Organizations member accounts were created.

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

See the [S3 backend decision](../decisions/backend.md), [secrets decision](../decisions/secrets.md),
and HashiCorp's [S3 backend documentation](https://developer.hashicorp.com/terraform/language/backend/s3).

## Orchestration and slice review

Slice partitions, judge/nixer/fixer dispatch, scoring thresholds, approval hash
pinning, and the Windows CI gate are recorded in
[orchestration.md](orchestration.md). Related architecture pages:
[accounts](accounts.md), [network](network.md), and [logging](logging.md).

## Delivery navigation

Direct links for reviewers (existing content above is unchanged):

- Frozen rubrics: [`harness/rubrics/`](../../../harness/rubrics/)
- Evidence index: [`project-a/evidence-index.md`](../../evidence-index.md)
- Platform diagram: [`docs/diagrams/platform.svg`](../diagrams/platform.svg)
- Network diagram: [`docs/diagrams/network.svg`](../diagrams/network.svg)
- Graphify navigation aid (not a validation substitute):
  [`graphify-out/GRAPH_REPORT.md`](../../graphify-out/GRAPH_REPORT.md)
