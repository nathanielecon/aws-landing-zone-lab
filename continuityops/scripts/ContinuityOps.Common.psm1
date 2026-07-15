# ContinuityOps.Common.psm1 — shared helpers for ContinuityOps Phase 0 validators

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    param([string]$Start = $PSScriptRoot)
    $dir = (Resolve-Path -LiteralPath $Start).Path
    while ($dir) {
        if (Test-Path -LiteralPath (Join-Path $dir '.git')) { return $dir }
        $parent = Split-Path -Parent $dir
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    throw 'Unable to locate repository root (.git).'
}

function Get-FileSha256Hex {
    param([Parameter(Mandatory)][string]$Path)
    $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
    return [string]$hash.Hash.ToLowerInvariant()
}

function Get-TextSha256Hex {
    param([AllowEmptyString()][string]$Text = '')
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing JSON file: $Path"
    }
    return (Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json)
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Object
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $json = $Object | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($Path, $json + "`n", [System.Text.UTF8Encoding]::new($false))
}

function Get-ContinuityOpsPaths {
    param([Parameter(Mandatory)][string]$Root)
    $base = Join-Path $Root 'continuityops'
    if (-not (Test-Path -LiteralPath $base)) {
        throw "continuityops/ missing under $Root"
    }
    return Get-ChildItem -LiteralPath $base -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($Root.Length).TrimStart('\', '/')
        $rel -replace '\\', '/'
    } | Sort-Object
}

function Test-PathUnderContinuityOps {
    param([Parameter(Mandatory)][string]$RelativePath)
    $norm = $RelativePath -replace '\\', '/'
    return $norm.StartsWith('continuityops/')
}

function Get-SliceForPath {
    param([Parameter(Mandatory)][string]$RelativePath)
    $p = $RelativePath -replace '\\', '/'
    if ($p -match '^continuityops/(PLAN\.md|STATUS\.md|ISSUES\.md|DECISIONS\.md|BREAK_FIX_LOG\.md|AGENTS\.md|README\.md)$') { return 'S0' }
    if ($p -match '^continuityops/tests/(recovery|performance)/') { return 'S7' }
    if ($p -match '^continuityops/(harness|scripts|integration|tests)/') { return 'S0' }
    if ($p -match '^continuityops/evidence/manifests/') { return 'S0' }
    if ($p -match '^continuityops/(terraform|\.github|app-contract)/') { return 'S1' }
    if ($p -match '^continuityops/kubernetes/') { return 'S2' }
    if ($p -match '^continuityops/serverless/') { return 'S3' }
    if ($p -match '^continuityops/observability/') { return 'S4' }
    if ($p -match '^continuityops/operations/changes/') { return 'S7' }
    if ($p -match '^continuityops/docs/decisions/(rto-rpo|finops)\.md$') { return 'S7' }
    if ($p -match '^continuityops/evidence/slices/') { return 'S7' }
    if ($p -match '^continuityops/operations/') { return 'S5' }
    if ($p -match '^continuityops/agentic/') { return 'S6' }
    if ($p -match '^continuityops/docs/') { return 'S8' }
    if ($p -match '^continuityops/evidence/') { return 'S8' }
    return 'S0'
}

Export-ModuleMember -Function @(
    'Get-RepoRoot',
    'Get-FileSha256Hex',
    'Get-TextSha256Hex',
    'Read-JsonFile',
    'Write-JsonFile',
    'Get-ContinuityOpsPaths',
    'Test-PathUnderContinuityOps',
    'Get-SliceForPath'
)
