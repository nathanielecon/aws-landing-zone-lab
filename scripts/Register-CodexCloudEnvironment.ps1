#Requires -Version 7.0
<#
.SYNOPSIS
  Register or update a Codex Cloud Environment id in the local warm registry.

.DESCRIPTION
  Registry path (not committed):
    %LOCALAPPDATA%\codex-cloud-warm\environments.json

.PARAMETER Repo
  GitHub nameWithOwner (e.g. nathanielecon/aws-landing-zone-lab).
  Defaults to `gh repo view --json nameWithOwner -q .nameWithOwner` when omitted.

.PARAMETER EnvId
  Codex Cloud Environment id (from Codex UI or `codex cloud`).

.PARAMETER DefaultBranch
  Branch Cloud smoke tasks should use (default: main).
#>
[CmdletBinding()]
param(
    [string]$Repo,
    [Parameter(Mandatory = $true)]
    [string]$EnvId,
    [string]$DefaultBranch = 'main'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DefaultRepo {
    $name = gh repo view --json nameWithOwner --jq .nameWithOwner 2>$null
    if (-not $name) {
        throw 'Could not resolve -Repo. Pass -Repo explicitly or run from a GitHub checkout with gh auth.'
    }
    return $name.Trim()
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
            lastWarmUtc   = $(
                if ($p.Value.PSObject.Properties['lastWarmUtc'] -and $null -ne $p.Value.lastWarmUtc -and "$($p.Value.lastWarmUtc)" -ne '') {
                    [string]$p.Value.lastWarmUtc
                }
                else {
                    $null
                }
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

if (-not $Repo) {
    $Repo = Get-DefaultRepo
}

$RegistryDir = Join-Path $env:LOCALAPPDATA 'codex-cloud-warm'
$RegistryPath = Join-Path $RegistryDir 'environments.json'
$registry = Read-WarmRegistry -Path $RegistryPath

$existingWarm = $null
if ($registry.Contains($Repo)) {
    $existingWarm = $registry[$Repo].lastWarmUtc
}

$registry[$Repo] = [ordered]@{
    envId         = $EnvId.Trim()
    defaultBranch = $DefaultBranch.Trim()
    lastWarmUtc   = $existingWarm
}

Write-WarmRegistry -Path $RegistryPath -Map $registry
Write-Host "Registered $Repo -> envId=$($EnvId.Trim()) defaultBranch=$($DefaultBranch.Trim())"
Write-Host "Registry: $RegistryPath"
