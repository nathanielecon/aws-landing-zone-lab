# Backend bootstrap contract

This root is intentionally repo-only: it validates the inputs and exposes the
contract for a separately bootstrapped S3 backend, but creates no AWS resources.
The future reviewed bootstrap must provide an S3 bucket with versioning, public
access blocking, KMS encryption, and least-privilege policies for state and its
lockfile. Backend activation and migration are excluded.

Use Terraform 1.15.5. Supply only non-secret values. Do not commit state,
`.tfvars`, credentials, or secret values. Store operational secrets in Secrets
Manager or Parameter Store. Recovery and ownership rules are in the
[backend decision](../../docs/decisions/backend.md).
