<#
.SYNOPSIS
  Compress laptop ~/.codex/auth.json to gzip+base64 for Orchestrator inject.

.DESCRIPTION
  Writes ONLY the gzb64 string to stdout. Never logs token contents.
  Used by Invoke-CursorCloudWorker.ps1 -Role Orchestrator.

.PARAMETER AuthPath
  Path to auth.json (default: $HOME/.codex/auth.json or $CODEX_HOME/auth.json).
#>
[CmdletBinding()]
param(
    [string]$AuthPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($AuthPath)) {
    $codexHome = if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        $env:CODEX_HOME
    }
    else {
        Join-Path $HOME '.codex'
    }
    $AuthPath = Join-Path $codexHome 'auth.json'
}

if (-not (Test-Path -LiteralPath $AuthPath -PathType Leaf)) {
    throw "Codex auth file not found: $AuthPath (run local 'codex login' first)."
}

$bytes = [System.IO.File]::ReadAllBytes($AuthPath)
$ms = [System.IO.MemoryStream]::new()
$gz = [System.IO.Compression.GzipStream]::new(
    $ms,
    [System.IO.Compression.CompressionLevel]::Optimal
)
try {
    $gz.Write($bytes, 0, $bytes.Length)
}
finally {
    $gz.Dispose()
}
$b64 = [Convert]::ToBase64String($ms.ToArray())
$ms.Dispose()

if ($b64.Length -gt 4096) {
    throw "CODEX_AUTH_JSON_GZB64 length $($b64.Length) exceeds Cursor SDK envVars 4096-byte limit."
}

# Pipeline output only — callers must not Write-Host this value
Write-Output $b64
