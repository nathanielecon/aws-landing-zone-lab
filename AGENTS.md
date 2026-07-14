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

- Prefer the repo `.cursor/environment.json` image (PowerShell, Node 24, Terraform 1.15.5, AWS CLI, Docker).
- Do not reinstall those tools with `apt-get` / `npm install` at session start; they are already in the image.
- AWS auth for Cloud Agents uses the dashboard secret `CURSOR_AWS_ASSUME_IAM_ROLE_ARN` → `arn:aws:iam::283077380808:role/CursorCloudAgent`. Use the injected `cursor-cloud-agent` AWS profile / default credential chain. Do **not** run `aws login`, do **not** ask for `/opt/cursor/artifacts/aws-login/code.txt`, and do not request long-lived access keys.
- Keep harness runs sequential and repo-only unless the user explicitly asks for live cloud validation.
- Fast validation order when touching harness code:
  1. `pwsh -NoLogo -NoProfile -File tests/Run-ProjectAHarnessTests.ps1`
  2. `pwsh -NoLogo -NoProfile -File tests/Run-ProjectASpecTests.ps1`
  3. `pwsh -NoLogo -NoProfile -File tests/Run-ContractTests.ps1`
- After editing `scripts/Invoke-ProjectAValidators.ps1`, `scripts/Harness.Common.psm1`, or `scripts/Start-ProjectAHarness.ps1`, recompute execution hashes and repin Project A approval JSON files before claiming the harness is green.
