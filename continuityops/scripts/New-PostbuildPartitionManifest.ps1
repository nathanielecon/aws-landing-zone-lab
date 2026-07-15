#Requires -Version 7
<#
.SYNOPSIS
  Build post-build logical partition manifest for ContinuityOps.
  Partitions by operational capability (not construction stream).
  Does not score and does not embed council thresholds.
#>
[CmdletBinding()]
param([string]$Root = '')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module -Force -Name (Join-Path $PSScriptRoot 'ContinuityOps.Common.psm1')
if (-not $Root) { $Root = Get-RepoRoot -Start $PSScriptRoot }
$Root = (Resolve-Path -LiteralPath $Root).Path

# Prefer git-tracked paths; exclude provider cache under .terraform/
$paths = @(
    git -C $Root ls-files -- 'continuityops/' |
        Where-Object { $_ -and ($_ -notmatch '/\.terraform/') } |
        ForEach-Object { $_ -replace '\\', '/' }
)
# Ensure self-describing policy artifacts are covered even before first commit
foreach ($extra in @(
        'continuityops/harness/policies/postbuild-partition-manifest.json',
        'continuityops/harness/policies/postbuild-partition-notes.md',
        'continuityops/scripts/New-PostbuildPartitionManifest.ps1'
    )) {
    if ($paths -notcontains $extra) { $paths += $extra }
}
$paths = @($paths | Sort-Object -Unique)

$partitions = [ordered]@{
    P_authority     = @{ title = 'Authority, harness, orchestration'; match = { param($p) $p -match '^continuityops/(PLAN|STATUS|ISSUES|DECISIONS|BREAK_FIX_LOG|AGENTS|README)\.md$' -or $p -match '^continuityops/(harness|scripts|integration)/' -or $p -match '^continuityops/evidence/manifests/' -or $p -match '^continuityops/tests/phase0/' } }
    P_foundation    = @{ title = 'Cloud foundation and delivery'; match = { param($p) $p -match '^continuityops/(terraform|\.github|app-contract)/' } }
    P_kubernetes    = @{ title = 'Kubernetes runtime'; match = { param($p) $p -match '^continuityops/kubernetes/' -or $p -match '^continuityops/tests/kubernetes/' } }
    P_serverless    = @{ title = 'Serverless and SaaS contracts'; match = { param($p) $p -match '^continuityops/serverless/' -or $p -match '^continuityops/docs/decisions/(saas-lifecycle|opportunity-model)\.md$' } }
    P_observability = @{ title = 'Observability and SLOs'; match = { param($p) $p -match '^continuityops/observability/' -or $p -match '^continuityops/tests/observability/' } }
    P_operations    = @{ title = 'Incident, Linux, network operations'; match = { param($p) $p -match '^continuityops/operations/' -and $p -notmatch '^continuityops/operations/changes/' } }
    P_security      = @{ title = 'Security, governance, agentic'; match = { param($p) $p -match '^continuityops/agentic/' -or $p -match '^continuityops/docs/guardrails/' } }
    P_resilience    = @{ title = 'Resilience, DR, performance, FinOps'; match = { param($p) $p -match '^continuityops/operations/changes/' -or $p -match '^continuityops/tests/(recovery|performance)/' -or $p -match '^continuityops/docs/decisions/(rto-rpo|finops)\.md$' -or $p -match '^continuityops/evidence/slices/' } }
    P_portfolio     = @{ title = 'Evidence and portfolio delivery'; match = { param($p) $p -match '^continuityops/docs/' -or $p -match '^continuityops/evidence/' } }
}

$assigned = @{}
foreach ($p in $paths) {
    $owner = $null
    foreach ($key in $partitions.Keys) {
        if ((& $partitions[$key].match $p)) {
            $owner = $key
            break
        }
    }
    if (-not $owner) { $owner = 'P_authority' }
    $assigned[$p] = $owner
}

$partOut = [ordered]@{}
foreach ($key in $partitions.Keys) {
    $plist = @($assigned.GetEnumerator() | Where-Object { $_.Value -eq $key } | ForEach-Object { $_.Key } | Sort-Object)
    $concat = if ($plist.Count -eq 0) { '' } else { ($plist -join "`n") + "`n" }
    $partOut[$key] = [ordered]@{
        id           = $key
        title        = $partitions[$key].title
        paths        = $plist
        path_count   = $plist.Count
        paths_sha256 = Get-TextSha256Hex -Text $concat
    }
}

$dupCheck = @{}
foreach ($p in $assigned.Keys) {
    if ($dupCheck.ContainsKey($p)) { throw "Duplicate assignment: $p" }
    $dupCheck[$p] = $true
}
if ($assigned.Count -ne $paths.Count) {
    throw "Assignment count $($assigned.Count) != path count $($paths.Count)"
}

$manifest = [ordered]@{
    schema_version   = 'continuityops-postbuild-partition-v1'
    generated_at_utc = [DateTime]::UtcNow.ToString('o')
    candidate_sha    = (git -C $Root rev-parse HEAD).Trim()
    root             = 'continuityops/'
    file_count       = $paths.Count
    partitions       = $partOut
    notes            = @(
        'Logical post-build partition by operational capability, independent of construction-stream ownership.',
        'Coverage is every git-tracked path under continuityops/ excluding .terraform/, plus self-describing postbuild policy/script artifacts.',
        'This manifest does not score quality and does not embed numeric pass thresholds.'
    )
}

$out = Join-Path $Root 'continuityops/harness/policies/postbuild-partition-manifest.json'
Write-JsonFile -Path $out -Object $manifest
Write-Output "Wrote $out ($($paths.Count) files, $($partOut.Keys.Count) partitions)"
foreach ($key in $partOut.Keys) {
    Write-Output ("  {0}: {1}" -f $key, $partOut[$key].path_count)
}
