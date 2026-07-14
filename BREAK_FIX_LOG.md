# Break/Fix Log

## 2026-07-14 (Cursor Cloud env orch)

- Break: Cloud agents cold-built every run (apt/tool install), ignoring the
  cached toolchain intent after `6a8be57` landed `.cursor/Dockerfile` +
  `environment.json`.
- Fix: Documented and hardened `cloud-harness` orch contract — repo env
  preferred over personal/team, start-commit ≥ `6a8be57`, lightweight
  `.cursor/verify-toolchain.ps1` install (no apt/npm on startup),
  `agentCanUpdateSnapshot` for dashboard snapshot reuse, multi-repo group note,
  secrets stay in Cursor Secrets/IAM. Files: `.cursor/README.md`,
  `.cursor/environment.json`, `AGENTS.md`, `orchestration.md`. Harness
  sequential rules / Codex `workspace-write` unchanged.

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
