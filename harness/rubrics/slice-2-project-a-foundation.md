# Slice 2 rubric — Project A foundation

Status: frozen  
Scope: Project A foundation surfaces owned primarily by tasks `A-001` and
`A-002`, including:

- `project-a/docs/architecture/overview.md`
- `project-a/docs/architecture/accounts.md`
- `project-a/docs/decisions/backend.md`
- `project-a/docs/decisions/secrets.md`
- `project-a/docs/guardrails/organizations.md`
- `project-a/terraform/bootstrap/**`
- `project-a/terraform/organization/**`
- `project-a/terraform/examples/foundation/**`
- `project-a/examples/backend/**`
- related task policies `project-a/harness/tasks/A-001.json`,
  `A-002.json`

Do not invent Control Tower, AFT, or live account-creation flows. Judges score
only against this rubric. Advance only at **≥ 9.5/10** with all must-haves
passing.

## must-have to pass slice

- Architecture overview states repo-only scope: not cloud validated; AWS/Azure
  not implemented; Azure Government out of implementation scope.
- Account/OU taxonomy matches the locked plan: Management plus Security
  Tooling, Log Archive, Network, Shared Services, Non-production Workload, and
  Production Workload under Security, Infrastructure, and Workloads OUs.
- `accounts.md` preserves typed-input / H1 approval language for emails,
  owners, initial roles, and break-glass consequences; Management stays outside
  the member-account loop.
- Backend decision documents separately bootstrapped, versioned, encrypted S3
  state with `use_lockfile = true` and explicitly excludes DynamoDB locking.
- Secrets decision and examples contain no credentials; backend examples are
  non-secret placeholders only.
- Bootstrap and organization Terraform modules validate offline
  (`terraform fmt -check`, `init -backend=false`, `validate`) without AWS API
  calls.
- Organization module exposes reviewed account-creation interfaces without
  authorizing apply or live creation; SCP attachment is guardrail-oriented.
- Naming/tagging contract is explicit (`Project`, `Environment`, `Owner`,
  `CostCenter`, `ManagedBy=terraform`, `DataClassification`).
- Human gates `H0`/`H1` remain required in task policy for A-001/A-002
  post-validation pre-commit.
- Evidence records for foundation tasks set `mode: repo_only` and
  `cloud_validated` / `aws_implemented` / `azure_implemented` false.

## needed for 9/10+

- Cross-links among overview, accounts, backend, secrets, and Organizations
  guardrails resolve and stay consistent.
- Organization semantics validator and docs distinguish Organizations/SCPs
  (guardrails) from IAM roles (permissions) and permission boundaries.
- Bootstrap README and examples separate nonproduction vs production state keys
  and ownership.
- Negative or semantic checks reject unsafe defaults (shared state keys,
  committed credentials, missing required tags).
- Foundation docs read as decision records a skeptical reviewer can audit,
  not marketing copy.

## needed for 10/10

- Exhaustive recovery runbook detail for state restore with dual-approval
  language that matches operator pressure tests.
- Explicit blocked-change examples for taxonomy/email/role mutations that
  would invalidate H1.
- Machine-checkable consistency between taxonomy tables, Terraform variables,
  and guardrail docs with zero drift.
- Portfolio-safe wording that never upgrades foundation design into production
  ownership claims.

## nice-to-have

- Additional Mermaid or SVG diagrams for OU topology beyond the later platform
  diagram.
- Sample SCP JSON fixtures beyond the organizations interface.
- Cost estimates for Organizations overhead (not required for slice exit).
