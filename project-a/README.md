# Project A

Plain-English map of what this folder is:

<p align="center">
  <img src="docs/diagrams/project-a-landing-zone-infographic.png" alt="Project A AWS Landing Zone Lab flow" width="100%">
</p>

<p align="center">
  <a href="docs/diagrams/project-a-landing-zone.drawio">draw.io source</a>
  ·
  <a href="docs/diagrams/platform-eli5.svg">ELI5 SVG</a>
  ·
  <a href="docs/diagrams/platform.svg">platform contract SVG</a>
  ·
  <a href="docs/diagrams/network.svg">network SVG</a>
</p>

Project A is mostly a repo-only reference contract for a multi-account AWS
platform: inspectable Terraform, docs, harness gates, and evidence for
A-001…A-007 that is **not** cloud-validated. Azure Government stays
translation-only.

Separately, a **single-account Landing Zone lab** under
[`sandbox/landing-zone-lab`](sandbox/landing-zone-lab/EVIDENCE.md) was
**cloud-validated** in account `<AWS_ACCOUNT_ID>` / `us-east-1` via GitHub OIDC →
Terraform CI (role `project-a-lzlab-gha`): identity + private network + audit
(CloudTrail/KMS Log Archive). Organizations member accounts are **not**
created; the Orgs/OU/SCP module stays a design interface
([`ORGS_INTERFACE.md`](sandbox/landing-zone-lab/ORGS_INTERFACE.md)).

An earlier audit-only sandbox
([`sandbox/aws-proof`](sandbox/aws-proof/EVIDENCE.md)) is historical evidence
of the first live audit-module apply.

### Honest resume bullet

> Designed a multi-account AWS Landing Zone (Orgs/OU/SCP interfaces) and
> cloud-validated a single-account lab composition of identity, private
> network, and audit (CloudTrail/KMS Log Archive) in `us-east-1` with
> Terraform, evidence, and CI-gated delivery.

Start with the [architecture overview](docs/architecture/overview.md), then
the [backend](docs/decisions/backend.md) and [secrets](docs/decisions/secrets.md)
decisions. Cite lab evidence for live resources; other examples stay
placeholders for human review.

### Delivery path (zero orphans)

README → architecture → evidence → review:

1. [Architecture overview](docs/architecture/overview.md)
2. [Evidence index](evidence-index.md)
3. [Claims boundary](docs/portfolio/claims-boundary.md)
4. [Pushback and handoff](docs/review/pushback-and-handoff.md)
5. [Azure Government readiness](docs/azure-government/readiness.md) (translation-only)

The [Graphify report](graphify-out/GRAPH_REPORT.md) is a navigation aid only.
It is not a substitute for Terraform, policy, security, or human validation,
and it does not prove cloud behavior.

Fresh-clone Windows one-command proof matching CI (pin fail-closed):

```powershell
$env:HARNESS_STRICT_PINS = '1'
pwsh -NoLogo -NoProfile -File ../scripts/Invoke-HarnessReleaseValidation.ps1
```

Details: [HARNESS.md](HARNESS.md).

This repository proves a documented junior-to-mid level infrastructure design
exercise plus an honest single-account live lab; it does **not** prove
production readiness, senior ownership, enterprise operations, or
multi-account cloud validation.
