# Policy validation

Every IAM or policy change must run `terraform fmt -check -recursive`,
`terraform validate`, `terraform test`, and TFLint before review. Validation is
offline and does not prove a cloud deployment.

Required tags and naming are reviewed as code: IAM role names use the approved
workload prefix, policy names state their purpose, and any future taggable
resource must carry the baseline required tags. A policy reviewer verifies
principal, action, resource, condition, and permission-boundary scope.

## Platform gate validator IDs

Platform gates for tasks `A-003` through `A-006` select validators by ID from
the allowlist implemented in
[`scripts/Invoke-ProjectAValidators.ps1`](../../../scripts/Invoke-ProjectAValidators.ps1).
Representative IDs used on those task policies include:

| Task | Representative validator IDs |
| --- | --- |
| `A-003` | `scope`, `credential_boundary`, `forbidden_operations`, `secret_scan`, `terraform_fmt_check`, `terraform_validate_offline`, `iam_policy_semantics`, `iam_negative_tests`, `governance_semantics` |
| `A-004` | `terraform_fmt_check`, `terraform_validate_offline`, `network_boundary_semantics`, `network_negative_tests` (plus the shared scope/credential/forbidden/secret gates) |
| `A-005` | `terraform_fmt_check`, `terraform_validate_offline`, `audit_semantics`, `docs_links` (plus the shared gates) |
| `A-006` | `terraform_fmt_check`, `terraform_validate_all_offline`, `terraform_tests_offline`, `cross_module_negative_tests`, `operations_semantics` (plus the shared gates) |

The full known set also includes related platform IDs such as
`backend_state_semantics`, `organizations_semantics`, `claims_boundary`,
`claim_language_semantics`, `diagram_links`, `graphify_evidence`, and
`final_repo_validation`. Task JSON under `platform/harness/tasks/` is the
authoritative per-task selection; the PowerShell allowlist is the authoritative
implementation catalog.

### Unknown validator ID: fail-closed

If a task policy names a validator ID that is not in the known allowlist, or if
the switch in `Invoke-ProjectAValidators.ps1` hits an unmatched ID,
validation throws `UNKNOWN_VALIDATOR` and the gate fails closed. There is no
skip, soft-pass, or cloud fallback for an unrecognized ID. Passing these gates
proves offline policy compliance only; it does not claim a cloud deployment.

## Blocked change example

A change that widens the GitHub trust subject from one protected repository and
branch to a wildcard is blocked. The negative Terraform test rejects a branch
other than `main`; an equivalent policy change must fail review and be rejected.

See the [IAM negative tests](../../tests/iam/README.md) and
[governance checks](../../tests/governance/README.md).
