output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "region" {
  value = var.aws_region
}

output "archive_bucket_name" {
  value = local.archive_bucket_name
}

output "cloudtrail_name" {
  value = "${var.name_prefix}-trail"
}

output "kms_alias" {
  value = "alias/${var.name_prefix}-audit"
}
