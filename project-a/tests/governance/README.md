# Governance checks

Governance review runs Terraform formatting, `terraform validate`, Terraform
tests, and TFLint. Reviewers check naming and required tags for every taggable
resource, plus least-privilege actions, resources, principals, and conditions.

The blocked-change example is widening a trust condition beyond the protected
branch; the IAM negative test rejects it. Its expected assertion shape is:

```hcl
assert {
  condition     = var.github_branch == "main"
  error_message = "Unprotected branches are rejected."
}
```
