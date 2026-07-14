[CmdletBinding()]
param(
    [string]$Root = (Join-Path $PSScriptRoot '..'),
    [string]$BundleApprovalPath,
    [string]$ExecutionApprovalPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = [System.IO.Path]::GetFullPath($Root)
if (-not $BundleApprovalPath) { $BundleApprovalPath = Join-Path $Root 'project-a/harness/bundle-approval.json' }
if (-not $ExecutionApprovalPath) { $ExecutionApprovalPath = Join-Path $Root 'project-a/harness/execution-approval.json' }

$spec = & (Join-Path $PSScriptRoot 'Get-ProjectASpecHash.ps1') -Root $Root | ConvertFrom-Json
$execution = & (Join-Path $PSScriptRoot 'Get-ProjectAExecutionHash.ps1') -Root $Root | ConvertFrom-Json
$bundleApproval = Get-Content -Raw -LiteralPath $BundleApprovalPath | ConvertFrom-Json
$executionApproval = Get-Content -Raw -LiteralPath $ExecutionApprovalPath | ConvertFrom-Json

$checks = @(
    [pscustomobject]@{
        name     = 'bundle-approval.spec_bundle_sha256'
        expected = [string]$bundleApproval.spec_bundle_sha256
        actual   = [string]$spec.sha256
    }
    [pscustomobject]@{
        name     = 'bundle-approval.hash_implementation_sha256'
        expected = [string]$bundleApproval.hash_implementation_sha256
        actual   = [string]$spec.members.'scripts/Get-ProjectASpecHash.ps1'
    }
    [pscustomobject]@{
        name     = 'bundle-approval.execution_bundle_sha256'
        expected = [string]$bundleApproval.execution_bundle_sha256
        actual   = [string]$execution.sha256
    }
    [pscustomobject]@{
        name     = 'bundle-approval.validator_implementation_sha256'
        expected = [string]$bundleApproval.validator_implementation_sha256
        actual   = [string]$execution.members.'scripts/Invoke-ProjectAValidators.ps1'
    }
    [pscustomobject]@{
        name     = 'execution-approval.spec_bundle_sha256'
        expected = [string]$executionApproval.spec_bundle_sha256
        actual   = [string]$spec.sha256
    }
    [pscustomobject]@{
        name     = 'execution-approval.execution_bundle_sha256'
        expected = [string]$executionApproval.execution_bundle_sha256
        actual   = [string]$execution.sha256
    }
    [pscustomobject]@{
        name     = 'execution-approval.validator_implementation_sha256'
        expected = [string]$executionApproval.validator_implementation_sha256
        actual   = [string]$execution.members.'scripts/Invoke-ProjectAValidators.ps1'
    }
    [pscustomobject]@{
        name     = 'execution-approval.execution_hash_implementation_sha256'
        expected = [string]$executionApproval.execution_hash_implementation_sha256
        actual   = [string]$execution.members.'scripts/Get-ProjectAExecutionHash.ps1'
    }
)

$failed = 0
foreach ($check in $checks) {
    if ([string]$check.expected -eq [string]$check.actual) {
        Write-Host "PASS $($check.name)"
    } else {
        Write-Host "FAIL $($check.name)"
        Write-Host "  expected=$($check.expected)"
        Write-Host "  actual  =$($check.actual)"
        $failed++
    }
}

if ($failed -gt 0) {
    Write-Host "Verify-ProjectABundle FAILED ($failed pin(s))."
    exit 1
}
Write-Host 'Verify-ProjectABundle PASSED.'
exit 0
