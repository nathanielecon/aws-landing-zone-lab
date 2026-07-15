# One-time bootstrap: GitHub OIDC provider + CI apply role.
# Applied locally (account root / break-glass) so GitHub Actions can plan/apply
# the lab without Cursor Cloud Agent credentials.
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

variable "github_organization" {
  type    = string
  default = "nathanielecon"
}

variable "github_repository" {
  type    = string
  default = "aws-landing-zone-lab"
}

# Stable across GitHub renames (nathanielecon/aws-landing-zone-lab → was cloud).
variable "github_repository_id" {
  type        = string
  default     = "1296742987"
  description = "GitHub repository id claim; survives repo renames."
}

variable "github_repository_owner_id" {
  type        = string
  default     = "177059064"
  description = "GitHub repository_owner_id claim for nathanielecon."
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
    Purpose     = "github-actions-oidc"
  }

  # Immutable subject claims (GitHub renames after 2026-07-15):
  #   repo:OWNER@OWNER_ID/REPO@REPO_ID:...
  # Name-only repo:OWNER/REPO:... no longer matches. Lock IDs; wildcard repo name.
  github_sub_patterns = [
    "repo:${var.github_organization}@${var.github_repository_owner_id}/*@${var.github_repository_id}:ref:refs/heads/main",
    "repo:${var.github_organization}@${var.github_repository_owner_id}/*@${var.github_repository_id}:pull_request",
    "repo:${var.github_organization}@${var.github_repository_owner_id}/*@${var.github_repository_id}:ref:refs/heads/cursor/*",
    "repo:${var.github_organization}@${var.github_repository_owner_id}/*@${var.github_repository_id}:environment:lab",
  ]
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # Thumbprints optional for GitHub (AWS trusts GitHub CA library); kept for
  # provider compatibility with older create paths.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
  tags = local.tags
}

data "aws_iam_policy_document" "gha_assume" {
  statement {
    sid     = "GitHubActionsOidc"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:repository_id"
      values   = [var.github_repository_id]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:repository_owner_id"
      values   = [var.github_repository_owner_id]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_sub_patterns
    }
  }
}

# Same lab surface as operator role — enough to apply identity/network/audit.
data "aws_iam_policy_document" "gha_lab" {
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
      "sts:AssumeRole",
      "sts:TagSession",
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

resource "aws_iam_role" "gha_lab" {
  name               = "${var.name_prefix}-gha"
  assume_role_policy = data.aws_iam_policy_document.gha_assume.json
  description        = "GitHub Actions OIDC role for Project A single-account LZ lab"
  tags               = local.tags
}

resource "aws_iam_role_policy" "gha_lab" {
  name   = "${var.name_prefix}-gha"
  role   = aws_iam_role.gha_lab.id
  policy = data.aws_iam_policy_document.gha_lab.json
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "gha_role_arn" {
  value = aws_iam_role.gha_lab.arn
}

output "gha_role_name" {
  value = aws_iam_role.gha_lab.name
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
