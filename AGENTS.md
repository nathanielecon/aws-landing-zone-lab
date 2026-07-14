# Harness rules

- Run only the approved manifest whose `PLAN.md` SHA-256 matches
  `harness/plan-approval.json`.
- Use one sequential Ralphy process. Never add parallel, sandbox, worktree,
  branch-per-task, browser, PR, or automatic merge flags.
- Codex must not commit. `scripts/Invoke-CodexAdapter.ps1` is the only task
  commit authority.
- Never widen Codex beyond `workspace-write`.
- Runtime state and verbose logs must remain untracked and sanitized.
- Do not clean, reset, stash, or overwrite unexplained user changes.

## Cursor Cloud specific instructions

- Prefer the repo `.cursor/environment.json` image (`cloud-harness`: PowerShell,
  Node 24, Terraform 1.15.5, AWS CLI, Docker). Full orch contract:
  [`.cursor/README.md`](.cursor/README.md).
- **Start-commit:** Cloud Agents / env builds for this repo must use `main` at
  `6a8be57` or later so `.cursor/environment.json` is present as start-commit
  config.
- **Resolution order:** repo `.cursor/environment.json` → personal → team.
  Prefer the repo env; do not let personal/team wizard snapshots silently skip
  this Dockerfile for routine runs.
- **Snapshots:** after the first successful env build, save/reuse a VM snapshot
  in Cursor Cloud Agents Environments. Do not force rebuild every agent unless
  `Dockerfile` / `environment.json` changed (or the snapshot is unusable).
- **Startup path:** `install` is version-check only
  (`.cursor/verify-toolchain.ps1`). Do not inject `apt-get` / cold `npm`
  installs into orch startup. `start` only brings up Docker.
- **Multi-repo:** if orch launches multi-repo agents, include
  `nathanielecon/cloud` in the environment repo group so `cloud-harness` is
  reused.
- **Secrets:** AWS keys/roles and similar stay in Cursor Cloud Agents Secrets /
  IAM role config — never bake into the Dockerfile.
- Do not reinstall those tools with `apt-get` / `npm install` at session start;
  they are already in the image.
- Keep harness runs sequential and repo-only unless the user explicitly asks for
  live cloud validation.
- Fast validation order when touching harness code:
  1. `pwsh -NoLogo -NoProfile -File tests/Run-ProjectAHarnessTests.ps1`
  2. `pwsh -NoLogo -NoProfile -File tests/Run-ProjectASpecTests.ps1`
  3. `pwsh -NoLogo -NoProfile -File tests/Run-ContractTests.ps1`
- After editing `scripts/Invoke-ProjectAValidators.ps1`, `scripts/Harness.Common.psm1`, or `scripts/Start-ProjectAHarness.ps1`, recompute execution hashes and repin Project A approval JSON files before claiming the harness is green.
