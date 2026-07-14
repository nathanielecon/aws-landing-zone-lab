mock_provider "aws" {}

run "accepts_workloads_ou_scp_attachment" {
  command = plan

  variables {
    account_emails = {
      security_tooling       = "security-tooling@example.com"
      log_archive            = "log-archive@example.com"
      network                = "network@example.com"
      shared_services        = "shared-services@example.com"
      nonproduction_workload = "nonproduction@example.com"
      production_workload    = "production@example.com"
    }
    account_access_role_name = "OrganizationAccountAccessRole"
    scp_attachments = {
      deny_leave_organization = "Workloads"
    }
  }

  assert {
    condition     = length(aws_organizations_policy_attachment.scp) == 1
    error_message = "Approved OU SCP attachments must plan a single deny_leave_organization attachment."
  }
}

run "rejects_root_scp_attachment" {
  command = plan

  variables {
    account_emails = {
      security_tooling       = "security-tooling@example.com"
      log_archive            = "log-archive@example.com"
      network                = "network@example.com"
      shared_services        = "shared-services@example.com"
      nonproduction_workload = "nonproduction@example.com"
      production_workload    = "production@example.com"
    }
    account_access_role_name = "OrganizationAccountAccessRole"
    scp_attachments = {
      deny_leave_organization = "root"
    }
  }

  expect_failures = [var.scp_attachments]
}

run "rejects_account_id_scp_attachment" {
  command = plan

  variables {
    account_emails = {
      security_tooling       = "security-tooling@example.com"
      log_archive            = "log-archive@example.com"
      network                = "network@example.com"
      shared_services        = "shared-services@example.com"
      nonproduction_workload = "nonproduction@example.com"
      production_workload    = "production@example.com"
    }
    account_access_role_name = "OrganizationAccountAccessRole"
    scp_attachments = {
      deny_leave_organization = "123456789012"
    }
  }

  expect_failures = [var.scp_attachments]
}
