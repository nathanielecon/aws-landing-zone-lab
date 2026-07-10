[CmdletBinding()]
param([string]$Root = (Join-Path $PSScriptRoot '..'))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = [System.IO.Path]::GetFullPath($Root)
$spec = & (Join-Path $PSScriptRoot 'Get-ProjectASpecHash.ps1') -Root $Root | ConvertFrom-Json
$members = @($spec.members.psobject.Properties.Name) + @(
    '.harness/bin/codex.cmd',
    'harness/profiles/project-a.json',
    'project-a/HARNESS.md',
    'scripts/Harness.Common.psm1',
    'scripts/Invoke-NativeCodex.ps1',
    'scripts/Invoke-CodexAdapter.ps1',
    'scripts/Invoke-ProjectAAdapter.ps1',
    'scripts/Invoke-ProjectAValidators.ps1',
    'scripts/Approve-ProjectATask.ps1',
    'scripts/Test-ProjectAApproval.ps1',
    'scripts/Start-ProjectAHarness.ps1',
    'scripts/Get-ProjectASpecHash.ps1',
    'scripts/Get-ProjectAExecutionHash.ps1',
    'launcher/Launch Project A Harness.cmd',
    'tests/Run-ProjectAHarnessTests.ps1'
)
$builder=[Text.StringBuilder]::new();$hashes=[ordered]@{}
foreach($relative in @($members|Sort-Object -Unique)){
    $path=Join-Path $Root $relative;if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Execution bundle member missing: $relative"}
    $hash=(Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash;$hashes[$relative]=$hash;[void]$builder.Append("$relative`0$hash`n")
}
$aggregate=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($builder.ToString())))
[pscustomobject]@{schema_version='project-a-execution-bundle-v1';spec_sha256=$spec.sha256;sha256=$aggregate;members=$hashes}|ConvertTo-Json -Depth 5
