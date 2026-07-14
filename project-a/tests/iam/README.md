# IAM negative tests

`identity.tftest.hcl` uses a mocked AWS provider so it remains offline. It
asserts the proposed role name and contains blocked-change tests:

- A trust request from any branch other than protected `main` must fail
  variable validation (`rejects_unprotected_branch`).
- Dropping the required permissions boundary
  (`require_permissions_boundary = false`) must fail closed
  (`rejects_missing_permissions_boundary`).
- A non–GitHub Actions OIDC provider ARN (overly broad / wrong trust principal)
  must fail closed (`rejects_non_github_oidc_trust_principal`).
- Over-broad workload action overrides (for example `*`) must fail closed
  (`rejects_overbroad_workload_actions`).
- Omitting OIDC trust conditions
  (`require_oidc_trust_conditions = false`) must fail closed
  (`rejects_missing_oidc_trust_conditions`).

These are tests of repository policy shape, not cloud validation.
