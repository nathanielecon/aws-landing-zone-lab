# AWS Landing Zone Lab — agent notes

- Prefer the repo `.cursor/environment.json` image (PowerShell, Node 24, Terraform 1.15.5, AWS CLI, Docker) when present.
- **Landing Zone lab AWS apply** uses **GitHub OIDC → Terraform CI**
  (`.github/workflows/landing-zone-lab.yml`, role `project-a-lzlab-gha` from
  `platform/sandbox/landing-zone-lab/ci-bootstrap/`). Cloud Agents edit
  Terraform/PRs; they do **not** hold apply creds for this lab.
  `NoCredentials` in Cloud Agent pods is expected. Do **not** chase
  `CURSOR_AWS_ASSUME_IAM_ROLE_ARN` for the lab goal.
- After renaming this GitHub repository from `cloud` to `aws-landing-zone-lab`,
  an operator must re-apply `ci-bootstrap` so the IAM OIDC trust matches the
  new repository name (see `platform/sandbox/landing-zone-lab/ci-bootstrap/README.md`).
- The Ralphy smoke harness is a **sibling** repo:
  https://github.com/nathanielecon/ralphy-windows-harness — do not reintroduce
  sequential harness runners into this tree.

## Codex Cloud warm forever (orchestrator gate)

Warmth is **per Codex Environment** (~12h cache), not global. “Forever” means:
wire `.codex/` on each repo, register the Environment id locally, and
**re-warm before Cloud work** when the local stamp is stale.

### Before any Codex Cloud task

1. Run:

   ```powershell
   pwsh -NoLogo -NoProfile -File scripts/Invoke-CodexCloudWarm.ps1
   ```

2. Only then launch the real Cloud task (`codex cloud exec` or app/web).
3. If warm fails because the Environment is unwired: stop and follow
   [`.codex/README.md`](.codex/README.md) — do not open a new chat for that.

### Every new project that uses Codex Cloud

1. Copy `.codex/` from this template (trim tools if needed).
2. Push to the branch Cloud clones (prefer default branch).
3. Wire Codex → Environments (setup/maintenance, caching On).
4. Register:

   ```powershell
   pwsh -NoLogo -NoProfile -File scripts/Register-CodexCloudEnvironment.ps1 `
     -Repo '<owner>/<repo>' -EnvId '<ENV_ID>' -DefaultBranch main
   ```

5. Let the orchestrator warm (or run `Invoke-CodexCloudWarm.ps1 -Force` once).

Registry (machine-local, never commit):
`%LOCALAPPDATA%\codex-cloud-warm\environments.json`

### This repo’s Codex Cloud Environment (example fill)

| Item | Value |
| --- | --- |
| GitHub repo | `nathanielecon/aws-landing-zone-lab` (renamed from `cloud`) |
| Env id | `6a52b532673c8191b12b47eb0958625c` |
| Setup / maintenance | `.codex/cloud-setup.sh` / `.codex/cloud-maintenance.sh` |
| Caching | Post-setup cache On; avoid Reset unless rebuild needed |

Prompt paste blocks: [`.codex/PROMPT-SPEED-ADDENDUM.md`](.codex/PROMPT-SPEED-ADDENDUM.md).

Do **not** reinstall Node/pwsh/Terraform/AWS CLI at session start when those
tools are already on PATH from the warm Environment.
