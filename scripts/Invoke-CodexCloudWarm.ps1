#Requires -Version 7.0
<#
.SYNOPSIS
  Ensure a Codex Cloud Environment cache is warm before Cloud work.

.DESCRIPTION
  Looks up the Environment id in the local registry
  (%LOCALAPPDATA%\codex-cloud-warm\environments.json). If lastWarmUtc is
  missing or older than -MaxAgeHours (default 10), submits a version-smoke
  via `codex cloud exec` and records success. Registry is machine-local and
  never committed.

.PARAMETER Repo
  GitHub nameWithOwner. Defaults to current gh repo.

.PARAMETER EnvId
  Override registry env id.

.PARAMETER Branch
  Override registry defaultBranch for the smoke task.

.PARAMETER MaxAgeHours
  Re-warm if last successful warm is older than this (default 10).

.PARAMETER Force
  Always run the smoke, even if lastWarmUtc is fresh.

.PARAMETER TimeoutSeconds
  Max wait for smoke task (default 900).

.PARAMETER SkipWait
  Submit smoke and return without polling (still does not stamp lastWarmUtc).
#>
[CmdletBinding()]
param(
    [string]$Repo,
    [string]$EnvId,
    [string]$Branch,
    [double]$MaxAgeHours = 10,
    [switch]$Force,
    [int]$TimeoutSeconds = 900,
    [switch]$SkipWait
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SmokePrompt = @'
Smoke only: print versions for git, node, pwsh, terraform, aws. Make no repo changes.
If a tool is missing, run bash .codex/cloud-setup.sh once, then reprint versions.
'@

function Get-DefaultRepo {
    $name = gh repo view --json nameWithOwner --jq .nameWithOwner 2>$null
    if (-not $name) {
        throw 'Could not resolve -Repo. Pass -Repo explicitly or run from a GitHub checkout with gh auth.'
    }
    return $name.Trim()
}

function ConvertTo-WarmUtcStamp {
    param($Value)
    if ($null -eq $Value -or "$Value" -eq '') {
        return $null
    }
    if ($Value -is [datetime]) {
        return ([datetime]$Value).ToUniversalTime().ToString('o')
    }
    $text = [string]$Value
    try {
        $parsed = [datetime]::Parse($text, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)
        if ($parsed.Kind -eq [DateTimeKind]::Unspecified) {
            $parsed = [DateTime]::SpecifyKind($parsed, [DateTimeKind]::Utc)
        }
        return $parsed.ToUniversalTime().ToString('o')
    }
    catch {
        return $text
    }
}

function Read-WarmRegistry {
    param([string]$Path)
    $map = [ordered]@{}
    if (-not (Test-Path $Path)) {
        return $map
    }
    $raw = Get-Content -Raw -Path $Path
    if (-not $raw.Trim()) {
        return $map
    }
    $obj = $raw | ConvertFrom-Json
    foreach ($p in $obj.PSObject.Properties) {
        $map[$p.Name] = [ordered]@{
            envId         = [string]$p.Value.envId
            defaultBranch = [string]$(if ($p.Value.PSObject.Properties['defaultBranch'] -and $p.Value.defaultBranch) { $p.Value.defaultBranch } else { 'main' })
            lastWarmUtc   = ConvertTo-WarmUtcStamp -Value $(
                if ($p.Value.PSObject.Properties['lastWarmUtc']) { $p.Value.lastWarmUtc } else { $null }
            )
        }
    }
    return $map
}

function Write-WarmRegistry {
    param(
        [string]$Path,
        [System.Collections.IDictionary]$Map
    )
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $root = [ordered]@{}
    foreach ($key in ($Map.Keys | Sort-Object)) {
        $root[$key] = [pscustomobject]$Map[$key]
    }
    ($root | ConvertTo-Json -Depth 6) | Set-Content -Path $Path -Encoding utf8
}

function Test-WarmIsFresh {
    param(
        [string]$LastWarmUtc,
        [double]$MaxAgeHours
    )
    if ([string]::IsNullOrWhiteSpace($LastWarmUtc)) {
        return $false
    }
    $parsed = [datetime]::Parse($LastWarmUtc, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)
    if ($parsed.Kind -eq [DateTimeKind]::Unspecified) {
        $parsed = [DateTime]::SpecifyKind($parsed, [DateTimeKind]::Utc)
    }
    $age = [DateTime]::UtcNow - $parsed.ToUniversalTime()
    return ($age.TotalHours -lt $MaxAgeHours)
}

function Get-CodexCloudTaskId {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }
    # Common patterns: task_..., uuid, "id": "..."
    $patterns = @(
        'task_[A-Za-z0-9_-]+',
        '(?i)(?:task[_ -]?id|id)\s*[:=]\s*["'']?([A-Za-z0-9_-]{8,})',
        '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
    )
    foreach ($pat in $patterns) {
        $m = [regex]::Match($Text, $pat)
        if ($m.Success) {
            if ($m.Groups.Count -gt 1 -and $m.Groups[1].Success) {
                return $m.Groups[1].Value
            }
            return $m.Value
        }
    }
    return $null
}

