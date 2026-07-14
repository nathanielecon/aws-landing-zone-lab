# Network negative tests

The mocked Terraform tests use real `expect_failures` for a non-private VPC
CIDR, a single-subnet layout, invalid/empty-AZ/public subnet CIDR edges,
subnet CIDR outside the VPC (`check.private_subnets_inside_vpc`), overlapping
subnet CIDRs, unrestricted ingress- and egress-exception attempts, typed SG
exception shapes (non-empty CIDR, port, or protocol via `sg_exception_attempts`),
and a non–S3 flow-log destination ARN. A separate happy-path run
(`enforces_default_deny_security_group`) asserts empty ingress/egress on the
private workload security group. They prove template boundary validation only;
they do not validate AWS connectivity or deploy a network.
