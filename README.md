# Ralphy Windows Harness

Native-Windows, Codex-first smoke harness for one sequential Ralphy loop.

This repository is the **smoke harness only**. The AWS Landing Zone lab (Terraform,
OIDC CI, diagrams, design contract) lives in a sibling repo:
[`nathanielecon/aws-landing-zone-lab`](https://github.com/nathanielecon/aws-landing-zone-lab).

Historical Project A harness profile / A-001…A-007 evidence was relocated with
that Landing Zone repo under `platform/` and `evidence/platform/`. This tree
keeps the smoke profile (`S-001` / `S-002`) so the harness can stand alone.

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

## Release validation

```powershell
$env:HARNESS_STRICT_PINS = '1'
pwsh -NoLogo -NoProfile -File ./scripts/Invoke-HarnessReleaseValidation.ps1
```

## Rules

See [`AGENTS.md`](AGENTS.md). Run only the approved manifest whose `PLAN.md`
SHA-256 matches `harness/plan-approval.json`. One sequential Ralphy process.
Codex must not commit — `scripts/Invoke-CodexAdapter.ps1` is the task commit
authority.
