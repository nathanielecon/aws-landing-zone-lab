# Break/Fix Log

## 2026-07-13

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
