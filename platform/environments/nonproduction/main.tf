locals {
  environment_name = "nonproduction"
  backend_key      = "nonproduction/project-a.tfstate"
  audit_prefix     = "nonproduction/audit"
  network_boundary = "private-only"

  # Shared non-secret Log Archive token for offline composition review.
  # Identity, network, and audit inputs below must stay aligned on this name.
  log_archive_bucket_name = "example-log-archive"

  # Non-secret identity module inputs (OIDC trust + workload → Log Archive).
  identity_module_inputs = {
    github_organization           = "example-org"
    github_repository             = "example-repo"
    github_branch                 = "main"
    audit_bucket_name             = local.log_archive_bucket_name
    oidc_provider_arn             = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    require_permissions_boundary  = true
    workload_action_overrides     = []
    require_oidc_trust_conditions = true
  }

  # Non-secret network module inputs (private-only VPC → Log Archive flow logs).
  network_module_inputs = {
    environment = "nonproduction"
    vpc_cidr    = "10.10.0.0/16"
    private_subnets = {
      az1 = { availability_zone = "us-east-1a", cidr = "10.10.1.0/24" }
      az2 = { availability_zone = "us-east-1b", cidr = "10.10.2.0/24" }
    }
    flow_logs_destination_arn  = "arn:aws:s3:::${local.log_archive_bucket_name}/vpc-flow-logs"
    allow_unrestricted_ingress = false
    allow_unrestricted_egress  = false
    sg_exception_attempts = {
      cidrs    = []
      ports    = []
      protocol = ""
    }
  }

  # Non-secret audit module inputs (Security Tooling path → Log Archive storage).
  # is_organization_trail stays false: org-trail delivery is interface-only.
  audit_module_inputs = {
    trail_name                         = "example-nonproduction-trail"
    config_recorder_name               = "example-nonproduction-recorder"
    archive_bucket_name                = local.log_archive_bucket_name
    kms_alias_name                     = "alias/example-nonproduction-audit"
    cloudtrail_prefix                  = "cloudtrail"
    config_prefix                      = "config"
    flow_logs_prefix                   = "vpc-flow-logs"
    retention_days                     = 365
    is_organization_trail              = false
    enable_log_file_validation         = true
    enable_archive_versioning          = true
    allow_public_archive_acls          = false
    require_customer_managed_kms       = true
    config_snapshot_delivery_frequency = "TwentyFour_Hours"
  }
}

output "environment_name" {
  value = local.environment_name
}

output "backend_key" {
  value = local.backend_key
}

output "audit_prefix" {
  value = local.audit_prefix
}

output "network_boundary" {
  value = local.network_boundary
}

output "log_archive_bucket_name" {
  description = "Shared non-secret Log Archive bucket name token for identity/network/audit composition review."
  value       = local.log_archive_bucket_name
}

output "identity_module_inputs" {
  description = "Reviewable non-secret inputs that would feed terraform/identity (no secrets, no apply)."
  value       = local.identity_module_inputs
}

output "network_module_inputs" {
  description = "Reviewable non-secret inputs that would feed terraform/network (no secrets, no apply)."
  value       = local.network_module_inputs
}

output "audit_module_inputs" {
  description = "Reviewable non-secret inputs that would feed terraform/audit (org-trail remains false / interface-only)."
  value       = local.audit_module_inputs
}
