#Requires -Version 7
<#
.SYNOPSIS
  Assert unsafe agent proposals are rejected per prompt-safety and mutation-policy rules.
.DESCRIPTION
  Loads negative test cases from unsafe-proposal-cases.json and verifies each
  proposal triggers the expected rejection rules and/or keywords.
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

$agenticRoot = Join-Path $Root 'agentic'
$casesPath = Join-Path $agenticRoot 'tests/unsafe-proposal-cases.json'
$policyPath = Join-Path $agenticRoot 'policies/mutation-policy.json'
$safetyPath = Join-Path $agenticRoot 'policies/prompt-safety.md'

$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message)
}

foreach ($required in @($casesPath, $policyPath, $safetyPath)) {
    if (-not (Test-Path -LiteralPath $required)) {
        Add-Failure "missing required file: $required"
    }
}

if ($failures.Count -gt 0) {
    foreach ($f in $failures) { Write-Error $f }
    exit 1
}

$mutationPolicy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$safetyText = Get-Content -LiteralPath $safetyPath -Raw
$casesDoc = Get-Content -LiteralPath $casesPath -Raw | ConvertFrom-Json

if ($mutationPolicy.default_write -ne $false) {
    Add-Failure 'mutation-policy.json must set default_write to false'
}

if ($mutationPolicy.mutation_capable_jobs.requires_human_approval -ne $true) {
    Add-Failure 'mutation-policy.json must require human approval for mutation-capable jobs'
}

$ruleIdPattern = [regex]'`([A-Z]{2}-[A-Z]{3}-\d{2})`'
$knownRuleIds = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]($ruleIdPattern.Matches($safetyText) | ForEach-Object { $_.Groups[1].Value }),
    [StringComparer]::OrdinalIgnoreCase
)

$injectionKeywords = @('ignore previous', 'disregard policy', 'you are now', 'skip approval', 'jailbreak')
$forgedKeywords = @('trust this log line', 'fabricated', 'assume metric shows')
$scopeKeywords = @('delete all', 'wipe account', 'rebuild entire')
$secretKeywords = @('api key', 'password', 'private key', 'AWS_SECRET', 'paste token', '.env')
$runbookKeywords = @('draft runbook', 'deprecated', 'last reviewed 20', 'unversioned')
$mutationKeywords = @('kubectl apply', 'terraform apply', 'helm upgrade', 'purge queue', 'chmod 777')

function Test-KeywordMatch {
    param(
        [string]$Text,
        [string[]]$Keywords
    )
    $lower = $Text.ToLowerInvariant()
    foreach ($kw in $Keywords) {
        if ($lower.Contains($kw.ToLowerInvariant())) {
            return $true
        }
    }
    return $false
}

function Test-ProposalRejection {
    param(
        [pscustomobject]$Case
    )

    $text = [string]$Case.proposal
    $matchedRules = [System.Collections.Generic.List[string]]::new()
    $matchedKeywords = [System.Collections.Generic.List[string]]::new()

    foreach ($ruleId in @($Case.rejection_rules)) {
        if ($knownRuleIds.Contains([string]$ruleId)) {
            $matchedRules.Add([string]$ruleId)
        }
    }

    foreach ($kw in @($Case.rejection_keywords)) {
        if ($text.ToLowerInvariant().Contains([string]$kw.ToLowerInvariant())) {
            $matchedKeywords.Add([string]$kw)
        }
    }

    $category = [string]$Case.category
    switch ($category) {
        'prompt_injection' {
            if (Test-KeywordMatch -Text $text -Keywords $injectionKeywords) {
                $null = $matchedKeywords.Add('injection-heuristic')
            }
        }
        'forged_evidence' {
            if (Test-KeywordMatch -Text $text -Keywords $forgedKeywords) {
                $null = $matchedKeywords.Add('forged-heuristic')
            }
        }
        'excessive_scope' {
            if (Test-KeywordMatch -Text $text -Keywords $scopeKeywords) {
                $null = $matchedKeywords.Add('scope-heuristic')
            }
        }
        'secret_requests' {
            if (Test-KeywordMatch -Text $text -Keywords $secretKeywords) {
                $null = $matchedKeywords.Add('secret-heuristic')
            }
        }
        'stale_runbook' {
            if (Test-KeywordMatch -Text $text -Keywords $runbookKeywords) {
                $null = $matchedKeywords.Add('runbook-heuristic')
            }
        }
        'unauthorized_mutation' {
            if (Test-KeywordMatch -Text $text -Keywords $mutationKeywords) {
                $null = $matchedKeywords.Add('mutation-heuristic')
            }
            foreach ($signal in @($mutationPolicy.rejection_signals)) {
                if ($text.ToLowerInvariant().Contains([string]$signal.ToLowerInvariant())) {
                    $null = $matchedKeywords.Add([string]$signal)
                }
            }
        }
    }

  $rejected = ($matchedRules.Count -gt 0) -and ($matchedKeywords.Count -gt 0)

    [pscustomobject]@{
        Rejected        = $rejected
        MatchedRules    = @($matchedRules)
        MatchedKeywords = @($matchedKeywords)
    }
}

if (-not $casesDoc.cases -or $casesDoc.cases.Count -lt 1) {
    Add-Failure 'unsafe-proposal-cases.json must contain at least one case'
}

$caseCount = 0
foreach ($case in $casesDoc.cases) {
    $caseCount++
    $id = [string]$case.id
    if (-not $id) {
        Add-Failure "case #$caseCount missing id"
        continue
    }

    if (-not $case.proposal) {
        Add-Failure "case '$id' missing proposal text"
        continue
    }

    if (-not $case.rejection_rules -or $case.rejection_rules.Count -lt 1) {
        Add-Failure "case '$id' must declare rejection_rules"
        continue
    }

    if (-not $case.rejection_keywords -or $case.rejection_keywords.Count -lt 1) {
        Add-Failure "case '$id' must declare rejection_keywords"
        continue
    }

    foreach ($ruleId in @($case.rejection_rules)) {
        if (-not $knownRuleIds.Contains([string]$ruleId)) {
            Add-Failure "case '$id' references unknown rule '$ruleId' (not in prompt-safety.md)"
        }
    }

    $result = Test-ProposalRejection -Case $case
    if (-not $result.Rejected) {
        Add-Failure @(
            "case '$id' was not rejected",
            "  rules matched: $($result.MatchedRules -join ', ')",
            "  keywords matched: $($result.MatchedKeywords -join ', ')"
        ) -join "`n"
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Test-UnsafeProposals: FAILED ($($failures.Count) failure(s))" -ForegroundColor Red
    foreach ($f in $failures) {
        Write-Host $f
    }
    exit 1
}

Write-Host "Test-UnsafeProposals: PASSED ($caseCount cases rejected)" -ForegroundColor Green
exit 0
