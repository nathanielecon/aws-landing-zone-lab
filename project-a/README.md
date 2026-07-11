# Project A

Project A is a repo-only reference contract for a multi-account AWS platform.
It contains inspectable Terraform and documentation, but it has not been
validated against a cloud account, does not create cloud resources, and does
not implement Azure Government.

Start with the [architecture overview](docs/architecture/overview.md), then
review the [backend](docs/decisions/backend.md) and
[secrets](docs/decisions/secrets.md) decisions. All account IDs, regions,
names, and backend settings in examples are placeholders requiring human
review.

Use the [platform diagram](docs/diagrams/platform.svg), the
[network diagram](docs/diagrams/network.svg), and the
[evidence index](evidence-index.md) to inspect the full repo-only contract.
This repository proves a documented junior-to-mid level infrastructure design
exercise; it does not prove production readiness, senior ownership, enterprise
operations, or cloud validation.
