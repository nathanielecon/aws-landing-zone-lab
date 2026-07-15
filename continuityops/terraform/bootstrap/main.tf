# ContinuityOps remote state bootstrap.
# Separated from Project A state. No credentials stored in-repo.
#
# Offline validation:
#   terraform init -backend=false
#   terraform validate
#
# To provision the state bucket and lock table, set create_bootstrap_resources = true
# and replace REPLACE_ME placeholders in terraform.tfvars.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

resource "aws_s3_bucket" "terraform_state" {
  count = var.create_bootstrap_resources ? 1 : 0

  bucket = var.state_bucket_name

  tags = merge(var.tags, {
    Name = var.state_bucket_name
    Role = "terraform-state"
  })
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  count = var.create_bootstrap_resources ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count = var.create_bootstrap_resources ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count = var.create_bootstrap_resources ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_locks" {
  count = var.create_bootstrap_resources ? 1 : 0

  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(var.tags, {
    Name = var.lock_table_name
    Role = "terraform-locks"
  })
}
