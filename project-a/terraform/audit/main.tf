data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid = "AllowCloudTrailWrite"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = ["s3:GetBucketAcl", "s3:PutObject"]

    resources = [
      aws_s3_bucket.archive.arn,
      "${aws_s3_bucket.archive.arn}/${var.cloudtrail_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]
  }

  statement {
    sid = "AllowConfigWrite"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = ["s3:GetBucketAcl", "s3:ListBucket", "s3:PutObject"]

    resources = [
      aws_s3_bucket.archive.arn,
      "${aws_s3_bucket.archive.arn}/${var.config_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
      "${aws_s3_bucket.archive.arn}/${var.config_prefix}/*"
    ]
  }

  dynamic "statement" {
    for_each = var.flow_logs_prefix == "" ? [] : [var.flow_logs_prefix]

    content {
      sid = "AllowVpcFlowLogsAclCheck"

      principals {
        type        = "Service"
        identifiers = ["delivery.logs.amazonaws.com"]
      }

      actions   = ["s3:GetBucketAcl", "s3:ListBucket"]
      resources = [aws_s3_bucket.archive.arn]

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
    }
  }

  dynamic "statement" {
    for_each = var.flow_logs_prefix == "" ? [] : [var.flow_logs_prefix]

    content {
      sid = "AllowVpcFlowLogsWrite"

      principals {
        type        = "Service"
        identifiers = ["delivery.logs.amazonaws.com"]
      }

      actions = ["s3:PutObject"]
      resources = [
        "${aws_s3_bucket.archive.arn}/${statement.value}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      ]

      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }

      condition {
        test     = "StringEquals"
        variable = "s3:x-amz-acl"
        values   = ["bucket-owner-full-control"]
      }
    }
  }
}

data "aws_iam_policy_document" "kms" {
  statement {
    sid    = "AllowAccountAdministration"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowAuditServices"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [
        "cloudtrail.amazonaws.com",
        "config.amazonaws.com",
        "s3.amazonaws.com",
        "delivery.logs.amazonaws.com"
      ]
    }

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*"
    ]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "config_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "config_role" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetBucketAcl",
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.archive.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.archive.arn}/${var.config_prefix}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*"
    ]
    resources = [aws_kms_key.audit.arn]
  }
}

resource "aws_s3_bucket" "archive" {
  bucket        = var.archive_bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "archive" {
  bucket = aws_s3_bucket.archive.id

  versioning_configuration {
    # enable_archive_versioning is fail-closed (must be true); Suspended is unreachable on valid plans.
    status = var.enable_archive_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.require_customer_managed_kms ? aws_kms_key.audit.arn : null
      sse_algorithm     = var.require_customer_managed_kms ? "aws:kms" : "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "archive" {
  bucket = aws_s3_bucket.archive.id

  # allow_public_archive_acls is fail-closed (must be false); negation keeps all blocks on.
  block_public_acls       = !var.allow_public_archive_acls
  block_public_policy     = !var.allow_public_archive_acls
  ignore_public_acls      = !var.allow_public_archive_acls
  restrict_public_buckets = !var.allow_public_archive_acls
}

resource "aws_s3_bucket_lifecycle_configuration" "archive" {
  bucket = aws_s3_bucket.archive.id

  rule {
    id     = "retention-and-recovery"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.retention_days
    }
  }
}

resource "aws_s3_bucket_policy" "archive" {
  bucket = aws_s3_bucket.archive.id
  policy = data.aws_iam_policy_document.bucket.json
}

resource "aws_kms_key" "audit" {
  description             = "KMS key protecting centralized audit objects."
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms.json
}

resource "aws_kms_alias" "audit" {
  name          = var.kms_alias_name
  target_key_id = aws_kms_key.audit.key_id
}

resource "aws_cloudtrail" "audit" {
  name                          = var.trail_name
  s3_bucket_name                = aws_s3_bucket.archive.bucket
  s3_key_prefix                 = var.cloudtrail_prefix
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = var.enable_log_file_validation
  kms_key_id                    = aws_kms_key.audit.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
}

resource "aws_iam_role" "config" {
  name               = "${var.config_recorder_name}-role"
  assume_role_policy = data.aws_iam_policy_document.config_assume_role.json
}

resource "aws_iam_role_policy" "config" {
  name   = "${var.config_recorder_name}-policy"
  role   = aws_iam_role.config.id
  policy = data.aws_iam_policy_document.config_role.json
}

resource "aws_config_configuration_recorder" "audit" {
  name     = var.config_recorder_name
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "audit" {
  name           = "${var.config_recorder_name}-delivery"
  s3_bucket_name = aws_s3_bucket.archive.bucket
  s3_key_prefix  = var.config_prefix
  sns_topic_arn  = null

  snapshot_delivery_properties {
    delivery_frequency = var.config_snapshot_delivery_frequency
  }

  # AWS allows only one recorder; PutDeliveryChannel fails if the recorder
  # create has not finished (parallel create races).
  depends_on = [aws_config_configuration_recorder.audit]
}
