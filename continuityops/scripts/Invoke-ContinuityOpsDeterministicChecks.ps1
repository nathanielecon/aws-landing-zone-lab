#Requires -Version 7
<#
.SYNOPSIS
  Deterministic ContinuityOps check runner (NOT a judge council).
  Does not embed pass thresholds into per-check "judge" objects.
  Use Invoke-FreshCouncilAggregate.ps1 after blind Grok judges.
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
$cop = Join-Path $Root 'continuityops'

& (Join-Path $PSScriptRoot 'Invoke-ContinuityOpsValidate.ps1') -Root $Root
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$checks = [System.Collections.Generic.List[object]]::new()
function Add-Check($Name, $Ok, $Detail) {
    $checks.Add([ordered]@{ name = $Name; pass = [bool]$Ok; detail = $Detail })
}

function Test-Rel([string]$Rel) { Test-Path -LiteralPath (Join-Path $Root $Rel) }

Add-Check 'independence_lock' (Test-Rel 'continuityops/integration/upstreams.lock.json') 'lock'
Add-Check 'postbuild_partition' (Test-Rel 'continuityops/harness/policies/postbuild-partition-manifest.json') 'partition'
Add-Check 'helm_deployment' (Test-Rel 'continuityops/kubernetes/chart/templates/deployment.yaml') 'helm'
Add-Check 'serverless_worker' (Test-Rel 'continuityops/serverless/src/worker/index.js') 'worker'
Add-Check 'worker_zip_min_size' ((Get-Item (Join-Path $cop 'serverless/build/worker.zip')).Length -gt 500) 'zip'
Add-Check 'lab_digest_set' (-not ((Get-Content (Join-Path $cop 'app-contract/release-contract.json') -Raw) -match 'PENDING_BUILD')) 'digest'
Add-Check 'eight_drills' ((Get-ChildItem (Join-Path $cop 'operations/drills') -Filter '*.md').Count -ge 8) 'drills'
Add-Check 'restore_event' (Test-Rel 'continuityops/evidence/events/restore-verification-lab.json') 'restore'
Add-Check 'claims_boundary' (Test-Rel 'continuityops/docs/claims/claims-boundary.md') 'claims'
Add-Check 'project_a_clean' (@(git -C $Root status --porcelain -- project-a).Count -eq 0) 'project-a'

Push-Location (Join-Path $cop 'serverless')
try { node --test tests/*.test.js 2>&1 | Out-Null; Add-Check 'serverless_unit' ($LASTEXITCODE -eq 0) "node=$LASTEXITCODE" }
finally { Pop-Location }

& (Join-Path $cop 'agentic/tests/Test-UnsafeProposals.ps1') 2>&1 | Out-Null
Add-Check 'unsafe_proposals' ($LASTEXITCODE -eq 0) "agentic=$LASTEXITCODE"

$failed = @($checks | Where-Object { -not $_.pass })
$out = [ordered]@{
    schema_version = 'continuityops-deterministic-checks-v1'
    note           = 'Deterministic checks only. Blind Grok judges score separately without thresholds.'
    candidate_sha  = (git -C $Root rev-parse HEAD).Trim()
    timestamp_utc  = [DateTime]::UtcNow.ToString('o')
    pass_count     = @($checks | Where-Object { $_.pass }).Count
    fail_count     = $failed.Count
    checks         = @($checks)
}
Write-JsonFile -Path (Join-Path $cop 'evidence/manifests/deterministic-checks.json') -Object $out
if ($failed.Count -gt 0) {
    Write-Host ("Deterministic checks failed: {0}" -f ($failed.name -join ', ')) -ForegroundColor Red
    exit 1
}
Write-Host 'Deterministic checks passed (no judge thresholds used).' -ForegroundColor Green
exit 0
