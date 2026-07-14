# Governance checks

Governance review runs Terraform formatting, `terraform validate`, Terraform
tests, and TFLint. Reviewers check naming and required tags for every taggable
resource, plus least-privilege actions, resources, principals, and conditions.

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
