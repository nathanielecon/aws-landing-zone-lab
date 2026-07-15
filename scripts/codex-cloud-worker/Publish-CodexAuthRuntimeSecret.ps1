<#
.SYNOPSIS
  Prepare CODEX_AUTH_JSON_GZB64 for pasting into a Cursor Runtime Secret (no API key).

.DESCRIPTION
  Exports laptop ~/.codex/auth.json as gzip+base64 and prints Cursor UI steps to
  store it as Runtime Secret CODEX_AUTH_JSON_GZB64. Primary Orchestrator path —
  does not use CURSOR_API_KEY or the SDK launcher.

.PARAMETER ShowValue
  Print the gzb64 on stdout (default: write to a temp file outside the repo).

.PARAMETER CopyToClipboard
  On Windows, copy the gzb64 to the clipboard via Set-Clipboard.
#>
[CmdletBinding()]
param(
    [switch]$ShowValue,

    [switch]$CopyToClipboard
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$export = Join-Path $PSScriptRoot 'Export-CodexAuthGzB64.ps1'
if (-not (Test-Path -LiteralPath $export -PathType Leaf)) {
    throw "Missing $export"
}

$gzb64 = (& $export).Trim()
if ([string]::IsNullOrWhiteSpace($gzb64)) {
    throw 'Export produced an empty value. Run local: codex login'
}
if ($gzb64.Length -gt 4096) {
    Write-Host "WARNING: value length $($gzb64.Length) exceeds 4096 bytes (SDK envVars limit). Dashboard Runtime Secrets usually accept larger values; keep using gzb64."
}

$tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ('CODEX_AUTH_JSON_GZB64-' + [guid]::NewGuid().ToString('n') + '.txt')
[System.IO.File]::WriteAllText($tempPath, $gzb64, [System.Text.UTF8Encoding]::new($false))

if ($CopyToClipboard) {
    if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
        Set-Clipboard -Value $gzb64
        Write-Host 'Copied CODEX_AUTH_JSON_GZB64 to clipboard (Windows).'
    }
    else {
        Write-Host 'Set-Clipboard not available; use the temp file path below.'
    }
}

Write-Host ''
Write-Host '=== Cursor Runtime Secret setup (no CURSOR_API_KEY) ==='
Write-Host '1. Confirm local ChatGPT auth:  codex login status'
Write-Host '2. Open Cursor Dashboard → Cloud Agents / Secrets:'
Write-Host '   https://cursor.com/dashboard'
Write-Host '3. Create or update a Runtime Secret (redacted from transcripts):'
Write-Host '   Name:  CODEX_AUTH_JSON_GZB64'
Write-Host '   Type:  Runtime Secret'
Write-Host '   Value: paste contents of the temp file (or clipboard if used)'
Write-Host '4. Prefer scoping the secret to this repo''s Orchestrator-capable environment.'
Write-Host '5. Start a Cloud Agent in the Cursor UI; paste the prompt from:'
Write-Host '   scripts/cursor-cloud-worker/ORCHESTRATOR_UI_PROMPT.md'
Write-Host '6. Only one Orchestrator session should bootstrap/refresh this secret at a time.'
Write-Host '7. After auth refresh / write-back, re-run this script and update the same secret.'
Write-Host ''
Write-Host "Secret value written to temp file (not in repo): $tempPath"
Write-Host 'Delete that file after pasting into the dashboard.'

if ($ShowValue) {
    Write-Output $gzb64
}
else {
    Write-Host 'Value not printed (pass -ShowValue to echo, or -CopyToClipboard on Windows).'
}

exit 0
