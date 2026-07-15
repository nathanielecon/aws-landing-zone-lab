# AWS Landing Zone Lab

Terraform + GitHub OIDC CI. **Cloud-validated** single-account lab in `us-east-1`: identity, private network, and audit. Multi-account Orgs/OU/SCP interfaces stay design-only.

## Diagram

One Image2 figure — architecture, how it works, and private network consolidated (latest panels preferred where they overlapped).

<p align="center">
  <img src="project-a/docs/diagrams/aws-landing-zone-lab.png" alt="AWS Landing Zone Lab — consolidated architecture, how it works, and private network" width="100%">
</p>

<p align="center">
  <a href="project-a/docs/diagrams/aws-landing-zone-lab.drawio">Editable draw.io source</a>
</p>

| Panel | What it shows |
|-------|----------------|
| **A. Architecture** | Bootstrap → Organization (design) → Identity → Network → Audit → Validation. Live lab applied identity + network + audit in one account. |
| **B. How it works** | Push → OIDC → Terraform (one account) → live resources → evidence. |
| **C. Private network** | Private subnets, default-deny SG, Flow Logs → Log Archive. No internet, NAT, peering, Transit Gateway, or cross-account route. |

Section archives (harness / deep links): [`architecture.png`](project-a/docs/diagrams/aws-landing-zone-architecture.png) · [`network.png`](project-a/docs/diagrams/aws-landing-zone-network.png)

## Resume bullet

> Designed a multi-account AWS Landing Zone (Orgs/OU/SCP interfaces) and cloud-validated a single-account lab composition of identity, private network, and audit (CloudTrail/KMS Log Archive) in `us-east-1` with Terraform, evidence, and CI-gated delivery.

## Proven vs not

**Cloud-validated (live lab)** — single-account `us-east-1`; OIDC role `project-a-lzlab-gha`; private VPC + flow logs; CloudTrail / Config / KMS Log Archive; CI-gated Terraform apply with written evidence.

**Not proven** — multi-account Organizations with real member accounts; enterprise production operations; Azure Government (translation docs only). This repository does **not** prove production deployment or senior-level platform ownership.

Details: [`project-a/docs/portfolio/claims-boundary.md`](project-a/docs/portfolio/claims-boundary.md).

## Where to look next

| Want… | Go here |
|-------|---------|
| Project docs entry | [`project-a/README.md`](project-a/README.md) |
| Architecture contract | [`project-a/docs/architecture/overview.md`](project-a/docs/architecture/overview.md) |
| Live lab evidence | [`project-a/sandbox/landing-zone-lab/EVIDENCE.md`](project-a/sandbox/landing-zone-lab/EVIDENCE.md) |
| Orgs design interface | [`project-a/sandbox/landing-zone-lab/ORGS_INTERFACE.md`](project-a/sandbox/landing-zone-lab/ORGS_INTERFACE.md) |

## Harness (repo tooling)

Native-Windows smoke harness for one sequential Ralphy loop — separate from the Landing Zone lab story above.

```powershell
./scripts/Start-Harness.ps1 -DryRun
./scripts/Start-Harness.ps1
```

Details: [`project-a/HARNESS.md`](project-a/HARNESS.md).
