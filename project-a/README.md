# Project A

Project A is primarily a repo-only reference contract for a multi-account AWS
platform: inspectable Terraform and documentation, deterministic harness gates,
and evidence for A-001…A-007 that is **not** cloud-validated. Azure Government
remains translation-only.

Separately, a **single-account Landing Zone lab** under
[`sandbox/landing-zone-lab`](sandbox/landing-zone-lab/EVIDENCE.md) is **READY TO
APPLY** / `PENDING_APPLY` for a collapsed composition of identity + private
network + audit in account `<AWS_ACCOUNT_ID>` / `us-east-1`. Designed Terraform
interfaces exist; live cloud apply of that composition is **not** yet complete,
so identity + network + audit are **not** cloud-validated as a completed fact.
Organizations member accounts are **not** created; the Orgs/OU/SCP module
remains a design interface
([`ORGS_INTERFACE.md`](sandbox/landing-zone-lab/ORGS_INTERFACE.md)).

An earlier audit-only sandbox
([`sandbox/aws-proof`](sandbox/aws-proof/EVIDENCE.md)) remains the first live
audit-module proof.

### Honest resume bullet (target / after-exit wording)

Not current proof — use only after a successful live lab apply and evidence
update. Target wording:

> Designed a multi-account AWS Landing Zone (Orgs/OU/SCP interfaces) and
> cloud-validated a single-account lab composition of identity, private
> network, and audit (CloudTrail/KMS Log Archive) in `us-east-1` with
> Terraform, evidence, and CI-gated delivery.

Start with the [architecture overview](docs/architecture/overview.md), then
review the [backend](docs/decisions/backend.md) and
[secrets](docs/decisions/secrets.md) decisions. All account IDs, regions,
names, and backend settings in examples are placeholders requiring human
review unless citing the lab evidence files.

Use the [platform diagram](docs/diagrams/platform.svg), the
[network diagram](docs/diagrams/network.svg), and the
[evidence index](evidence-index.md) to inspect the full repo-only contract.
The [Graphify report](graphify-out/GRAPH_REPORT.md) is a structural navigation
aid only; it is not a substitute for Terraform, policy, security, or human
validation, and it does not prove cloud behavior.
This repository proves a documented junior-to-mid level infrastructure design
exercise plus an honest single-account lab that is ready to apply; it does
**not** prove production readiness, senior ownership, enterprise operations,
multi-account cloud validation, or a completed identity+network+audit cloud
validation until `EVIDENCE.md` leaves `PENDING_APPLY`.
