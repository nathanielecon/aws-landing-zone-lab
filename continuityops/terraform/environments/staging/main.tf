provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.default_tags
  }
}

locals {
  name_prefix = "continuityops-staging"

  default_tags = {
    Project     = "continuityops"
    Environment = "staging"
    ManagedBy   = "terraform"
    Source      = "continuityops-lab"
  }
}

module "network" {
  source = "../../modules/network"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  enable_nat_gateway = var.enable_nat_gateway
  tags               = local.default_tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name       = "${local.name_prefix}-eks"
  subnet_ids         = module.network.private_subnet_ids
  kubernetes_version = var.kubernetes_version
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  tags               = local.default_tags
}

module "serverless" {
  source = "../../modules/serverless"

  name_prefix         = local.name_prefix
  lambda_package_path = var.lambda_package_path
  tags                = local.default_tags
}

module "observability" {
  source = "../../modules/observability"

  name_prefix         = local.name_prefix
  alarm_sns_topic_arn = var.alarm_sns_topic_arn
  tags                = local.default_tags
}
