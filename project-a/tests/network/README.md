# Network negative tests

The mocked Terraform tests reject a non-private VPC CIDR, a single-subnet
layout, a non–S3 flow-log destination ARN shape, and any planned ingress or
egress exception on the private workload security group. They prove template
boundary validation only; they do not validate AWS connectivity or deploy a
network.
