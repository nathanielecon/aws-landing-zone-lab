[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Resume,
    [switch]$ResetSmoke
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.Common.psm1') -Force

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error 'PowerShell 7 is required. Run from an elevated shell: choco install powershell-core -y --no-progress'
    exit 10
}

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$runtimeRoot = Join-Path $root '.harness/runtime'
$manifestTemplate = Join-Path $root 'harness/PRD.template.json'
$manifestPath = Join-Path $runtimeRoot 'PRD.json'
$approvalPath = Join-Path $root 'harness/plan-approval.json'
$versionsPath = Join-Path $root 'harness/tool-versions.json'
$lockPath = Join-Path $runtimeRoot 'harness.lock'
$adapterDir = Join-Path $root '.harness/bin'
$stopFlag = Join-Path $runtimeRoot 'stop.flag'
$pwshPath = 'C:\Program Files\PowerShell\7\pwsh.exe'

if (-not (Test-Path -LiteralPath $pwshPath)) { throw 'PowerShell 7 is missing. Run elevated: choco install powershell-core -y --no-progress' }
if ((& git -C $root rev-parse --show-toplevel).Trim() -ne ($root -replace '\\', '/')) { throw "Unexpected Git root: $root" }
$branch = (& git -C $root branch --show-current).Trim()
if ($branch -ne 'codex/ralphy-harness') { throw "Expected branch codex/ralphy-harness; current branch is $branch" }

