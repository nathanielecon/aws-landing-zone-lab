# Network failure cases

## Private workload to the public internet

A workload in a private subnet cannot reach a public package mirror because the
private route table has no default route, NAT gateway, or centralized egress
path. First check the subnet association and approved route intent. Stop and
escalate if the proposed repair adds `0.0.0.0/0`, an internet gateway, or NAT
without an approved egress design.

## Untrusted source to a private workload

An internet or another account cannot initiate a connection to the workload
because private subnets have no public IPs or cross-account routing, and the
workload security group defines no ingress rule. First check the source identity,
the intended protocol and port, and the approved boundary owner. Stop and
escalate if the repair uses an unrestricted source or bypasses security-group
review.

## Missing flow-log records

If expected flow-log records are absent, first check the VPC ID, destination ARN,
and Log Archive destination policy after a separately approved deployment. Do not
add a new destination or weaken archive controls during incident handling; record
the gap and escalate to the Network and Security owners.

These cases are design-time guidance only. No live connectivity test, route
change, or cloud deployment is authorized by this repository.
