# Policy validation

Every IAM or policy change must run `terraform fmt -check -recursive`,
`terraform validate`, `terraform test`, and TFLint before review. Validation is
offline and does not prove a cloud deployment.

Required tags and naming are reviewed as code: IAM role names use the approved
workload prefix, policy names state their purpose, and any future taggable
resource must carry the baseline required tags. A policy reviewer verifies
principal, action, resource, condition, and permission-boundary scope.

## Blocked change example

A change that widens the GitHub trust subject from one protected repository and
branch to a wildcard is blocked. The negative Terraform test rejects a branch
other than `main`; an equivalent policy change must fail review and be rejected.

See the [IAM negative tests](../../tests/iam/README.md) and
[governance checks](../../tests/governance/README.md).
