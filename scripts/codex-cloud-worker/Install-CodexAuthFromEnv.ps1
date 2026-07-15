<#
.SYNOPSIS
  Bootstrap ~/.codex/auth.json from CODEX_AUTH_JSON_GZB64 (Orchestrator VM).

.DESCRIPTION
  Decodes the gzip+base64 ChatGPT auth blob injected via Cursor Cloud env vars /
  Runtime Secrets. Configures file-backed credential storage. Never prints tokens.
#>
[CmdletBinding()]
param(
    [string]$CodexHome = '',

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gzb64 = [string]$env:CODEX_AUTH_JSON_GZB64
if ([string]::IsNullOrWhiteSpace($gzb64)) {
    throw 'CODEX_AUTH_JSON_GZB64 is not set. Launch with Invoke-CursorCloudWorker.ps1 -Role Orchestrator (or set a Cursor Runtime Secret).'
}

if ([string]::IsNullOrWhiteSpace($CodexHome)) {
    $CodexHome = if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        $env:CODEX_HOME
    }
    else {
        Join-Path $HOME '.codex'
    }
}

$authPath = Join-Path $CodexHome 'auth.json'
$configPath = Join-Path $CodexHome 'config.toml'

if ((Test-Path -LiteralPath $authPath -PathType Leaf) -and -not $Force) {
    Write-Host "Codex auth already present at $authPath (use -Force to replace)."
}
else {
    [System.IO.Directory]::CreateDirectory($CodexHome) | Out-Null

    $compressed = [Convert]::FromBase64String($gzb64.Trim())
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

    # Validate JSON shape without printing secrets
    $text = [System.Text.Encoding]::UTF8.GetString($jsonBytes)
    $obj = $text | ConvertFrom-Json
    $mode = [string]$obj.auth_mode
    if ($mode -ne 'chatgpt') {
        throw "Injected auth_mode is '$mode'; expected 'chatgpt' (Codex subscription path)."
    }
    if (-not $obj.tokens -or [string]::IsNullOrWhiteSpace([string]$obj.tokens.refresh_token)) {
        throw 'Injected auth.json lacks a ChatGPT refresh_token.'
    }

    [System.IO.File]::WriteAllBytes($authPath, $jsonBytes)
    if ($IsLinux -or $IsMacOS) {
        & chmod 700 $CodexHome 2>$null
        & chmod 600 $authPath 2>$null
    }
    Write-Host "Wrote Codex ChatGPT auth to $authPath (mode=chatgpt; tokens redacted)."
}

# Ensure file-backed store so refresh writes back to auth.json
$configBody = @'
# Managed by Install-CodexAuthFromEnv.ps1 — file store required for CI auth refresh.
cli_auth_credentials_store = "file"
'@
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    [System.IO.File]::WriteAllText($configPath, $configBody + "`n", [System.Text.UTF8Encoding]::new($false))
    Write-Host "Wrote $configPath (cli_auth_credentials_store=file)."
}
else {
    $existing = [System.IO.File]::ReadAllText($configPath)
    if ($existing -notmatch 'cli_auth_credentials_store') {
        [System.IO.File]::AppendAllText($configPath, "`n" + $configBody + "`n")
        Write-Host "Appended cli_auth_credentials_store=file to $configPath."
    }
}

Write-Host 'Codex auth bootstrap complete.'
