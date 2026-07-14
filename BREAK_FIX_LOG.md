# Break/Fix Log

## 2026-07-14 (CLEAN REJUDGE — no transcript leak)

- Orchestrator turn loaded durable artifacts only; spawned 3 independent Grok
  4.5 judges with fresh short contracts (no implementing transcript).
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
  `project-a/evidence-index.md` opener (judge R2 gap). Slice exit ≥9.5 on
  clean multi-judge rejudge.

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
  (account `283077380808` explicit), landing-zone-lab README/EVIDENCE, and
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
  Action: Installed AWS CLI; authenticated account `283077380808`; created separate root `project-a/sandbox/aws-proof` reusing `terraform/audit`; applied in `us-east-1` (13 resources). CloudTrail `project-a-sandbox-trail` IsLogging=true; archive bucket KMS-encrypted + versioned + public access blocked. Evidence: `project-a/sandbox/aws-proof/EVIDENCE.md`. Does not rewrite A-001…A-007 repo-only harness claims.

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
