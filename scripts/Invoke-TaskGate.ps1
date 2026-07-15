[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][string]$PolicyPath,
    [Parameter(Mandatory)][ValidateSet('terra', 'sol')][string]$Phase,
    [switch]$ForceAlreadyApplied
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.Common.psm1') -Force

try {
    $policy = Read-JsonFile -Path $PolicyPath
    $allowed = @($policy.allowed_paths | ForEach-Object { [string]$_ })
    $runtimeExcluded = @(Get-HarnessLifecycleExcludedPaths -Root $Root -ProfileId 'smoke')
    $changed = @(Assert-OnlyAllowedChanges -Root $Root -AllowedPaths $allowed -ExcludedPaths $runtimeExcluded)
    if ($changed.Count -eq 0) { throw 'NO_MEANINGFUL_DIFF: no allowlisted task change exists' }

    $relativePath = [string]$policy.gate.path
    $fullPath = Join-Path $Root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw "MISSING_FIXTURE: $relativePath" }
    $expectedText = if ($Phase -eq 'sol') { [string]$policy.gate.sol_content } else { [string]$policy.gate.terra_content }
    $expected = [System.Text.UTF8Encoding]::new($false).GetBytes($expectedText)
    $actual = [System.IO.File]::ReadAllBytes($fullPath)
    if (-not [System.Linq.Enumerable]::SequenceEqual[byte]($actual, $expected)) { throw "EXACT_CONTENT_MISMATCH: $relativePath" }

    if ($Phase -eq 'terra' -and [bool]$policy.force_smoke_escalation -and -not $ForceAlreadyApplied) {
        [pscustomobject]@{ passed = $false; error_class = 'SMOKE_FORCE_SOL'; message = 'Synthetic smoke gate requires Sol takeover.'; changed_paths = $changed } | ConvertTo-Json -Compress
        exit 2
    }

    [pscustomobject]@{ passed = $true; error_class = $null; message = 'All deterministic gates passed.'; changed_paths = $changed } | ConvertTo-Json -Compress
    exit 0
} catch {
    $message = $_.Exception.Message
    $errorClass = if ($message -match '^(?<class>[A-Z_]+):') { $Matches.class } elseif ($message -like 'Changed paths outside*') { 'SCOPE_ESCAPE' } else { 'GATE_EXCEPTION' }
    [pscustomobject]@{ passed = $false; error_class = $errorClass; message = $message; changed_paths = @() } | ConvertTo-Json -Compress
    exit 1
}
