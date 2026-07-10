[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][string]$PolicyPath,
    [Parameter(Mandatory)][string]$RequestPath,
    [Parameter(Mandatory)][string]$ReceiptPath,
    [Parameter(Mandatory)][string]$KeyPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.Common.psm1') -Force
try {
    $request = Read-JsonFile -Path $RequestPath; $receipt = Read-JsonFile -Path $ReceiptPath; $policy = Read-JsonFile -Path $PolicyPath
    $protectedKey = [Convert]::FromBase64String((Get-Content -Raw -LiteralPath $KeyPath).Trim())
    $key = [System.Security.Cryptography.ProtectedData]::Unprotect($protectedKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    $payloadJson = $receipt.payload | ConvertTo-Json -Compress -Depth 10
    $expectedSignature = Get-HmacSha256 -Key $key -Text $payloadJson
    if (-not [System.Security.Cryptography.CryptographicOperations]::FixedTimeEquals([Convert]::FromHexString($expectedSignature), [Convert]::FromHexString([string]$receipt.signature))) { throw 'Approval signature mismatch.' }
    $diff = Get-CanonicalDiffRecord -Root $Root -AllowedPaths @($policy.allowed_paths) -AdapterOwnedPaths @($policy.adapter_owned_paths)
    $branch = (& git -C $Root branch --show-current).Trim(); $head = (& git -C $Root rev-parse HEAD).Trim()
    foreach ($binding in @('task_id','gate_id','execution_bundle_sha256','validator_implementation_sha256','policy_sha256','branch','starting_commit','head','diff_sha256','validation_digest','request_nonce')) {
        $expected = if ($binding -eq 'diff_sha256') { $diff.sha256 } elseif ($binding -eq 'branch') { $branch } elseif ($binding -eq 'head') { $head } else { [string]$request.$binding }
        if ([string]$receipt.payload.$binding -ne $expected) { throw "Approval binding mismatch: $binding" }
    }
    [pscustomobject]@{ passed = $true; message = 'Exact diff approval verified.'; receipt_digest = (Get-FileHash -Algorithm SHA256 -LiteralPath $ReceiptPath).Hash } | ConvertTo-Json -Compress
    exit 0
} catch {
    [pscustomobject]@{ passed = $false; message = $_.Exception.Message; receipt_digest = $null } | ConvertTo-Json -Compress
    exit 1
}
