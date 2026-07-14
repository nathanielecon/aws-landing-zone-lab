# Governance checks

Governance review runs Terraform formatting, `terraform validate`, Terraform
tests, and TFLint. Reviewers check naming and required tags for every taggable
resource, plus least-privilege actions, resources, principals, and conditions.

## Executable SCP attachment negatives

Fail-closed coverage for BC-ORG-01 (SCP attach to organization root or an
individual account). The allowlisted `governance_semantics` validator invokes
`Assert-ScpAttachmentNegatives.ps1` and fails closed when the assert is missing
or returns non-zero:

| Artifact | Role |
| --- | --- |
| `fixtures/known-bad-scp-root-attachment.json` | Known-bad sample (`root`, account ID) |
| `Assert-ScpAttachmentNegatives.ps1` | Offline assert: fixture targets must stay outside the OU allowlist; `variables.tf` must keep the Security/Infrastructure/Workloads gate |
| `organization.tftest.hcl` | Terraform `expect_failures` on `var.scp_attachments` for the same blocked shapes |

Run the offline assert (no AWS, no provider init):

```powershell
pwsh -NoLogo -NoProfile -File project-a/tests/governance/Assert-ScpAttachmentNegatives.ps1
```

Terraform behavioral runs can copy this directory beside the organization module
(same pattern as harness `Invoke-TerraformBehavioralTests`), then:

```powershell
terraform -chdir=project-a/terraform/organization test -no-color -test-directory=.harness-tests
```

## IAM blocked-change shapes

Blocked-change examples in the IAM negative suite include widening trust beyond
the protected branch, dropping the required permissions boundary, and using a
non–GitHub Actions OIDC trust principal. Expected shapes:

```hcl
assert {
  condition     = var.github_branch == "main"
  error_message = "Unprotected branches are rejected."
}

assert {
  condition     = var.require_permissions_boundary == true
  error_message = "Missing permissions boundary is rejected."
}
```
