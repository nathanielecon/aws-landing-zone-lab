# Offline SCP attachment fail-closed assert (BC-ORG-01).
# Rejects known-bad organization-root and account-ID attachment samples without AWS.
# Run: pwsh -NoLogo -NoProfile -File platform/tests/governance/Assert-ScpAttachmentNegatives.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $here '../../..'))
$variablesPath = Join-Path $repoRoot 'platform/terraform/organization/variables.tf'
$fixturePath = Join-Path $here 'fixtures/known-bad-scp-root-attachment.json'
$tftestPath = Join-Path $here 'organization.tftest.hcl'

if (-not (Test-Path -LiteralPath $variablesPath -PathType Leaf)) {
    throw "Missing organization variables: $variablesPath"
}
if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
    throw "Missing known-bad SCP fixture: $fixturePath"
}
if (-not (Test-Path -LiteralPath $tftestPath -PathType Leaf)) {
    throw "Missing governance tftest: $tftestPath"
}

$variablesText = Get-Content -Raw -LiteralPath $variablesPath
$allowlistPattern = 'contains\(\[\s*"Security"\s*,\s*"Infrastructure"\s*,\s*"Workloads"\s*\]'
if ($variablesText -notmatch $allowlistPattern) {
    throw 'FAIL OPEN: scp_attachments validation no longer restricts targets to Security/Infrastructure/Workloads OUs.'
}

$fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
$allowedOus = @('Security', 'Infrastructure', 'Workloads')
$badTargets = @($fixture.scp_attachments.PSObject.Properties | ForEach-Object { [string]$_.Value })
if ($badTargets.Count -eq 0) {
    throw 'Known-bad fixture must declare at least one scp_attachments target.'
}

foreach ($target in $badTargets) {
    if ($allowedOus -contains $target) {
        throw "FAIL OPEN: known-bad target '$target' is in the approved OU allowlist."
    }
}

$tftestText = Get-Content -Raw -LiteralPath $tftestPath
foreach ($required in @(
        'rejects_root_scp_attachment',
        'rejects_account_id_scp_attachment',
        'expect_failures\s*=\s*\[var\.scp_attachments\]'
    )) {
    if ($tftestText -notmatch $required) {
        throw "Governance tftest missing fail-closed coverage: $required"
    }
}

Write-Output 'PASS: known-bad SCP root/account attachment samples fail closed against OU allowlist.'
