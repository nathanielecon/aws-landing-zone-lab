# Project A

Project A is primarily a repo-only reference contract for a multi-account AWS
platform: inspectable Terraform and documentation, deterministic harness gates,
and evidence for A-001…A-007 that is **not** cloud-validated. Azure Government
remains translation-only.

Separately, an operator sandbox under
[`sandbox/aws-proof`](sandbox/aws-proof/EVIDENCE.md) applied the **audit**
module live in a commercial AWS account (CloudTrail + KMS Log Archive). That
proves audit-module apply efficacy only — not Organizations, network, or
identity deployment, and not production readiness.

Start with the [architecture overview](docs/architecture/overview.md), then
review the [backend](docs/decisions/backend.md) and
[secrets](docs/decisions/secrets.md) decisions. All account IDs, regions,
names, and backend settings in examples are placeholders requiring human
review unless citing the sandbox evidence file.

Use the [platform diagram](docs/diagrams/platform.svg), the
[network diagram](docs/diagrams/network.svg), and the
[evidence index](evidence-index.md) to inspect the full repo-only contract.
The [Graphify report](graphify-out/GRAPH_REPORT.md) is a structural navigation
aid only; it is not a substitute for Terraform, policy, security, or human
validation, and it does not prove cloud behavior.
This repository proves a documented junior-to-mid level infrastructure design
exercise (optionally plus a narrow live audit proof); it does not prove
production readiness, senior ownership, enterprise operations, or full-platform
cloud validation.
