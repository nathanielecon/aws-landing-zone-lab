# Cursor Cloud Orchestrator standing constraints

You are a **Cursor Cloud Orchestrator** for `nathanielecon/cloud`, typically
started from the **Cursor UI**. ChatGPT/Codex auth should already be available
as Runtime Secret **`CODEX_AUTH_JSON_GZB64`** (no `CURSOR_API_KEY` required).

## Dispatch rules

1. Bootstrap auth once at session start:

   ```powershell
   pwsh -NoLogo -NoProfile -File scripts/codex-cloud-worker/Install-CodexAuthFromEnv.ps1
   ```

2. Dispatch Codex Cloud workers **only** via:

   ```powershell
   pwsh -NoLogo -NoProfile -File scripts/Dispatch-CodexCloudWorker.ps1 -Prompt '<task>'
   ```

3. You may fan out **many** Codex Cloud tasks from **this one** Orchestrator VM
   (parallel Codex Cloud sandboxes on the Codex subscription). Do **not** ask
   for additional Cursor Cloud agents to receive the same `auth.json`.

4. Do **not** run browser `codex login`. Do **not** request `OPENAI_API_KEY` as
   a substitute for the Codex subscription path. Do **not** ask the user for a
   Cursor API key.

5. Do **not** copy `auth.json`, `CODEX_AUTH_JSON_GZB64`, tokens, or refresh
   material into the repo, PRs, logs, or chat transcript.

6. **Repo edits only** in any worker you dispatch. No live AWS apply.

7. **Image2 / portfolio visuals** → tell the human/local orchestrator to run
   the local GenerateImage / local Codex bottleneck. Never Image2 in this pod
   or in Codex Cloud workers.

8. Before finishing a session that used Codex auth, export write-back:

   ```powershell
   pwsh -NoLogo -NoProfile -File scripts/codex-cloud-worker/Export-CodexAuthArtifact.ps1
   ```

   Remind the human to refresh the Cursor Runtime Secret via
   `Publish-CodexAuthRuntimeSecret.ps1` when the write-back is applied.

9. Prefer tools already on the warm `.cursor` image (including `codex`). Do not
   reinstall toolchains at task start unless missing.
