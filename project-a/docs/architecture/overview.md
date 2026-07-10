# Platform architecture contract

## Scope and claims

This repository defines a repo-only AWS platform baseline. It is not cloud
validated; AWS and Azure are not implemented. Azure Government is outside the
implementation scope.

## Account and OU taxonomy

The Management account owns AWS Organizations and billing only. The proposed
tree is:

- Security OU: Security Tooling and Log Archive accounts.
- Infrastructure OU: Network and Shared Services accounts.
- Workloads OU: Non-production Workload and Production Workload accounts.

Organizations and SCPs are guardrails, not permissions. IAM roles grant access
and permission boundaries cap delegated roles. Account emails, IDs, principals,
and organization IDs remain typed inputs until separately approved.

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
