output "vpc_id" {
  description = "VPC identifier."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet identifiers."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet identifiers."
  value       = aws_subnet.private[*].id
}

output "nat_gateway_enabled" {
  description = "Whether a NAT gateway was provisioned."
  value       = var.enable_nat_gateway
}

output "nat_gateway_id" {
  description = "NAT gateway identifier when enabled."
  value       = var.enable_nat_gateway ? aws_nat_gateway.this[0].id : null
}
