# Break/Fix Log

## 2026-07-14 (CLEAN REJUDGE cloud-lab PASS)

- Clean no-leak multi-judge scores: **9.5 / 9.5 / 9.5** (avg **9.5**).
  Must-haves PASS. All five slices now have clean no-leak averages.

## 2026-07-14 (CLEAN REJUDGE cloud-lab fixer)

- Add `sandbox/landing-zone-lab/TEARDOWN.md` (cost drivers + destroy order +
  one-time bootstrap posture). Must-haves already passed; polish for clean
  multi-judge average.

## 2026-07-14 (CLEAN REJUDGE slice-4 PASS)

- Clean no-leak multi-judge scores: **9.6 / 9.5 / 9.5** (avg **9.53**).
  Must-haves PASS.

## 2026-07-14 (CLEAN REJUDGE slice-4 fixer r2)

- Repin execution/bundle hashes after HARNESS.md drift from slice-4 fixer.
- GRAPH_REPORT substitute disclaimer; orchestration closeout notes one-command
  CI path; execution-approval records contract 139 + spec 167 assertion counts
  alongside harness 101.

## 2026-07-14 (CLEAN REJUDGE slice-4 FIXER)

- Break: Slice 4 avg ~9.17 — README/overview delivery path orphaned claims /
  review / Azure readiness; `platform.svg` subtitle claimed “no live cloud
  execution” against separate lab APPLIED; fresh-clone CI one-command proof
  under-documented; A-007 index drift note needed historical clarity.
- Fix: Linked README + overview delivery navigation to claims-boundary,
  pushback-and-handoff, and Azure readiness (README → architecture → evidence
  → review); clarified `platform.svg` foundation repo-only vs separate
  single-account lab APPLIED caption (no multi-account cloud claim); pointed
  HARNESS.md + README at `Invoke-HarnessReleaseValidation.ps1` with
  `HARNESS_STRICT_PINS=1`; marked A-007 evidence-index drift as historical
  with `validation_digest` binding. No AWS; leave PR #15 alone; no
  execution-bundle repin.

## 2026-07-14 (CLEAN REJUDGE slice-3 PASS)

- Clean no-leak multi-judge scores: **9.8 / 10 / 10** (avg **9.93**).
  Must-haves PASS.

## 2026-07-14 (CLEAN REJUDGE slice-3 FIXER r11)

- Break: Stuck judges wanted a typed SG exception-shape matrix (CIDR / port /
  protocol) plus deeper IAM negatives beyond unprotected-branch / boundary /
  non-GitHub OIDC.
- Fix: Added fail-closed `sg_exception_attempts` (default empty/deny;
  extension-blocked) with `expect_failures` for non-empty CIDR, port, and
  protocol shapes (BC-NET-10–12); added IAM `workload_action_overrides` (rejects
  `*`) and `require_oidc_trust_conditions` with matching `expect_failures`
  (BC-IAM-03/04); mirrored empty/deny defaults into env compositions. No AWS;
  no execution-bundle repin.

## 2026-07-14 (CLEAN REJUDGE slice-3 FIXER r10)

- Break: Production env composition stayed thin while nonproduction already
  wired identity/network/audit module inputs; audit troubleshooting lacked
  BC-AUD-05 / org-trail enable stop conditions; integration assert did not lock
  env composition shared Log Archive token or `is_organization_trail = false`.
- Fix: Mirrored nonproduction’s deepened identity/network/audit module-input
  composition into `environments/production` (non-secret placeholders, shared
  `example-log-archive` token, `is_organization_trail = false`); mapped
  BC-AUD-05 into `audit-troubleshooting.md` stop conditions; extended
  `log_archive_arn_prefix_contract_alignment` to lock both env compositions.
  No AWS; no execution-bundle repin.

## 2026-07-14 (CLEAN REJUDGE slice-3 FIXER r9)

- Break: Audit org-trail stayed prose-only (no typed `is_organization_trail`);
  environment compositions were thin locals without wired identity/network/audit
  inputs; `docs/guardrails/iam.md` lacked a blocked-change-catalog cross-link.
- Fix: Added fail-closed `is_organization_trail` (default false) on the audit
  module + `rejects_organization_trail_enabled` expect_failures + BC-AUD-05;
  deepened `environments/nonproduction` with non-secret identity/network/audit
  module-input composition (shared Log Archive token, org-trail false); linked
  `iam.md` to the blocked-change catalog. No AWS; no execution-bundle repin.

