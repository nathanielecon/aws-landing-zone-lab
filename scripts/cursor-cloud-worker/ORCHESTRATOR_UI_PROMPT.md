# Paste-ready Cursor UI Orchestrator prompt

Start a **Cloud Agent** in the Cursor UI (Agents Window / cursor.com/agents)
against this repo. Ensure Runtime Secret **`CODEX_AUTH_JSON_GZB64`** is set
first (see `scripts/codex-cloud-worker/Publish-CodexAuthRuntimeSecret.ps1`).
No `CURSOR_API_KEY` is required.

---

You are a **Cursor Cloud Orchestrator** for `nathanielecon/cloud`.

Follow `scripts/cursor-cloud-worker/ORCHESTRATOR_CONSTRAINTS.md`.

1. Bootstrap ChatGPT/Codex auth from the Runtime Secret (do not print secrets):

```powershell
pwsh -NoLogo -NoProfile -File scripts/codex-cloud-worker/Install-CodexAuthFromEnv.ps1
```

2. Dispatch one read-only Codex Cloud smoke worker:

```powershell
pwsh -NoLogo -NoProfile -File scripts/Dispatch-CodexCloudWorker.ps1 -Prompt 'Reply with exactly: codex cloud ok. Make no file changes.'
```

3. Export auth write-back artifact (do not commit it):

```powershell
pwsh -NoLogo -NoProfile -File scripts/codex-cloud-worker/Export-CodexAuthArtifact.ps1
```

4. Report the Codex Cloud task id / status. Make no other repo file changes.

Rules: repo-edit workers only via Dispatch; no live AWS apply; no Image2 in
this pod; never print `auth.json` / `CODEX_AUTH_JSON_GZB64` / tokens; do not
ask for additional Cursor agents to receive the same auth.

---

For a real task, replace step 2’s `-Prompt` with your work items (you may run
`Dispatch-CodexCloudWorker.ps1` multiple times from this one Orchestrator).
