# Codex Cloud speed — prompt instructions

Paste-ready blocks for project prompts. Each repository needs its **own** Codex
Environment and ~12h cache; a warm cache on one project does **not** speed up
another.

## Rename note

GitHub repo `nathanielecon/cloud` → **`nathanielecon/aws-landing-zone-lab`**.
Local path may still be `C:\dev\cloud`. Codex Environment labels may still say
`cloud` until you rename them in the Codex UI.

Reference Environment (verify label in UI): previously `nathanielecon/cloud` /
id `6a52b532673c8191b12b47eb0958625c` — may now show as
**`nathanielecon/aws-landing-zone-lab`**.

## Facts to bake into every prompt

- **Per-project cache:** Warm tools on one Environment do not speed up another
  repo. Each project needs setup + one warm task.
- **Local vs Cloud:** Laptop `codex` ChatGPT login ≠ credentials inside Codex
  Cloud containers. Speed here is **toolchain cache**, not Image2/auth.
- **Do not** reinstall Node/pwsh/Terraform/AWS CLI every task when the
  Environment already provides them.
- **Orchestrator warm gate (forever):** Before any Codex Cloud task, the lead
  orchestrator must run `scripts/Invoke-CodexCloudWarm.ps1` for that repo. If
  `lastWarmUtc` is missing or older than ~10 hours, the script submits Paste
  block C via `codex cloud exec` and stamps success locally. Register new
  Environments with `scripts/Register-CodexCloudEnvironment.ps1`. Registry:
  `%LOCALAPPDATA%\codex-cloud-warm\environments.json` (never commit).

## Human setup (once per project)

Do this **before** relying on Paste block A:

1. Add `.codex/cloud-setup.sh`, `.codex/cloud-maintenance.sh`, and
   `.codex/README.md` (copy from `aws-landing-zone-lab`; trim tool list if that
   project does not need Terraform/Ralphy).
2. Commit/push so the **default branch** (or the branch Cloud tasks use)
   contains `.codex/`.
3. Codex → **Environments** → that repository → Manual setup, caching **On**:
   - Setup: `bash .codex/cloud-setup.sh` **or** paste script body (safer if
     `.codex/` is not on every branch)
   - Maintenance: `bash .codex/cloud-maintenance.sh`
4. Save → run one throwaway Cloud task (Paste block C) → confirm `node` /
   `pwsh` / `terraform` / `aws` exist.
5. Avoid editing setup/secrets/env vars unless needed (invalidates cache).

## Folding into two (or N) projects

| Step | Project 1 | Project 2 |
| --- | --- | --- |
| Copy `.codex/` (+ trim tools) | Yes | Yes (separate clone) |
| Codex Environment for that GitHub repo | Own env | Own env |
| `Register-CodexCloudEnvironment.ps1` | Yes | Yes |
| Attach **Paste block A** to standing prompts / AGENTS.md | Yes | Yes |
| Run **Paste block B** only if cold | As needed | As needed |
| Orchestrator: `Invoke-CodexCloudWarm.ps1` before Cloud work | Always | Always |
| First warm: `-Force` or Paste block C once | Yes | Yes |

---

## Paste block A — Project prompt addendum (generic, both projects)

```text
## Codex Cloud speed (required)

This project uses a Codex Cloud Environment with cached setup (~12h).

Rules for Codex Cloud tasks:
1. Do NOT reinstall Node, PowerShell, Terraform, AWS CLI, or Ralphy at session start
   unless `command -v` shows they are missing.
2. Prefer tools already on PATH from Environment setup/maintenance
   (`.codex/cloud-setup.sh` / `.codex/cloud-maintenance.sh`).
3. In-progress tasks keep the container they started with; Environment changes
   apply only to NEW tasks.
4. If tools are missing: run `bash .codex/cloud-setup.sh` once, then continue.
   Do not invent alternate apt/npm install loops.
5. Cache is PER REPOSITORY Environment. Do not assume another project's warm
   cache applies here.
6. Nested `codex doctor` / Image2 / laptop ChatGPT auth are NOT available in
   this container. For Image2 or ChatGPT-subscription Codex CLI, stop and ask
   the orchestrator to dispatch a LOCAL bottleneck.
7. Edit the repo only. Live cloud apply is GitOps/CI, not this agent.

Orchestrator (before launching this task): run
`pwsh -File scripts/Invoke-CodexCloudWarm.ps1` so the Environment cache is
warmed if lastWarmUtc is missing or older than ~10 hours.
```

---

## Paste block B — One-time bootstrap prompt (new project / cold Environment)

Use once per project when `.codex/` is not set up yet:

```text
Goal: Make Codex Cloud agents fast for THIS repository only.

1. Add `.codex/cloud-setup.sh`, `.codex/cloud-maintenance.sh`, and `.codex/README.md`
   mirroring the aws-landing-zone-lab pattern (Node 24, PowerShell 7, Terraform 1.15.5,
   AWS CLI v2; include Ralphy only if this project needs it).
2. Document in `.codex/README.md`: wire Setup + Maintenance in Codex → Environments,
   caching On, warm with one throwaway task, cache ~12h, do not reinstall every task.
3. Do not reinstall toolchains in normal task prompts after the Environment is warm.
4. Commit on the branch Cloud tasks will clone (prefer default branch).
5. Reply with: files added, exact Setup/Maintenance one-liners for the dashboard,
   and a one-line warm-task prompt the human can run.
```

---

## Paste block C — Warm-task prompt (after dashboard wire)

```text
Smoke only: print versions for git, node, pwsh, terraform, aws. Make no repo changes.
If a tool is missing, run bash .codex/cloud-setup.sh once, then reprint versions.
```
