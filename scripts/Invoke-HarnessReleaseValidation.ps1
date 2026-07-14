[CmdletBinding()]
param(
    [string]$Root = (Join-Path $PSScriptRoot '..')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = [System.IO.Path]::GetFullPath($Root)

# Capture incoming CI / strict-pin mode before this script forces CI=1 for suites.
# HARNESS_STRICT_PINS=1 matches CI fail-closed terraform/ralphy pin checks on a fresh machine.
$strictPins = ($env:CI -eq '1') -or ($env:HARNESS_STRICT_PINS -eq '1')

$pinsPath = Join-Path $Root 'project-a/harness/tool-versions.json'
$expected = [ordered]@{
    terraform = '1.15.5'
    ralphy    = '4.7.2'
    node      = '24'
}
if (Test-Path -LiteralPath $pinsPath -PathType Leaf) {
    $pins = Get-Content -Raw -LiteralPath $pinsPath | ConvertFrom-Json
    if ($pins.PSObject.Properties.Name -contains 'terraform' -and $pins.terraform) { $expected.terraform = [string]$pins.terraform }
    if ($pins.PSObject.Properties.Name -contains 'ralphy' -and $pins.ralphy) { $expected.ralphy = [string]$pins.ralphy }
    Write-Host "Loaded tool pins from project-a/harness/tool-versions.json (terraform=$($expected.terraform), ralphy=$($expected.ralphy); Node expected major $($expected.node))."
} else {
    Write-Host "project-a/harness/tool-versions.json missing; expecting Terraform $($expected.terraform), ralphy $($expected.ralphy), Node $($expected.node)."
}

$toolState = [ordered]@{
    terraform = [ordered]@{ actual = $null; mismatch = $false; available = $false }
    ralphy    = [ordered]@{ actual = $null; mismatch = $false; available = $false }
    node      = [ordered]@{ actual = $null; mismatch = $false; available = $false }
}

function Write-ToolCheck {
    param([string]$Name, [string]$Expected, [scriptblock]$Probe)
    try {
        $actual = & $Probe
        if ([string]::IsNullOrWhiteSpace([string]$actual)) {
            Write-Warning "$Name not available locally (expected $Expected)."
            $script:toolState[$Name].mismatch = $true
            return
        }
        $script:toolState[$Name].available = $true
        $script:toolState[$Name].actual = [string]$actual
        Write-Host "${Name}: $actual (expected $Expected)"
    } catch {
        Write-Warning "$Name not available locally (expected $Expected): $($_.Exception.Message)"
        $script:toolState[$Name].mismatch = $true
    }
}

Write-ToolCheck -Name 'terraform' -Expected $expected.terraform -Probe {
    $tf = Get-Command terraform -ErrorAction Stop
    (& $tf.Source version -json 2>$null | ConvertFrom-Json).terraform_version
}
Write-ToolCheck -Name 'ralphy' -Expected $expected.ralphy -Probe {
    $cmd = Get-Command ralphy, ralphy.cmd -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { return $null }
    $out = & $cmd.Source --version 2>&1 | Out-String
    return ($out -replace '\s+', ' ').Trim()
}
Write-ToolCheck -Name 'node' -Expected "major $($expected.node)" -Probe {
    $node = Get-Command node -ErrorAction Stop
    (& $node.Source -v).Trim()
}

if ($toolState.terraform.available) {
    $tfActual = [string]$toolState.terraform.actual
    if ($tfActual -ne [string]$expected.terraform) {
        $toolState.terraform.mismatch = $true
    }
}
if ($toolState.ralphy.available) {
    $ralphyActual = [string]$toolState.ralphy.actual
    if ($ralphyActual -notlike "*$($expected.ralphy)*") {
        $toolState.ralphy.mismatch = $true
    }
}
if ($toolState.node.available) {
    $nodeActual = [string]$toolState.node.actual
    $nodeMajor = if ($nodeActual -match 'v?(\d+)') { $Matches[1] } else { '' }
    if ($nodeMajor -ne [string]$expected.node) {
        $toolState.node.mismatch = $true
    }
}

if ($strictPins) {
    $pinFailures = @()
    if ($toolState.terraform.mismatch) {
        $pinFailures += "terraform pin mismatch: actual='$($toolState.terraform.actual)' expected='$($expected.terraform)' (major.minor.patch must match)"
    }
    if ($toolState.ralphy.mismatch) {
        $pinFailures += "ralphy pin mismatch: actual='$($toolState.ralphy.actual)' must contain expected version string '$($expected.ralphy)'"
    }
    if ($toolState.node.mismatch) {
        # Node remains warn-only under CI / HARNESS_STRICT_PINS unless terraform and ralphy also mismatch.
        Write-Warning "node major mismatch: actual='$($toolState.node.actual)' expected major $($expected.node) (warning only; terraform/ralphy are fail-closed)"
    }
    if ($pinFailures.Count -gt 0) {
        Write-Host "Harness release validation FAILED (strict tool pin; CI=1 or HARNESS_STRICT_PINS=1):"
        foreach ($failure in $pinFailures) { Write-Host "  - $failure" }
        exit 1
    }
} elseif ($toolState.node.mismatch) {
    Write-Warning "node major mismatch: actual='$($toolState.node.actual)' expected major $($expected.node)"
}

Write-Host 'Verifying Project A bundle / execution approval pins ...'
& pwsh -NoLogo -NoProfile -File (Join-Path $Root 'scripts/Verify-ProjectABundle.ps1') -Root $Root
if ($LASTEXITCODE -ne 0) {
    Write-Host "Verify-ProjectABundle failed (exit $LASTEXITCODE)."
    exit 1
}

$env:CI = '1'
$env:HARNESS_CONTRACT_ONLY = '1'

$suites = @(
    'tests/Run-ContractTests.ps1'
    'tests/Run-ProjectASpecTests.ps1'
    'tests/Run-ProjectAHarnessTests.ps1'
)
$failed = 0
foreach ($relative in $suites) {
    $path = Join-Path $Root $relative
    Write-Host "Running $relative ..."
    & pwsh -NoLogo -NoProfile -File $path
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Suite failed: $relative (exit $LASTEXITCODE)"
        $failed++
    }
}

if ($failed -gt 0) {
    Write-Host "Harness release validation FAILED ($failed suite(s))."
    exit 1
}
Write-Host 'Harness release validation PASSED.'
exit 0
