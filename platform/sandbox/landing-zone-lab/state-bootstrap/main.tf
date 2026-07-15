terraform {
  required_version = "= 1.15.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.36.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name_prefix" {
  type    = string
  default = "project-a-lzlab"
}

data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${var.name_prefix}-tfstate-${data.aws_caller_identity.current.account_id}"
  tags = {
    Project     = "project-a"
    Environment = "lab"
    Owner       = "platform"
    ManagedBy   = "terraform"
    Purpose     = "terraform-state"
  }
}

data "aws_iam_policy_document" "kms" {
  statement {
    sid    = "AccountAdmin"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }
}

resource "aws_kms_key" "state" {
  description             = "KMS key for Project A single-account LZ lab Terraform state"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms.json
  tags                    = local.tags
}

resource "aws_kms_alias" "state" {
  name          = "alias/${var.name_prefix}-tfstate"
  target_key_id = aws_kms_key.state.key_id
}

resource "aws_s3_bucket" "state" {
  bucket        = local.bucket_name
  force_destroy = false
  tags          = local.tags
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.state.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

output "state_bucket_name" {
  value = aws_s3_bucket.state.bucket
}

output "state_bucket_arn" {
  value = aws_s3_bucket.state.arn
}

output "kms_key_arn" {
  value = aws_kms_key.state.arn
}

output "kms_alias" {
  value = aws_kms_alias.state.name
}

output "backend_hcl" {
  description = "Copy into lab/backend.hcl (gitignored local file) after bootstrap."
  value       = <<-EOT
bucket       = "${aws_s3_bucket.state.bucket}"
key          = "lab/landing-zone-lab.tfstate"
region       = "${var.aws_region}"
encrypt      = true
kms_key_id   = "${aws_kms_key.state.arn}"
use_lockfile = true
EOT
}
