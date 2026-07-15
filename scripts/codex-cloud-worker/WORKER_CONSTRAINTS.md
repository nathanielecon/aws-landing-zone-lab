# Codex Cloud worker standing constraints

You are a **Codex Cloud** worker dispatched by a Cursor Cloud Orchestrator for
this repo (`nathanielecon/cloud`). Follow these rules for the entire run:

1. **Repo edits only.** Change IaC, workflows, docs, evidence, scripts, and
   tests in git. You are **not** the cloud apply control plane.
2. **No live AWS apply.** Do not run `terraform apply`, destroy, or mutate live
   cloud resources. Prefer GitOps: edit repo config; let CI apply after merge.
3. **No Image2 / portfolio visuals in this container.** If visuals are
   required, tell the orchestrator to run the **local** Image2 / Codex
   bottleneck — do not chase `OPENAI_API_KEY` or request `auth.json` dumps.
4. **Prefer the warm Codex Environment.** Use tools already installed by
   `.codex/cloud-setup.sh`. Do not reinstall toolchains unless missing.
5. **Secrets hygiene.** Never print API keys, tokens, or `auth.json` contents
   into logs, commits, or PR text.
6. **Honest scope.** If blocked on credentials or live cloud access, stop and
   report the blocker — do not invent workarounds that violate AGENTS.md.
