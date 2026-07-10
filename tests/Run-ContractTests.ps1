[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'scripts/Harness.Common.psm1') -Force
$passed = 0

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
    $script:passed++
}

function New-TestRepo([string]$Name) {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) "Ralphy Harness Tests/$Name-$([Guid]::NewGuid().ToString('N'))"
    [System.IO.Directory]::CreateDirectory($path) | Out-Null
    & git -C $path init -b codex/ralphy-harness | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $path 'README.md'), "test`n", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $path '.gitignore'), ".harness/runtime/`n.logs/`nlast message.txt`n.codex-last-message-*`n", [System.Text.UTF8Encoding]::new($false))
    & git -C $path add README.md .gitignore
    & git -C $path commit -m baseline | Out-Null
    return $path
}

$taskId = Get-TaskIdFromArguments -Arguments @('exec', '[TASK:S-001] hello')
Assert-True ($taskId -eq 'S-001') 'task marker extraction'
$safe = @(New-SafeInitialCodexArguments -Arguments @('exec', '--full-auto', '--model', 'wrong', '--dangerously-bypass-approvals-and-sandbox', '--json', '[TASK:S-001]') -Model 'gpt-5.6-terra')
Assert-True ($safe -contains 'workspace-write') 'workspace-write is enforced'
Assert-True (-not ($safe -contains '--full-auto')) 'full-auto is stripped'
Assert-True (-not ($safe -contains '--dangerously-bypass-approvals-and-sandbox')) 'dangerous bypass is stripped'
Assert-True (($safe -join ' ') -match 'gpt-5.6-terra') 'model override is replaced'
$redacted = Protect-LogText -Text 'Authorization: Bearer abc.def token=secretvalue password: hunter2'
Assert-True ($redacted -notmatch 'abc\.def|secretvalue|hunter2') 'credential-shaped text is redacted'
$threshold = { param($Attempts = 1, $Consecutive = 1, $Same = 1, $NoDiff = $false, $Elapsed = 1, $ErrorClass = 'TEST_FAILURE') Test-TerraEscalation -ForceApplied $false -Attempts $Attempts -AttemptLimit 3 -ConsecutiveFailures $Consecutive -SameErrorCount $Same -NoDiff $NoDiff -ElapsedMinutes $Elapsed -ElapsedLimitMinutes 25 -ErrorClass $ErrorClass }
Assert-True (-not (& $threshold)) 'one ordinary failure remains with Terra'
Assert-True (& $threshold -Attempts 3) 'attempt limit escalates'
Assert-True (& $threshold -Consecutive 2) 'consecutive failures escalate'
Assert-True (& $threshold -Same 2) 'repeated error class escalates'
Assert-True (& $threshold -NoDiff $true) 'no meaningful diff escalates'
Assert-True (& $threshold -Elapsed 25) 'elapsed limit escalates'
Assert-True (& $threshold -ErrorClass 'SCOPE_ESCAPE') 'scope escape escalates'

$manifestRepo = New-TestRepo -Name 'manifest reconciliation'
try {
    [System.IO.Directory]::CreateDirectory((Join-Path $manifestRepo '.harness/runtime/state')) | Out-Null
    $manifestPath = Join-Path $manifestRepo '.harness/runtime/PRD.json'
    Write-JsonNoBom -Path $manifestPath -Value ([ordered]@{ tasks = @([ordered]@{ title = '[TASK:S-001] first'; completed = $true }, [ordered]@{ title = '[TASK:S-002] second'; completed = $true }) })
    Write-JsonNoBom -Path (Join-Path $manifestRepo '.harness/runtime/state/S-001.json') -Value ([ordered]@{ status = 'completed' })
    $manifest = Sync-RalphyManifestWithTaskState -Root $manifestRepo -ManifestPath $manifestPath
    Assert-True ([bool]$manifest.tasks[0].completed) 'completed adapter state remains complete in Ralphy manifest'
    Assert-True (-not [bool]$manifest.tasks[1].completed) 'failed or missing adapter state is restored to incomplete'
} finally { Remove-Item -LiteralPath $manifestRepo -Recurse -Force }

$lockPath = Join-Path ([System.IO.Path]::GetTempPath()) "ralphy-lock-$([Guid]::NewGuid().ToString('N')).lock"
$lock = Open-ExclusiveLock -Path $lockPath
try {
    $blocked = $false
    try { $second = Open-ExclusiveLock -Path $lockPath; $second.Dispose() } catch { $blocked = $true }
    Assert-True $blocked 'second launcher lock is rejected'
} finally { $lock.Dispose(); Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }

