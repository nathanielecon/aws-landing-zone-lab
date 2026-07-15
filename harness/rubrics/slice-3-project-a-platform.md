# Slice 3 rubric — Project A platform

Status: frozen  
Scope: platform modules and matching architecture / guardrail / operations
docs owned primarily by tasks `A-003` through `A-006`, including:

- `project-a/terraform/identity/**`, `network/**`, `audit/**`
- `project-a/policies/**`
- `project-a/environments/**`
- `project-a/tests/iam/**`, `governance/**`, `network/**`, `audit/**`,
  `integration/**`
- `project-a/docs/architecture/network.md`, `logging.md`
- `project-a/docs/guardrails/iam.md`, `policy-validation.md`
- `project-a/docs/operations/network-failure-cases.md`, `audit-review.md`,
  `audit-troubleshooting.md`, `baseline-runbook.md`, `cost-and-teardown.md`
- `project-a/docs/validation.md`
- `project-a/docs/diagrams/aws-landing-zone-network.png`
- task policies `A-003.json` … `A-006.json`

Extension points that must remain unimplemented: Transit Gateway, Network
Firewall, centralized egress, Direct Connect, VPN, live RAM shares, Identity
Center lifecycle, and live audit deployment.

## must-have to pass slice

- IAM/identity module plus policy fixtures document trust, permission
  boundaries, and break-glass expectations without deploying IAM in cloud.
- Negative IAM/governance tests exist and are exercised by allowlisted
  validators (`iam_policy_semantics`, `iam_negative_tests`,
  `governance_semantics`).
- Network module models account/VPC/subnet boundaries, private-only posture,
  default-deny security groups, and Flow Logs interface to a Log Archive ARN.
- Network docs and failure-case runbook state that TGW/NFW/NAT/VPN/DX/RAM are
  extension points, not features.
- Audit module and logging architecture cover organization CloudTrail, Config
  interfaces, protected Log Archive S3 posture, integrity/validation, and
  retention as typed inputs—interfaces only, no live log-service calls.
- Audit review and troubleshooting runbooks exist and link to the audit module.
- Environment compositions under `project-a/environments/` stay non-secret and
  offline-validatable.
- Offline validation suite covers fmt/validate/tests across modules plus
  cross-module negative checks (`A-006` validators).
- Operations docs include baseline runbook and cost/teardown guidance without
  claiming cloud teardown was performed.
- All platform evidence claims remain repo-only / not cloud validated.

## needed for 9/10+

- Network SVG diagram matches documented boundaries and is linked from
  `network.md`.
- Policy-validation docs explain validator IDs and fail-closed unknown-ID
  behavior for platform gates.
- Integration tests assert composition consistency across identity, network,
  and audit interfaces without AWS credentials.
- Clear ownership language: Network account owns VPC boundary; Security
  Tooling owns audit path; Log Archive owns protected storage.
- Operator troubleshooting covers common connectivity and audit delivery
  failure modes with claim-safe wording.

## needed for 10/10

- Exhaustive negative matrices for ingress/egress exceptions, CIDR validation,
  and audit bucket/KMS misconfiguration cases.
- End-to-end offline “blocked change” catalog that a reviewer can replay from
  docs alone.
- Zero broken links among architecture, guardrails, operations, tests, and
  module READMEs.
- Explicit cost/teardown scenarios sized for interview pressure without
  inventing live billing data.

## nice-to-have

- Extra regional variants beyond primary + optional DR region inputs.
- Sample IAM Access Analyzer findings fixtures.
- Automated SVG regeneration pipeline (hand-authored diagrams are acceptable).
