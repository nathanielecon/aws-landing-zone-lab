# ContinuityOps GitHub Actions OIDC bootstrap (one-time, account break-glass).
# Reuses the account GitHub OIDC provider (created by LZ lab ci-bootstrap).
# Cloud Agents do not apply this — operator CloudShell / local aws login.
terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

# Repo that hosts continuityops/ (currently aws-landing-zone-lab after rename).
variable "github_repository" {
  type    = string
  default = "aws-landing-zone-lab"
}

variable "github_repository_id" {
  type        = string
  default     = "1296742987"
  description = "GitHub repository_id; survives renames."
}

variable "github_repository_owner_id" {
  type        = string
  default     = "177059064"
  description = "GitHub repository_owner_id for nathanielecon."
}

variable "name_prefix" {
  type    = string
  default = "continuityops"
}

data "aws_caller_identity" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  tags = {
    Project     = "continuityops"
    Environment = "lab"
    Owner       = "platform"
    ManagedBy   = "terraform"
    Purpose     = "github-actions-oidc"
  }

  # Immutable subject claims (GitHub renames on/after 2026-07-15).
  github_sub_patterns = [
    "repo:${var.github_organization}@${var.github_repository_owner_id}/*@${var.github_repository_id}:ref:refs/heads/main",
    "repo:${var.github_organization}@${var.github_repository_owner_id}/*@${var.github_repository_id}:pull_request",
    "repo:${var.github_organization}@${var.github_repository_owner_id}/*@${var.github_repository_id}:ref:refs/heads/cursor/*",
    "repo:${var.github_organization}@${var.github_repository_owner_id}/*@${var.github_repository_id}:environment:continuityops",
    "repo:${var.github_organization}@${var.github_repository_owner_id}/*@${var.github_repository_id}:environment:continuityops-staging",
    "repo:${var.github_organization}@${var.github_repository_owner_id}/*@${var.github_repository_id}:environment:continuityops-recovery-lab",
  ]
}

data "aws_iam_policy_document" "gha_assume" {
  statement {
    sid     = "GitHubActionsOidc"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
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

# Lab surface for ContinuityOps staging / recovery-lab roots (network, EKS, lambda, obs).
data "aws_iam_policy_document" "gha_lab" {
  statement {
    sid    = "CoreLabServices"
    effect = "Allow"
    actions = [
      "iam:*",
      "s3:*",
      "kms:*",
      "ec2:*",
      "eks:*",
      "ecr:*",
      "lambda:*",
      "logs:*",
      "cloudwatch:*",
      "events:*",
      "sns:*",
      "sqs:*",
      "dynamodb:*",
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

resource "aws_iam_role" "gha" {
  name               = "${var.name_prefix}-gha"
  assume_role_policy = data.aws_iam_policy_document.gha_assume.json
  description        = "GitHub Actions OIDC role for ContinuityOps lab plan/apply"
  tags               = local.tags
}

resource "aws_iam_role_policy" "gha" {
  name   = "${var.name_prefix}-gha"
  role   = aws_iam_role.gha.id
  policy = data.aws_iam_policy_document.gha_lab.json
}

output "gha_role_arn" {
  value = aws_iam_role.gha.arn
}

output "gha_role_name" {
  value = aws_iam_role.gha.name
}

output "oidc_provider_arn" {
  value = data.aws_iam_openid_connect_provider.github.arn
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
