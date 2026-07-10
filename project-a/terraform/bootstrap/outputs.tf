output "backend_contract" {
  description = "Non-secret inputs used to prepare environment-specific backend configuration."
  value = {
    bucket        = var.state_bucket_name
    region        = var.primary_region
    kms_key_alias = var.kms_key_alias
    use_lockfile  = true
  }
}
