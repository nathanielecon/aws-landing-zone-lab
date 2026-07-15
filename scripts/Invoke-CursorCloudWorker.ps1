<#
.SYNOPSIS
  Advanced/optional: launch a Cursor Cloud worker or Orchestrator via @cursor/sdk.

.DESCRIPTION
  Primary Orchestrator path does **not** use this script — start a Cloud Agent
  in the Cursor UI with Runtime Secret CODEX_AUTH_JSON_GZB64
  (see Publish-CodexAuthRuntimeSecret.ps1 + ORCHESTRATOR_UI_PROMPT.md).

  This SDK launcher is optional and requires CURSOR_API_KEY from
  https://cursor.com/dashboard/integrations.
  -Role Worker (default): repo edits only; no Codex auth.
  -Role Orchestrator: injects CODEX_AUTH_JSON_GZB64 from local ~/.codex/auth.json.

.PARAMETER Prompt
  User task for the cloud agent.

.PARAMETER Role
  worker | orchestrator

.PARAMETER Branch
  Git ref to start from (default: current branch).

.PARAMETER RepoUrl
  GitHub repo URL (default: origin remote).

.PARAMETER Model
  Cursor model id (default: composer-2.5).

.PARAMETER Wait
  Wait for the run to finish (default: $true).

.EXAMPLE
  # Advanced only — prefer UI + Runtime Secret for day-to-day use.
  $env:CURSOR_API_KEY = 'cursor_...'
  pwsh -File scripts/Invoke-CursorCloudWorker.ps1 -Role Orchestrator `
    -Prompt 'Bootstrap auth, then Dispatch-CodexCloudWorker with: Reply codex cloud ok; make no file changes.'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Prompt,

    [ValidateSet('Worker', 'Orchestrator', 'worker', 'orchestrator')]
    [string]$Role = 'Worker',

    [string]$Branch = '',

    [string]$RepoUrl = '',

    [string]$Model = 'composer-2.5',

    [bool]$Wait = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Invoke-CursorCloudWorker.ps1 requires PowerShell 7 or later.'
}

$roleNorm = $Role.ToLowerInvariant()
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$shimDir = Join-Path $PSScriptRoot 'cursor-cloud-worker'
$launchJs = Join-Path $shimDir 'launch.mjs'
$packageJson = Join-Path $shimDir 'package.json'
$exportAuth = Join-Path $PSScriptRoot 'codex-cloud-worker/Export-CodexAuthGzB64.ps1'

if (-not (Test-Path -LiteralPath $launchJs -PathType Leaf)) {
    throw "Missing launch shim: $launchJs"
}
if (-not (Test-Path -LiteralPath $packageJson -PathType Leaf)) {
    throw "Missing package.json: $packageJson"
}

$apiKey = [string]$env:CURSOR_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw @"
CURSOR_API_KEY is not set.
Create a user API key at https://cursor.com/dashboard/integrations ,
then: `$env:CURSOR_API_KEY = 'cursor_...'` (never commit the key).
"@
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    throw 'Node.js is required (engines.node >= 22.13). Install Node, then retry.'
}

if ([string]::IsNullOrWhiteSpace($Branch)) {
    $Branch = (& git -C $root branch --show-current).Trim()
    if ([string]::IsNullOrWhiteSpace($Branch)) {
        throw 'Could not detect current branch; pass -Branch explicitly.'
    }
}

if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
    $origin = (& git -C $root remote get-url origin).Trim()
    if ([string]::IsNullOrWhiteSpace($origin)) {
        throw 'Could not read git remote origin; pass -RepoUrl explicitly.'
    }
    if ($origin -match '^git@github\.com:(.+?)(?:\.git)?$') {
        $RepoUrl = "https://github.com/$($Matches[1])"
    }
    elseif ($origin -match '^https://github\.com/(.+?)(?:\.git)?$') {
        $RepoUrl = "https://github.com/$($Matches[1])"
    }
    else {
        $RepoUrl = $origin -replace '\.git$', ''
    }
}

$nodeModules = Join-Path $shimDir 'node_modules'
$sdkMarker = Join-Path $nodeModules '@cursor/sdk/package.json'
if (-not (Test-Path -LiteralPath $sdkMarker -PathType Leaf)) {
    Write-Host "Installing @cursor/sdk into $shimDir ..."
    $npm = Get-Command npm -ErrorAction Stop
    Push-Location $shimDir
    try {
        & $npm.Source install --no-fund --no-audit
        if ($LASTEXITCODE -ne 0) {
            throw "npm install failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

$authFile = $null
$promptFile = [System.IO.Path]::GetTempFileName()
try {
    [System.IO.File]::WriteAllText($promptFile, $Prompt, [System.Text.UTF8Encoding]::new($false))

    $nodeArgs = @(
        $launchJs,
        '--prompt-file', $promptFile,
        '--repo', $RepoUrl,
        '--ref', $Branch,
        '--model', $Model,
        '--role', $roleNorm
    )

    if ($roleNorm -eq 'orchestrator') {
        if (-not (Test-Path -LiteralPath $exportAuth -PathType Leaf)) {
            throw "Missing $exportAuth"
        }
        $gzb64 = & $exportAuth
        if ([string]::IsNullOrWhiteSpace($gzb64)) {
            throw 'Export-CodexAuthGzB64.ps1 returned empty output.'
        }
        $authFile = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($authFile, $gzb64.Trim(), [System.Text.UTF8Encoding]::new($false))
        $nodeArgs += @('--auth-gzb64-file', $authFile)
        Write-Host 'Orchestrator launch: CODEX_AUTH_JSON_GZB64 will be injected (value not logged).'
    }

    if ($Wait) { $nodeArgs += '--wait' } else { $nodeArgs += '--no-wait' }

    Write-Host "Launching Cursor Cloud ($roleNorm) repo=$RepoUrl ref=$Branch model=$Model wait=$Wait ..."
    & $node.Source @nodeArgs
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) { $exitCode = 0 }

    if ($Wait -and $roleNorm -eq 'orchestrator' -and $exitCode -eq 0) {
        Write-Host 'If a write-back artifact was downloaded, run scripts/codex-cloud-worker/Import-CodexAuthWriteback.ps1 -ArtifactPath <path>.'
        Write-Host 'Also refresh any Cursor Dashboard Runtime Secret for CODEX_AUTH_JSON_GZB64 when the local auth rotates.'
    }

    exit $exitCode
}
finally {
    Remove-Item -LiteralPath $promptFile -Force -ErrorAction SilentlyContinue
    if ($authFile) {
        Remove-Item -LiteralPath $authFile -Force -ErrorAction SilentlyContinue
    }
}
