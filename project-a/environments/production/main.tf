locals {
  environment_name = "production"
  backend_key      = "production/project-a.tfstate"
  audit_prefix     = "production/audit"
  network_boundary = "private-only"
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