# Verify actual Ralphy 4.7.2 calls Codex once when max-retries is zero.
$retryRepo = New-TestRepo -Name 'retry contract'
try {
    $fakeBin = Join-Path $retryRepo 'fake bin'
    [System.IO.Directory]::CreateDirectory($fakeBin) | Out-Null
    $countPath = Join-Path $retryRepo 'count.txt'
    $cmd = "@echo off`r`necho call>>`"$countPath`"`r`nexit /b 9`r`n"
    [System.IO.File]::WriteAllText((Join-Path $fakeBin 'codex.cmd'), $cmd, [System.Text.ASCIIEncoding]::new())
    $oldPath = $env:PATH
    $env:PATH = "$env:SystemRoot\System32;$fakeBin;$oldPath"
    Push-Location $retryRepo
    try {
        & 'C:\Users\natha\AppData\Roaming\npm\ralphy.cmd' --codex --max-retries 0 --no-commit --no-tests --no-lint --no-browser '[TASK:T-001] fake failure' 2>&1 | Out-Null
    } finally { Pop-Location; $env:PATH = $oldPath }
    $calls = if (Test-Path -LiteralPath $countPath) { @(Get-Content -LiteralPath $countPath).Count } else { 0 }
    Assert-True ($calls -eq 1) "Ralphy max-retries=0 invokes Codex once (actual: $calls)"
} finally { Remove-Item -LiteralPath $retryRepo -Recurse -Force }

# Verify the actual Ralphy -> cmd.exe -> PowerShell adapter stdin contract.
$stdinRepo = New-TestRepo -Name 'ralphy stdin adapter'
try {
    [System.IO.Directory]::CreateDirectory((Join-Path $stdinRepo 'harness/tasks')) | Out-Null
    [System.IO.Directory]::CreateDirectory((Join-Path $stdinRepo '.harness/runtime')) | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'harness/tasks/S-001.json') -Destination (Join-Path $stdinRepo 'harness/tasks/S-001.json')
    $manifestPath = Join-Path $stdinRepo '.harness/runtime/PRD.json'
    Write-JsonNoBom -Path $manifestPath -Value ([ordered]@{ tasks = @([ordered]@{ title = '[TASK:S-001] stdin proof'; completed = $false; description = 'Create the exact S-001 fixture and do not commit.' }) })
    & git -C $stdinRepo add harness/tasks/S-001.json
    & git -C $stdinRepo commit -m 'add stdin policy' | Out-Null
    $oldPath = $env:PATH
    $env:HARNESS_ROOT = $stdinRepo
    $env:HARNESS_REAL_CODEX = Join-Path $root 'tests/fixtures/fake-codex.cmd'
    $env:HARNESS_RUN_ID = 'stdin-contract'
    $env:HARNESS_LOG_DIR = Join-Path $stdinRepo '.logs'
    $env:HARNESS_PLAN_HASH = ('B' * 64)
    $env:HARNESS_MANIFEST_PATH = $manifestPath
    $env:PATH = "$env:SystemRoot\System32;$(Join-Path $root '.harness/bin');$oldPath"
    Push-Location $stdinRepo
    try {
        $ralphyOutput = & 'C:\Users\natha\AppData\Roaming\npm\ralphy.cmd' --codex --json $manifestPath --model gpt-5.6-terra --max-retries 0 --no-commit --no-tests --no-lint --no-browser 2>&1 | Out-String
        $ralphyCode = $LASTEXITCODE
    } finally { Pop-Location; $env:PATH = $oldPath }
    Assert-True ($ralphyCode -eq 0) "real Ralphy selects and reinjects the approved manifest task; output: $ralphyOutput"
    $stdinState = Read-JsonFile -Path (Join-Path $stdinRepo '.harness/runtime/state/S-001.json')
    Assert-True ($stdinState.status -eq 'completed') 'stdin-routed task passes adapter and commits'
} finally {
    Remove-Item Env:HARNESS_ROOT,Env:HARNESS_REAL_CODEX,Env:HARNESS_RUN_ID,Env:HARNESS_LOG_DIR,Env:HARNESS_PLAN_HASH,Env:HARNESS_MANIFEST_PATH -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stdinRepo -Recurse -Force
}

# Exercise the real adapter with a fake Codex in a temporary repository.
$adapterRepo = New-TestRepo -Name 'adapter integration'
try {
    [System.IO.Directory]::CreateDirectory((Join-Path $adapterRepo 'harness/tasks')) | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'harness/tasks/S-002.json') -Destination (Join-Path $adapterRepo 'harness/tasks/S-002.json')
    & git -C $adapterRepo add harness/tasks/S-002.json
    & git -C $adapterRepo commit -m 'add adapter policy' | Out-Null
    $logRoot = Join-Path $adapterRepo '.logs'
    $env:HARNESS_ROOT = $adapterRepo
    $env:HARNESS_REAL_CODEX = Join-Path $root 'tests/fixtures/fake-codex.cmd'
    $env:HARNESS_RUN_ID = 'contract-test'
    $env:HARNESS_LOG_DIR = $logRoot
    $env:HARNESS_PLAN_HASH = ('A' * 64)
    $env:HARNESS_STDIN_OVERRIDE = '[TASK:S-002] fake integration through stdin'
    $lastMessage = Join-Path $adapterRepo 'last message.txt'
    & (Join-Path $root 'scripts/Invoke-CodexAdapter.ps1') exec --full-auto --json --output-last-message $lastMessage --model wrong | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) 'adapter integration exits successfully'
    $state = Read-JsonFile -Path (Join-Path $adapterRepo '.harness/runtime/state/S-002.json')
    Assert-True ($state.terra_attempts -eq 1) 'Terra ran first exactly once'
    Assert-True ($state.sol_attempts -eq 1) 'forced escalation invoked Sol exactly once'
    Assert-True ([bool]$state.force_applied) 'synthetic takeover was recorded'
    Assert-True ((Get-Content -Raw -LiteralPath (Join-Path $adapterRepo 'smoke/takeover.txt')) -eq "SOL_TAKEOVER_OK`n") 'Sol final fixture passed exact gate'
    Assert-True ((@(Get-ChangedPaths -Root $adapterRepo)).Count -eq 0) 'adapter integration leaves clean tree'
    $subject = (& git -C $adapterRepo log -1 --format=%s).Trim()
    Assert-True ($subject -eq 'test(S-002): prove Terra-to-Sol takeover') 'adapter owns deterministic commit message'
} finally {
    Remove-Item Env:HARNESS_ROOT,Env:HARNESS_REAL_CODEX,Env:HARNESS_RUN_ID,Env:HARNESS_LOG_DIR,Env:HARNESS_PLAN_HASH,Env:HARNESS_STDIN_OVERRIDE -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $adapterRepo -Recurse -Force
}

Write-Host "Contract tests passed: $passed assertions"