## 2026-07-14 (CLEAN REJUDGE slice-3 FIXER r8)

- Break: SCP negatives existed as prose/fixtures but were not on an allowlisted
  validator path; BC-ORG-01 still cited only the H1 sample; integration Log
  Archive alignment lacked string-equality of the shared bucket name token
  across identity / network / audit.
- Fix: Extended `governance_semantics` to invoke
  `Assert-ScpAttachmentNegatives.ps1` fail-closed; catalog BC-ORG-01 cites
  `organization.tftest.hcl` + Assert script; integration assert requires
  identity `audit_bucket_name`, network `flow_logs_destination_arn`, and audit
  `archive_bucket_name` share `example-log-archive` (plus lab
  `module.audit.archive_bucket_*` wiring). Repinned execution-bundle approvals
  after `Invoke-ProjectAValidators.ps1` edit. No AWS.

## 2026-07-14 (CLEAN REJUDGE slice-3 FIXER r7)

- Break: Governance suite still prose-only (no executable SCP/root-attachment
  negative); integration composition checks did not assert shared Log Archive
  ARN/prefix alignment across identity/network/audit/env interfaces.
- Fix: Added `tests/governance/organization.tftest.hcl` (`expect_failures` for
  root and account-ID SCP attach), known-bad fixture +
  `Assert-ScpAttachmentNegatives.ps1` fail-closed offline assert; added
  `log_archive_arn_prefix_contract_alignment` to
  `tests/integration/root_composition.tftest.hcl`. Docs/tests only; no AWS
  apply; no execution-bundle repin.

## 2026-07-14 (CLEAN REJUDGE slice-3 FIXER r6)

- Break: Scores stuck ~9.0 — catalog lacked BC-AUD rows for disable log-file
  validation and disable archive versioning; audit troubleshooting did not map
  those IDs; identity/network/audit module READMEs lacked catalog + policy-fixture
  cross-links; `network.svg` ownership graph omitted Security Tooling.
- Fix: Added BC-AUD-03/04 to `blocked-change-catalog.md` and mapped them in
  `audit-troubleshooting.md`; cross-linked terraform identity/network/audit
  READMEs to the catalog and `tests/*/README.md` fixtures; labeled Security
  Tooling (trail/Config path) on `network.svg`. Docs-only; no AWS apply; no
  execution-bundle repin.

## 2026-07-14 (CLEAN REJUDGE slice-3 FIXER r5)

- Break: Scores short of 10/10 — `network.svg` lacked Network-account /
  default-deny SG / Flow Logs→Log Archive ownership labels; audit negatives
  omitted log-file validation and versioning disable paths; catalog missing
  BC-IAM rows for permissions boundary and non–GitHub OIDC trust; `audit-review.md`
  lacked Related cross-links.
- Fix: Updated `network.svg` labels for Network-account VPC ownership,
  default-deny SG, and Log Archive storage ownership on the Flow Logs edge;
  added fail-closed `enable_log_file_validation` /
  `enable_archive_versioning` with matching `expect_failures`; catalog
  BC-IAM-01/02; Related links on `audit-review.md`. Docs/tests/module
  validations only; no AWS apply; no execution-bundle repin.

## 2026-07-14 (CLEAN REJUDGE slice-3 FIXER r4)

- Break: Scores stuck ~9.2 — network failure ops doc thin on fail-closed
  ingress/egress flags and CIDR `expect_failures` (BC-NET-08/09) plus
  default-deny SG triage; IAM negatives still only unprotected-branch; ops
  docs lacked Related cross-links among catalog / network-failure /
  audit-troubleshooting.
- Fix: Expanded `network-failure-cases.md` with BC-NET-06/08/09 fail-closed
  table, default-deny SG triage, and CIDR failure guidance; added IAM
  `require_permissions_boundary` fail-closed + `expect_failures` for missing
  boundary and non–GitHub OIDC trust principal; Related links across the three
  ops docs. Docs/tests/module validations only; no AWS apply; no
  execution-bundle repin.

## 2026-07-14 (CLEAN REJUDGE slice-3 FIXER r3)

- Break: Scores still short of 10/10 network negative matrix — egress
  exceptions lacked a fail-closed mirror of ingress; happy-path SG assert was
  misnamed `rejects_public_security_group_ingress`; subnet-outside-VPC and
  overlapping CIDR cases were missing.
