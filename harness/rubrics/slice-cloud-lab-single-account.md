# Slice — single-account Landing Zone cloud lab

Status: frozen  
Scope: collapsed live lab under `project-a/sandbox/landing-zone-lab/` composing
identity + private network + audit in one commercial AWS account, plus honest
claims/docs/evidence packaging. Organization module remains design-interface
only (no member-account apply).

This rubric is **not** a multi-account Orgs must-have. Scoring fake
multi-account theater as success is a fail.

## must-have to pass slice

- Single-account mode is explicit in README, claims-boundary,
  `docs/architecture/accounts.md`, `docs/architecture/overview.md`, and lab
  evidence; account `<AWS_ACCOUNT_ID>` and region `us-east-1` are documented.
- Non-root apply identity: GitHub OIDC role `project-a-lzlab-gha` from
  `sandbox/landing-zone-lab/ci-bootstrap/` (preferred CI path; workflow
  `.github/workflows/landing-zone-lab.yml`) and/or lab `operator/` IAM;
  evidence shows caller is not account root. Do **not** recreate
  `github-oidc/` / `GitHubActionsLZLab`. Cloud Agent
  `CURSOR_AWS_ASSUME_IAM_ROLE_ARN` is **not** required for this slice.
- Live Terraform lab root composes identity + network + audit in one account
  with remote state bootstrap (S3 + KMS); no cross-account providers. CI path
  documented in `.github/workflows/landing-zone-lab.yml`.
- AWS CLI evidence confirms: CloudTrail logging to KMS-encrypted archive,
  private VPC with flow logs targeting the archive, and workload identity
  role/OIDC (or equivalent documented identity resources) present.
- Organization module is validated as interface only; evidence states member
  accounts were **not** created (single-account constraint). No claim of
  multi-account cloud validation.
- GitHub docs/claims/BREAK_FIX updated with the honest resume bullet; banned
  production/enterprise multi-account fully-validated wording is absent.
- Judge/nixer/fixer loop uses Grok 4.5 or a less capable allowed model — not
  Composer — for council workers on this slice.

## needed for 9/10+

- Evidence file includes concrete CLI outputs or structured command results
  (caller identity, trail status, bucket encryption, VPC/flow-log ids, role).
- Reconciliation note for prior `aws-proof` audit sandbox (coexist, import, or
  teardown path) is written without erasing prior audit evidence.
- Lab rubrics and orchestration notes document one-account exit criteria and
  the stretch path if unique account emails appear later.
- Offline `terraform validate` remains green for modules and lab roots
  (`init -backend=false` where appropriate).

## needed for 10/10

- Independent second-pass judge ≥9.5 confirming must-haves without score
  inflation from the implementing conversation alone.
- Operator / CI posture is clean: root used at most for one-time
  `github-oidc` + `state-bootstrap`; subsequent plan/apply evidence is
  GitHub OIDC (non-root).
- Claims packet could be pasted onto a resume and survive skeptical senior
  review without hedging contradictions.

## nice-to-have

- Native S3 lockfile backend actively used by the lab root (not local-only).
- Automated teardown runbook with cost notes.
- Future assume-role provider stubs commented as stretch-only.
