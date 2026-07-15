<#
.SYNOPSIS
  Laptop-direct Codex Cloud task submit (debug / fallback).

.DESCRIPTION
  Primary orchestration path is Cursor UI Orchestrator (Runtime Secret
  CODEX_AUTH_JSON_GZB64) → scripts/Dispatch-CodexCloudWorker.ps1.
  This script runs `codex cloud exec` on the laptop using the local ChatGPT
  login for quick tests only.

.PARAMETER Prompt
  Task prompt.

.PARAMETER Branch
  Git branch (default: current).

.PARAMETER EnvId
  Codex Environment id.

.PARAMETER Attempts
  Best-of-N attempts.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Prompt,

    [string]$Branch = '',

    [string]$EnvId = '6a52b532673c8191b12b47eb0958625c',

    [int]$Attempts = 1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$codex = Get-Command codex -ErrorAction SilentlyContinue
if (-not $codex) {
    throw 'codex CLI not found on PATH.'
}

$statusOut = & $codex.Source login status 2>&1 | Out-String
if ($statusOut -notmatch 'ChatGPT') {
    throw "Local Codex is not logged in with ChatGPT.`n$statusOut"
}

if ([string]::IsNullOrWhiteSpace($Branch)) {
    $Branch = (& git -C $root branch --show-current).Trim()
}

$constraintsPath = Join-Path $PSScriptRoot 'codex-cloud-worker/WORKER_CONSTRAINTS.md'
$constraints = if (Test-Path -LiteralPath $constraintsPath) {
    [System.IO.File]::ReadAllText($constraintsPath).Trim()
}
else { '' }
$full = if ($constraints) {
    "$constraints`n`n---`n`n## Task`n`n$($Prompt.Trim())`n"
}
else { $Prompt.Trim() }

Write-Host "Submitting Codex Cloud task (env=$EnvId branch=$Branch) from laptop ..."
& $codex.Source cloud exec --env $EnvId --branch $Branch --attempts $Attempts $full
exit $LASTEXITCODE
