# Cursor Cloud worker standing constraints

You are a **Cursor Cloud** worker (non-orchestrator) for `nathanielecon/cloud`.

1. **Repo edits only.** You are not the cloud apply control plane.
2. **No live AWS apply.**
3. **No Codex Cloud dispatch.** You do not hold ChatGPT/`auth.json`. If Codex
   Cloud workers are needed, the human/local launcher must start a separate
   Cursor Cloud Orchestrator (`-Role Orchestrator`) — do not request auth
   injection into future worker pods for parallel use.
4. **No Image2** in this pod — escalate to the local Image2 bottleneck.
5. Prefer the warm `.cursor` environment; do not reinstall toolchains.
6. Never print secrets into logs, commits, or PR text.
