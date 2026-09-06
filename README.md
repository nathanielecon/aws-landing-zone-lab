# AWS Landing Zone Lab

Terraform + GitHub OIDC CI. **Cloud-validated and retired** single-account lab:
identity, private network, and audit. Multi-account Orgs/OU/SCP interfaces stay
design-only. Retained evidence remains under Terraform ownership; the current
tree cannot recreate the former live lab.

Formerly the `cloud` monorepo; the Ralphy smoke harness now lives in
[`nathanielecon/ralphy-windows-harness`](https://github.com/nathanielecon/ralphy-windows-harness).

## Diagram

<p align="center">
  <img src="platform/docs/diagrams/aws-landing-zone-lab.png" alt="AWS Landing Zone Lab — consolidated architecture, how it works, and private network" width="100%">
</p>

<p align="center">
  <a href="platform/docs/diagrams/aws-landing-zone-lab.drawio">Editable draw.io source</a>
</p>

| Panel | What it shows |
|-------|----------------|
| **A. Architecture** | Bootstrap → Organization (design) → Identity → Network → Audit → Validation. Live lab applied identity + network + audit in one account. |
| **B. How it worked** | Protected GitHub OIDC → Terraform (one account) → live resources → evidence; later reviewer-gated retirement. |
| **C. Private network** | Private-by-design VPC: private subnets, default-deny SG, closed network edge (no IGW/NAT/peering/TGW unless added). Flow Logs → Log Archive. |

The displayed figure uses generic symbols. Legacy brandmarked assets were removed; see [`platform/docs/BRANDMARK_REMOVAL.md`](platform/docs/BRANDMARK_REMOVAL.md).

## Repo map

| Path | What it is |
|------|------------|
| **This README** | Recruiter face: what was cloud-validated and what was not |
| [`platform/`](platform/) | Engineering surface — multi-account **design contract**, reusable Terraform modules, docs, and retained evidence |
| [`platform/sandbox/landing-zone-lab/`](platform/sandbox/landing-zone-lab/) | **Cloud-validated, then retired** single-account lab |
| [`evidence/platform/`](evidence/platform/) | Historical A-001…A-007 design-gate receipts (repo-only; not cloud proof) |
| Sibling: [ralphy-windows-harness](https://github.com/nathanielecon/ralphy-windows-harness) | Sequential Ralphy/Codex smoke harness (separate product) |

## Resume bullet

> Designed a multi-account AWS Landing Zone (Orgs/OU/SCP interfaces) and cloud-validated a single-account lab composition of identity, private network, and audit (CloudTrail/KMS Log Archive) in `us-east-1` with Terraform, evidence, and CI-gated delivery.

## Proven vs not

**Cloud-validated (historical lab)** — single-account `us-east-1`; private VPC
and flow logs; CloudTrail / Config / KMS Log Archive; CI-gated Terraform apply
with written evidence. On 2026-09-06, retained S3/KMS ownership was transferred
to a dedicated Terraform state, the remaining lab was destroyed, and all 17
enabled regions were verified clear.

**Not proven** — multi-account Organizations with real member accounts; enterprise production operations; Azure Government (translation docs only). This repository does **not** prove production deployment or senior-level platform ownership.

Details: [`platform/docs/portfolio/claims-boundary.md`](platform/docs/portfolio/claims-boundary.md).

## Where to look next

| Want… | Go here |
|-------|---------|
| How `platform/` connects | [`platform/README.md`](platform/README.md) |
| Architecture contract | [`platform/docs/architecture/overview.md`](platform/docs/architecture/overview.md) |
| Original lab evidence | [`platform/sandbox/landing-zone-lab/EVIDENCE.md`](platform/sandbox/landing-zone-lab/EVIDENCE.md) |
| Retirement evidence | [`platform/sandbox/landing-zone-lab/RETIREMENT_EVIDENCE.md`](platform/sandbox/landing-zone-lab/RETIREMENT_EVIDENCE.md) |
| Orgs design interface | [`platform/sandbox/landing-zone-lab/ORGS_INTERFACE.md`](platform/sandbox/landing-zone-lab/ORGS_INTERFACE.md) |
| Retained Terraform root | [`platform/sandbox/landing-zone-lab/retained-evidence/`](platform/sandbox/landing-zone-lab/retained-evidence/) |

> Three independent, evidence-backed cloud engineering labs; presented as a reinforcing portfolio, not a claim of one sustained customer-production platform.

## License

Apache-2.0. See [`LICENSE`](LICENSE).
