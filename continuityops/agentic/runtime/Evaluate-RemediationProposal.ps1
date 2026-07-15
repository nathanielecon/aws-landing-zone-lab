#Requires -Version 7
<#
.SYNOPSIS
  Executable ContinuityOps agentic gate: evaluate remediation proposal text.
  Rejects unsafe proposals. Never mutates cloud resources.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Proposal,
    [string]$Root = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Root) {
    $probe = $PSScriptRoot
    while ($probe -and -not (Test-Path (Join-Path $probe '.git'))) {
        $parent = Split-Path $probe -Parent
        if (-not $parent -or $parent -eq $probe) { break }
        $probe = $parent
    }
    if (-not (Test-Path (Join-Path $probe '.git'))) { throw 'repo root not found' }
    $Root = $probe
}

$casesPath = Join-Path $Root 'continuityops/agentic/tests/unsafe-proposal-cases.json'
$policyPath = Join-Path $Root 'continuityops/agentic/policies/mutation-policy.json'
$cases = Get-Content -LiteralPath $casesPath -Raw -Encoding utf8 | ConvertFrom-Json
$policy = Get-Content -LiteralPath $policyPath -Raw -Encoding utf8 | ConvertFrom-Json

$rejected = [System.Collections.Generic.List[object]]::new()
$propLower = $Proposal.ToLowerInvariant()
foreach ($c in @($cases.cases)) {
    foreach ($kw in @($c.rejection_keywords)) {
        if ($propLower.Contains([string]$kw.ToLowerInvariant())) {
            $rejected.Add([ordered]@{ case_id = $c.id; rules = @($c.rejection_rules) })
            break
        }
    }
}

$mutationHints = @('kubectl apply', 'terraform apply', 'helm upgrade', 'aws ec2 terminate', 'wipe account', 'delete all')
$mutationHit = @($mutationHints | Where-Object { $propLower.Contains($_) })

$defaultWrite = $false
if ($null -ne $policy.default_write) { $defaultWrite = [bool]$policy.default_write }

$decision = if ($rejected.Count -gt 0 -or $mutationHit.Count -gt 0 -or $defaultWrite) {
    if ($defaultWrite) { 'reject' } elseif ($rejected.Count -gt 0 -or $mutationHit.Count -gt 0) { 'reject' } else { 'allow_proposal_only' }
} else {
    'allow_proposal_only'
}
# Force: default_write true would be a policy bug → reject
if ($defaultWrite) { $decision = 'reject' }

$result = [ordered]@{
    schema_version     = 'continuityops-proposal-evaluation-v1'
    decision           = $decision
    default_write      = $defaultWrite
    mutation_allowed   = $false
    matched_cases      = @($rejected)
    mutation_hints     = @($mutationHit)
    note               = 'Proposal-only gate. Never performs cloud mutation.'
}
($result | ConvertTo-Json -Depth 10)
if ($decision -eq 'reject') { exit 2 }
exit 0
