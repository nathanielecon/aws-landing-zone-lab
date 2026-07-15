#Requires -Version 7
<#
.SYNOPSIS
  Aggregate fresh-judge JSON verdicts. Threshold application is ORCHESTRATOR-ONLY
  and must never be passed into judge prompts.
#>
[CmdletBinding()]
param(
    [string]$Root = '',
    [double]$OrchestratorAverageMin = 9.5,
    [double]$OrchestratorFloorMin = 9.0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module -Force -Name (Join-Path $PSScriptRoot 'ContinuityOps.Common.psm1')
if (-not $Root) { $Root = Get-RepoRoot -Start $PSScriptRoot }
$Root = (Resolve-Path -LiteralPath $Root).Path
$dir = Join-Path $Root 'continuityops/evidence/manifests'

$judges = @()
foreach ($id in @('J1', 'J2', 'J3')) {
    $path = Join-Path $dir "fresh-judge-$id.json"
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing $path" }
    $j = Read-JsonFile -Path $path
    if ($j.threshold_provided -eq $true) { throw "$id claimed threshold_provided=true (leak)" }
    # Detect rationale leakage
    $blob = ($j | ConvertTo-Json -Depth 20)
    if ($blob -match '9\.5' -or $blob -match 'pass bar' -or $blob -match 'threshold') {
        Write-Warning "$id output mentions threshold-like language; review manually."
    }
    $judges += $j
}

$scores = @($judges | ForEach-Object { [double]$_.overall_score })
$avg = [math]::Round((($scores | Measure-Object -Average).Average), 2)
$min = [math]::Round((($scores | Measure-Object -Minimum).Minimum), 2)

# Per-partition averages
$partIds = @($judges[0].partitions | ForEach-Object { $_.partition_id })
$partAgg = @()
foreach ($pid in $partIds) {
    $ps = @()
    foreach ($j in $judges) {
        $p = @($j.partitions | Where-Object { $_.partition_id -eq $pid } | Select-Object -First 1)
        if ($p) { $ps += [double]$p.score }
    }
    $partAgg += [ordered]@{
        partition_id = $pid
        average      = [math]::Round((($ps | Measure-Object -Average).Average), 2)
        floor        = [math]::Round((($ps | Measure-Object -Minimum).Minimum), 2)
        scores       = $ps
    }
}

$opinions = @($judges | ForEach-Object { [string]$_.merge_ready_opinion })
$agg = [ordered]@{
    schema_version = 'continuityops-fresh-council-aggregate-v1'
    timestamp_utc  = [DateTime]::UtcNow.ToString('o')
    candidate_sha  = (git -C $Root rev-parse HEAD).Trim()
    threshold_in_judge_prompts = $false
    judges = @($judges | ForEach-Object {
        [ordered]@{
            judge_id = $_.judge_id
            overall_score = $_.overall_score
            merge_ready_opinion = $_.merge_ready_opinion
            threshold_provided = $_.threshold_provided
        }
    })
    overall_average = $avg
    overall_floor   = $min
    partition_averages = $partAgg
    opinions = $opinions
    orchestrator_gate = [ordered]@{
        note = 'Applied only by orchestrator after blind scoring; judges never received these numbers.'
        average_min = $OrchestratorAverageMin
        floor_min = $OrchestratorFloorMin
        pass = ($avg -ge $OrchestratorAverageMin -and $min -ge $OrchestratorFloorMin)
    }
}

$out = Join-Path $dir 'fresh-council-aggregate.json'
Write-JsonFile -Path $out -Object $agg
Write-Host ("Fresh council: avg={0} floor={1} orchestrator_pass={2}" -f $avg, $min, $agg.orchestrator_gate.pass)
Write-Host "Wrote $out"
