mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:root"
      id         = "123456789012"
      user_id    = "AIDAEXAMPLE"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"kms:DescribeKey\",\"Resource\":\"*\"}]}"
    }
  }
}

run "rejects_short_retention" {
  command = plan

  variables {
    trail_name           = "example-trail"
    config_recorder_name = "example-recorder"
    archive_bucket_name  = "example-log-archive"
    kms_alias_name       = "alias/example-audit"
    retention_days       = 30
  }

  expect_failures = [var.retention_days]
}

run "rejects_public_archive_acl_and_missing_kms" {
  command = plan

  variables {
    trail_name           = "example-trail"
    config_recorder_name = "example-recorder"
    archive_bucket_name  = "example-log-archive"
    kms_alias_name       = "alias/example-audit"
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.archive.block_public_acls &&
      aws_s3_bucket_public_access_block.archive.block_public_policy &&
      aws_s3_bucket_public_access_block.archive.ignore_public_acls &&
      aws_s3_bucket_public_access_block.archive.restrict_public_buckets
    )
    error_message = "Log Archive bucket must block public ACLs and public policies."
  }

  assert {
    condition = (
      length([
        for rule in aws_s3_bucket_server_side_encryption_configuration.archive.rule : rule
        if length([
          for enc in rule.apply_server_side_encryption_by_default : enc
          if enc.sse_algorithm == "aws:kms"
        ]) > 0
      ]) > 0 &&
      aws_kms_key.audit.enable_key_rotation
    )
    error_message = "Log Archive objects must use KMS encryption with a rotatable audit key."
  }
}
