# `platform/` — AWS Landing Zone engineering surface

This folder is the former **Project A** tree, renamed for recruiters.

## How it connects to the rest of the repo

```text
aws-landing-zone-lab/          ← portfolio face (root README + Image2 figure)
├── platform/                  ← YOU ARE HERE
│   ├── terraform/             ← reusable module design (Orgs, IAM, network, audit, …)
│   ├── docs/                  ← architecture, claims, operations
│   ├── sandbox/landing-zone-lab/  ← retired cloud-validated lab + retained evidence
│   └── harness/tasks/A-00x    ← historical task policies (reference only)
└── evidence/platform/A-00x    ← historical design-gate receipts (repo-only)
```

| Layer | Meaning |
|-------|---------|
| **Design contract** (`terraform/`, `docs/`, `environments/`) | Multi-account Landing Zone **on paper** — inspectable Terraform and offline gates. Orgs member accounts were **not** created in the historical lab. |
| **Retired lab** (`sandbox/landing-zone-lab/`) | **Cloud-validated, then retired** in one account: identity + private network + audit via GitHub OIDC → Terraform CI. Retained S3/KMS evidence remains under separate Terraform state. |
| **A-001…A-007 evidence** (`../evidence/platform/`) | How the design was gated under the old Ralphy Project A profile. Useful audit trail; **not** cloud proof. |
| **Smoke harness** | Separate repo: [ralphy-windows-harness](https://github.com/nathanielecon/ralphy-windows-harness). Not required to understand or run this lab. |

## Diagram

<p align="center">
  <img src="docs/diagrams/aws-landing-zone-lab.png" alt="AWS Landing Zone Lab retired-state architecture, validation flow, private network, and retained evidence" width="100%">
</p>

<p align="center"><sub>
The Image2 figure uses generic, logo-free illustrations. Service names identify
the tools used and do not imply affiliation or endorsement. The editable draw.io
file remains the content authority; see
<a href="docs/diagrams/aws-landing-zone-lab-image2-provenance.md">provenance and validation</a>.
</sub></p>

## Honest resume bullet

> Designed a multi-account AWS Landing Zone (Orgs/OU/SCP interfaces) and
> cloud-validated a single-account lab composition of identity, private
> network, and audit (CloudTrail/KMS Log Archive) in `us-east-1` with
> Terraform, evidence, and CI-gated delivery.

## Delivery path

1. [Architecture overview](docs/architecture/overview.md)
2. [Evidence index](evidence-index.md)
3. [Claims boundary](docs/portfolio/claims-boundary.md)
4. [Pushback and handoff](docs/review/pushback-and-handoff.md)
5. [Azure Government readiness](docs/azure-government/readiness.md) (translation-only)
6. Historical lab: [EVIDENCE.md](sandbox/landing-zone-lab/EVIDENCE.md) and [RETIREMENT_EVIDENCE.md](sandbox/landing-zone-lab/RETIREMENT_EVIDENCE.md)

This folder proves junior-to-mid infrastructure design work plus an honest
cloud-validated, retired single-account lab. It does **not** prove production
deployment, senior ownership, enterprise operations, or multi-account cloud
validation. Avoid unsupported claims of production readiness.
