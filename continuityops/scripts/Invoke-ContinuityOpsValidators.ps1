#Requires -Version 7
<#
.SYNOPSIS
  ContinuityOps allowlisted validators (scope: continuityops/ only).
#>
[CmdletBinding()]
param(
    [string]$Root = '',
    [string]$TaskId = 'COP-001'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module -Force -Name (Join-Path $PSScriptRoot 'ContinuityOps.Common.psm1')

if (-not $Root) { $Root = Get-RepoRoot -Start $PSScriptRoot }
$Root = (Resolve-Path -LiteralPath $Root).Path
$copRoot = Join-Path $Root 'continuityops'

$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param(
        [string]$Id,
        [ValidateSet('pass', 'fail')][string]$Status,
        [string]$Detail
    )
    $results.Add([ordered]@{ id = $Id; status = $Status; detail = $Detail })
    $color = if ($Status -eq 'pass') { 'Green' } else { 'Red' }
    Write-Host ("[{0}] {1}: {2}" -f $Status.ToUpperInvariant(), $Id, $Detail) -ForegroundColor $color
}

# --- path_scope ---
try {
    $policyPath = Join-Path $copRoot "harness/tasks/$TaskId.json"
    $policy = Read-JsonFile -Path $policyPath
    $dirty = @(git -C $Root status --porcelain --untracked-files=all)
    $escaped = @()
    foreach ($line in $dirty) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $path = $line.Substring(3).Trim().Trim('"') -replace '\\', '/'
        if ($path -match ' -> ') { $path = ($path -split ' -> ')[-1] }
        if (-not $path.StartsWith('continuityops/')) {
            $allowedRoot = ($path -match '^\.harness/') -or
                ($path -match '^\.ralphy/') -or
                ($path -match '^\.github/workflows/continuityops-[^/]+\.ya?ml$')
            if (-not $allowedRoot) {
                $escaped += $path
            }
        }
    }
    foreach ($ap in @($policy.allowed_paths)) {
        $norm = [string]$ap -replace '\\', '/'
        $ok = ($norm -like 'continuityops/*') -or
            ($norm -eq 'continuityops') -or
            ($norm -like '.github/workflows/continuityops-*.yml') -or
            ($norm -like '.github/workflows/continuityops-*.yaml')
        if (-not $ok) {
            $escaped += "allowed_paths:$norm"
        }
    }
    if ($escaped.Count -gt 0) {
        Add-Result -Id 'path_scope' -Status 'fail' -Detail ("escaped paths: " + ($escaped -join ', '))
    } else {
        Add-Result -Id 'path_scope' -Status 'pass' -Detail 'allowed_paths confined to continuityops/'
    }
}
catch {
    Add-Result -Id 'path_scope' -Status 'fail' -Detail $_.Exception.Message
}

# --- secret_scan ---
try {
    $patterns = @(
        'AKIA[0-9A-Z]{16}',
        'ASIA[0-9A-Z]{16}',
        '-----BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY-----',
        'aws_secret_access_key\s*=\s*\S+',
        'xox[baprs]-[0-9A-Za-z-]{10,}'
    )
    $hits = @()
    $files = Get-ChildItem -LiteralPath $copRoot -Recurse -File | Where-Object {
        $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.Length -lt 2MB
    }
    foreach ($f in $files) {
        $text = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $text) { continue }
        foreach ($pat in $patterns) {
            if ($text -match $pat) {
                $rel = $f.FullName.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/'
                $hits += "$rel~$pat"
            }
        }
    }
    if ($hits.Count -gt 0) {
        Add-Result -Id 'secret_scan' -Status 'fail' -Detail ($hits -join '; ')
    } else {
        Add-Result -Id 'secret_scan' -Status 'pass' -Detail 'no high-confidence secrets in continuityops/'
    }
}
catch {
    Add-Result -Id 'secret_scan' -Status 'fail' -Detail $_.Exception.Message
}

# --- independence_lock ---
try {
    $lockPath = Join-Path $copRoot 'integration/upstreams.lock.json'
    $lock = Read-JsonFile -Path $lockPath
    if ([string]$lock.schema_version -ne '1.0') { throw 'schema_version must be 1.0' }
    if (-not $lock.independence) { throw 'independence block required' }
    if ([bool]$lock.independence.edits_project_a) { throw 'edits_project_a must be false' }
    if ([bool]$lock.independence.edits_project_c) { throw 'edits_project_c must be false' }
    if (-not [bool]$lock.independence.owns_lab_artifacts) { throw 'owns_lab_artifacts must be true' }
    Add-Result -Id 'independence_lock' -Status 'pass' -Detail 'ContinuityOps owns lab artifacts; A/C edits forbidden'
}
catch {
    Add-Result -Id 'independence_lock' -Status 'fail' -Detail $_.Exception.Message
}

