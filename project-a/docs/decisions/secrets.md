# Decision: secrets handling

Status: proposed for H0 human approval.

Secrets belong in AWS Secrets Manager or, for suitable configuration values,
AWS Systems Manager Parameter Store. Access uses workload identity and
least-privilege policy. KMS administration and secret reading are separate
roles; rotation and audit requirements are defined per secret.

Do not commit secrets in Terraform state, `.tfvars`, backend configuration,
source files, examples, outputs, or logs. Sensitive Terraform values can still
be stored in state, so modules should pass references (such as a secret ARN)
instead of secret material. Marking a value `sensitive` only redacts display.

Examples contain obvious placeholders, never usable credentials. Runtime
systems inject identity and retrieve secret values directly from the approved
secret store. Suspected exposure requires stopping work, revoking or rotating
the value, preserving audit evidence, and notifying security.

Reference: [Terraform sensitive data guidance](https://developer.hashicorp.com/terraform/language/manage-sensitive-data).

## Related

- [Platform architecture overview](../architecture/overview.md)
- [Accounts and OU taxonomy](../architecture/accounts.md)
- [S3 backend decision](backend.md)
- [Organizations guardrails](../guardrails/organizations.md)
- [Organization taxonomy checklist](../../terraform/organization/TAXONOMY.md)
