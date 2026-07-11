# Network negative tests

The mocked Terraform tests reject a non-private VPC CIDR and a single-subnet
layout. They prove template boundary validation only; they do not validate AWS
connectivity or deploy a network.
