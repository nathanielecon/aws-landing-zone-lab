# Cursor Cloud worker standing constraints

You are a **Cursor Cloud** worker (non-orchestrator) for `nathanielecon/cloud`.

1. **Repo edits only.** You are not the cloud apply control plane.
2. **No live AWS apply.**
3. **No Codex Cloud dispatch.** Even if Runtime Secret `CODEX_AUTH_JSON_GZB64`
   is present on this environment, you must **not** run
   `Dispatch-CodexCloudWorker.ps1`, `Install-CodexAuthFromEnv.ps1`, or read /
   write `~/.codex/auth.json`. Only a dedicated **Orchestrator** UI session may
   use that secret (one concurrent Orchestrator).
4. **No Image2** in this pod — escalate to the local Image2 bottleneck.
5. Prefer the warm `.cursor` environment; do not reinstall toolchains.
6. Never print secrets into logs, commits, or PR text.