# --- partition_manifest ---
try {
    & (Join-Path $PSScriptRoot 'New-PartitionManifest.ps1') -Root $Root | Out-Null
    $manifestPath = Join-Path $copRoot 'harness/policies/partition-manifest.json'
    $manifest = Read-JsonFile -Path $manifestPath
    if ([int]$manifest.file_count -lt 1) { throw 'empty partition manifest' }
    $dupCheck = @{}
    foreach ($f in @($manifest.files)) {
        $p = [string]$f.path
        if ($dupCheck.ContainsKey($p)) { throw "duplicate path $p" }
        $dupCheck[$p] = $true
        if (-not $f.primary_slice) { throw "missing primary_slice for $p" }
    }
    $live = @(Get-ContinuityOpsPaths -Root $Root)
    if ($live.Count -ne [int]$manifest.file_count) {
        throw "manifest file_count $($manifest.file_count) != live $($live.Count)"
    }
    Add-Result -Id 'partition_manifest' -Status 'pass' -Detail "files=$($manifest.file_count) tree=$($manifest.tree_paths_sha256.Substring(0,12))"
}
catch {
    Add-Result -Id 'partition_manifest' -Status 'fail' -Detail $_.Exception.Message
}

# --- orchestration_model ---
try {
    $orch = Read-JsonFile -Path (Join-Path $copRoot 'harness/policies/orchestration-model.json')
    if ($orch.stages.Count -lt 2) { throw 'expected stage_1_build and stage_2_accuracy' }
    $s1 = $orch.stages | Where-Object { $_.id -eq 'stage_1_build' } | Select-Object -First 1
    $s2 = $orch.stages | Where-Object { $_.id -eq 'stage_2_accuracy' } | Select-Object -First 1
    if (-not $s1 -or -not $s2) { throw 'missing required stages' }
    if ([bool]$s1.human_gates -or [bool]$s2.human_gates) { throw 'human_gates must be false while building' }
    if (-not [bool]$s2.concurrency.multi_threaded) { throw 'stage 2 must be multi_threaded' }
    $stop = [double]$s2.stop_when.council_average_min
    if ($stop -lt 9.5) { throw 'council_average_min must be >= 9.5' }
    Add-Result -Id 'orchestration_model' -Status 'pass' -Detail 'stage1 build + stage2 multi-threaded ≥9.5; no build gates'
}
catch {
    Add-Result -Id 'orchestration_model' -Status 'fail' -Detail $_.Exception.Message
}

# --- project_a_untouched ---
try {
    $paDirty = @(git -C $Root status --porcelain -- project-a)
    if ($paDirty.Count -gt 0) {
        Add-Result -Id 'project_a_untouched' -Status 'fail' -Detail ($paDirty -join ' | ')
    } else {
        Add-Result -Id 'project_a_untouched' -Status 'pass' -Detail 'no working-tree changes under project-a/'
    }
}
catch {
    Add-Result -Id 'project_a_untouched' -Status 'fail' -Detail $_.Exception.Message
}

$failed = @($results | Where-Object { $_.status -eq 'fail' })
$summary = [ordered]@{
    schema_version = 'continuityops-validate-v1'
    task_id        = $TaskId
    candidate_sha  = (git -C $Root rev-parse HEAD).Trim()
    timestamp_utc  = [DateTime]::UtcNow.ToString('o')
    results        = @($results)
    pass_count     = @($results | Where-Object { $_.status -eq 'pass' }).Count
    fail_count     = $failed.Count
    overall        = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
}

$evidencePath = Join-Path $copRoot 'evidence/manifests/folder-ready.json'
$summaryJson = ($summary | ConvertTo-Json -Depth 20)
$artifactHash = Get-TextSha256Hex -Text $summaryJson
$evidence = [ordered]@{
    schema_version  = 'continuityops-evidence-event-v1'
    event_id        = 'folder-ready'
    candidate_sha   = $summary.candidate_sha
    environment     = 'repo_only'
    identity        = 'continuityops-validate'
    timestamp_utc   = $summary.timestamp_utc
    command         = 'pwsh -File continuityops/scripts/Invoke-ContinuityOpsValidators.ps1'
    exit_code       = if ($failed.Count -eq 0) { 0 } else { 1 }
    result          = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
    artifact_sha256 = $artifactHash
    slice           = 'S0'
    notes           = 'ContinuityOps folder health validation'
    validation      = $summary
}
Write-JsonFile -Path $evidencePath -Object $evidence
& (Join-Path $PSScriptRoot 'New-PartitionManifest.ps1') -Root $Root | Out-Null

if ($failed.Count -gt 0) {
    Write-Host "ContinuityOps validators failed ($($failed.Count))." -ForegroundColor Red
    exit 1
}

Write-Host "ContinuityOps validators passed. Evidence: $evidencePath" -ForegroundColor Green
exit 0
