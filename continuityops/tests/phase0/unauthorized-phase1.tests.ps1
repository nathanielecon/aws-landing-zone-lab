#Requires -Version 7
# Unauthorized Phase 1 rejection unit probe (no Pester dependency).
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
$scripts = Join-Path (Split-Path (Split-Path $here -Parent) -Parent) 'scripts'
Import-Module -Force -Name (Join-Path $scripts 'ContinuityOps.Common.psm1')
$root = Get-RepoRoot -Start $scripts
$approval = Read-JsonFile -Path (Join-Path $root 'continuityops/harness/approvals/plan-approval.json')

if ([bool]$approval.execution_approved) {
    throw 'execution_approved must be false before H0'
}

$env:CONTINUITYOPS_FORCE_PHASE1 = '1'
& (Join-Path $scripts 'Invoke-ContinuityOpsValidators.ps1') -Root $root
$code = $LASTEXITCODE
Remove-Item Env:CONTINUITYOPS_FORCE_PHASE1 -ErrorAction SilentlyContinue

if ($code -eq 0) {
    throw 'Expected non-zero exit when CONTINUITYOPS_FORCE_PHASE1=1'
}

Write-Host 'unauthorized-phase1.tests.ps1 PASS' -ForegroundColor Green
