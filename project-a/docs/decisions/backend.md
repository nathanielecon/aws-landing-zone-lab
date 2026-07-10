# Decision: remote Terraform state

Status: proposed for H0 human approval.

## Decision

Use a separately bootstrapped Amazon S3 bucket for remote state. Enable bucket
versioning, server-side encryption with a customer-managed KMS key, public
access blocking, and least-privilege bucket and key policies. Terraform uses
the S3 lockfile with `use_lockfile = true`; DynamoDB locking is excluded because
it is deprecated.

Backend infrastructure has a distinct lifecycle and owner from platform
stacks. The examples deliberately contain no credentials and are not activated
by the bootstrap module. Nonproduction state uses a `nonproduction/foundation.tfstate`
key and production state uses a `production/foundation.tfstate` key, in
separately controlled buckets or accounts. Never share a state key across
environments.

## Concurrency and access

Lockfile permissions include the state key's `.tflock` object. CI and operators
assume narrowly scoped roles; read, write, list, delete-lock, KMS decrypt, and
KMS encrypt permissions are granted only where required. Backend credentials
are supplied by the runtime identity, never by an HCL file.

## Recovery

Stop writers before recovery. Preserve the current object version and lock,
identify the last known-good S3 version, review the Terraform and audit trail,
then have two people approve restoration. Restore or copy the selected version,
reinitialize, and compare state to configuration with an approved offline or
future cloud workflow. Never overwrite state merely to clear drift. Record the
incident, object version, approvers, and rollback outcome. A stale lock may be
removed only after proving no writer remains.

S3 versioning supports rollback but is not a substitute for tested recovery.
See [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3).
