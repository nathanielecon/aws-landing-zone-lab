mock_provider "aws" {}

run "accepts_protected_branch" {
  command = plan

  variables {
    github_organization = "example-org"
    github_repository   = "platform"
    audit_bucket_name   = "example-audit-bucket"
  }

  assert {
    condition     = output.workload_role_name == "workload-audit-writer"
    error_message = "The workload role name changed unexpectedly."
  }
}

run "rejects_unprotected_branch" {
  command = plan

  variables {
    github_organization = "example-org"
    github_repository   = "platform"
    github_branch       = "feature"
    audit_bucket_name   = "example-audit-bucket"
  }

  expect_failures = [var.github_branch]
}
