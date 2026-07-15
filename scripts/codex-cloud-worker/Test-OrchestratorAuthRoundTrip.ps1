<#
.SYNOPSIS
  Local smoke for Codex auth gzip inject / write-back (no network).
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-orch-smoke-" + [guid]::NewGuid().ToString('n'))
$h1 = Join-Path $tmp 'h1'
$h2 = Join-Path $tmp 'h2'
$h3 = Join-Path $tmp 'h3'
try {
    [System.IO.Directory]::CreateDirectory($h1) | Out-Null
    $auth1 = Join-Path $h1 'auth.json'
    $payload = @{
        auth_mode    = 'chatgpt'
        tokens       = @{
            access_token  = 'test-access'
            refresh_token = 'test-refresh-token-value'
            id_token      = 'test-id'
        }
        last_refresh = '2026-07-01T00:00:00.000Z'
    } | ConvertTo-Json -Compress -Depth 5
    [System.IO.File]::WriteAllText($auth1, $payload, [System.Text.UTF8Encoding]::new($false))

    $env:CODEX_HOME = $h1
    $gzb64 = & (Join-Path $here 'Export-CodexAuthGzB64.ps1')
    if ($gzb64.Length -gt 4096) { throw "gzb64 too large: $($gzb64.Length)" }

    $env:CODEX_AUTH_JSON_GZB64 = $gzb64
    & (Join-Path $here 'Install-CodexAuthFromEnv.ps1') -CodexHome $h2 -Force
    $art = Join-Path $tmp 'out.gzb64'
    & (Join-Path $here 'Export-CodexAuthArtifact.ps1') -CodexHome $h2 -OutputPath $art
    & (Join-Path $here 'Import-CodexAuthWriteback.ps1') -ArtifactPath $art -CodexHome $h3

    $round = Get-Content -LiteralPath (Join-Path $h3 'auth.json') -Raw | ConvertFrom-Json
    if ($round.auth_mode -ne 'chatgpt') { throw 'auth_mode mismatch' }
    if ([string]$round.tokens.refresh_token -ne 'test-refresh-token-value') { throw 'refresh_token mismatch' }

    Write-Host 'SMOKE_OK auth_roundtrip (Export → Install → Artifact → Import)'
    exit 0
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue
    Remove-Item Env:CODEX_AUTH_JSON_GZB64 -ErrorAction SilentlyContinue
}
