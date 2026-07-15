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

### 1. Orchestrator — bottleneck dispatch

If work stalls on auth, CI, cloud credentials, dashboards, or any tool the
current agent cannot reach, the **lead orchestrator must dispatch a bottleneck
agent** **in this session**. Do not leave the user to open a new chat.

| Worker | When | How (primary) |
| --- | --- | --- |
| **Cursor Cloud Orchestrator** | Needs to fan out **Codex Cloud** workers on the Codex/ChatGPT subscription | **Cursor UI** Cloud Agent + Runtime Secret `CODEX_AUTH_JSON_GZB64` (see `Publish-CodexAuthRuntimeSecret.ps1` + `ORCHESTRATOR_UI_PROMPT.md`) |
| **Cursor Cloud worker** | Long repo/CI edits; **must not** use Codex auth | Cursor UI Cloud Agent **without** calling Dispatch |
| **Codex Cloud worker** | Dispatched **by** a Cursor Cloud Orchestrator | In-VM: `scripts/Dispatch-CodexCloudWorker.ps1` · Laptop debug: `scripts/Invoke-CodexCloudWorker.ps1` |
| **Local Codex / Image2 bottleneck** | Portfolio visuals, ChatGPT Codex tools on the laptop | This chat’s GenerateImage **or** local `codex` (ChatGPT login) |
| **GitHub Actions / local AWS** | Live cloud plan/apply | Unchanged GitOps path below |

**Advanced / optional:** `scripts/Invoke-CursorCloudWorker.ps1` + `CURSOR_API_KEY`
can SDK-launch the same Orchestrator. **Not required** for the primary UI path.

**Cursor Cloud Orchestrator → Codex Cloud (required pattern):** One Cursor Cloud
Orchestrator holds ChatGPT/`auth.json` (via Runtime Secret
`CODEX_AUTH_JSON_GZB64`) and runs many `codex cloud exec` launches. Parallel
**Codex Cloud** sandboxes on the Codex subscription = allowed. Seeding the
**same** `auth.json` into **multiple concurrent Cursor Cloud agents** that each
refresh auth = forbidden (OpenAI refresh-token races).

### 2. Auth planes (do not conflate)

| Plane | Auth | Role |
| --- | --- | --- |
| Local laptop | Cursor desktop session + ChatGPT `~/.codex/auth.json` | Export Runtime Secret; Image2 bottleneck; optional SDK launch |
| Cursor Cloud Orchestrator | Cursor account + **one** Runtime Secret `CODEX_AUTH_JSON_GZB64` | Dispatches Codex Cloud workers via `Dispatch-CodexCloudWorker.ps1` |
| Cursor Cloud worker | Cursor account only (do not call Dispatch) | Repo edits |
| Codex Cloud task | ChatGPT/Codex subscription that submitted the task | Inner cloud workers under the Orchestrator |
| Local Codex CLI | ChatGPT login | Image2 / laptop Codex tools |

**Runtime Secret setup (no API key):**

1. Laptop: `codex login` (ChatGPT) if needed.
2. `pwsh -File scripts/codex-cloud-worker/Publish-CodexAuthRuntimeSecret.ps1`
3. Paste into Cursor Dashboard → Secrets as **Runtime Secret**
   `CODEX_AUTH_JSON_GZB64` (prefer environment-scoped to the Orchestrator env).
4. Start Cloud Agent in the UI with
   [`scripts/cursor-cloud-worker/ORCHESTRATOR_UI_PROMPT.md`](scripts/cursor-cloud-worker/ORCHESTRATOR_UI_PROMPT.md).
5. After refresh/write-back, re-run Publish and update the same secret.
   Only **one** Orchestrator session may bootstrap/refresh that secret at a time.

**Secret hygiene:** Environment Runtime Secrets are visible to agents on that
environment. Ordinary worker prompts must **not** run
`Dispatch-CodexCloudWorker.ps1` or touch `auth.json` even if the secret is
present. Prefer a dedicated Orchestrator environment when the dashboard allows
environment-scoped secrets.

- Never commit tokens; never print them.
- After Orchestrator runs, import write-back with
  `scripts/codex-cloud-worker/Import-CodexAuthWriteback.ps1` when present, then
  refresh the dashboard secret via Publish.
- Do **not** use `OPENAI_API_KEY` as the Codex Cloud power source (Platform
  billing ≠ Codex subscription).
- Image2 stays **local** (GenerateImage or local Codex) — never in Cursor or
  Codex Cloud pods.

### 3. Cursor Cloud specific instructions

- Prefer the repo `.cursor/environment.json` image (PowerShell, Node 24,
  Terraform 1.15.5, AWS CLI, Docker, **Codex CLI**). Do not reinstall those
  tools with `apt-get` / `npm install` at session start unless missing.
- **Landing Zone lab AWS apply** uses **GitHub OIDC → Terraform CI**
  (`.github/workflows/landing-zone-lab.yml`, role `project-a-lzlab-gha` from
  `ci-bootstrap/`). Cloud Agents edit Terraform/PRs; they do **not** hold apply
  creds for this lab. `NoCredentials` in Cloud Agent pods is expected. Do
  **not** chase `CURSOR_AWS_ASSUME_IAM_ROLE_ARN` / External ID / `aws login`
  for the lab goal. Do **not** recreate `github-oidc/` / `GitHubActionsLZLab`.
- Keep harness runs sequential and repo-only unless the user explicitly asks for
  live cloud validation.

**Example fill — this repo’s Codex Cloud Environment:**

| Item | Value |
| --- | --- |
| Environment | `nathanielecon/cloud` |
| Env id | `6a52b532673c8191b12b47eb0958625c` |
| Setup / maintenance | `.codex/cloud-setup.sh` / `.codex/cloud-maintenance.sh` |
| Caching | Post-setup cache On; avoid Reset unless rebuild needed |

### 4. Portfolio visuals (when requested)

**AUTH / TOOLING (Image2 — local only):** Cursor built-in GenerateImage **or**
local `codex` with ChatGPT login. Do **not** use `OPENAI_API_KEY` SDK scripts.
Do **not** ask Cursor Cloud or Codex Cloud workers to generate portfolio
visuals.

## Harness validation (this repo)

- Fast validation order when touching harness code (prefer the one-command
  CI-parity gate first):
  0. `pwsh -NoLogo -NoProfile -File scripts/Invoke-HarnessReleaseValidation.ps1`
     (sets CI + HARNESS_CONTRACT_ONLY; use `HARNESS_STRICT_PINS=1` for pin
     fail-closed; also runs `Verify-ProjectABundle.ps1`)
  1. `pwsh -NoLogo -NoProfile -File tests/Run-ProjectAHarnessTests.ps1`
  2. `pwsh -NoLogo -NoProfile -File tests/Run-ProjectASpecTests.ps1`
  3. `pwsh -NoLogo -NoProfile -File tests/Run-ContractTests.ps1`
- After editing `scripts/Invoke-ProjectAValidators.ps1`, `scripts/Harness.Common.psm1`,
  or `scripts/Start-ProjectAHarness.ps1`, recompute execution hashes and repin
  Project A approval JSON files before claiming the harness is green.
