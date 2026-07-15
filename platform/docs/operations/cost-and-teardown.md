# Cost and teardown guidance

This repository is not cloud validated, but operators still need to understand
cost drivers before any separate deployment. The figures below are
**interview-sized order-of-magnitude ranges** for a small multi-account design
discussion. They are **not** live billing extracts, reserved-instance quotes, or
proof that teardown was performed from this repository.

## Order-of-magnitude cost drivers

| Driver | When it appears | Interview-scale monthly order of magnitude (USD, rough) | Notes |
| --- | --- | --- | --- |
| Private VPC only (baseline) | Current template: VPC, subnets, SG, flow-log *interface* | ~$0–5 beyond free-tier nuances | No NAT/TGW/NFW in baseline |
| VPC Flow Logs → S3 | After approved emission + archive retention | ~$1–20 for light lab traffic; rises with GB ingested + retention | Storage often dominates over delivery |
| CloudTrail + Config → Log Archive | After separately controlled audit deploy | ~$5–40 for a small org footprint; multi-region + validation add modest overhead | Archive GB × retention is the long-term lever |
| KMS (CMK) | Archive encryption + trail | ~$1/key/month + per-request cents at lab scale | Rotation enabled in template; request volume usually small offline |
| NAT Gateway (extension) | Only if egress design approved | ~$30–45/AZ gateway-hours + data processing | Often the first large jump off private-only |
| Transit Gateway (extension) | Only if shared routing approved | ~$30+/attachment-hour class costs + data | Dominates once multi-VPC sharing starts |
| Network Firewall / VPN / DX (extension) | Only if those designs approved | Tens to hundreds+ depending on endpoints and circuits | Out of baseline; treat as separate cost case |

**Reading the table:** baseline private-only + deferred audit interfaces stay in
the low tens of dollars per month at lab scale; approving NAT or TGW typically
moves the conversation into tens-per-month fixed charges before meaningful
workload traffic. Do not use cost pressure to drop CloudTrail, Config, or flow
log events that the design intends to capture.

## Cost review

- Check whether a proposed change adds NAT Gateway, Transit Gateway, or another
  cross-network component outside the current private-only boundary.
- Check whether CloudTrail, Config, and flow logs all point at the intended Log
  Archive S3 destination with the approved retention window.
- Check whether KMS key usage, bucket versioning, and retention settings align
  with the expected billing and recovery window.
- Prefer shrinking retention only after security review—not as an unreviewed
  cost cut—because Log Archive owns protected storage for investigation.

## Teardown order (design-time only)

Do not destroy from this repository. If a **separately deployed** environment
later needs teardown after validation, operators should follow an approved
workflow that preserves the audit trail. Suggested order of magnitude for
discussion (not executed here):

1. **Freeze writes** — stop workload and CI writers; confirm no in-flight apply.
2. **Capture evidence** — export final trail/Config/flow-log pointers, bucket
   inventory samples, and incident ticket IDs before deletion.
3. **Remove workload / environment attachments** — nonproduction then production
   compositions; keep Log Archive readable during this step.
4. **Remove network emission** — flow-log configurations and VPC resources in the
   Network account boundary after confirming archive retention still holds.
5. **Remove Security Tooling path interfaces** — trail/recorder interfaces only
   after confirming Log Archive retention window and legal hold needs.
6. **Retire Log Archive protected storage last** — bucket/KMS only after
   retention expiry and dual approval; never set `force_destroy`-style shortcuts
   to save time.
7. **Backend state keys** — retire environment-specific state objects last among
   platform artifacts; never share or cross-delete `nonproduction/` and
   `production/` keys.

## Teardown boundary

Do not destroy from this repository. If a separately deployed environment needs
teardown after validation, remove after validation only through an approved
operator workflow that preserves the audit trail, captures final evidence, and
documents retained logs before deletion. This document does **not** claim that
live teardown or live billing reconciliation was performed.

## Stop and escalate

Stop and escalate when cost pressure is used to justify removing audit events
captured by CloudTrail, Config, or flow logs, shortening retention below the
approved review window, or bypassing the archive destination to save charges.
Also stop when a teardown proposal would delete Log Archive storage before
Network/Security Tooling emission paths are drained, or would merge shared state
keys across environments.

See the [blocked-change catalog](blocked-change-catalog.md) for related offline
reject cases (NAT/TGW/NFW, live audit deploy, shared state keys).
