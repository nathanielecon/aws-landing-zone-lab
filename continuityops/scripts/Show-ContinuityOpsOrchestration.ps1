#Requires -Version 7
<#
.SYNOPSIS
  Print ContinuityOps orchestration stage status (build vs accuracy loops).
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

$orch = Read-JsonFile -Path (Join-Path $Root 'continuityops/harness/policies/orchestration-model.json')
$status = Get-Content -LiteralPath (Join-Path $Root 'continuityops/STATUS.md') -Raw

Write-Host 'ContinuityOps orchestration model' -ForegroundColor Cyan
foreach ($stage in @($orch.stages)) {
    Write-Host ("- {0}: {1}" -f $stage.id, $stage.name)
    Write-Host ("  human_gates={0}" -f $stage.human_gates)
}
Write-Host ''
Write-Host 'STATUS.md excerpt:' -ForegroundColor Cyan
($status -split "`n" | Select-Object -First 20) -join "`n" | Write-Host
