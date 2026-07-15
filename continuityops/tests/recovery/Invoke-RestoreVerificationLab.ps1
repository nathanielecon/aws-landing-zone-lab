#Requires -Version 7
<#
.SYNOPSIS
  Lightweight schema checks for restore-verification-lab.json (repo-only).

.DESCRIPTION
  Validates continuityops/evidence/events/restore-verification-lab.json against
  the required shape of tests/recovery/restore-verification.schema.json using
  PowerShell property checks (no external JSON Schema CLI required).
  Exits 0 on success; non-zero on failure.
#>
[CmdletBinding()]
param(
    [string]$Root = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Root) {
    $Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
}

$artifactPath = Join-Path $Root 'evidence/events/restore-verification-lab.json'
$schemaPath = Join-Path $Root 'tests/recovery/restore-verification.schema.json'
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string]$Message)
    [void]$failures.Add($Message)
}

if (-not (Test-Path -LiteralPath $artifactPath)) {
    Write-Error "Missing restore verification artifact: $artifactPath"
    exit 1
}
if (-not (Test-Path -LiteralPath $schemaPath)) {
    Write-Error "Missing schema: $schemaPath"
    exit 1
}

$doc = Get-Content -LiteralPath $artifactPath -Raw | ConvertFrom-Json
$allowedEnvironments = @('recovery-lab', 'staging', 'local', 'repo_only')
$allowedScenarios = @('helm_rollback', 'queue_redrive', 'full_rebuild', 'kubernetes_drill', 'teardown_complete')
$allowedResults = @('pass', 'fail', 'blocked', 'skipped')
$allowedComponentNames = @(
    'eks_workloads', 'eks_control_plane', 'lambda_worker', 'sqs_primary', 'sqs_dlq',
    'terraform_state', 'cloudwatch_logs', 'vpc_network', 'synthetic_tenant_metadata'
)
$allowedStatuses = @('pass', 'fail', 'skipped')

# Required top-level fields
$required = @(
    'schema_version', 'verification_id', 'candidate_sha', 'environment', 'change_id',
    'scenario', 'started_at_utc', 'completed_at_utc', 'result', 'components',
    'rto_rpo', 'synthetic_data_label'
)
foreach ($field in $required) {
    if (-not ($doc.PSObject.Properties.Name -contains $field)) {
        Add-Failure "Missing required field: $field"
    }
}

if ($doc.schema_version -ne 'continuityops-restore-verification-v1') {
    Add-Failure "schema_version must be continuityops-restore-verification-v1"
}

if ([string]::IsNullOrWhiteSpace([string]$doc.verification_id)) {
    Add-Failure 'verification_id must be non-empty'
}

if ([string]$doc.candidate_sha -notmatch '^[0-9a-f]{40}$') {
    Add-Failure 'candidate_sha must be a 40-char lowercase hex SHA'
}

if ($allowedEnvironments -notcontains [string]$doc.environment) {
    Add-Failure "environment must be one of: $($allowedEnvironments -join ', ')"
}

if ($allowedScenarios -notcontains [string]$doc.scenario) {
    Add-Failure "scenario must be one of: $($allowedScenarios -join ', ')"
}

if ($allowedResults -notcontains [string]$doc.result) {
    Add-Failure "result must be one of: $($allowedResults -join ', ')"
}

if ($doc.synthetic_data_label -ne $true) {
    Add-Failure 'synthetic_data_label must be true (lab synthetic data only)'
}

# Timestamps (ISO-8601 strings; ConvertFrom-Json may promote to DateTime)
foreach ($tsField in @('started_at_utc', 'completed_at_utc')) {
    $raw = $doc.$tsField
    if ($raw -is [datetime]) {
        continue
    }
    $val = [string]$raw
    if ($val -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}') {
        Add-Failure "$tsField must look like an ISO-8601 date-time"
    }
}

# rto_rpo
$rto = $doc.rto_rpo
if ($null -eq $rto) {
    Add-Failure 'rto_rpo is required'
}
else {
    foreach ($rtoField in @('rto_minutes_measured', 'rto_minutes_target', 'rpo_minutes_measured', 'rpo_minutes_target')) {
        if (-not ($rto.PSObject.Properties.Name -contains $rtoField)) {
            Add-Failure "rto_rpo missing $rtoField"
        }
        else {
            $num = $rto.$rtoField
            if ($null -eq $num -or [double]$num -lt 0) {
                Add-Failure "rto_rpo.$rtoField must be a number >= 0"
            }
        }
    }
}

# components
$components = @($doc.components)
if ($components.Count -lt 1) {
    Add-Failure 'components must contain at least one item'
}
else {
    foreach ($c in $components) {
        foreach ($cf in @('name', 'check', 'status')) {
            if (-not ($c.PSObject.Properties.Name -contains $cf)) {
                Add-Failure "component missing $cf"
            }
        }
        if ($c.PSObject.Properties.Name -contains 'name' -and $allowedComponentNames -notcontains [string]$c.name) {
            Add-Failure "component name '$($c.name)' is not in the allowed enum"
        }
        if ($c.PSObject.Properties.Name -contains 'check' -and [string]::IsNullOrWhiteSpace([string]$c.check)) {
            Add-Failure 'component check must be non-empty'
        }
        if ($c.PSObject.Properties.Name -contains 'status' -and $allowedStatuses -notcontains [string]$c.status) {
            Add-Failure "component status must be one of: $($allowedStatuses -join ', ')"
        }
    }
}

# Optional checklist shape
if ($doc.PSObject.Properties.Name -contains 'checklist' -and $null -ne $doc.checklist) {
    foreach ($row in @($doc.checklist)) {
        foreach ($cf in @('id', 'description', 'passed')) {
            if (-not ($row.PSObject.Properties.Name -contains $cf)) {
                Add-Failure "checklist item missing $cf"
            }
        }
        if ($row.PSObject.Properties.Name -contains 'id') {
            $id = [int]$row.id
            if ($id -lt 1 -or $id -gt 99) {
                Add-Failure "checklist id $id out of range 1..99"
            }
        }
    }
}

# Completeness signals expected for the lab instance (synthetic but filled)
$notesBlob = ([string]$doc.notes) + ' ' + (($components | ForEach-Object { [string]$_.notes }) -join ' ')
foreach ($needle in @('checksum', 'record', 'health', 'version', 'digest', 'smoke')) {
    if ($notesBlob -notmatch [regex]::Escape($needle)) {
        Add-Failure "Lab completeness: expected '$needle' to appear in notes/component notes"
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'Invoke-RestoreVerificationLab FAILED:' -ForegroundColor Red
    foreach ($f in $failures) {
        Write-Host "  - $f" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Invoke-RestoreVerificationLab OK: $artifactPath" -ForegroundColor Green
Write-Host "  verification_id=$($doc.verification_id) candidate_sha=$($doc.candidate_sha) result=$($doc.result) synthetic_data_label=$($doc.synthetic_data_label)"
exit 0
