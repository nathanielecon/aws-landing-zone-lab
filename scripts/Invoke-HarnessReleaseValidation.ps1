[CmdletBinding()]
param(
    [string]$Root = (Join-Path $PSScriptRoot '..')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = [System.IO.Path]::GetFullPath($Root)

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

function Write-ToolCheck {
    param([string]$Name, [string]$Expected, [scriptblock]$Probe)
    try {
        $actual = & $Probe
        if ([string]::IsNullOrWhiteSpace([string]$actual)) {
            Write-Warning "$Name not available locally (expected $Expected)."
            return
        }
        Write-Host "${Name}: $actual (expected $Expected)"
    } catch {
        Write-Warning "$Name not available locally (expected $Expected): $($_.Exception.Message)"
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