- Fix: Added default-deny `allow_unrestricted_egress` (extension-blocked) with
  `expect_failures`; renamed happy-path to `enforces_default_deny_security_group`;
  overlapping subnet validation on `private_subnets`; cross-var
  `check.private_subnets_inside_vpc` + matching negatives; catalog BC-NET-08/09.
  Docs/tests/module validations only; no AWS apply; no execution-bundle repin.

## 2026-07-14 (CLEAN REJUDGE slice-3 FIXER r2)

- Break: Scores stuck ~9.0 — misleading audit run
  `rejects_public_archive_acl_and_missing_kms` was a happy-path assert under a
  reject name; network negatives lacked CIDR/subnet-edge and ingress-exception
  `expect_failures`; integration notes did not tie `flow_logs_destination_arn`
  shape to Log Archive ownership.
- Fix: Renamed happy-path to `enforces_private_archive_acl_and_kms_encryption`;
  added real `expect_failures` for public-ACL attempt, missing CMK flag, empty
  KMS alias (plus existing short retention); fail-closed audit/network review
  inputs; network negatives for invalid/empty-AZ/public subnet CIDR edges and
  unrestricted ingress attempt; integration README ownership note for flow-log
  S3 ARN → Log Archive. Docs/tests/module validations only; no AWS apply; no
  execution-bundle repin.

## 2026-07-14 (CLEAN REJUDGE slice-3 FIXER)

- Break: Slice 3 must-haves passed; avg ~8.7 below bar on 9/10–10/10 gaps —
  weak Log Archive vs Security Tooling ownership language, no offline
  blocked-change catalog, thin cost/teardown interview sizing, and sparse
  network/audit negative coverage.
- Fix: Stated Log Archive owns protected storage and Network/Security Tooling
  boundaries in `logging.md` / `network.md`; added replayable
  `operations/blocked-change-catalog.md` (TGW/NFW/NAT/VPN/DX/RAM, Identity
  Center lifecycle, live audit deploy, root SCP, `close_on_deletion`, shared
  state keys, credential-shaped examples) linked from `validation.md` and
  `baseline-runbook.md`; expanded `cost-and-teardown.md` with order-of-magnitude
  drivers + teardown order without live billing/teardown claims; added offline
  negative cases in `tests/network` (bad flow-log ARN, default-deny SG) and
  `tests/audit` (short retention, public ACL block + KMS). Docs/tests only; no
  AWS apply; no execution-bundle repin.

## 2026-07-14 (CLEAN REJUDGE slice-2 PASS)

- Clean no-leak multi-judge scores: **9.6 / 9.5 / 9.5** (avg **9.53**).
  Must-haves PASS.

## 2026-07-14 (CLEAN REJUDGE slice-2 fixer r2)

- Break: Slice 2 must-haves passed; scores still below bar on 10/10 gaps —
  thin state-restore recovery detail, incomplete sibling cross-links, and no
  machine-checkable account/OU taxonomy assert.
- Fix: Exhaustive dual-approval state-restore runbook in `backend.md`
  (detect/freeze/platform+security approve/S3 version restore/lockfile
  verify/`terraform init`+`plan`/abort criteria; DynamoDB locking excluded);
  Related links across overview/accounts/backend/secrets/organizations;
  `terraform/organization/TAXONOMY.md` consistency checklist aligned to
  `accounts.md` + module locals.

## 2026-07-14 (CLEAN REJUDGE slice-2 fixer)

- Break: Clean judges failed Slice 2 must-haves — overview lab APPLIED language
  displaced foundation “not cloud validated / AWS-Azure not implemented”
  wording; accounts.md missing H1 typed-input owners + break-glass consequences.
- Fix: Silo foundation vs lab claims in `overview.md`; restore accounts.md H1
  table (emails/owners/initial role/break-glass) + blocked-change examples.

## 2026-07-14 (CLEAN REJUDGE slice-1 PASS)

- Clean no-leak multi-judge scores: **9.8 / 9.5 / 9.5** (avg **9.6**).
  Must-haves PASS. Orchestrator alone applied the advance rule.

## 2026-07-14 (CLEAN REJUDGE slice-1 fixer r9)

- Point `AGENTS.md` fast-validation at `Invoke-HarnessReleaseValidation.ps1`
  (CI-parity one-command gate + Verify-ProjectABundle).
- Expand contract property/mutation loop to N=25 distinct one-byte SHA256
  mutations with uniqueness + idempotent rewrite asserts.

## 2026-07-14 (CLEAN REJUDGE slice-1 fixer r8)

- Extended `Test-JsonSchema` in `Harness.Common.psm1` to evaluate top-level
  `allOf` entries with `if` / `then` / `else` (policy.schema.json:
  approval.required true → gate_id `H[0-5]` + receipt_path pattern; else nulls).
