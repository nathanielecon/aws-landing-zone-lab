# IAM guardrails

This module is a reviewable IAM template, not a deployment. It has no provider
configuration and must not be applied from this repository. H2 approval is
required for the real OIDC provider account, principals, actions, trust
conditions, permission boundary, and break-glass process.

The workload role trusts only GitHub Actions tokens with the expected audience
and one protected `main` branch subject. Its attached policy uses least
privilege: it writes only beneath the supplied audit bucket's `workload/`
prefix. The permission boundary repeats that maximum permission, so delegated
changes cannot grant broader permissions. Fail-closed review input
`require_permissions_boundary` defaults to `true` and must stay true; setting it
false fails offline validation. Non–GitHub Actions OIDC provider ARNs are
rejected as overly broad trust principals. `workload_action_overrides` defaults
to empty and must stay empty (over-broad actions such as `*` fail closed).
`require_oidc_trust_conditions` defaults to `true` and must stay true; omitting
aud/sub trust conditions fails offline validation.

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

See [IAM guardrails](../../docs/guardrails/iam.md),
[policy validation](../../docs/guardrails/policy-validation.md), the
[blocked-change catalog](../../docs/operations/blocked-change-catalog.md)
(BC-ID-01, BC-IAM-01–04), and the offline policy fixtures in
[tests/iam](../../tests/iam/README.md) (`identity.tftest.hcl`).
