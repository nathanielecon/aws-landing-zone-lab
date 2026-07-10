# Project A candidate execution plan

Status: `candidate-specification`  
Plan ID: `project-a-repo-baseline-v1`

This is the single approved-plan candidate for a repo-only AWS platform baseline.
It is not executable until Phase 4 supplies and tests the generic validator and
human-approval contracts, computes the complete execution-bundle hash, and the
user explicitly approves that exact bundle.

## Outcome and claims boundary

Produce inspectable Terraform, tests, diagrams, decision records, and evidence
for a multi-account AWS baseline. No task may authenticate to AWS or Azure, run
a live plan, create an account, change a cloud resource, or claim cloud
validation. Azure Government is translation/readiness guidance only.

Every evidence record must set:

- `mode: repo_only`
- `cloud_validated: false`
- `aws_implemented: false`
- `azure_implemented: false`

## Locked architecture decisions

- One sequential Ralphy task stream; no worktrees, parallel tasks, sandbox
  copies, or branch-per-task behavior.
- Terra attempts every task first. Existing takeover thresholds remain: three
  Terra executions, two consecutive validation failures, the same error twice,
  one no-diff repair, 25 active minutes, scope escape, or explicit policy gate.
- Sol receives the compact takeover and gets one implementation plus one repair
  pass. Sol does not replace required human approval.
- Terraform CLI target is `1.15.5`; the AWS provider target is `6.36.x`, with an
  exact dependency lock file generated and reviewed during implementation.
- State uses a separately bootstrapped, versioned, encrypted S3 bucket and S3
  lockfile (`use_lockfile = true`). DynamoDB locking is excluded because it is
  deprecated. Backend credentials and sensitive values are never committed.
- The reference account taxonomy is Management plus Security Tooling, Log
  Archive, Network, Shared Services, Non-production Workload, and Production
  Workload accounts under Security, Infrastructure, and Workloads OUs.
- Account emails, IDs, organization IDs, CIDRs, regions, retention periods, KMS
  administrators, and human principals remain typed inputs/examples until a
  human approves real values.
- AWS Organizations/SCPs provide guardrails, not permissions. IAM roles grant
  access; permission boundaries cap delegated application roles.
- Network MVP documents and models account/VPC/subnet boundaries, route intent,
  security groups, NACL posture, and flow-log interfaces. Transit Gateway,
  Network Firewall, centralized egress, Direct Connect, VPN, and live RAM shares
  are extension points, not implemented features.
- Central audit design covers organization CloudTrail, AWS Config interfaces,
  VPC Flow Logs, protected Log Archive S3 storage, KMS boundaries, integrity,
  retention inputs, and an audit-review runbook.
- Graphify is a navigation/evidence aid after structure stabilizes. Its report
  never substitutes for Terraform, policy, security, or human validation.

## Sequential task stream

1. `A-001` creates the architecture/toolchain contract, repo layout, naming and
   tagging rules, backend bootstrap design, and non-secret examples.
2. `A-002` implements the Organizations/OU/account model and SCP attachment
   interfaces without creating or applying accounts.
3. `A-003` implements IAM/SCP/trust/permission-boundary templates, break-glass
   documentation, and negative policy tests.
4. `A-004` implements network-boundary modules and diagrams without cross-account
   connectivity or live deployment.
5. `A-005` implements centralized audit/logging interfaces and the audit-review
   runbook without cloud calls.
6. `A-006` composes non-secret example environments and runs all static,
   offline-capable validation and negative tests.
7. `A-007` assembles evidence, Graphify output, Azure Government translation
   notes, reviewer pushback/narrowing, and the final handoff.

## Human gates

For `A-001` through `A-005`, Terra/Sol may produce a validated diff, but the
adapter must pause after validation and before commit. A human approval receipt
must bind the bundle hash, task, branch, starting commit, exact diff fingerprint,
changed paths, and validation digest. Agents cannot create receipts. Any changed
binding invalidates approval. `A-007` requires the same gate before final commit
and PR. `A-006` may pass deterministically without a human pause.

Human review owns these decisions:

- `H0`: account taxonomy, regions, naming/tags, state ownership and recovery.
- `H1`: OU/account topology, account-creation semantics, and SCP attachment.
- `H2`: principals, actions, trust conditions, permission boundaries, and
  emergency-access design.
- `H3`: CIDRs, ingress/egress intent, route ownership, and network boundaries.
- `H4`: retention, KMS administration, log readers, integrity, and recovery.
- `H5`: evidence completeness, Azure wording, narrowing, and merge readiness.

## Deterministic validation contract

Policies reference allowlisted validator IDs, never arbitrary shell commands.
Phase 4 must fail closed on unknown IDs and pin implementation hashes. Required
validators include path scope, UTF-8/text rules, secret scanning, forbidden
operations, `terraform fmt -check -recursive`, `terraform init -backend=false`,
`terraform validate`, Terraform tests with mocks where appropriate, JSON/IAM
semantic checks, network-negative assertions, documentation links, evidence
digests, and clean-tree/commit ownership.

`terraform validate` proves syntax and internal consistency only; it does not
validate remote services. Every validator is check-only: Terraform commands use
an external per-run `TF_DATA_DIR`, read-only dependency locks, and must leave no
tracked or untracked repo changes. Provider installation may use a pinned cache,
but no validator may use cloud credentials or make AWS/Azure API calls. Agents
may edit only `allowed_paths`; the adapter alone creates and stages the single
`adapter_owned_paths` evidence record after all gates pass.

## Explicit exclusions

- AWS/Azure credentials, apply, destroy, import, live plan, or account creation.
- Control Tower, AFT, production backend activation/migration, workloads,
  Kubernetes, databases, Identity Center lifecycle, incident automation, and
  compliance certification.
- Azure Terraform/Bicep or an Azure Government deployment.
- Claude Code, codex-plugin-cc, worktrees, and additional orchestrators.

## Acceptance

The final repo must contain evidence-linked commits, architecture and network
diagrams, an IAM/guardrail summary, audit-review path, Azure Government
translation note with explicit non-implementation language, reviewer pushback,
and escalation/handoff instructions. Final merge and any cloud-validation phase
remain human decisions.