- Contract asserts: approval.required=true with null gate_id fails; 
  approval.required=false with string gate_id fails (mutated real task policies).
- Kept existing const/enum/type/pattern/nested behavior. Updated HARNESS.md
  trust note. Repinned execution-bundle approval hashes after owned edits.

## 2026-07-14 (CLEAN REJUDGE slice-1 fixer r7)

- Deepened `Test-JsonSchema` in `Harness.Common.psm1`: fail-closed const, enum,
  type, pattern, array minItems, one nested object required/additionalProperties,
  and light object-array item checks (e.g. validators). Not draft-2020 allOf/if-then.
- `Invoke-CodexAdapter.ps1`: call `Test-JsonSchema` when a smoke policy schema
  file exists; skip with a one-line comment when absent; accept Unix `codex`
  fixture alongside `fake-codex.cmd`.
- `Invoke-ProjectAValidators.ps1`: pass lifecycle ExcludedPaths into
  `Get-DiffFingerprint` so held task locks are not hashed (Linux FileShare.None).
- Contract asserts: wrong `schema_version` const, bad `id` pattern, validators
  item missing `timeout_seconds`; Unix PATH/codex shims for ralphy contracts.
- `Start-ProjectAHarness.ps1` / harness fixtures: Unix terraform/codex/ralphy
  resolve, PathSeparator PATH joins; DPAPI approval broker asserts skip off-Windows.
- `HARNESS.md` trust note updated for schema enforcement scope.
- Repinned execution-bundle approval hashes after owned bundle member edits.

## 2026-07-14 (CLEAN REJUDGE slice-1 fixer r6)

- `Invoke-HarnessReleaseValidation.ps1`: under `CI=1` / `HARNESS_STRICT_PINS=1`,
  Node major mismatch is now fail-closed with terraform/ralphy (was warn-only).
- Contract tests: symlink/reparse adversarial fixture under allowlisted path
  (skips if `ln -s`/`mklink` unavailable); ExcludedPaths algebra naming for
  `.harness/runtime/rogue.txt` stay-vs-exclude.
- Policy schema fail-closed: `Test-JsonSchema` in `Harness.Common.psm1`
  (required + `additionalProperties:false`); adapter validates task policy
  after read; contract assert undeclared field fails the helper.
- `HARNESS_CONTRACT_ONLY` on-disk approval verify skipped (invasive: fixtures
  inject synthetic `HARNESS_BUNDLE_HASH` while writing real pin files).
- Repinned execution-bundle approval hashes after `Harness.Common.psm1` /
  `Invoke-ProjectAAdapter.ps1` / `HARNESS.md` edits.

## 2026-07-14 (CLEAN REJUDGE slice-1 fixer r5)

- Commit CI wire-up of `Invoke-HarnessReleaseValidation.ps1` + `HARNESS_STRICT_PINS`
  in `harness-contracts.yml` (was previously only logged).
- Reject hard links in `Get-CanonicalDiffRecord` (LinkType / nlink / fsutil) with
  contract fixture; add operator error-class → recovery catalog in `HARNESS.md`.
- Repinned execution-bundle approval hashes after `Harness.Common.psm1` /
  `HARNESS.md` edits.

## 2026-07-14 (CLEAN REJUDGE slice-1 fixer r4)

- Wire Windows CI `harness-contracts.yml` through
  `scripts/Invoke-HarnessReleaseValidation.ps1` with `HARNESS_STRICT_PINS=1`
  so fresh-machine release validation + `Verify-ProjectABundle` run on every
  PR/push (same path as local one-command gate).

## 2026-07-14 (CLEAN REJUDGE slice-1 fixer r3)

- Property/mutation expansion in `tests/Run-ContractTests.ps1`: N=5 one-byte
  fixture SHA256 mutations + idempotent rewrite; `execution_bundle_sha256` hex
  flip fails `Verify-ProjectABundle`; policy field mutation fails `Test-Json`
  schema (or ConvertFrom-Json fallback).
- Persistent-boundary fixtures in `tests/Run-ProjectAHarnessTests.ps1`: named
  asserts for lock ownership, stop sentinel (dirty tree + stop.flag), approval
  boundary (receipt hash flip → binding mismatch), resume dirty-set mismatch via
  `Get-CanonicalDiffRecord`.
