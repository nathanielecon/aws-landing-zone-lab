<#
.SYNOPSIS
  Export refreshed ~/.codex/auth.json as a gitignored gzip-b64 write-back artifact.

.DESCRIPTION
  Writes .harness/runtime/codex-auth-writeback.gzb64 for the local launcher to
  download after an Orchestrator run. Never prints token contents.
#>
[CmdletBinding()]
param(
    [string]$CodexHome = '',

    [string]$OutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($CodexHome)) {
    $CodexHome = if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        $env:CODEX_HOME
    }
    else {
        Join-Path $HOME '.codex'
    }
}

$authPath = Join-Path $CodexHome 'auth.json'
if (-not (Test-Path -LiteralPath $authPath -PathType Leaf)) {
    throw "No auth.json at $authPath to export."
}

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $runtimeDir = Join-Path $root '.harness/runtime'
    [System.IO.Directory]::CreateDirectory($runtimeDir) | Out-Null
    $OutputPath = Join-Path $runtimeDir 'codex-auth-writeback.gzb64'
}

$bytes = [System.IO.File]::ReadAllBytes($authPath)
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

[System.IO.File]::WriteAllText($OutputPath, $b64, [System.Text.UTF8Encoding]::new($false))
Write-Host "Wrote Codex auth write-back artifact to $OutputPath (contents redacted; gitignored)."
