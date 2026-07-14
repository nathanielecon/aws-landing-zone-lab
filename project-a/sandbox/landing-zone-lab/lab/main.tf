terraform {
  required_version = "= 1.15.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.36.0"
    }
  }

  # Partial backend — activate with: terraform init -backend-config=backend.hcl
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

# Stretch only (do not enable in this single-account lab): future cross-account
# assume-role provider aliases would belong here when unique member-account
# emails exist. Keep the single `provider "aws"` above as the live path.

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name_prefix" {
  type    = string
  default = "project-a-lzlab"
}

variable "github_organization" {
  type    = string
  default = "nathanielecon"
}

variable "github_repository" {
  type    = string
  default = "cloud"
}

variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "private_subnets" {
  type = map(object({
    availability_zone = string
    cidr              = string
  }))
  default = {
    az1 = { availability_zone = "us-east-1a", cidr = "10.40.1.0/24" }
    az2 = { availability_zone = "us-east-1b", cidr = "10.40.2.0/24" }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id          = data.aws_caller_identity.current.account_id
  archive_bucket_name = "${var.name_prefix}-archive-${local.account_id}"
}

# OIDC provider is created once by ../ci-bootstrap (GitHub Actions control plane).
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

module "audit" {
  source = "../../../terraform/audit"

  trail_name           = "${var.name_prefix}-trail"
  config_recorder_name = "${var.name_prefix}-config"
  archive_bucket_name  = local.archive_bucket_name
  kms_alias_name       = "alias/${var.name_prefix}-audit"
  cloudtrail_prefix    = "cloudtrail"
  config_prefix        = "config"
  flow_logs_prefix     = "vpc-flow-logs"
  retention_days       = 90
}

module "network" {
  source = "../../../terraform/network"

  environment               = "nonproduction"
  vpc_cidr                  = var.vpc_cidr
  private_subnets           = var.private_subnets
  flow_logs_destination_arn = "${module.audit.archive_bucket_arn}/vpc-flow-logs"
}

module "identity" {
  source = "../../../terraform/identity"

  github_organization = var.github_organization
  github_repository   = var.github_repository
  github_branch       = "main"
  audit_bucket_name   = module.audit.archive_bucket_name
  oidc_provider_arn   = data.aws_iam_openid_connect_provider.github.arn
}

output "account_id" {
  value = local.account_id
}

output "archive_bucket_name" {
  value = module.audit.archive_bucket_name
}

output "archive_bucket_arn" {
  value = module.audit.archive_bucket_arn
}

output "cloudtrail_arn" {
  value = module.audit.cloudtrail_arn
}

output "kms_key_arn" {
  value = module.audit.kms_key_arn
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnet_count" {
  value = module.network.private_subnet_count
}

output "private_security_group_id" {
  value = module.network.private_security_group_id
}

output "workload_role_name" {
  value = module.identity.workload_role_name
}

output "oidc_provider_arn" {
  value = data.aws_iam_openid_connect_provider.github.arn
}