- `Invoke-HarnessReleaseValidation.ps1`: `HARNESS_STRICT_PINS=1` or `CI=1`
  fail-closed on terraform/ralphy pin mismatch (node warn-only). Documented in
  `project-a/HARNESS.md`. Execution-bundle members edited → approval pins
  repinned.

## 2026-07-14 (CLEAN REJUDGE slice-1 fixer r2)

- `Open-ExclusiveLock` now uses `FileShare.None` so a second open is rejected
  on Linux and Windows (true exclusive lock).
- `Invoke-HarnessReleaseValidation.ps1` runs `Verify-ProjectABundle.ps1` after
  tool checks and fails closed on non-zero; in CI, terraform major.minor.patch
  and ralphy expected-version string are fail-closed (node major mismatch is
  warning-only unless both terraform and ralphy also mismatch).
- Harness fixture: second `Open-ExclusiveLock` on the adapter lock path fails
  closed; `$env:TEMP` defaults via `GetTempPath()` when unset on Linux.
- Execution-bundle member change → approval pins repinned. Release/verify
  scripts remain outside execution-hash members.

## 2026-07-14 (CLEAN REJUDGE slice-1 fixer)


- Added `scripts/Invoke-HarnessReleaseValidation.ps1` (tool-version checks +
  `CI=1` / `HARNESS_CONTRACT_ONLY=1` + contract/spec/harness suites).
- Documented one-command release validation + pin verify in
  `project-a/HARNESS.md` (execution-bundle member; approval pins repinned).
- Added `scripts/Verify-ProjectABundle.ps1` (recompute vs bundle/execution
  approval pins; optional approval-path overrides for fail-closed tests).
- Thin contract tests: one-byte digest mutation + flipped pin fails closed;
  `Invoke-ProcessWithTimeout` kills child sleep. New scripts intentionally
  omitted from execution-hash members.

## 2026-07-14 (PROCESS MISHAP — advance-threshold leak into judge prompts)

- Break: Orchestrator included advance-threshold language (`9.5`, `≥9.5`,
  “advance bar”, `merge_ready` framing tied to exit) in judge prompts for the
  earlier cloud-lab rejudge on this turn. Historical per-slice 9.5+ scores
  from contaminated prompts are **not** process-audit clean.
- Fix: Adopt hard anti-leak prompt contract in
  `project-a/docs/architecture/orchestration.md` (banned phrases; required
  return shape). Judges score the frozen rubric only; **orchestrator alone**
  compares averages / must-haves to the advance rule. Re-run clean Grok
  multi-judge rounds for slices 1–4 + cloud lab with fresh agents (no
  `resume`, no parent transcript, no threshold tokens in worker prompts).

## 2026-07-14 (PROCESS MISHAP — human-wait instead of early bottleneck / OIDC)

- Break: Orchestrator waited on human/`aws login` / Cursor assume-role
  injection when Cloud Agent pods returned `NoCredentials`, delaying the
  single-account lab instead of dispatching an early bottleneck agent and
  pivoting to the GitHub OIDC CI control plane.
- Fix (already on `main` via PR `#14` / AGENTS.md): Lab apply is
  **GitHub OIDC → `project-a-lzlab-gha`** (`ci-bootstrap/`, workflow
  `landing-zone-lab.yml`). Do not chase `CURSOR_AWS_ASSUME_IAM_ROLE_ARN` for
  this lab. `NoCredentials` in Cloud Agent pods is expected. Recorded so
  later orchestrators do not repeat the human-wait pattern.

## 2026-07-14 (CLEAN REJUDGE — no transcript leak)

- Orchestrator turn loaded durable artifacts only; spawned 3 independent Grok
  4.5 judges with fresh short contracts (no implementing transcript).
- **Contaminated for process-audit:** Round 1/2 scores below used prompts that
  leaked advance-threshold language; superseded by the clean no-leak rejudge
  plan on this branch.
- Round 1 scores: **9.3 / 9.2 / 9.2** (avg **9.23**). Must-haves PASS.
  Gaps: orchestration blanket `cloud_validated: false` vs lab APPLIED;
  frozen rubric still preferred dead role `GitHubActionsLZLab`;
  `EVIDENCE.capture.md` still recorded that role’s `NoSuchEntity`;
  “historically green” validate hearsay; operator README framed Cursor
  assume-role as apply path.
- Fixer: carve-out in `orchestration.md`; re-freeze rubric to
  `project-a-lzlab-gha` / `ci-bootstrap/`; strip stale capture error;
  add `OFFLINE_VALIDATE.md` with fresh local validate Success on lab +
  modules; retone `operator/README.md`.
