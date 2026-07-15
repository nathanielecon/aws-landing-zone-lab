run "root_shell_stays_in_default_workspace" {
  command = plan

  assert {
    condition     = terraform.workspace == "default"
    error_message = "The root composition shell must stay in the default workspace."
  }
}

run "environment_docs_remain_present" {
  command = plan

  assert {
    condition     = terraform.workspace == "default" && fileexists("${path.root}/environments/README.md")
    error_message = "Environment composition guidance must remain present."
  }
}

run "identity_network_audit_module_entries_remain" {
  command = plan

  assert {
    condition = (
      fileexists("${path.root}/terraform/identity/main.tf") &&
      fileexists("${path.root}/terraform/identity/outputs.tf") &&
      fileexists("${path.root}/terraform/identity/README.md") &&
      fileexists("${path.root}/terraform/network/main.tf") &&
      fileexists("${path.root}/terraform/network/outputs.tf") &&
      fileexists("${path.root}/terraform/network/README.md") &&
      fileexists("${path.root}/terraform/audit/main.tf") &&
      fileexists("${path.root}/terraform/audit/outputs.tf") &&
      fileexists("${path.root}/terraform/audit/README.md")
    )
    error_message = "Identity, network, and audit module entry points (main/outputs/README) must remain present for composition."
  }
}

run "environment_locals_outputs_contract" {
  command = plan

  assert {
    condition = (
      fileexists("${path.root}/environments/nonproduction/main.tf") &&
      fileexists("${path.root}/environments/production/main.tf") &&
      can(regex("(?s)backend_key\\s*=\\s*\"nonproduction/platform\\.tfstate\"", file("${path.root}/environments/nonproduction/main.tf"))) &&
      can(regex("(?s)audit_prefix\\s*=\\s*\"nonproduction/audit\"", file("${path.root}/environments/nonproduction/main.tf"))) &&
      can(regex("(?s)network_boundary\\s*=\\s*\"private-only\"", file("${path.root}/environments/nonproduction/main.tf"))) &&
      can(regex("(?s)backend_key\\s*=\\s*\"production/platform\\.tfstate\"", file("${path.root}/environments/production/main.tf"))) &&
      can(regex("(?s)audit_prefix\\s*=\\s*\"production/audit\"", file("${path.root}/environments/production/main.tf"))) &&
      can(regex("(?s)network_boundary\\s*=\\s*\"private-only\"", file("${path.root}/environments/production/main.tf"))) &&
      can(regex("(?s)output\\s+\"environment_name\"", file("${path.root}/environments/nonproduction/main.tf"))) &&
      can(regex("(?s)output\\s+\"backend_key\"", file("${path.root}/environments/nonproduction/main.tf"))) &&
      can(regex("(?s)output\\s+\"audit_prefix\"", file("${path.root}/environments/nonproduction/main.tf"))) &&
      can(regex("(?s)output\\s+\"network_boundary\"", file("${path.root}/environments/nonproduction/main.tf"))) &&
      can(regex("(?s)output\\s+\"environment_name\"", file("${path.root}/environments/production/main.tf"))) &&
      can(regex("(?s)output\\s+\"backend_key\"", file("${path.root}/environments/production/main.tf"))) &&
      can(regex("(?s)output\\s+\"audit_prefix\"", file("${path.root}/environments/production/main.tf"))) &&
      can(regex("(?s)output\\s+\"network_boundary\"", file("${path.root}/environments/production/main.tf")))
    )
    error_message = "Nonproduction and production compositions must keep distinct backend_key/audit_prefix locals and shared private-only network_boundary outputs."
  }
}

run "identity_network_audit_interface_consistency" {
  command = plan

  assert {
    condition = (
      can(regex("(?s)variable\\s+\"audit_bucket_name\"", file("${path.root}/terraform/identity/variables.tf"))) &&
      can(regex("(?s)output\\s+\"workload_role_name\"", file("${path.root}/terraform/identity/outputs.tf"))) &&
      can(regex("(?s)variable\\s+\"flow_logs_destination_arn\"", file("${path.root}/terraform/network/variables.tf"))) &&
      can(regex("(?s)output\\s+\"private_subnet_count\"", file("${path.root}/terraform/network/outputs.tf"))) &&
      can(regex("(?s)resource\\s+\"aws_cloudtrail\"\\s+\"audit\"", file("${path.root}/terraform/audit/main.tf"))) &&
      can(regex("(?s)output\\s+\"archive_bucket_name\"", file("${path.root}/terraform/audit/outputs.tf"))) &&
      can(regex("(?s)output\\s+\"cloudtrail_arn\"", file("${path.root}/terraform/audit/outputs.tf")))
    )
    error_message = "Identity→audit bucket, network→flow-log archive, and audit→CloudTrail/archive interfaces must remain present for offline composition consistency."
  }
}

