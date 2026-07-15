<#
.SYNOPSIS
  Apply a gzip-b64 write-back artifact onto local ~/.codex/auth.json.

.PARAMETER ArtifactPath
  Path to codex-auth-writeback.gzb64 (or any gzb64 auth blob).

.PARAMETER CodexHome
  Codex home directory (default: ~/.codex).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ArtifactPath,

    [string]$CodexHome = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ArtifactPath -PathType Leaf)) {
    throw "Artifact not found: $ArtifactPath"
}

if ([string]::IsNullOrWhiteSpace($CodexHome)) {
    $CodexHome = if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        $env:CODEX_HOME
    }
    else {
        Join-Path $HOME '.codex'
    }
}

$gzb64 = [System.IO.File]::ReadAllText($ArtifactPath).Trim()
$compressed = [Convert]::FromBase64String($gzb64)
$inMs = [System.IO.MemoryStream]::new($compressed)
$gz = [System.IO.Compression.GzipStream]::new($inMs, [System.IO.Compression.CompressionMode]::Decompress)
$outMs = [System.IO.MemoryStream]::new()
try {
    $gz.CopyTo($outMs)
}
finally {
    $gz.Dispose()
    $inMs.Dispose()
}
$jsonBytes = $outMs.ToArray()
$outMs.Dispose()

$text = [System.Text.Encoding]::UTF8.GetString($jsonBytes)
$obj = $text | ConvertFrom-Json
if ([string]$obj.auth_mode -ne 'chatgpt') {
    throw "Write-back auth_mode is '$($obj.auth_mode)'; expected chatgpt."
}

[System.IO.Directory]::CreateDirectory($CodexHome) | Out-Null
$authPath = Join-Path $CodexHome 'auth.json'
[System.IO.File]::WriteAllBytes($authPath, $jsonBytes)
if ($IsLinux -or $IsMacOS) {
    & chmod 700 $CodexHome 2>$null
    & chmod 600 $authPath 2>$null
}
Write-Host "Imported refreshed ChatGPT auth into $authPath (tokens redacted)."
Write-Host 'If you also store CODEX_AUTH_JSON_GZB64 as a Cursor Dashboard Runtime Secret, refresh that secret from a new Export-CodexAuthGzB64.ps1 run.'
