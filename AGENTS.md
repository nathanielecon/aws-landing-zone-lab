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

## Standing addendum (orchestrator + cloud workers)

Orchestrator → Codex Cloud specialty tooling lives in a separate repo:

**https://github.com/nathanielecon/cloud-tools**

Clone or submodule that repo for Dispatch / Runtime Secret helpers. Do not
treat this `cloud` repo as the canonical home of those scripts.

### 1. Orchestrator — bottleneck dispatch

If work stalls on auth, CI, cloud credentials, dashboards, or any tool the
current agent cannot reach, the **lead orchestrator must dispatch a bottleneck
agent** **in this session**. Do not leave the user to open a new chat.

| Worker | When | How (primary) |
| --- | --- | --- |
| **Cursor Cloud Orchestrator** | Fan out Codex Cloud workers on Codex/ChatGPT sub | Cursor UI + Runtime Secret `CODEX_AUTH_JSON_GZB64` via **cloud-tools** (`Publish-CodexAuthRuntimeSecret.ps1` + `ORCHESTRATOR_UI_PROMPT.md`) |
| **Cursor Cloud worker** | Long repo/CI edits; must not use Codex auth | Cursor UI Cloud Agent without Dispatch |
| **Codex Cloud worker** | Dispatched by Orchestrator | **cloud-tools** `Dispatch-CodexCloudWorker.ps1` |
| **Local Codex / Image2** | Portfolio visuals | GenerateImage or local `codex` (ChatGPT login) |
| **GitHub Actions / local AWS** | Live cloud plan/apply | GitOps below |

**One** Orchestrator may bootstrap/refresh `CODEX_AUTH_JSON_GZB64` at a time.
Parallel Codex Cloud sandboxes = allowed. Parallel Cursor agents each
refreshing the same ChatGPT auth = forbidden.

### 2. Auth planes (do not conflate)

| Plane | Auth | Role |
| --- | --- | --- |
| Laptop | ChatGPT `~/.codex/auth.json` | Publish Runtime Secret (cloud-tools); Image2 |
| Cursor Cloud Orchestrator | Cursor + Runtime Secret `CODEX_AUTH_JSON_GZB64` | Dispatch Codex Cloud (cloud-tools) |
| Cursor Cloud worker | Cursor only | Repo edits; no Dispatch |
| Codex Cloud task | ChatGPT/Codex sub that submitted the task | Inner workers |

Setup details and scripts: **nathanielecon/cloud-tools** README.

- Never commit tokens; never print them.
- Do **not** use `OPENAI_API_KEY` for Codex Cloud (Platform ≠ Codex sub).
- Image2 stays local — never in Cursor or Codex Cloud pods.

### 3. Cursor Cloud specific instructions

- Prefer the repo `.cursor/environment.json` image (PowerShell, Node 24,
  Terraform 1.15.5, AWS CLI, Docker, **Codex CLI**). Do not reinstall those
  tools at session start unless missing.
- **Landing Zone lab AWS apply** uses **GitHub OIDC → Terraform CI**
  (`.github/workflows/landing-zone-lab.yml`, role `project-a-lzlab-gha` from
  `ci-bootstrap/`). Cloud Agents edit Terraform/PRs; they do **not** hold apply
  creds. `NoCredentials` is expected. Do **not** chase
  `CURSOR_AWS_ASSUME_IAM_ROLE_ARN` / External ID / `aws login` for the lab goal.
  Do **not** recreate `github-oidc/` / `GitHubActionsLZLab`.
- Keep harness runs sequential and repo-only unless the user explicitly asks for
  live cloud validation.

**Codex Cloud Environment (this consumer repo):**

| Item | Value |
| --- | --- |
| Environment | `nathanielecon/cloud` |
| Env id | `6a52b532673c8191b12b47eb0958625c` |
| Setup / maintenance | `.codex/cloud-setup.sh` / `.codex/cloud-maintenance.sh` |

### 4. Portfolio visuals (when requested)

**AUTH / TOOLING (Image2 — local only):** Cursor GenerateImage or local `codex`
with ChatGPT login. No `OPENAI_API_KEY` SDK scripts. No Image2 in cloud workers.

## Harness validation (this repo)

- Fast validation order when touching harness code (prefer the one-command
  CI-parity gate first):
  0. `pwsh -NoLogo -NoProfile -File scripts/Invoke-HarnessReleaseValidation.ps1`
  1. `pwsh -NoLogo -NoProfile -File tests/Run-ProjectAHarnessTests.ps1`
  2. `pwsh -NoLogo -NoProfile -File tests/Run-ProjectASpecTests.ps1`
  3. `pwsh -NoLogo -NoProfile -File tests/Run-ContractTests.ps1`
- After editing `scripts/Invoke-ProjectAValidators.ps1`, `scripts/Harness.Common.psm1`,
  or `scripts/Start-ProjectAHarness.ps1`, recompute execution hashes and repin
  Project A approval JSON files before claiming the harness is green.