run "log_archive_arn_prefix_contract_alignment" {
  command = plan

  assert {
    condition = (
      # Network: Flow Logs destination must be an S3 ARN owned by Log Archive.
      can(regex("(?s)variable\\s+\"flow_logs_destination_arn\"[\\s\\S]*?condition\\s*=\\s*can\\(regex\\(\"\\^arn:aws:s3:::\"", file("${path.root}/terraform/network/variables.tf"))) &&
      # Audit: protected bucket name + ARN output + flow-logs prefix interface.
      can(regex("(?s)variable\\s+\"archive_bucket_name\"", file("${path.root}/terraform/audit/variables.tf"))) &&
      can(regex("(?s)variable\\s+\"flow_logs_prefix\"", file("${path.root}/terraform/audit/variables.tf"))) &&
      can(regex("(?s)output\\s+\"archive_bucket_arn\"[\\s\\S]*?aws_s3_bucket\\.archive\\.arn", file("${path.root}/terraform/audit/outputs.tf"))) &&
      # Identity: workload writes target the same Log Archive bucket name contract.
      can(regex("(?s)variable\\s+\"audit_bucket_name\"", file("${path.root}/terraform/identity/variables.tf"))) &&
      can(regex("(?s)arn:aws:s3:::\\$\\{var\\.audit_bucket_name\\}/workload/\\*", file("${path.root}/terraform/identity/main.tf"))) &&
      # Environments: distinct audit_prefix values stay aligned with env composition.
      can(regex("(?s)audit_prefix\\s*=\\s*\"nonproduction/audit\"", file("${path.root}/environments/nonproduction/main.tf"))) &&
      can(regex("(?s)audit_prefix\\s*=\\s*\"production/audit\"", file("${path.root}/environments/production/main.tf"))) &&
      # Nonproduction composition: shared Log Archive token + org-trail fail-closed.
      can(regex("(?s)log_archive_bucket_name\\s*=\\s*\"example-log-archive\"", file("${path.root}/environments/nonproduction/main.tf"))) &&
      can(regex("(?s)audit_bucket_name\\s*=\\s*local\\.log_archive_bucket_name", file("${path.root}/environments/nonproduction/main.tf"))) &&
      can(regex("(?s)flow_logs_destination_arn\\s*=\\s*\"arn:aws:s3:::\\$\\{local\\.log_archive_bucket_name\\}/vpc-flow-logs\"", file("${path.root}/environments/nonproduction/main.tf"))) &&
      can(regex("(?s)archive_bucket_name\\s*=\\s*local\\.log_archive_bucket_name", file("${path.root}/environments/nonproduction/main.tf"))) &&
      can(regex("(?s)is_organization_trail\\s*=\\s*false", file("${path.root}/environments/nonproduction/main.tf"))) &&
      # Production composition mirrors the same shared-token / org-trail-false contract.
      can(regex("(?s)log_archive_bucket_name\\s*=\\s*\"example-log-archive\"", file("${path.root}/environments/production/main.tf"))) &&
      can(regex("(?s)audit_bucket_name\\s*=\\s*local\\.log_archive_bucket_name", file("${path.root}/environments/production/main.tf"))) &&
      can(regex("(?s)flow_logs_destination_arn\\s*=\\s*\"arn:aws:s3:::\\$\\{local\\.log_archive_bucket_name\\}/vpc-flow-logs\"", file("${path.root}/environments/production/main.tf"))) &&
      can(regex("(?s)archive_bucket_name\\s*=\\s*local\\.log_archive_bucket_name", file("${path.root}/environments/production/main.tf"))) &&
      can(regex("(?s)is_organization_trail\\s*=\\s*false", file("${path.root}/environments/production/main.tf"))) &&
      # String equality: identity / network / audit offline fixtures share one bucket name token.
      regex("(?m)^\\s*audit_bucket_name\\s*=\\s*\"([^\"]+)\"", file("${path.root}/tests/iam/identity.tftest.hcl")) == regex("(?m)^\\s*archive_bucket_name\\s*=\\s*\"([^\"]+)\"", file("${path.root}/tests/audit/audit.tftest.hcl")) &&
      regex("(?m)^\\s*flow_logs_destination_arn\\s*=\\s*\"arn:aws:s3:::([^\"]+)\"", file("${path.root}/tests/network/network.tftest.hcl")) == regex("(?m)^\\s*archive_bucket_name\\s*=\\s*\"([^\"]+)\"", file("${path.root}/tests/audit/audit.tftest.hcl")) &&
      # Lab composition wires identity + network flow logs to the same audit archive outputs.
      can(regex("(?s)audit_bucket_name\\s*=\\s*module\\.audit\\.archive_bucket_name", file("${path.root}/sandbox/landing-zone-lab/lab/main.tf"))) &&
      can(regex("(?s)flow_logs_destination_arn\\s*=\\s*\"\\$\\{module\\.audit\\.archive_bucket_arn\\}/", file("${path.root}/sandbox/landing-zone-lab/lab/main.tf")))
    )
    error_message = "Shared Log Archive bucket token must be string-equal across identity audit_bucket_name, network flow_logs_destination_arn, and audit archive_bucket_name/ARN (fixtures + lab wiring); env compositions keep example-log-archive + is_organization_trail=false."
  }
}
