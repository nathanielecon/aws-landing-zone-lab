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
  default = "cloud"
}

variable "role_name" {
  type    = string
  default = "GitHubActionsLZLab"
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  # Same-repo PRs + main branch applies.
  github_subs = [
    "repo:${var.github_organization}/${var.github_repository}:ref:refs/heads/main",
    "repo:${var.github_organization}/${var.github_repository}:pull_request",
    "repo:${var.github_organization}/${var.github_repository}:environment:landing-zone-lab",
  ]
  tags = {
    Project     = "project-a"
    Environment = "lab"
    Owner       = "platform"
    ManagedBy   = "terraform"
    Purpose     = "github-oidc-ci"
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
  tags = local.tags
}

data "aws_iam_policy_document" "assume" {
  statement {
    sid     = "GitHubActionsOIDC"
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
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_subs
    }
  }
}

# Lab-scoped rights for CI plan/apply (not break-glass root).
data "aws_iam_policy_document" "lab" {
  statement {
    sid    = "LabServices"
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

resource "aws_iam_role" "github_actions" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${var.role_name}-lab"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.lab.json
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "github_actions_role_name" {
  value = aws_iam_role.github_actions.name
}

output "account_id" {
  value = local.account_id
}

output "workflow_role_arn_hint" {
  description = "Set repo variable AWS_LZLAB_ROLE_ARN to this value (or hardcode in workflow)."
  value       = aws_iam_role.github_actions.arn
}
