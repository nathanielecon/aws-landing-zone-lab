locals {
  name_prefix = "project-a-${var.environment}"
  # Fail-closed review inputs; validation rejects unrestricted ingress/egress attempts.
  unrestricted_ingress_blocked = !var.allow_unrestricted_ingress
  unrestricted_egress_blocked  = !var.allow_unrestricted_egress
  tags = {
    Project            = "project-a"
    Environment        = var.environment
    Owner              = "platform"
    CostCenter         = "pending-human-approval"
    ManagedBy          = "terraform"
    DataClassification = "internal"
  }
}

# Cross-variable CIDR containment cannot live in variable validation (single-var
# scope only). This check rejects subnet CIDRs outside the VPC prefix offline.
# Implemented with cidrhost (this Terraform pin has no cidrcontains).
check "private_subnets_inside_vpc" {
  assert {
    condition = alltrue([
      for subnet in values(var.private_subnets) :
      can(cidrnetmask(subnet.cidr)) &&
      tonumber(split("/", subnet.cidr)[1]) >= tonumber(split("/", var.vpc_cidr)[1]) &&
      cidrhost(format("%s/%s", cidrhost(subnet.cidr, 0), split("/", var.vpc_cidr)[1]), 0) == cidrhost(var.vpc_cidr, 0) &&
      cidrhost(format("%s/%s", cidrhost(subnet.cidr, -1), split("/", var.vpc_cidr)[1]), 0) == cidrhost(var.vpc_cidr, 0)
    ])
    error_message = "Each private subnet CIDR must be contained within the VPC CIDR."
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = false

  tags = merge(local.tags, { Name = "${local.name_prefix}-private-${each.key}", Tier = "private" })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, { Name = "${local.name_prefix}-private" })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "private_workload" {
  name        = "${local.name_prefix}-private-workload"
  description = "Default-deny ingress and egress security group for private workloads."
  vpc_id      = aws_vpc.this.id
  ingress     = []
  egress      = []

  tags = merge(local.tags, { Name = "${local.name_prefix}-private-workload" })
}

resource "aws_flow_log" "vpc" {
  log_destination      = var.flow_logs_destination_arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.this.id
}
