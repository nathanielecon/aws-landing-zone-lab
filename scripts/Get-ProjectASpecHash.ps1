[CmdletBinding()]
param([string]$Root = (Join-Path $PSScriptRoot '..'))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = [System.IO.Path]::GetFullPath($Root)
function Get-PortableTextHash([string]$Path) {
    $text=[Text.UTF8Encoding]::new($false,$true).GetString([IO.File]::ReadAllBytes($Path))
    $normalized=$text.Replace("`r`n","`n").Replace("`r","`n")
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($normalized)))
}
$members = @(
    'project-a/PROJECT_A_PLAN.md'
    'project-a/PROJECT_A_ADDITIONS.md'
    'project-a/SOURCES.md'
    'project-a/harness/PRD.template.json'
    'project-a/harness/policy.schema.json'
    'project-a/harness/tool-versions.json'
    'tests/Run-ProjectASpecTests.ps1'
    'scripts/Get-ProjectASpecHash.ps1'
) + @(Get-ChildItem -LiteralPath (Join-Path $Root 'project-a/harness/tasks') -Filter 'A-*.json' | ForEach-Object { "project-a/harness/tasks/$($_.Name)" })

$builder = [System.Text.StringBuilder]::new()
$hashes = [ordered]@{}
foreach ($relative in @($members | Sort-Object -Unique)) {
    $path = Join-Path $Root $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Spec bundle member is missing: $relative" }
    $hash = Get-PortableTextHash -Path $path
    $hashes[$relative] = $hash
    [void]$builder.Append("$relative`0$hash`n")
}
$aggregateBytes = [System.Text.Encoding]::UTF8.GetBytes($builder.ToString())
$aggregate = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($aggregateBytes))
[pscustomobject]@{ schema_version = 'project-a-spec-bundle-v1'; sha256 = $aggregate; members = $hashes } | ConvertTo-Json -Depth 5
