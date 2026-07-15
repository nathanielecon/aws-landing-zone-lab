#Requires -Version 7
<#
.SYNOPSIS
  ContinuityOps Phase 0 allowlisted validators (repo-only).
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
            # Allow only continuityops changes in this task scope check when dirty
            if ($path -notmatch '^\.harness/' -and $path -notmatch '^\.ralphy/') {
                $escaped += $path
            }
        }
    }
    # Also verify policy allowed_paths stay under continuityops/
    foreach ($ap in @($policy.allowed_paths)) {
        $norm = [string]$ap -replace '\\', '/'
        if ($norm -notlike 'continuityops/*' -and $norm -ne 'continuityops') {
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

# --- upstream_lock ---
try {
    $lockPath = Join-Path $copRoot 'integration/upstreams.lock.json'
    $lock = Read-JsonFile -Path $lockPath
    if ([string]$lock.schema_version -ne '1.0') { throw 'schema_version must be 1.0' }
    if (-not $lock.project_a.commit_sha -or [string]$lock.project_a.commit_sha -eq 'REQUIRED') {
        throw 'project_a.commit_sha missing'
    }
    $hostSha = (git -C $Root rev-parse HEAD).Trim()
    # Pin must be an ancestor or equal of current HEAD for bootstrap honesty
    $null = git -C $Root merge-base --is-ancestor $lock.project_a.commit_sha HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -and [string]$lock.project_a.commit_sha -ne $hostSha) {
        throw "project_a.commit_sha $($lock.project_a.commit_sha) is not an ancestor of HEAD"
    }
    $pcDigest = [string]$lock.project_c.image_digest
    if ([string]::IsNullOrWhiteSpace($pcDigest) -or $pcDigest -eq 'REQUIRED') {
        throw 'project_c.image_digest must be set or REQUIRED_OR_EXPLICITLY_UNAVAILABLE'
    }
    Add-Result -Id 'upstream_lock' -Status 'pass' -Detail "A=$($lock.project_a.commit_sha.Substring(0,12)) C.digest=$pcDigest"
}
catch {
    Add-Result -Id 'upstream_lock' -Status 'fail' -Detail $_.Exception.Message
}

# --- unauthorized_phase_rejection (fail-closed short circuit for Phase 1 probes) ---
$approval = Read-JsonFile -Path (Join-Path $copRoot 'harness/approvals/plan-approval.json')
$phase1Requested = $env:CONTINUITYOPS_PHASE -eq '1' -or $env:CONTINUITYOPS_FORCE_PHASE1 -eq '1'
if ($phase1Requested -and -not ([bool]$approval.execution_approved -eq $true -and $approval.approved_by)) {
    Add-Result -Id 'unauthorized_phase_rejection' -Status 'fail' -Detail 'Phase 1 requested but execution_approved is false (fail-closed)'
    $summary = [ordered]@{
        schema_version = 'continuityops-phase0-validation-v1'
        task_id        = $TaskId
        candidate_sha  = (git -C $Root rev-parse HEAD).Trim()
        timestamp_utc  = [DateTime]::UtcNow.ToString('o')
        results        = @($results)
        pass_count     = @($results | Where-Object { $_.status -eq 'pass' }).Count
        fail_count     = @($results | Where-Object { $_.status -eq 'fail' }).Count
        overall        = 'fail'
    }
    $evidencePath = Join-Path $copRoot 'evidence/manifests/phase0-baseline.json'
    $summaryJson = ($summary | ConvertTo-Json -Depth 20)
    $artifactHash = Get-TextSha256Hex -Text $summaryJson
    $evidence = [ordered]@{
        schema_version  = 'continuityops-evidence-event-v1'
        event_id        = 'phase0-unauthorized-phase1-rejection'
        candidate_sha   = $summary.candidate_sha
        environment     = 'repo_only'
        identity        = 'continuityops-phase0-validator'
        timestamp_utc   = $summary.timestamp_utc
        command         = 'CONTINUITYOPS_FORCE_PHASE1=1 pwsh -File continuityops/scripts/Invoke-ContinuityOpsValidators.ps1'
        exit_code       = 1
        result          = 'blocked'
        artifact_sha256 = $artifactHash
        slice           = 'S0'
        notes           = 'Unauthorized Phase 1 rejected'
        validation      = $summary
    }
    Write-JsonFile -Path $evidencePath -Object $evidence
    Write-Host 'ContinuityOps rejected unauthorized Phase 1 execution.' -ForegroundColor Yellow
    exit 1
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
        throw "manifest file_count $($manifest.file_count) != live $($live.Count); regenerate"
    }
    Add-Result -Id 'partition_manifest' -Status 'pass' -Detail "files=$($manifest.file_count) tree=$($manifest.tree_paths_sha256.Substring(0,12))"
}
catch {
    Add-Result -Id 'partition_manifest' -Status 'fail' -Detail $_.Exception.Message
}

# --- unauthorized_phase_rejection (gate closed under normal Phase 0) ---
try {
    if ([bool]$approval.execution_approved -eq $true -and $approval.approved_by) {
        Add-Result -Id 'unauthorized_phase_rejection' -Status 'pass' -Detail 'execution_approved with human approver present'
    }
    elseif ([bool]$approval.execution_approved) {
        Add-Result -Id 'unauthorized_phase_rejection' -Status 'fail' -Detail 'execution_approved true without approved_by'
    }
    else {
        Add-Result -Id 'unauthorized_phase_rejection' -Status 'pass' -Detail 'Phase 1 blocked: execution_approved=false'
    }
}
catch {
    Add-Result -Id 'unauthorized_phase_rejection' -Status 'fail' -Detail $_.Exception.Message
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
    schema_version   = 'continuityops-phase0-validation-v1'
    task_id          = $TaskId
    candidate_sha    = (git -C $Root rev-parse HEAD).Trim()
    timestamp_utc    = [DateTime]::UtcNow.ToString('o')
    results          = @($results)
    pass_count       = @($results | Where-Object { $_.status -eq 'pass' }).Count
    fail_count       = $failed.Count
    overall          = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
}

$evidencePath = Join-Path $copRoot 'evidence/manifests/phase0-baseline.json'
$summaryJson = ($summary | ConvertTo-Json -Depth 20)
$artifactHash = Get-TextSha256Hex -Text $summaryJson
$evidence = [ordered]@{
    schema_version   = 'continuityops-evidence-event-v1'
    event_id         = 'phase0-baseline'
    candidate_sha    = $summary.candidate_sha
    environment      = 'repo_only'
    identity         = 'continuityops-phase0-validator'
    timestamp_utc    = $summary.timestamp_utc
    command          = 'pwsh -File continuityops/scripts/Invoke-ContinuityOpsValidators.ps1'
    exit_code        = if ($failed.Count -eq 0) { 0 } else { 1 }
    result           = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
    artifact_sha256  = $artifactHash
    slice            = 'S0'
    notes            = 'Phase 0 allowlisted validator summary'
    validation       = $summary
}
Write-JsonFile -Path $evidencePath -Object $evidence

# Refresh partition manifest so evidence file is included for subsequent pin steps.
& (Join-Path $PSScriptRoot 'New-PartitionManifest.ps1') -Root $Root | Out-Null

if ($failed.Count -gt 0) {
    Write-Host "ContinuityOps Phase 0 validators failed ($($failed.Count))." -ForegroundColor Red
    exit 1
}

Write-Host "ContinuityOps Phase 0 validators passed. Evidence: $evidencePath" -ForegroundColor Green
exit 0
