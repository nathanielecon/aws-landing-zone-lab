# Network failure cases

These cases apply to the baseline private VPC boundary only. Transit Gateway
(TGW), Network Firewall (NFW), NAT gateways, centralized egress, peering, VPN,
Direct Connect (DX), and RAM shares are extension points—not baseline features.
Do not treat them as implemented connectivity when triage or repair guidance
mentions egress, cross-account paths, or shared networking. Align with the
[network architecture](../architecture/network.md).

Related: [blocked-change catalog](blocked-change-catalog.md),
[audit troubleshooting](audit-troubleshooting.md),
[network module](../../terraform/network/README.md).

## Fail-closed review inputs and CIDR negatives (BC-NET-06 / BC-NET-08 / BC-NET-09)

Offline review rejects unrestricted security-group exceptions and bad address
plans before any deploy. Replay these against the catalog when triage suggests
opening the private boundary:

| Catalog ID | Fail-closed signal | Offline `expect_failures` |
| --- | --- | --- |
| BC-NET-06 | `allow_unrestricted_ingress` defaults to deny and must stay `false` (extension-blocked) | `rejects_unrestricted_ingress_exception` → `var.allow_unrestricted_ingress` |
| BC-NET-08 | `allow_unrestricted_egress` defaults to deny and must stay `false` (extension-blocked) | `rejects_unrestricted_egress_exception` → `var.allow_unrestricted_egress` |
| BC-NET-09 | Private subnet CIDRs must sit inside the VPC and must not overlap | `check.private_subnets_inside_vpc` and `var.private_subnets` overlap / edge cases |

Happy-path coverage for the empty SG is
`enforces_default_deny_security_group` (`ingress = []`, `egress = []`). These
are template validations only; they do not prove live connectivity.

## Default-deny security group triage

When a private workload cannot accept or initiate connections, treat the
default-deny security group as intentional—not a missing rule to “fix” in
this repository:

1. Confirm the workload uses the private-workload security group with empty
   `ingress` and `egress`.
2. Confirm change inputs did not set `allow_unrestricted_ingress` or
   `allow_unrestricted_egress` to `true` (both must remain `false` offline;
   BC-NET-06 / BC-NET-08).
3. Identify the approved source or destination, protocol, port, owner, and
   expiry for any exception request.
4. Stop and escalate if the proposed repair opens `0.0.0.0/0`, adds
   NAT/IGW/TGW/VPN/DX/RAM, or bypasses Network-owner review (see BC-NET-03 and
   related catalog rows).

## Private workload to the public internet

A workload in a private subnet cannot reach a public package mirror because the
private route table has no default route, NAT gateway, or centralized egress
path. First check the subnet association and approved route intent. Stop and
escalate if the proposed repair adds `0.0.0.0/0`, an internet gateway, or NAT
without an approved egress design. NAT and centralized egress remain extension
points until a separate design is human-approved. Unrestricted egress exception
flags are fail-closed (BC-NET-08); do not flip
`allow_unrestricted_egress` during incident handling.

## Untrusted source to a private workload

An internet or another account cannot initiate a connection to the workload
because private subnets have no public IPs or cross-account routing, and the
workload security group defines no ingress rule. First check the source identity,
the intended protocol and port, and the approved boundary owner. Stop and
escalate if the repair uses an unrestricted source, introduces TGW/VPN/DX/RAM
sharing, or bypasses security-group review. Unrestricted ingress exception flags
are fail-closed (BC-NET-06); do not flip `allow_unrestricted_ingress` to open
the boundary from this repository.

## Missing flow-log records

If expected flow-log records are absent, first check the VPC ID, destination ARN,
and Log Archive destination policy after a separately approved deployment. Do not
add a new destination or weaken archive controls during incident handling; record
the gap and escalate to the Network and Security owners. For archive delivery
and KMS path issues after a separately controlled deploy, continue in
[audit troubleshooting](audit-troubleshooting.md).

## Subnet CIDR plan failures (BC-NET-09)

If plan or offline tests reject subnet layout, first check that each private
subnet CIDR is contained in the VPC prefix and that subnet CIDRs do not
overlap. Matching `expect_failures` cover outside-VPC and overlapping cases.
Stop and escalate if the proposed repair widens the VPC, invents public subnet
tiers, or bypasses address-plan ownership.

These cases are design-time guidance only. No live connectivity test, route
change, or cloud deployment is authorized by this repository.
