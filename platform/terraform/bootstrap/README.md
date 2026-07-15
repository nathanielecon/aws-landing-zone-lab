# Backend bootstrap contract

This root is intentionally repo-only: it validates the inputs and exposes the
contract for a separately bootstrapped S3 backend, but creates no AWS resources.
The future reviewed bootstrap must provide an S3 bucket with versioning, public
access blocking, KMS encryption, and least-privilege policies for state and its
lockfile. Backend activation and migration are excluded.

## State key isolation and ownership

Nonproduction and production state must stay isolated. The backend decision
records environment-prefixed keys such as
`nonproduction/foundation.tfstate` and `production/foundation.tfstate`, in
separately controlled buckets or accounts. Environment composition examples use
matching prefixes (`nonproduction/...`, `production/...`). Never share a state
key, lockfile object, or backend identity across environments.

Ownership stays split:

- Backend infrastructure (bucket, KMS key, lockfile policy) has a distinct
  lifecycle and owner from platform stacks.
- Each environment's state key and its `.tflock` object are owned by that
  environment's narrowly scoped CI/operator role.
- Read, write, list, delete-lock, and KMS encrypt/decrypt are granted only where
  required for that environment; do not reuse production principals for
  nonproduction state, or the reverse.

Use Terraform 1.15.5. Supply only non-secret values. Do not commit state,
`.tfvars`, credentials, or secret values. Store operational secrets in Secrets
Manager or Parameter Store. Recovery and ownership rules are in the
[backend decision](../../docs/decisions/backend.md).
