data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  # S3 bucket names must be globally unique.
  archive_bucket_name = "${var.name_prefix}-archive-${local.account_id}"
}

module "audit" {
  source = "../../terraform/audit"

  trail_name           = "${var.name_prefix}-trail"
  config_recorder_name = "${var.name_prefix}-config"
  archive_bucket_name  = local.archive_bucket_name
  kms_alias_name       = "alias/${var.name_prefix}-audit"
  cloudtrail_prefix    = "cloudtrail"
  config_prefix        = "config"
  retention_days       = 90
}
