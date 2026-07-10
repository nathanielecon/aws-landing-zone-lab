[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'scripts/Harness.Common.psm1') -Force
$ralphyCommand = (Get-Command ralphy.cmd -ErrorAction Stop | Select-Object -First 1).Source
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
$equalsSafe = @(New-SafeInitialCodexArguments -Arguments @('exec', '--sandbox=danger-full-access', '--model=wrong', '-s=danger-full-access', '-mwrong', '--json', '[TASK:S-001]') -Model 'gpt-5.6-terra')
Assert-True (-not (($equalsSafe -join ' ') -match 'danger-full-access|model=wrong')) 'equals-form authority and model overrides are stripped'
$authorityRejected = $false
try { [void](New-SafeInitialCodexArguments -Arguments @('exec', '--add-dir=C:\', '[TASK:S-001]') -Model 'gpt-5.6-terra') } catch { $authorityRejected = $true }
Assert-True $authorityRejected 'additional writable directories are rejected'
$configRejected = $false
try { [void](New-SafeInitialCodexArguments -Arguments @('exec', '-c', 'sandbox_mode=danger-full-access', '[TASK:S-001]') -Model 'gpt-5.6-terra') } catch { $configRejected = $true }
Assert-True $configRejected 'configuration overrides are rejected'
$resumeSafe = @(New-SafeResumeCodexArguments -Model 'gpt-5.6-terra' -ThreadId 'thread-123' -Prompt 'repair' -OutputLastMessage 'last message.txt')
Assert-True (($resumeSafe -join ' ') -match 'sandbox_mode="workspace-write"' -and -not (($resumeSafe -join ' ') -match 'danger-full-access')) 'resume and repair passes explicitly enforce workspace-write'
$redacted = Protect-LogText -Text 'Authorization: Bearer abc.def token=secretvalue password: hunter2'
Assert-True ($redacted -notmatch 'abc\.def|secretvalue|hunter2') 'credential-shaped text is redacted'
$bridgeArguments = @('-NoLogo', '-NoProfile', '-Command', '[Console]::Out.WriteLine("token=stdoutsecret"); [Console]::Error.WriteLine("Authorization: Bearer stderrsecret"); exit 7')
$bridgeBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($bridgeArguments | ConvertTo-Json -Compress)))
$bridgeOutput = & (Join-Path $root 'scripts/Invoke-NativeCodex.ps1') -Executable (Get-Command pwsh).Source -ArgumentsBase64 $bridgeBase64 -CommonModulePath (Join-Path $root 'scripts/Harness.Common.psm1') 2>&1 | Out-String
$bridgeExit = $LASTEXITCODE
Assert-True ($bridgeOutput -notmatch 'stdoutsecret|stderrsecret') 'native process output is redacted before the adapter can persist or replay it'
Assert-True ($bridgeExit -eq 7) 'sanitizing process bridge preserves native exit codes'
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
        & $ralphyCommand --codex --max-retries 0 --no-commit --no-tests --no-lint --no-browser '[TASK:T-001] fake failure' 2>&1 | Out-Null
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
        $ralphyOutput = & $ralphyCommand --codex --json $manifestPath --model gpt-5.6-terra --max-retries 0 --no-commit --no-tests --no-lint --no-browser 2>&1 | Out-String
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

# Reconcile an allowlisted gated commit created immediately before an adapter interruption.
$reconcileRepo = New-TestRepo -Name 'post-commit reconciliation'
try {
    [System.IO.Directory]::CreateDirectory((Join-Path $reconcileRepo 'harness/tasks')) | Out-Null
    [System.IO.Directory]::CreateDirectory((Join-Path $reconcileRepo '.harness/runtime/state')) | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'harness/tasks/S-001.json') -Destination (Join-Path $reconcileRepo 'harness/tasks/S-001.json')
    & git -C $reconcileRepo add harness/tasks/S-001.json
    & git -C $reconcileRepo commit -m 'add reconciliation policy' | Out-Null
    $startingCommit = (& git -C $reconcileRepo rev-parse HEAD).Trim()
    [System.IO.Directory]::CreateDirectory((Join-Path $reconcileRepo 'smoke')) | Out-Null
    [System.IO.Directory]::CreateDirectory((Join-Path $reconcileRepo 'evidence')) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $reconcileRepo 'smoke/terra.txt'), "TERRA_SMOKE_OK`n", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $reconcileRepo 'evidence/S-001.json'), "{}`n", [System.Text.UTF8Encoding]::new($false))
    & git -C $reconcileRepo add smoke/terra.txt evidence/S-001.json
    & git -C $reconcileRepo commit -m 'test(S-001): complete Terra smoke fixture' | Out-Null
    Write-JsonNoBom -Path (Join-Path $reconcileRepo '.harness/runtime/state/S-001.json') -Value ([ordered]@{
        plan_hash = ('C' * 64); task_id = 'S-001'; branch = 'codex/ralphy-harness'; starting_commit = $startingCommit
        started_at = [DateTimeOffset]::UtcNow.ToString('o'); status = 'running'; phase = 'terra'; terra_attempts = 1; sol_attempts = 0
        force_applied = $false; commit_sha = $null; completed_at = $null
    })
    $env:HARNESS_ROOT = $reconcileRepo
    $env:HARNESS_REAL_CODEX = Join-Path $root 'tests/fixtures/fake-codex.cmd'
    $env:HARNESS_RUN_ID = 'reconcile-contract'
    $env:HARNESS_LOG_DIR = Join-Path $reconcileRepo '.logs'
    $env:HARNESS_PLAN_HASH = ('C' * 64)
    $env:HARNESS_STDIN_OVERRIDE = '[TASK:S-001] reconcile only'
    & (Join-Path $root 'scripts/Invoke-CodexAdapter.ps1') exec --json '[TASK:S-001]' | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) 'post-commit interruption reconciles without another model pass'
    $reconciledState = Read-JsonFile -Path (Join-Path $reconcileRepo '.harness/runtime/state/S-001.json')
    Assert-True ($reconciledState.status -eq 'completed' -and $reconciledState.commit_sha -eq (& git -C $reconcileRepo rev-parse HEAD).Trim()) 'reconciled state records the existing gated commit'
    $reconciledSummary = Read-JsonFile -Path (Join-Path $reconcileRepo '.logs/S-001/summary.json')
    Assert-True ([bool]$reconciledSummary.reconciled_after_commit) 'reconciliation is recorded in sanitized summary evidence'
} finally {
    Remove-Item Env:HARNESS_ROOT,Env:HARNESS_REAL_CODEX,Env:HARNESS_RUN_ID,Env:HARNESS_LOG_DIR,Env:HARNESS_PLAN_HASH,Env:HARNESS_STDIN_OVERRIDE -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $reconcileRepo -Recurse -Force
}

Write-Host "Contract tests passed: $passed assertions"
