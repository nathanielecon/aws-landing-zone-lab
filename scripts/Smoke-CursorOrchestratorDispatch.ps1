<#
.SYNOPSIS
  Smoke the Cursor Cloud Orchestrator → Codex Cloud dispatch path.

.DESCRIPTION
  Always runs the local auth gzip round-trip.
  If CURSOR_API_KEY is set and local `codex login status` shows ChatGPT, also
  launches a read-only Cursor Cloud Orchestrator that dispatches one Codex Cloud
  task. Otherwise prints LIVE_SMOKE_SKIPPED and exits 0 after local proof.

.PARAMETER SkipLive
  Force skip of the live Cursor/Codex Cloud launch.
#>
[CmdletBinding()]
param(
    [switch]$SkipLive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot 'codex-cloud-worker/Test-OrchestratorAuthRoundTrip.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$hasKey = -not [string]::IsNullOrWhiteSpace([string]$env:CURSOR_API_KEY)
$codex = Get-Command codex -ErrorAction SilentlyContinue
$chatgpt = $false
if ($codex) {
    $status = & $codex.Source login status 2>&1 | Out-String
    $chatgpt = $status -match 'ChatGPT'
}

if ($SkipLive -or -not $hasKey -or -not $chatgpt) {
    Write-Host 'LIVE_SMOKE_SKIPPED: need CURSOR_API_KEY + local ChatGPT codex login on the laptop control plane.'
    Write-Host 'Live smoke on laptop:'
    Write-Host '  $env:CURSOR_API_KEY = ''cursor_...'''
    Write-Host '  pwsh -NoLogo -NoProfile -File scripts/Invoke-CursorCloudWorker.ps1 -Role Orchestrator -Prompt ''Bootstrap auth; Dispatch-CodexCloudWorker: Reply codex cloud ok; make no file changes.'' -Wait:$true'
    exit 0
}

Write-Host 'LIVE_SMOKE: launching Cursor Cloud Orchestrator to dispatch one Codex Cloud task ...'
$livePrompt = @(
    'Bootstrap Codex auth with Install-CodexAuthFromEnv.ps1.'
    'Then run Dispatch-CodexCloudWorker.ps1 with prompt: Reply with exactly: codex cloud ok. Make no file changes.'
    'Export the auth write-back artifact. Make no other file changes.'
) -join ' '

& (Join-Path $PSScriptRoot 'Invoke-CursorCloudWorker.ps1') `
    -Role Orchestrator `
    -Prompt $livePrompt `
    -Wait:$true
exit $LASTEXITCODE
