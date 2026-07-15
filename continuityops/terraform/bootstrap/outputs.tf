output "state_bucket_name" {
  description = "Terraform state bucket name (null when bootstrap is disabled)."
  value       = var.create_bootstrap_resources ? aws_s3_bucket.terraform_state[0].id : var.state_bucket_name
}

output "lock_table_name" {
  description = "DynamoDB lock table name (null when bootstrap is disabled)."
  value       = var.create_bootstrap_resources ? aws_dynamodb_table.terraform_locks[0].name : var.lock_table_name
}

output "bootstrap_enabled" {
  description = "Whether bootstrap resources were created in this apply."
  value       = var.create_bootstrap_resources
}
