mock_provider "aws" {}

run "accepts_protected_branch" {
  command = plan

  variables {
    github_organization = "example-org"
    github_repository   = "platform"
    audit_bucket_name   = "example-log-archive"
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
    audit_bucket_name   = "example-log-archive"
  }

  expect_failures = [var.github_branch]
}

run "rejects_missing_permissions_boundary" {
  command = plan

  variables {
    github_organization          = "example-org"
    github_repository            = "platform"
    audit_bucket_name            = "example-log-archive"
    require_permissions_boundary = false
  }

  expect_failures = [var.require_permissions_boundary]
}

run "rejects_non_github_oidc_trust_principal" {
  command = plan

  variables {
    github_organization = "example-org"
    github_repository   = "platform"
    audit_bucket_name   = "example-log-archive"
    oidc_provider_arn   = "arn:aws:iam::123456789012:oidc-provider/example.com"
  }

  expect_failures = [var.oidc_provider_arn]
}

run "rejects_overbroad_workload_actions" {
  command = plan

  variables {
    github_organization       = "example-org"
    github_repository         = "platform"
    audit_bucket_name         = "example-log-archive"
    workload_action_overrides = ["*"]
  }

  expect_failures = [var.workload_action_overrides]
}

run "rejects_missing_oidc_trust_conditions" {
  command = plan

  variables {
    github_organization           = "example-org"
    github_repository             = "platform"
    audit_bucket_name             = "example-log-archive"
    require_oidc_trust_conditions = false
  }

  expect_failures = [var.require_oidc_trust_conditions]
}
