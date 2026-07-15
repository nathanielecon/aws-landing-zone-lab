#Requires -Version 7
<#
.SYNOPSIS
  ContinuityOps Phase 0 entrypoint: regenerate partition manifest, run validators,
  pin plan approval hashes (execution_approved remains false until human H0).
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
$copRoot = Join-Path $Root 'continuityops'

Write-Host '== New-PartitionManifest ==' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'New-PartitionManifest.ps1') -Root $Root

Write-Host '== Invoke-ContinuityOpsValidators ==' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'Invoke-ContinuityOpsValidators.ps1') -Root $Root
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Pin hashes into plan-approval.json without flipping execution_approved
$planPath = Join-Path $copRoot 'PLAN.md'
$manifestPath = Join-Path $copRoot 'harness/policies/partition-manifest.json'
$validatorPath = Join-Path $PSScriptRoot 'Invoke-ContinuityOpsValidators.ps1'
$approvalPath = Join-Path $copRoot 'harness/approvals/plan-approval.json'

$approval = Read-JsonFile -Path $approvalPath
$approval.plan_sha256 = (Get-FileSha256Hex -Path $planPath)
$approval.partition_manifest_sha256 = (Get-FileSha256Hex -Path $manifestPath)
$approval.validator_implementation_sha256 = (Get-FileSha256Hex -Path $validatorPath)
$approval.execution_approved = $false
$approval.status = 'candidate-specification'
Write-JsonFile -Path $approvalPath -Object $approval

Write-Host ("Pinned plan_sha256={0}" -f $approval.plan_sha256) -ForegroundColor Yellow
Write-Host 'execution_approved remains false until human gate H0.' -ForegroundColor Yellow

# Negative probe: Phase 1 must fail closed
Write-Host '== Unauthorized Phase 1 rejection probe ==' -ForegroundColor Cyan
$env:CONTINUITYOPS_FORCE_PHASE1 = '1'
& (Join-Path $PSScriptRoot 'Invoke-ContinuityOpsValidators.ps1') -Root $Root
$phase1Exit = $LASTEXITCODE
Remove-Item Env:CONTINUITYOPS_FORCE_PHASE1 -ErrorAction SilentlyContinue
if ($phase1Exit -eq 0) {
    Write-Error 'Phase 1 probe unexpectedly passed; unauthorized rejection is broken.'
    exit 1
}
Write-Host 'Phase 1 probe correctly rejected.' -ForegroundColor Green

# Re-run clean validators (env cleared) so evidence ends in pass state
& (Join-Path $PSScriptRoot 'Invoke-ContinuityOpsValidators.ps1') -Root $Root
exit $LASTEXITCODE
