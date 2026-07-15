# `platform/` — AWS Landing Zone engineering surface

This folder is the former **Project A** tree, renamed for recruiters.

## How it connects to the rest of the repo

```text
aws-landing-zone-lab/          ← portfolio face (root README + Image2 figure)
├── platform/                  ← YOU ARE HERE
│   ├── terraform/             ← reusable module design (Orgs, IAM, network, audit, …)
│   ├── docs/                  ← architecture, claims, operations
│   ├── sandbox/landing-zone-lab/  ← live cloud-validated lab (OIDC CI)
│   └── harness/tasks/A-00x    ← historical task policies (reference only)
└── evidence/platform/A-00x    ← historical design-gate receipts (repo-only)
```

| Layer | Meaning |
|-------|---------|
| **Design contract** (`terraform/`, `docs/`, `environments/`) | Multi-account Landing Zone **on paper** — inspectable Terraform and offline gates. Orgs member accounts were **not** created in the live lab. |
| **Live lab** (`sandbox/landing-zone-lab/`) | **Cloud-validated** in one account: identity + private network + audit via GitHub OIDC → Terraform CI. This is what the resume bullet cites. |
| **A-001…A-007 evidence** (`../evidence/platform/`) | How the design was gated under the old Ralphy Project A profile. Useful audit trail; **not** cloud proof. |
| **Smoke harness** | Separate repo: [ralphy-windows-harness](https://github.com/nathanielecon/ralphy-windows-harness). Not required to understand or run this lab. |

## Diagram

<p align="center">
  <img src="docs/diagrams/aws-landing-zone-lab.png" alt="AWS Landing Zone Lab consolidated figure" width="100%">
</p>

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
6. Live lab: [EVIDENCE.md](sandbox/landing-zone-lab/EVIDENCE.md)

This folder proves junior-to-mid infrastructure design work plus an honest
cloud-validated single-account live lab. It does **not** prove production
deployment, senior ownership, enterprise operations, or multi-account cloud
validation. Avoid unsupported claims of production readiness.
