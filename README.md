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
