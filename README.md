# Ralphy Windows Harness

Native-Windows, Codex-first smoke harness for one sequential Ralphy loop.

The first milestone validates deterministic gating and Terra-to-Sol takeover
without Git worktrees, parallel agents, cloud credentials, or Project A code.

## Run

Double-click `launcher\Launch Ralphy Harness.cmd`, or use PowerShell 7:

```powershell
./scripts/Start-Harness.ps1 -DryRun
./scripts/Start-Harness.ps1
./scripts/Start-Harness.ps1 -Resume
```

Verbose sanitized logs are stored outside the repository under
`%LOCALAPPDATA%\RalphyHarness\cloud`. Mutable Ralphy progress and takeover state
are stored under ignored `.harness/runtime`.

The smoke baseline currently pins Codex CLI 0.144.x because GPT-5.6 Sol and
Terra reject the older 0.133.x CLI.

## Project A preparation

The proven smoke harness is tagged `ralphy-harness-v0.1.0`. The Phase 3
[Project A candidate plan](project-a/PROJECT_A_PLAN.md) defines seven sequential,
repo-only tasks and their human gates. It is intentionally marked non-executable
until Phase 4 generalizes the smoke adapter, scrubs cloud credentials, implements
the allowlisted validators, and binds explicit approval receipts to exact diffs.

Phase 4 implementation and its execution-approval pins (`execution_approved: true`) are documented
in [project-a/HARNESS.md](project-a/HARNESS.md). Architecture and delivery
navigation live under
[project-a/docs/architecture/overview.md](project-a/docs/architecture/overview.md).
The [Project A Graphify report](project-a/graphify-out/GRAPH_REPORT.md) is a
repo-only navigation aid and is never a substitute for Terraform, policy,
security, or human validation.