function Get-CodexCloudTaskStatus {
    param([string]$TaskId)
    $out = & codex cloud status $TaskId 2>&1 | Out-String
    return $out
}

function Test-CodexCloudTaskTerminalSuccess {
    param([string]$StatusText)
    $t = $StatusText.ToLowerInvariant()
    if ($t -match '\b(failed|error|cancelled|canceled|timeout)\b') {
        return $false
    }
    if ($t -match '\b(completed|succeeded|success|ready|done|finished)\b') {
        return $true
    }
    return $null
}

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    throw 'codex CLI not found on PATH. Install Codex CLI and ensure ChatGPT login works locally.'
}

if (-not $Repo) {
    $Repo = Get-DefaultRepo
}

$RegistryPath = Join-Path (Join-Path $env:LOCALAPPDATA 'codex-cloud-warm') 'environments.json'
$registry = Read-WarmRegistry -Path $RegistryPath

$entry = $null
if ($registry.Contains($Repo)) {
    $entry = $registry[$Repo]
}

$resolvedEnvId = if ($EnvId) { $EnvId.Trim() } elseif ($entry) { [string]$entry.envId } else { $null }
$resolvedBranch = if ($Branch) { $Branch.Trim() } elseif ($entry -and $entry.defaultBranch) { [string]$entry.defaultBranch } else { 'main' }
$lastWarm = if ($entry) { $entry.lastWarmUtc } else { $null }

if (-not $resolvedEnvId) {
    throw @"
No Codex Cloud Environment id for repo '$Repo'.

Wire Codex → Environments (setup/maintenance, caching On), then register:
  pwsh -NoLogo -NoProfile -File scripts/Register-CodexCloudEnvironment.ps1 -Repo '$Repo' -EnvId '<ENV_ID>' -DefaultBranch '$resolvedBranch'

See .codex/README.md and .codex/PROMPT-SPEED-ADDENDUM.md.
"@
}

if (-not $Force -and (Test-WarmIsFresh -LastWarmUtc $lastWarm -MaxAgeHours $MaxAgeHours)) {
    Write-Host "Codex Cloud cache considered warm for $Repo (lastWarmUtc=$lastWarm, MaxAgeHours=$MaxAgeHours). Skipping smoke."
    exit 0
}

Write-Host "Warming Codex Cloud env $resolvedEnvId for $Repo (branch=$resolvedBranch Force=$Force)..."
$execOut = & codex cloud exec --env $resolvedEnvId --branch $resolvedBranch $SmokePrompt 2>&1 | Out-String
Write-Host $execOut

$taskId = Get-CodexCloudTaskId -Text $execOut
if (-not $taskId) {
    # Fallback: newest task for this env
    $listOut = & codex cloud list --env $resolvedEnvId --limit 5 2>&1 | Out-String
    Write-Host $listOut
    $taskId = Get-CodexCloudTaskId -Text $listOut
}

if (-not $taskId) {
    throw "Submitted warm smoke but could not parse task id from codex cloud exec/list output.`n$execOut"
}

Write-Host "Warm smoke task id: $taskId"

if ($SkipWait) {
    Write-Host 'SkipWait set — not polling; lastWarmUtc NOT updated.'
    exit 0
}

$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
$success = $false
while ([DateTime]::UtcNow -lt $deadline) {
    $statusText = Get-CodexCloudTaskStatus -TaskId $taskId
    $terminal = Test-CodexCloudTaskTerminalSuccess -StatusText $statusText
    if ($terminal -eq $true) {
        Write-Host $statusText
        $success = $true
        break
    }
    if ($terminal -eq $false) {
        Write-Host $statusText
        throw "Codex Cloud warm smoke failed for task $taskId"
    }
    Start-Sleep -Seconds 15
}

if (-not $success) {
    throw "Timed out after ${TimeoutSeconds}s waiting for warm smoke task $taskId"
}

# Persist env id + last warm. Keep registry defaultBranch stable: -Branch only
# overrides the smoke checkout for this run (e.g. PR branch before merge).
$persistedBranch = if ($entry -and $entry.defaultBranch) {
    [string]$entry.defaultBranch
}
else {
    'main'
}
if (-not $registry.Contains($Repo)) {
    $registry[$Repo] = [ordered]@{
        envId         = $resolvedEnvId
        defaultBranch = $persistedBranch
        lastWarmUtc   = $null
    }
}
$registry[$Repo].envId = $resolvedEnvId
if (-not $registry[$Repo].defaultBranch) {
    $registry[$Repo].defaultBranch = $persistedBranch
}
$registry[$Repo].lastWarmUtc = [DateTime]::UtcNow.ToString('o')
Write-WarmRegistry -Path $RegistryPath -Map $registry
Write-Host "Warm OK. lastWarmUtc=$($registry[$Repo].lastWarmUtc) written to $RegistryPath"
