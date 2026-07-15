<#
.SYNOPSIS
  Dispatch a Codex Cloud worker from inside a Cursor Cloud Orchestrator.

.DESCRIPTION
  Bootstraps ChatGPT auth from CODEX_AUTH_JSON_GZB64 if needed, then runs
  `codex cloud exec` against this repo's Codex Environment. Powered by the
  Codex/ChatGPT subscription behind the injected auth — not OPENAI_API_KEY.

.PARAMETER Prompt
  Task for the Codex Cloud worker.

.PARAMETER Branch
  Git branch for Codex Cloud (default: current).

.PARAMETER EnvId
  Codex Environment id (default: this repo's env).

.PARAMETER Attempts
  Best-of-N attempts (default: 1).

.PARAMETER SkipBootstrap
  Skip Install-CodexAuthFromEnv.ps1 (auth already on disk).

.EXAMPLE
  pwsh -File scripts/Dispatch-CodexCloudWorker.ps1 `
    -Prompt 'Reply: codex cloud ok; make no file changes.'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Prompt,

    [string]$Branch = '',

    [string]$EnvId = '6a52b532673c8191b12b47eb0958625c',

    [int]$Attempts = 1,

    [switch]$SkipBootstrap
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Dispatch-CodexCloudWorker.ps1 requires PowerShell 7 or later.'
}

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$bootstrap = Join-Path $PSScriptRoot 'codex-cloud-worker/Install-CodexAuthFromEnv.ps1'
$constraintsPath = Join-Path $PSScriptRoot 'codex-cloud-worker/WORKER_CONSTRAINTS.md'
$writeBack = Join-Path $PSScriptRoot 'codex-cloud-worker/Export-CodexAuthArtifact.ps1'

$codex = Get-Command codex -ErrorAction SilentlyContinue
if (-not $codex) {
    throw 'codex CLI not found on PATH. Prefer the warm .cursor image (Codex preinstalled); do not npm-install ad hoc unless the image lacks it.'
}

if (-not $SkipBootstrap) {
    if (-not [string]::IsNullOrWhiteSpace([string]$env:CODEX_AUTH_JSON_GZB64)) {
        & $bootstrap
    }
    elseif (-not (Test-Path -LiteralPath (Join-Path (Join-Path $HOME '.codex') 'auth.json') -PathType Leaf)) {
        throw 'No CODEX_AUTH_JSON_GZB64 and no ~/.codex/auth.json. Launch Orchestrator with auth inject.'
    }
}

$statusOut = & $codex.Source login status 2>&1 | Out-String
if ($statusOut -notmatch 'ChatGPT') {
    throw @"
codex login status is not ChatGPT-backed. Dispatch refused.
status:
$statusOut
"@
}

if ([string]::IsNullOrWhiteSpace($Branch)) {
    $Branch = (& git -C $root branch --show-current).Trim()
    if ([string]::IsNullOrWhiteSpace($Branch)) {
        throw 'Could not detect current branch; pass -Branch.'
    }
}

$constraints = ''
if (Test-Path -LiteralPath $constraintsPath -PathType Leaf) {
    $constraints = [System.IO.File]::ReadAllText($constraintsPath).Trim()
}
$fullPrompt = if ($constraints) {
    "$constraints`n`n---`n`n## Task`n`n$($Prompt.Trim())`n"
}
else {
    $Prompt.Trim()
}

# Avoid leaving the prompt on argv in process lists longer than needed: use temp file via stdin.
$promptFile = [System.IO.Path]::GetTempFileName()
try {
    [System.IO.File]::WriteAllText($promptFile, $fullPrompt, [System.Text.UTF8Encoding]::new($false))

    Write-Host "Dispatching Codex Cloud worker (env=$EnvId branch=$Branch attempts=$Attempts) ..."
    $query = Get-Content -LiteralPath $promptFile -Raw
    $execOut = & $codex.Source cloud exec --env $EnvId --branch $Branch --attempts $Attempts $query 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($execOut | ForEach-Object { "$_" }) -join "`n"

    # Best-effort task id parse (Codex CLI output varies by version)
    $taskId = $null
    if ($text -match '(?:task[:\s]+|id[:\s]+)([a-f0-9-]{8,})') {
        $taskId = $Matches[1]
    }
    elseif ($text -match '\b([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\b') {
        $taskId = $Matches[1]
    }

    $result = [ordered]@{
        status      = if ($exitCode -eq 0) { 'submitted' } else { 'failed' }
        exitCode    = $exitCode
        taskId      = $taskId
        envId       = $EnvId
        branch      = $Branch
        attempts    = $Attempts
        # Do not embed full CLI stdout (may contain paths); keep a short tail for ops.
        outputTail  = if ($text.Length -gt 800) { $text.Substring($text.Length - 800) } else { $text }
        dashboardHint = 'Open Codex → Cloud tasks for this environment to confirm the worker.'
    }
    $result | ConvertTo-Json -Depth 5 | Write-Output

    if (Test-Path -LiteralPath $writeBack -PathType Leaf) {
        try {
            & $writeBack
        }
        catch {
            Write-Host "WARNING: auth write-back artifact export failed: $($_.Exception.Message)"
        }
    }

    if ($exitCode -ne 0) {
        exit $exitCode
    }
}
finally {
    Remove-Item -LiteralPath $promptFile -Force -ErrorAction SilentlyContinue
}