- Round 2 scores: **9.5 / 9.5 / 9.5** (avg **9.5**). Must-haves PASS.
  `merge_ready: yes` ×3. Follow-up: carve lab vs harness in
  `project-a/evidence-index.md` opener (judge R2 gap).
- Closeout polish: derive `project-a-lzlab-gha` Role.[Name,Arn] from STS in
  `EVIDENCE.capture.md`; add organization module to `OFFLINE_VALIDATE.md`;
  retone `apply-lab.sh` / `aws-env.sh` so GHA OIDC is the only scored path
  (no Cursor assume-role auto-select). Landed on `main` via PR `#16`.

## 2026-07-14 (LZ lab slice exit ≥9.5)

- Judge #1 post-apply: **8.7** (doc tense drift). Fixer retensed → Judge #2:
  **9.5**, must-haves pass, merge_ready. Windows CI + Terraform plan green on
  PR `#14`. Lesson reinforced: when stuck on AWS control-plane/creds, dispatch
  a bottleneck agent early and prefer GitHub OIDC CI over Cloud Agent login.
  Squash-merge PR `#14` to `main` for resume-ready packet.

## 2026-07-14 (FIXER — judge 8.7 → doc retense for APPLIED)

- Break: Judge score **8.7** — must-haves pass, but accounts/overview/
  pushback-and-handoff still said `PENDING_APPLY` / READY TO APPLY / “not yet
  cloud-validated” after EVIDENCE.md was already `APPLIED`.
