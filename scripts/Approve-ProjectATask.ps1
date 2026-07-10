[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^A-00[1-7]$')][string]$TaskId,
    [string]$Root = (Join-Path $PSScriptRoot '..')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.Common.psm1') -Force
$Root = [System.IO.Path]::GetFullPath($Root)
$localBase = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $env:USERPROFILE 'AppData/Local' }
$approvalRoot = Join-Path $localBase 'RalphyHarness/cloud/approvals/project-a'
$requestPath = Join-Path $approvalRoot "requests/$TaskId.json"
$receiptPath = Join-Path $approvalRoot "receipts/$TaskId.json"
$keyPath = Join-Path $approvalRoot "keys/$TaskId.dpapi"
$request = Read-JsonFile -Path $requestPath
if ([string]$request.task_id -ne $TaskId) { throw 'Approval request task mismatch.' }
$policy = Read-JsonFile -Path (Join-Path $Root "project-a/harness/tasks/$TaskId.json")
$diff = Get-CanonicalDiffRecord -Root $Root -AllowedPaths @($policy.allowed_paths) -AdapterOwnedPaths @($policy.adapter_owned_paths)
$branch = (& git -C $Root branch --show-current).Trim(); $head = (& git -C $Root rev-parse HEAD).Trim()
if ($branch -ne [string]$request.branch -or $head -ne [string]$request.head -or $diff.sha256 -ne [string]$request.diff_sha256) { throw 'Approval request no longer matches branch, HEAD, or exact diff.' }
$confirmation = if ($env:HARNESS_CONTRACT_ONLY -eq '1' -and $env:HARNESS_APPROVE_TASK) {
    [string]$env:HARNESS_APPROVE_TASK
} else {
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected -or -not [Environment]::UserInteractive) { throw 'Human approval requires an interactive, non-redirected console.' }
    Read-Host "Type APPROVE:$TaskId to approve the exact validated diff"
}
if ($confirmation -ne "APPROVE:$TaskId") { throw 'Approval cancelled.' }

$payload = [ordered]@{
    schema_version = 'project-a-approval-v1'; decision = 'approved'; task_id = $TaskId; gate_id = [string]$request.gate_id
    execution_bundle_sha256 = [string]$request.execution_bundle_sha256; validator_implementation_sha256 = [string]$request.validator_implementation_sha256; policy_sha256 = [string]$request.policy_sha256
    branch = $branch; starting_commit = [string]$request.starting_commit; head = $head; diff_sha256 = $diff.sha256; changed_entries = $diff.entries
    validation_digest = [string]$request.validation_digest; request_nonce = [string]$request.request_nonce; approved_at = [DateTimeOffset]::UtcNow.ToString('o')
}
$key = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
$protectedKey = [System.Security.Cryptography.ProtectedData]::Protect($key, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
Write-Utf8NoBom -Path $keyPath -Text ([Convert]::ToBase64String($protectedKey))
$receipt = [ordered]@{ payload = $payload; signature = $null }
Write-JsonNoBom -Path $receiptPath -Value $receipt
$normalized = Read-JsonFile -Path $receiptPath
$receipt.signature = Get-HmacSha256 -Key $key -Text ($normalized.payload | ConvertTo-Json -Compress -Depth 10)
Write-JsonNoBom -Path $receiptPath -Value $receipt
Write-Host "Approved $TaskId. Resume with: .\scripts\Start-ProjectAHarness.ps1 -Resume"
