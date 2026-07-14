# IAM guardrails

This module is a reviewable IAM template, not a deployment. It has no provider
configuration and must not be applied from this repository. H2 approval is
required for the real OIDC provider account, principals, actions, trust
conditions, permission boundary, and break-glass process.

The workload role trusts only GitHub Actions tokens with the expected audience
and one protected `main` branch subject. Its attached policy uses least
privilege: it writes only beneath the supplied audit bucket's `workload/`
prefix. The permission boundary repeats that maximum permission, so delegated
changes cannot grant broader permissions.

The OIDC provider ARN defaults to a documentation-only account placeholder for
offline review. Live lab applies must pass `oidc_provider_arn` for the real
account provider (see `sandbox/landing-zone-lab/lab`). No real account ID,
principal, or credential belongs in this repository as a committed default.

Run only offline checks:

```powershell
terraform fmt -check -recursive
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
terraform test -no-color -test-directory=../../tests/iam
```

See [IAM guardrails](../../docs/guardrails/iam.md) and
[policy validation](../../docs/guardrails/policy-validation.md).
