# Network negative tests

The mocked Terraform tests use real `expect_failures` for a non-private VPC
CIDR, a single-subnet layout, invalid/empty-AZ/public subnet CIDR edges,
an unrestricted ingress-exception attempt, and a non–S3 flow-log destination
ARN. A separate happy-path run asserts empty ingress/egress on the private
workload security group. They prove template boundary validation only; they do
not validate AWS connectivity or deploy a network.
