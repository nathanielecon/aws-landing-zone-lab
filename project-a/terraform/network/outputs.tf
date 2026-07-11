output "vpc_id" {
  description = "VPC identifier after a separately approved deployment."
  value       = aws_vpc.this.id
}

output "private_subnet_count" {
  description = "Number of isolated private subnets defined by this template."
  value       = length(aws_subnet.private)
}

output "private_security_group_id" {
  description = "Default-deny private workload security group identifier after deployment."
  value       = aws_security_group.private_workload.id
}