- Fix: Retensed those three docs to match GHA OIDC apply run
  [29366105164](https://github.com/nathanielecon/cloud/actions/runs/29366105164)
  (role `project-a-lzlab-gha`). Kept honest: multi-account Orgs still **not**
  cloud-validated; single-account identity+network+audit **is**. Noted
  historical offline `terraform validate` green / CI plan validates lab.
  Added orchestration lesson: dispatch bottleneck early on credentials/
  control-plane mismatch; prefer GHA OIDC. Did **not** recreate
  `github-oidc/` / `GitHubActionsLZLab` or chase Cursor AWS.

## 2026-07-14 (LZ lab APPLIED via GitHub OIDC CI)

- Status: Apply **DONE** on run
  [29366105164](https://github.com/nathanielecon/cloud/actions/runs/29366105164)
  (`cursor/single-account-lz-lab-b6ce` @ `8434d15`). Caller
  `assumed-role/project-a-lzlab-gha`. Live: VPC+flow logs, CloudTrail logging,
  Config, archive SSE-KMS, workload role, operator, tfstate. Stale aws-proof
  Config recorder cleared (account limit=1). Evidence/claims updated from
  `PENDING_APPLY` → `APPLIED` / cloud-validated. Control plane remains GHA
  OIDC (`ci-bootstrap/`); do not chase Cursor AWS or recreate
  `github-oidc/` / `GitHubActionsLZLab`.

## 2026-07-14 (LZ lab → GitHub OIDC CI)

- Break: Cloud Agent AWS apply blocked on individual plan (no team External ID
  for `CURSOR_AWS_ASSUME_IAM_ROLE_ARN`); wrong control plane for the lab goal.
- Fix: Switch primary path to **GitHub OIDC → Terraform CI** —
  `github-oidc/` (provider + `GitHubActionsLZLab`), workflow
  `.github/workflows/landing-zone-lab.yml` (plan on PR, apply on main /
  `workflow_dispatch` + environment `landing-zone-lab`), evidence render from
  CI. Stop chasing Cursor assume-role for this lab. One-off local `aws login`
  remains only for bootstrap.

## 2026-07-14 (LZ lab — AWS role ready, this agent not injected)

- Break: Live apply blocked on this Cloud Agent run (`bc-ef4b7237-…`). Exact
  errors after role secret was configured on the dashboard:
  - `aws sts get-caller-identity` → `NoCredentials: Unable to locate credentials`
  - `aws sts get-caller-identity --profile cursor-cloud-agent` →
    `The config profile (cursor-cloud-agent) could not be found`
  - Env has neither `AWS_PROFILE=cursor-cloud-agent` nor `AWS_CONFIG_FILE`
    (Cursor IAM-role injection not present on this pre-secret pod).
- Fix (partial, repo): Merged `main` (`bf62431` role guidance + `cloud-harness`)
  into `cursor/single-account-lz-lab-b6ce`; updated `apply-lab.sh` / operator to
  use CursorCloudAgent profile and drop long-lived access keys. **Requires
  restart or new Cloud Agent on this branch/main so Cursor injects the role.**
- Fix (follow-up): Added shared `aws-env.sh` fail-fast bootstrap sourced by
  `apply-lab.sh` and `capture-evidence.sh` so a restarted agent with role
  injection can finish immediately, and old pods fail with an explicit restart
  message instead of opaque `NoCredentials`.

## 2026-07-14 (FIXER — judge 5.2 claims tense)

- Break: Judge score **5.2** — premature "cloud-validated" wording treated the
  single-account Landing Zone lab identity+network+audit composition as a
  completed fact while live AWS apply remains `PENDING_APPLY` / not done.
- Fix: Retensed claims across README, claims-boundary, accounts, overview
  (account `<AWS_ACCOUNT_ID>` explicit), landing-zone-lab README/EVIDENCE, and
  pushback-and-handoff to **READY TO APPLY** / `PENDING_APPLY`. Kept the honest
  resume bullet as **target / after-exit wording**, not current proof. Clarified
  AWS credentials are still required. Preserved banned-claim list and Orgs
  interface-only language. No invented CLI evidence; no multi-account apply
  claims; no LocalStack.

## 2026-07-14 (single-account Landing Zone lab)

- Operator plan: with one AWS account, run collapsed Landing Zone lab (identity +
  network + audit live; Orgs as interface only) and judge to ≥9.5 on
  single-account lab rubrics — not fake multi-account claims.
  Action: Added `project-a/sandbox/landing-zone-lab/{operator,state-bootstrap,lab}`,
  frozen `harness/rubrics/slice-cloud-lab-single-account.md`, extended audit
  module for VPC Flow Logs archive permissions, parameterized identity
  `oidc_provider_arn`, documented Orgs non-apply in `ORGS_INTERFACE.md`, updated
  claims/README/accounts/overview. Live apply requires AWS credentials in the
  executing environment (cloud agent starts `aws login --remote` waiter; see
  `/opt/cursor/artifacts/aws-login/`).

## 2026-07-13 (sandbox AWS proof)

- Operator override: live AWS apply requested despite repo-only stop conditions.
  Action: Installed AWS CLI; authenticated account `<AWS_ACCOUNT_ID>`; created separate root `project-a/sandbox/aws-proof` reusing `terraform/audit`; applied in `us-east-1` (13 resources). CloudTrail `project-a-sandbox-trail` IsLogging=true; archive bucket KMS-encrypted + versioned + public access blocked. Evidence: `project-a/sandbox/aws-proof/EVIDENCE.md`. Does not rewrite A-001…A-007 repo-only harness claims.

## 2026-07-13

- Closeout: PR `#13` squash-merged to `main` as `1564c6b` after Windows CI green on `5fd7d0b` and slice advances (1: 9.6, 2: 9.6, 3: 9.5, 4: 9.6).
  Process postmortem: recorded on-the-fly judge-loop deviations in `project-a/docs/architecture/orchestration.md` § “Delivery closeout — recorded process deviations (2026-07-13)” — mid-stream rubric restore, CI-first then slice accounting, frequent single-judge rejudges, cloud-worker cherry-picks, A-007 evidence hash drift honesty, and repo-only confidence boundary. Technical break/fix rows below remain the machine-facing history.

- Break: Slice 3 judge score 9.2 < 9.5 after must-haves passed (missing platform validator-ID / fail-closed docs and weak integration composition assertions).
  Fix: Documented A-003…A-006 representative validator IDs plus `UNKNOWN_VALIDATOR` fail-closed behavior in `policy-validation.md`; strengthened `root_composition.tftest.hcl` with identity/network/audit module-entry and environment locals/outputs contract asserts (offline `fileexists`/content checks) and clarified the composition contract in `tests/integration/README.md`. Docs/tests only; no harness hot-path or execution-bundle repin.

- Break: Slice 2/3 documentation and architecture consistency gates (network extension-point alignment, audit module deep links, bootstrap state-key ownership, H1 blocked-change sample).
  Fix: Docs/terraform README-only updates on `cursor/slice-2-3-32fe` — declared TGW/NFW/NAT/VPN/DX/RAM as extension points in `network-failure-cases.md`; linked `audit-review.md` / `audit-troubleshooting.md` to `terraform/audit/README.md`; clarified organization CloudTrail / org-trail as interface semantics; thickened bootstrap state-key isolation; added H1 blocked-change sample under Organizations guardrails. No harness hot-path or execution-bundle changes; no approval repin.

- Break: Slice 1/4 quality scores were below the 9.5 advance bar after CI green.
  Fix: Documented `HARNESS_CONTRACT_ONLY=1` as test/CI-only; launchers explicitly reject `--parallel` / `--worktree(s)` / `--sandbox` / `--branch-per-task` with harness regressions; overview/README deep-link rubrics, evidence-index, diagrams, and Graphify-as-non-substitute; noted A-007 `evidence-index.md` `content_sha256` drift while `validation_digest` remains authoritative. Repinned execution approvals after owned bundle members changed.

- Break: PR `#13` Windows contract suite failed on `runtime task state accepts valid ISO 8601 timestamps with offsets and fractional seconds`.
  Fix: Updated `scripts/Harness.Common.psm1` so `Read-JsonFile` uses `ConvertFrom-Json -DateKind String`, preserving contract timestamps as strings across PowerShell environments; repinned execution approval hashes.

- Break: PR `#13` Windows contract suite then failed on `default forbidden-operations policy allows clean text artifacts`.
  Fix: Narrowed `scripts/Invoke-ProjectAValidators.ps1` forbidden-operation scanning to skip harness control files under `.harness/`, `harness/`, and `project-a/harness/`; repinned validator and execution approval hashes.

- Break: GitHub Actions still reported failure after branch fixes were pushed.
  Fix: Reproduced the PR merge ref locally by checking out `refs/pull/13/merge` into an isolated worktree and reran `tests/Run-ProjectAHarnessTests.ps1` under CI-equivalent environment variables. The merge-ref reproduction passed locally, so the remaining issue is currently isolated to GitHub runner behavior or stale rerun state rather than an obvious branch-only regression.

- Break: The rerun of the GitHub workflow continued to report the same forbidden-operations assertion.
  Fix: Reproduced the exact PR merge ref again, ran a direct standalone forbidden-operations validator repro successfully, and then ran the full `tests/Run-ProjectAHarnessTests.ps1` suite two more times on the merge commit under CI-equivalent environment variables; both passes point to runner-side flakiness or stale execution rather than a reproducible merge-ref code failure.

- Break: Requested switch to GitHub MCP.
  Fix: Inspected the live MCP catalog. No GitHub MCP server is currently provisioned in this session, so GitHub-side work remains on the authenticated `gh` CLI path until a GitHub MCP resource is added.

- Break: GitHub MCP was requested as a required resource.
  Fix: Provisioned global Cursor MCP config at `C:\Users\natha\.cursor\mcp.json` pointing at GitHub's hosted MCP endpoint and verified that Cursor now exposes the server as `user-github` with `serverStatus: ready`.

- Break: Fresh CI logs showed the real Windows failure was `credential_boundary`, not `forbidden_operations`; GitHub's Windows runner exposed `AZURE_DEVOPS_CACHE_DIR` and `AZURE_EXTENSION_DIR`, which the validator was treating as cloud credential leaks.
  Fix: Added those two runner-local cache/extension variables to the `credential_boundary` allowlist in `scripts/Invoke-ProjectAValidators.ps1`, added a regression fixture in `tests/Run-ProjectAHarnessTests.ps1`, and verified the current working tree locally with harness `94 assertions`, spec `167 assertions`, contract `49 assertions`, plus matching execution/validator approval hashes.

- Break: PR `#13` Windows contract suite failed on `completion reconciliation rechecks forbidden isolation directories created after task execution` (run `29263112226` / job `86861294954`, and again on `7780512` / run `29271355206`).
  Root cause: `.github/workflows/harness-contracts.yml` never installed Terraform. `Start-ProjectAHarness.ps1` exits `12` with `Terraform 1.15.5 is missing` before Fake-Ralphy runs, so `HARNESS_FAKE_FORBIDDEN_DIR_POSTRUN` is never planted and the assertion's Output match fails. Local machines with Terraform could still pass, which misled the earlier HARNESS_ROOT-only diagnosis.
  Fix: (1) Install pinned Terraform `1.15.5` in the Windows contract workflow; (2) plant a `terraform.cmd` version stub first on PATH inside `Invoke-ProjectAHarnessFixture` and accept `terraform.cmd` in the launcher preflight when `terraform.exe` is absent, so the fixture is hermetic; (3) keep Fake-Ralphy fail-closed when `HARNESS_ROOT` is unset; (4) include ExitCode/Output in the completion-forbidden assertion message; (5) repin `execution_bundle_sha256` after the owned bundle members change.