$system32 = Join-Path $env:SystemRoot 'System32'
if (-not (($env:PATH -split ';') -contains $system32)) { $env:PATH = "$system32;$env:PATH" }
$realCodexCommand = Get-Command codex.cmd -All -ErrorAction Stop | Where-Object { -not ([System.IO.Path]::GetFullPath($_.Source)).StartsWith([System.IO.Path]::GetFullPath($adapterDir), [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
$realRalphyCommand = Get-Command ralphy.cmd -All -ErrorAction Stop | Select-Object -First 1
if (-not $realCodexCommand) { throw 'Unable to resolve the real codex.cmd before adapter activation.' }
$realCodex = [System.IO.Path]::GetFullPath($realCodexCommand.Source)
$realRalphy = [System.IO.Path]::GetFullPath($realRalphyCommand.Source)

$approval = Read-JsonFile -Path $approvalPath
$actualPlanHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $root 'PLAN.md')).Hash
if ($actualPlanHash -ne [string]$approval.plan_sha256) { throw 'PLAN.md does not match the approved SHA-256.' }
$versions = Read-JsonFile -Path $versionsPath
$codexVersion = (& $realCodex --version 2>&1 | Out-String).Trim()
$ralphyVersion = (& $realRalphy --version 2>&1 | Out-String).Trim()
$nodeVersion = (& node --version 2>&1 | Out-String).Trim()
$gitVersion = (& git --version 2>&1 | Out-String).Trim()
if ($codexVersion -notmatch [string]$versions.codex_regex) { throw "Unsupported Codex version: $codexVersion" }
if ($ralphyVersion -ne [string]$versions.ralphy) { throw "Unsupported Ralphy version: $ralphyVersion" }
if ($nodeVersion -notmatch [string]$versions.node_regex) { throw "Unsupported Node version: $nodeVersion" }
if ($gitVersion -notmatch [string]$versions.git_regex) { throw "Unsupported Git version: $gitVersion" }
$loginText = (& $realCodex login status 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $loginText -notmatch 'Logged in using ChatGPT') { throw 'Codex is not authenticated with ChatGPT. Run: codex login' }

if ($ResetSmoke) {
    $confirmation = if ($env:HARNESS_CONFIRM_RESET -eq 'RESET') { 'RESET' } else { Read-Host 'Type RESET to clear only interrupted smoke fixtures and runtime state' }
    if ($confirmation -ne 'RESET') { throw 'Smoke reset cancelled.' }
    $completedSmokeCommit = & git -C $root log --format=%s --grep='^test(S-00[12])' -1
    if ($completedSmokeCommit) { throw 'Completed smoke commits exist. Start a fresh branch from main instead of rewriting validated history.' }
    foreach ($relative in @('smoke/terra.txt', 'smoke/takeover.txt', 'evidence/S-001.json', 'evidence/S-002.json')) {
        $full = [System.IO.Path]::GetFullPath((Join-Path $root $relative))
        if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe reset path: $full" }
        & git -C $root restore --staged -- $relative 2>$null
        if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Force }
    }
    if (Test-Path -LiteralPath $runtimeRoot) {
        $resolvedRuntime = [System.IO.Path]::GetFullPath($runtimeRoot)
        if (-not $resolvedRuntime.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe runtime path: $resolvedRuntime" }
        Remove-Item -LiteralPath $resolvedRuntime -Recurse -Force
    }
    Write-Host 'Interrupted smoke state cleared.'
    exit 0
}

$lock = Open-ExclusiveLock -Path $lockPath
try {
    $changed = @(Get-ChangedPaths -Root $root)
    if (-not $Resume -and $changed.Count -gt 0) { throw "Normal launch requires a clean tree; use -Resume only for owned interrupted changes: $($changed -join ', ')" }
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        [System.IO.Directory]::CreateDirectory($runtimeRoot) | Out-Null
        Copy-Item -LiteralPath $manifestTemplate -Destination $manifestPath
    } elseif (-not $Resume -and -not $DryRun) {
        $existing = Read-JsonFile -Path $manifestPath
        if (@($existing.tasks | Where-Object { $_.completed }).Count -gt 0) { throw 'A prior smoke run exists. Use -Resume or -ResetSmoke.' }
    }
    if ($Resume -and (Test-Path -LiteralPath $stopFlag)) { Remove-Item -LiteralPath $stopFlag -Force }
    if (-not $Resume -and (Test-Path -LiteralPath $stopFlag)) { throw 'A prior adapter failure exists. Use -Resume after reviewing its evidence.' }

    $runId = [DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $localBase = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $env:USERPROFILE 'AppData/Local' }
    $logRoot = Join-Path $localBase "RalphyHarness/cloud/$runId"
    [System.IO.Directory]::CreateDirectory($logRoot) | Out-Null
    $env:HARNESS_ROOT = $root
    $env:HARNESS_REAL_CODEX = $realCodex
    $env:HARNESS_RUN_ID = $runId
    $env:HARNESS_LOG_DIR = $logRoot
    $env:HARNESS_PLAN_HASH = $actualPlanHash
    $env:HARNESS_MANIFEST_PATH = $manifestPath
    $env:PATH = "$adapterDir;$env:PATH"

    $ralphyArguments = @('--codex', '--json', $manifestPath, '--model', 'gpt-5.6-terra', '--max-retries', '0', '--no-commit', '--no-tests', '--no-lint', '--no-browser')
    if ($DryRun) { $ralphyArguments += @('--dry-run', '--max-iterations', '2') }
    Write-Host "Run ID: $runId"
    Write-Host "Sanitized logs: $logRoot"
    & $realRalphy @ralphyArguments
    $ralphyExit = $LASTEXITCODE
    $manifest = Sync-RalphyManifestWithTaskState -Root $root -ManifestPath $manifestPath
    if ($ralphyExit -ne 0) {
        Write-Host "Ralphy stopped with exit code $ralphyExit. Resume with:"
        Write-Host "  & '$PSCommandPath' -Resume"
        exit 30
    }
    if ($DryRun) { Write-Host 'Dry run completed; no model was invoked.'; exit 0 }

    $incomplete = @($manifest.tasks | Where-Object { -not $_.completed })
    if ($incomplete.Count -gt 0) { throw "Ralphy exited successfully with incomplete tasks: $($incomplete.title -join ', ')" }
    foreach ($forbidden in @('.ralphy-worktrees', '.ralphy-sandboxes')) {
        if (Test-Path -LiteralPath (Join-Path $root $forbidden)) { throw "Forbidden isolation directory was created: $forbidden" }
    }
    $finalChanges = @(Get-ChangedPaths -Root $root)
    if ($finalChanges.Count -gt 0) { throw "Smoke run ended with a dirty tree: $($finalChanges -join ', ')" }
    $states = foreach ($id in @('S-001', 'S-002')) { Read-JsonFile -Path (Join-Path $runtimeRoot "state/$id.json") }
    Write-JsonNoBom -Path (Join-Path $logRoot 'run-summary.json') -Value ([ordered]@{ run_id = $runId; plan_hash = $actualPlanHash; status = 'completed'; branch = $branch; ralphy_processes = 1; worktrees = 0; tasks = @($states | Select-Object task_id, terra_attempts, sol_attempts, commit_sha, completed_at) })
    Write-Host 'Local smoke proof passed: one Ralphy loop, Terra first, forced Sol takeover, clean tree.'
} finally {
    if ($lock) { $lock.Dispose() }
}
