#Requires -Version 7
<#
.SYNOPSIS
  Build the ContinuityOps content-addressed partition manifest (Phase 0).
#>
[CmdletBinding()]
param(
    [string]$Root = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module -Force -Name (Join-Path $PSScriptRoot 'ContinuityOps.Common.psm1')

if (-not $Root) { $Root = Get-RepoRoot -Start $PSScriptRoot }
$Root = (Resolve-Path -LiteralPath $Root).Path

$paths = @(Get-ContinuityOpsPaths -Root $Root)
$bySlice = [ordered]@{}
foreach ($slice in @('S0', 'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7', 'S8', 'IFACE')) {
    $bySlice[$slice] = [System.Collections.Generic.List[object]]::new()
}

$fileRecords = @()
foreach ($rel in $paths) {
    $full = Join-Path $Root ($rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    $sha = Get-FileSha256Hex -Path $full
    $slice = Get-SliceForPath -RelativePath $rel
    $rec = [ordered]@{
        path           = $rel
        sha256         = $sha
        primary_slice  = $slice
        bytes          = (Get-Item -LiteralPath $full).Length
    }
    $fileRecords += $rec
    [void]$bySlice[$slice].Add($rel)
}

$sliceSummaries = [ordered]@{}
foreach ($slice in $bySlice.Keys) {
    $list = @($bySlice[$slice] | Sort-Object)
    $concat = ($list -join "`n")
    $sliceSummaries[$slice] = [ordered]@{
        path_count     = $list.Count
        paths          = $list
        paths_sha256   = if ($list.Count -eq 0) {
            Get-TextSha256Hex -Text ''
        } else {
            Get-TextSha256Hex -Text ($concat + "`n")
        }
    }
}

$treeConcat = ($paths -join "`n") + "`n"
$manifest = [ordered]@{
    schema_version        = 'continuityops-partition-manifest-v1'
    plan_id               = 'continuityops-cloud-reliability-v1'
    generated_at_utc      = [DateTime]::UtcNow.ToString('o')
    host_commit_sha       = (git -C $Root rev-parse HEAD).Trim()
    root                  = 'continuityops/'
    file_count            = $paths.Count
    tree_paths_sha256     = Get-TextSha256Hex -Text $treeConcat
    slices                = $sliceSummaries
    files                 = $fileRecords
    rules                 = @(
        'Each path has exactly one primary slice owner.',
        'Shared interfaces are certified before dependent slices.',
        'Cross-partition changes require an interface-change issue.'
    )
}

$out = Join-Path $Root 'continuityops/harness/policies/partition-manifest.json'
Write-JsonFile -Path $out -Object $manifest
Write-Output "Wrote $out ($($paths.Count) files; tree_paths_sha256=$($manifest.tree_paths_sha256))"
