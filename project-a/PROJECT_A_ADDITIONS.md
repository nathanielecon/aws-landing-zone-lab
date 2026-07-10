# Project A gap-closure requirements

These requirements are normative for the repo-only Project A implementation.
They refine the seven-task plan without authorizing cloud access or execution.

## Required proof

1. **Backend and state discipline:** document the remote backend choice and
   rationale, S3 lockfile concurrency control, versioning/recovery, drift and
   overwrite protections, and explicit environment state-key separation.
2. **Policy and validation as code:** provide `fmt`, `validate`, lint, and test
   paths; machine-check naming and required tags; and include examples that
   demonstrate an invalid change being blocked.
3. **Network decisions:** explain VPC/subnet layout, routes, security-group and
   boundary intent, plus at least two negative connectivity cases identifying
   why a source cannot reach a destination or access path.
4. **Secrets discipline:** document the intended secret store/retrieval
   interface, least-privilege consumer access, environment/config boundaries,
   and explicit locations where secrets must never be committed or placed.
5. **Logging and audit proof:** identify captured events, destinations,
   integrity/retention defaults, operational review, and the governance reason
   for each default. Repo evidence must remain offline and inspectable.
6. **Cost and teardown discipline:** identify likely cost drivers, lightweight
   defaults, resources that would be removed after validation, and safe
   teardown guidance. The repo-only milestone must not perform teardown.
7. **Operator troubleshooting:** provide first checks for provisioning,
   access/connectivity, and missing audit signals, with a baseline validation
   runbook and explicit stop/escalation conditions.
8. **Claim boundaries:** state what the repository proves and does not prove,
   provide accurate junior-to-mid platform wording, and list senior/production
   claims that the evidence does not support.

## Acceptance boundary

Documentation alone is insufficient where deterministic checks are possible.
Terraform tests and harness validators must reject representative bad naming,
tagging, IAM, network, and cross-module changes. All examples are non-secret,
all cloud claims remain false, and human gates retain final ownership of state,
identity, network, logging, and evidence decisions.
