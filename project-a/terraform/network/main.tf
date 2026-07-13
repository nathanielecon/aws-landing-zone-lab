locals {
  name_prefix = "project-a-${var.environment}"
  tags = {
    Project            = "project-a"
    Environment        = var.environment
    Owner              = "platform"
    CostCenter         = "pending-human-approval"
    ManagedBy          = "terraform"
    DataClassification = "internal"
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
