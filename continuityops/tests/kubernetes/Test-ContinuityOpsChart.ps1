#Requires -Version 7
<#
.SYNOPSIS
  Validate ContinuityOps S2 Helm chart structure and values (repo-only).
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

$chartRoot = Join-Path $Root 'kubernetes/chart'
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-FileExists {
    param([string]$RelativePath)
    $full = Join-Path $chartRoot $RelativePath
    if (-not (Test-Path -LiteralPath $full)) {
        $failures.Add("missing file: kubernetes/chart/$RelativePath")
    }
}

function Assert-YamlParses {
    param([string]$RelativePath)
    $full = Join-Path $chartRoot $RelativePath
    if (-not (Test-Path -LiteralPath $full)) { return }
    try {
        $null = Get-Content -LiteralPath $full -Raw
        if ($full -match '\.(ya?ml)$') {
            # Basic YAML sanity: no tab-indented lines in k8s manifests
            $lines = Get-Content -LiteralPath $full
            foreach ($line in $lines) {
                if ($line -match '^\t') {
                    throw 'tab-indented YAML line'
                }
            }
        }
    }
    catch {
        $failures.Add("yaml read failed: kubernetes/chart/$RelativePath — $($_.Exception.Message)")
    }
}

$requiredTemplates = @(
    'Chart.yaml',
    'values.yaml',
    'templates/_helpers.tpl',
    'templates/deployment.yaml',
    'templates/service.yaml',
    'templates/serviceaccount.yaml',
    'templates/hpa.yaml',
    'templates/pdb.yaml',
    'templates/networkpolicy.yaml',
    'templates/ingress.yaml',
    'templates/configmap.yaml',
    'templates/secret.yaml',
    'templates/tests/test-connection.yaml'
)

foreach ($rel in $requiredTemplates) {
    Assert-FileExists -RelativePath $rel
    if ($rel -match '\.(ya?ml|tpl)$') {
        Assert-YamlParses -RelativePath $rel
    }
}

$valuesPath = Join-Path $chartRoot 'values.yaml'
if (Test-Path -LiteralPath $valuesPath) {
    $valuesText = Get-Content -LiteralPath $valuesPath -Raw
    $requiredKeys = @(
        'image:',
        'digest:',
        'runAsNonRoot:',
        'readOnlyRootFilesystem:',
        'topologySpreadConstraints:',
        'podDisruptionBudget:',
        'autoscaling:',
        'networkPolicy:',
        'egressAllowlist:',
        'secretName:'
    )
    foreach ($key in $requiredKeys) {
        if ($valuesText -notmatch [regex]::Escape($key)) {
            $failures.Add("values.yaml missing key fragment: $key")
        }
    }
    if ($valuesText -match 'AKIA[0-9A-Z]{16}') {
        $failures.Add('values.yaml must not contain AWS access keys')
    }
}

$policyRoot = Join-Path $Root 'kubernetes/policies'
foreach ($policy in @('require-digest.yaml', 'require-nonroot.yaml', 'deny-latest-tag.yaml')) {
    $p = Join-Path $policyRoot $policy
    if (-not (Test-Path -LiteralPath $p)) {
        $failures.Add("missing policy: kubernetes/policies/$policy")
    }
}

$scenarioRoot = Join-Path $Root 'kubernetes/scenarios'
$scenarios = @('crashloop', 'readiness-fail', 'dns-fail', 'networkpolicy-deny', 'resource-pressure')
foreach ($name in $scenarios) {
  foreach ($suffix in @('.md', '-inject.sh', '-restore.sh')) {
    $p = Join-Path $scenarioRoot "$name$suffix"
    if (-not (Test-Path -LiteralPath $p)) {
      $failures.Add("missing scenario artifact: kubernetes/scenarios/$name$suffix")
    }
  }
}

if ($failures.Count -gt 0) {
    Write-Host "ContinuityOps chart tests FAILED ($($failures.Count)):" -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}

Write-Host 'ContinuityOps chart tests passed.' -ForegroundColor Green
exit 0
