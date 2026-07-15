# Codex Cloud Environment (speed)

Codex Cloud Agents do **not** use [`.cursor/Dockerfile`](../.cursor/Dockerfile).
They use the Codex **universal** image plus a **dashboard setup script**. Codex
caches that container state for up to **~12 hours**, which is what makes follow-up
tasks fast.

**Prompt addenda** (paste into project prompts / two-project checklist):
[PROMPT-SPEED-ADDENDUM.md](PROMPT-SPEED-ADDENDUM.md).

**Keep warm (orchestrator):** before Codex Cloud work, run
[`scripts/Invoke-CodexCloudWarm.ps1`](../scripts/Invoke-CodexCloudWarm.ps1).
Register Environment ids with
[`scripts/Register-CodexCloudEnvironment.ps1`](../scripts/Register-CodexCloudEnvironment.ps1)
into `%LOCALAPPDATA%\codex-cloud-warm\environments.json` (local only).

## Wire once (Codex web / app)

1. Open **Codex → Environments** for this repository.
2. **Setup script** — paste contents of [`cloud-setup.sh`](cloud-setup.sh), or:

   ```bash
   bash .codex/cloud-setup.sh
   ```

   (Repo must be checked out first; Codex already clones before setup.)

3. **Maintenance script** — paste contents of [`cloud-maintenance.sh`](cloud-maintenance.sh), or:

   ```bash
   bash .codex/cloud-maintenance.sh
   ```

4. Pin runtimes in the UI when available (Node **24** if offered; otherwise the
   setup script installs Node 24 via NodeSource).
5. Save. Trigger a throwaway cloud task once to **warm the cache**.
6. Avoid editing the setup script, secrets, or env vars unless needed — those
   **invalidate** the cache.

## What gets installed (mirrors Cursor cloud image)

| Tool | Version |
| --- | --- |
| Node.js | 24.x |
| PowerShell | 7.x |
| Terraform | 1.15.5 |
| AWS CLI | v2 |
| Ralphy CLI | 4.7.2 |
| git / jq / Docker (when apt provides it) | distro |

## AWS apply

Same as Cursor Cloud Agents: **GitOps only**. Codex Cloud Agents edit the repo;
they do not hold apply credentials. See [`AGENTS.md`](../AGENTS.md) standing
addendum. Landing Zone lab apply is
[`.github/workflows/landing-zone-lab.yml`](../.github/workflows/landing-zone-lab.yml)
via role `project-a-lzlab-gha`.

## Cache troubleshooting

- **Still slow:** confirm setup completed once; open Environment → **Reset cache**,
  then re-run one task to rebuild.
- **Missing tools after resume:** maintenance should re-run setup; ensure the
  maintenance script field points at `cloud-maintenance.sh`.
- **Wrong Node/Terraform:** check `TERRAFORM_VERSION` / `NODE_MAJOR` overrides in
  environment variables, or re-save setup after script updates.
