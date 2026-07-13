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
      can(regex("(?s)backend_key\\s*=\\s*\"nonproduction/project-a\\.tfstate\"", file("${path.root}/environments/nonproduction/main.tf"))) &&
      can(regex("(?s)audit_prefix\\s*=\\s*\"nonproduction/audit\"", file("${path.root}/environments/nonproduction/main.tf"))) &&
      can(regex("(?s)network_boundary\\s*=\\s*\"private-only\"", file("${path.root}/environments/nonproduction/main.tf"))) &&
      can(regex("(?s)backend_key\\s*=\\s*\"production/project-a\\.tfstate\"", file("${path.root}/environments/production/main.tf"))) &&
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
