# AWS Landing Zone Lab

Terraform + GitHub OIDC CI. Designs a multi-account AWS Landing Zone, then proves a **single-account** live lab: identity, private network, and audit in `us-east-1`.

## The figure (architecture · how it works · network)

One poster. Three panels: platform contract, CI live-lab flow, and the private VPC detail (including the network diagram that was missing before).

<p align="center">
  <img src="project-a/docs/diagrams/aws-landing-zone-lab.png" alt="AWS Landing Zone Lab — architecture, how it works, and private network in one figure" width="100%">
</p>

<p align="center">
  <a href="project-a/docs/diagrams/aws-landing-zone-lab.drawio">draw.io (editable)</a>
  ·
  <a href="project-a/docs/diagrams/aws-landing-zone-lab.svg">SVG</a>
</p>

| Panel | What it shows |
|-------|----------------|
| **A. Architecture** | Bootstrap → Organization (design) → Identity → Network → Audit → Validation. Live lab applied identity + network + audit in one account; Orgs members stay design-only. |
| **B. How it works** | Push code → OIDC proves identity → Terraform builds one account → live resources → evidence written down. |
| **C. Private network** | Private subnets, default-deny SG, Flow Logs → Log Archive. No internet, NAT, peering, Transit Gateway, or cross-account route. |

Section sources (if you want to edit one panel alone): [`architecture`](project-a/docs/diagrams/aws-landing-zone-architecture.drawio) · [`how-it-works`](project-a/docs/diagrams/aws-landing-zone-how-it-works.drawio) · [`network.svg`](project-a/docs/diagrams/network.svg)

## Resume bullet (honest)

> Designed a multi-account AWS Landing Zone (Orgs/OU/SCP interfaces) and cloud-validated a single-account lab composition of identity, private network, and audit (CloudTrail/KMS Log Archive) in `us-east-1` with Terraform, evidence, and CI-gated delivery.

## Proven vs not

**Proven (live lab)** — single-account `us-east-1`; OIDC role `project-a-lzlab-gha`; private VPC + flow logs; CloudTrail / Config / KMS Log Archive; CI-gated Terraform apply with written evidence.

**Not proven** — multi-account Organizations with real member accounts; production ops; Azure Government (translation docs only).

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
