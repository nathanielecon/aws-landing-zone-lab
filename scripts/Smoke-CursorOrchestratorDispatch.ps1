<#
.SYNOPSIS
  Smoke the Cursor Cloud Orchestrator → Codex Cloud dispatch path.

.DESCRIPTION
  Always runs the local auth gzip round-trip.
  Prints UI + Runtime Secret live-smoke instructions (no CURSOR_API_KEY).
  Does not require or use the SDK launcher.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot 'codex-cloud-worker/Test-OrchestratorAuthRoundTrip.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host 'LOCAL_SMOKE_OK: auth gzip Export → Install → Artifact → Import'
Write-Host ''
Write-Host 'UI live smoke (primary path — no CURSOR_API_KEY):'
Write-Host '  1. On laptop: codex login status   # expect ChatGPT'
Write-Host '  2. pwsh -NoLogo -NoProfile -File scripts/codex-cloud-worker/Publish-CodexAuthRuntimeSecret.ps1'
Write-Host '  3. Paste value into Cursor Dashboard → Secrets as Runtime Secret CODEX_AUTH_JSON_GZB64'
Write-Host '  4. Start a Cloud Agent in the Cursor UI; paste prompt from:'
Write-Host '     scripts/cursor-cloud-worker/ORCHESTRATOR_UI_PROMPT.md'
Write-Host '  5. Confirm a Codex Cloud task appears under your ChatGPT/Codex account'
Write-Host ''
Write-Host 'Advanced/optional SDK path (not required): Invoke-CursorCloudWorker.ps1 -Role Orchestrator'
exit 0
