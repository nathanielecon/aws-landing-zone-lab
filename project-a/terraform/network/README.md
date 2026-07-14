# Network boundary template

This module is an offline, reviewable template; it has no provider configuration
and must not be applied from this repository. It defines one VPC, two or more
private subnets, a private route table with no default route, a default-deny
workload security group, and VPC Flow Logs sent to a human-approved Log Archive
S3 destination.

No internet gateway, NAT gateway, Transit Gateway, peering, VPN, Direct Connect,
RAM share, cross-account route, or centralized egress is implemented. Those are
separately reviewed extension points. A human must approve CIDRs, availability
zones, regions, route intent, destinations, and any ingress or egress exception.

Fail-closed review inputs `allow_unrestricted_ingress` and
`allow_unrestricted_egress` default to `false` and must stay false. Setting
either to `true` fails offline validation; opening SG ingress/egress remains
**extension-blocked** until a separate human-approved design. Subnet CIDRs must
stay inside the VPC prefix (`check.private_subnets_inside_vpc`) and must not
overlap.

Run only offline checks:

```powershell
terraform fmt -check -recursive
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
terraform test -no-color -test-directory=../../tests/network
```

See the [network architecture](../../docs/architecture/network.md),
[network failure cases](../../docs/operations/network-failure-cases.md), the
[blocked-change catalog](../../docs/operations/blocked-change-catalog.md)
(BC-NET-01–09), and the offline policy fixtures in
[tests/network](../../tests/network/README.md) (`network.tftest.hcl`).
