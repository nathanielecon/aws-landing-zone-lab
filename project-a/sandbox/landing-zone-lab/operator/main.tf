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
  tags = {
    Project     = "project-a"
    Environment = "lab"
    Owner       = "platform"
    ManagedBy   = "terraform"
    LabMode     = "single-account"
  }
}

data "aws_iam_policy_document" "operator_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.operator.arn]
    }
  }
}

# Scoped for Landing Zone lab operates in this account only — not break-glass root.
data "aws_iam_policy_document" "operator" {
  statement {
    sid    = "CoreLabServices"
    effect = "Allow"
    actions = [
      "iam:*",
      "s3:*",
      "kms:*",
      "ec2:*",
      "logs:*",
      "cloudtrail:*",
      "config:*",
      "sts:GetCallerIdentity",
      "sts:AssumeRole"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "DenyOrgMemberCreates"
    effect    = "Deny"
    actions   = ["organizations:CreateAccount", "organizations:InviteAccountToOrganization"]
    resources = ["*"]
  }
}

resource "aws_iam_user" "operator" {
  name = "${var.name_prefix}-operator"
  path = "/project-a/"
  tags = local.tags
}

resource "aws_iam_role" "operator" {
  name               = "${var.name_prefix}-operator"
  assume_role_policy = data.aws_iam_policy_document.operator_assume.json
  tags               = local.tags
}

resource "aws_iam_policy" "operator" {
  name   = "${var.name_prefix}-operator"
  policy = data.aws_iam_policy_document.operator.json
  tags   = local.tags
}

resource "aws_iam_user_policy_attachment" "operator" {
  user       = aws_iam_user.operator.name
  policy_arn = aws_iam_policy.operator.arn
}

resource "aws_iam_role_policy_attachment" "operator" {
  role       = aws_iam_role.operator.name
  policy_arn = aws_iam_policy.operator.arn
}

# No long-lived access keys. Lab apply is via GitHub Actions OIDC
# (role project-a-lzlab-gha from ../ci-bootstrap).

output "operator_user_name" {
  value = aws_iam_user.operator.name
}

output "operator_user_arn" {
  value = aws_iam_user.operator.arn
}

output "operator_role_arn" {
  value = aws_iam_role.operator.arn
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "region" {
  value = var.aws_region
}
