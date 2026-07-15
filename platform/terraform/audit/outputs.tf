output "archive_bucket_name" {
  description = "Approved Log Archive bucket name."
  value       = aws_s3_bucket.archive.bucket
}

output "archive_bucket_arn" {
  description = "Approved Log Archive bucket ARN (used by VPC Flow Logs destinations)."
  value       = aws_s3_bucket.archive.arn
}

output "cloudtrail_arn" {
  description = "CloudTrail ARN for review workflows."
  value       = aws_cloudtrail.audit.arn
}

output "config_recorder_name" {
  description = "AWS Config recorder name for review workflows."
  value       = aws_config_configuration_recorder.audit.name
}

output "kms_key_arn" {
  description = "KMS key ARN protecting audit objects."
  value       = aws_kms_key.audit.arn
}
