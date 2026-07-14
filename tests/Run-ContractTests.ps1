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
    [System.IO.Directory]::CreateDirectory((Join-Path $path 'harness/profiles')) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $path 'README.md'), "test`n", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $path '.gitignore'), ".harness/runtime/`n.logs/`nlast message.txt`n.codex-last-message-*`n", [System.Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath (Join-Path $root 'harness/profiles/smoke.json') -Destination (Join-Path $path 'harness/profiles/smoke.json')
    [System.IO.File]::WriteAllText((Join-Path $path 'harness/PRD.template.json'), "{`"tasks`":[]}`n", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $path 'harness/plan-approval.json'), "{`"plan_sha256`":`"" + ('A' * 64) + "`"}`n", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $path 'harness/tool-versions.json'), "{}`n", [System.Text.UTF8Encoding]::new($false))
    & git -C $path add README.md .gitignore harness
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
$threshold = {
    param(
        $Attempts = 1,
        $Consecutive = 1,
        $ConsecutiveLimit = 2,
        $Same = 1,
        $SameLimit = 2,
        $NoDiff = $false,
        $EscalateOnNoDiff = $true,
        $Elapsed = 1,
        $ScopeEscape = $true,
        $ErrorClass = 'TEST_FAILURE'
    )
    Test-TerraEscalation -ForceApplied $false -Attempts $Attempts -AttemptLimit 3 -ConsecutiveFailures $Consecutive -ConsecutiveFailureLimit $ConsecutiveLimit -SameErrorCount $Same -SameErrorLimit $SameLimit -NoDiff $NoDiff -EscalateOnNoDiff $EscalateOnNoDiff -ElapsedMinutes $Elapsed -ElapsedLimitMinutes 25 -EscalateOnScopeEscape $ScopeEscape -ErrorClass $ErrorClass
}
Assert-True (-not (& $threshold)) 'one ordinary failure remains with Terra'
Assert-True (& $threshold -Attempts 3) 'attempt limit escalates'
Assert-True (& $threshold -Consecutive 2) 'consecutive failures escalate'
Assert-True (& $threshold -Same 2) 'repeated error class escalates'
Assert-True (& $threshold -NoDiff $true) 'no meaningful diff escalates'
Assert-True (-not (& $threshold -Consecutive 2 -ConsecutiveLimit 3)) 'consecutive escalation honors policy thresholds'
Assert-True (-not (& $threshold -Same 2 -SameLimit 3)) 'same-error escalation honors policy thresholds'
Assert-True (-not (& $threshold -NoDiff $true -EscalateOnNoDiff $false)) 'no-diff escalation can be disabled by policy'
Assert-True (& $threshold -Elapsed 25) 'elapsed limit escalates'
Assert-True (& $threshold -ErrorClass 'SCOPE_ESCAPE') 'scope escape escalates'
Assert-True (-not (& $threshold -ErrorClass 'SCOPE_ESCAPE' -ScopeEscape $false)) 'scope-escape escalation honors policy settings'

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
    Assert-True ((@(Get-ChangedPaths -Root $adapterRepo -ExcludedPaths (Get-HarnessLifecycleExcludedPaths -Root $root -ProfileId 'smoke'))).Count -eq 0) 'adapter integration leaves clean tree'
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
    $evidenceText = (([ordered]@{
        plan_hash = ('C' * 64); run_id = 'reconcile-contract'; task_id = 'S-001'; phase_passed = 'terra'
        terra_attempts = 1; sol_attempts = 0; forced_takeover = $false; validation = 'ok'; changed_paths = @('smoke/terra.txt')
        started_at = [DateTimeOffset]::UtcNow.ToString('o'); completed_at = [DateTimeOffset]::UtcNow.ToString('o'); commit_sha = 'SELF'; commit_lookup = 'git log -1 --format=%H -- evidence/S-001.json'
    } | ConvertTo-Json -Depth 10) + "`n")
    [System.IO.File]::WriteAllText((Join-Path $reconcileRepo 'evidence/S-001.json'), $evidenceText, [System.Text.UTF8Encoding]::new($false))
    & git -C $reconcileRepo add smoke/terra.txt evidence/S-001.json
    & git -C $reconcileRepo commit -m 'test(S-001): complete Terra smoke fixture' | Out-Null
    $commitSha = (& git -C $reconcileRepo rev-parse HEAD).Trim()
    $treeSha = (& git -C $reconcileRepo rev-parse "$commitSha^{tree}").Trim()
    Write-JsonNoBom -Path (Join-Path $reconcileRepo '.harness/runtime/state/S-001.json') -Value ([ordered]@{
        plan_hash = ('C' * 64); task_id = 'S-001'; branch = 'codex/ralphy-harness'; starting_commit = $startingCommit
        started_at = [DateTimeOffset]::UtcNow.ToString('o'); status = 'committing'; phase = 'terra'; terra_attempts = 1; sol_attempts = 0
        force_applied = $false; stage_paths = @('evidence/S-001.json','smoke/terra.txt'); pending_evidence_path = 'evidence/S-001.json'
        evidence_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $reconcileRepo 'evidence/S-001.json')).Hash
        intended_tree = $treeSha; commit_sha = $null; completed_at = $null
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

$forgedSmokeRepo = New-TestRepo -Name 'forged smoke recovery'
try {
    [System.IO.Directory]::CreateDirectory((Join-Path $forgedSmokeRepo 'harness/tasks')) | Out-Null
    [System.IO.Directory]::CreateDirectory((Join-Path $forgedSmokeRepo '.harness/runtime/state')) | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'harness/tasks/S-001.json') -Destination (Join-Path $forgedSmokeRepo 'harness/tasks/S-001.json')
    & git -C $forgedSmokeRepo add harness/tasks/S-001.json
    & git -C $forgedSmokeRepo commit -m 'add forged smoke policy' | Out-Null
    $startingCommit = (& git -C $forgedSmokeRepo rev-parse HEAD).Trim()
    [System.IO.Directory]::CreateDirectory((Join-Path $forgedSmokeRepo 'smoke')) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $forgedSmokeRepo 'smoke/terra.txt'), "TERRA_SMOKE_OK`n", [System.Text.UTF8Encoding]::new($false))
    & git -C $forgedSmokeRepo add smoke/terra.txt
    & git -C $forgedSmokeRepo commit -m 'test(S-001): complete Terra smoke fixture' | Out-Null
    Write-JsonNoBom -Path (Join-Path $forgedSmokeRepo '.harness/runtime/state/S-001.json') -Value ([ordered]@{
        plan_hash = ('D' * 64); task_id = 'S-001'; branch = 'codex/ralphy-harness'; starting_commit = $startingCommit
        started_at = [DateTimeOffset]::UtcNow.ToString('o'); status = 'committing'; phase = 'terra'; terra_attempts = 1; sol_attempts = 0
        force_applied = $false; stage_paths = @('evidence/S-001.json','smoke/terra.txt'); pending_evidence_path = 'evidence/S-001.json'
        evidence_sha256 = ('0' * 64); intended_tree = ('0' * 40); commit_sha = $null; completed_at = $null
    })
    $env:HARNESS_ROOT = $forgedSmokeRepo
    $env:HARNESS_REAL_CODEX = Join-Path $root 'tests/fixtures/fake-codex.cmd'
    $env:HARNESS_RUN_ID = 'forged-smoke'
    $env:HARNESS_LOG_DIR = Join-Path $forgedSmokeRepo '.logs'
    $env:HARNESS_PLAN_HASH = ('D' * 64)
    $env:HARNESS_STDIN_OVERRIDE = '[TASK:S-001] forged recovery'
    & pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $root 'scripts/Invoke-CodexAdapter.ps1') exec --json '[TASK:S-001]' 2>$null | Out-Null
    Assert-True ($LASTEXITCODE -ne 0) 'smoke recovery rejects forged or non-exact owned commits'
} finally {
    Remove-Item Env:HARNESS_ROOT,Env:HARNESS_REAL_CODEX,Env:HARNESS_RUN_ID,Env:HARNESS_LOG_DIR,Env:HARNESS_PLAN_HASH,Env:HARNESS_STDIN_OVERRIDE -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $forgedSmokeRepo -Recurse -Force
}

$nulPathRepo = New-TestRepo -Name 'nul changed paths'
try {
    [System.IO.File]::AppendAllText((Join-Path $nulPathRepo '.gitignore'), "ignored-outside.txt`nnewline-path.txt`n", [System.Text.UTF8Encoding]::new($false))
    $newlinePath = Join-Path $nulPathRepo 'newline-path.txt'
    [System.IO.File]::WriteAllText((Join-Path $nulPathRepo 'ignored-outside.txt'), 'outside', [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($newlinePath, 'outside', [System.Text.UTF8Encoding]::new($false))
    $changed = @(Get-ChangedPaths -Root $nulPathRepo)
    Assert-True ($changed -contains 'ignored-outside.txt' -and $changed -contains 'newline-path.txt' -and (Test-AllowedPath -Path "safe`npath.txt" -AllowedPaths @("safe`npath.txt"))) 'NUL-safe changed paths include ignored paths and preserve newline path tokens'
    $rejected = $false; try { [void](Assert-OnlyAllowedChanges -Root $nulPathRepo -AllowedPaths @('smoke/**')) } catch { $rejected = $true }
    Assert-True $rejected 'ignored out-of-scope paths block before any model or commit action'
} finally { Remove-Item -LiteralPath $nulPathRepo -Recurse -Force }

$excludedValidationFailed = $false
foreach ($candidate in @('C:/absolute.txt','../escape.txt','*.json','.harness/runtime/state/')) {
    try { [void](Get-ChangedPaths -Root $root -ExcludedPaths @($candidate)) } catch { $excludedValidationFailed = $true; continue }
    throw "ASSERTION FAILED: ExcludedPaths accepted invalid entry $candidate"
}
Assert-True $excludedValidationFailed 'ExcludedPaths rejects absolute, traversal, wildcard, and directory-prefix entries'

$smokeRuntimeRepo = New-TestRepo -Name 'smoke runtime exclusions'
try {
    $smokeExcluded = @(Get-HarnessLifecycleExcludedPaths -Root $root -ProfileId 'smoke')
    [IO.Directory]::CreateDirectory((Join-Path $smokeRuntimeRepo '.harness/runtime/state')) | Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $smokeRuntimeRepo '.harness/runtime/takeovers')) | Out-Null
    foreach ($path in @(
        '.harness/runtime/harness.lock',
        '.harness/runtime/PRD.json',
        '.harness/runtime/state/S-001.json',
        '.harness/runtime/state/S-002.json',
        '.harness/runtime/takeovers/S-001.md',
        '.harness/runtime/takeovers/S-002.md'
    )) {
        $fullPath = Join-Path $smokeRuntimeRepo $path
        [IO.Directory]::CreateDirectory((Split-Path -Parent $fullPath)) | Out-Null
        [IO.File]::WriteAllText($fullPath, "owned`n", [Text.UTF8Encoding]::new($false))
    }
    $knownRuntime = @(Get-ChangedPaths -Root $smokeRuntimeRepo)
    Assert-True ($knownRuntime -contains '.harness/runtime/PRD.json' -and $knownRuntime -contains '.harness/runtime/state/S-001.json') 'known smoke runtime files are visible by default'
    Assert-True (@(Get-ChangedPaths -Root $smokeRuntimeRepo -ExcludedPaths $smokeExcluded).Count -eq 0) 'known smoke lifecycle paths can be excluded exactly'
    [IO.File]::WriteAllText((Join-Path $smokeRuntimeRepo '.harness/runtime/stop.flag'), "blocked`n", [Text.UTF8Encoding]::new($false))
    Assert-True (@(Get-ChangedPaths -Root $smokeRuntimeRepo -ExcludedPaths $smokeExcluded) -contains '.harness/runtime/stop.flag') 'stop.flag remains visible outside explicit resume preflight'
    Assert-True (@(Get-ChangedPaths -Root $smokeRuntimeRepo -ExcludedPaths @(Get-HarnessLifecycleExcludedPaths -Root $root -ProfileId 'smoke' -IncludeStopFlag)).Count -eq 0) 'stop.flag is excluded only when resume preflight explicitly allows it'
    $beforeUnknown = Get-DiffFingerprint -Root $smokeRuntimeRepo -ExcludedPaths $smokeExcluded
    [IO.File]::WriteAllText((Join-Path $smokeRuntimeRepo '.harness/runtime/rogue.txt'), "rogue`n", [Text.UTF8Encoding]::new($false))
    $afterUnknown = Get-DiffFingerprint -Root $smokeRuntimeRepo -ExcludedPaths $smokeExcluded
    Assert-True (@(Get-ChangedPaths -Root $smokeRuntimeRepo -ExcludedPaths $smokeExcluded) -contains '.harness/runtime/rogue.txt') 'unknown smoke runtime artifacts stay in changed-path inventory'
    Assert-True ($beforeUnknown -ne $afterUnknown) 'unknown smoke runtime mutations change the diff fingerprint'
} finally { Remove-Item -LiteralPath $smokeRuntimeRepo -Recurse -Force }

# Property/mutation: N=5 one-byte fixture mutations change SHA256; identical rewrite is idempotent.
$propMutationDir = Join-Path ([IO.Path]::GetTempPath()) "project-a-prop-mutation-$([Guid]::NewGuid().ToString('N'))"
try {
    [IO.Directory]::CreateDirectory($propMutationDir) | Out-Null
    $fixture = Join-Path $propMutationDir 'fixture.txt'
    $baseline = "property-fixture-baseline`n"
    [IO.File]::WriteAllText($fixture, $baseline, [Text.UTF8Encoding]::new($false))
    $baselineHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $fixture).Hash
    [IO.File]::WriteAllText($fixture, $baseline, [Text.UTF8Encoding]::new($false))
    Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $fixture).Hash -eq $baselineHash) 'repeating identical fixture content keeps SHA256 idempotent'
    for ($i = 0; $i -lt 5; $i++) {
        $mutatedContent = $baseline.Substring(0, $i) + [char](65 + $i) + $baseline.Substring($i + 1)
        [IO.File]::WriteAllText($fixture, $mutatedContent, [Text.UTF8Encoding]::new($false))
        $mutHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $fixture).Hash
        Assert-True ($mutHash -ne $baselineHash) "one-byte fixture mutation $i changes SHA256"
        [IO.File]::WriteAllText($fixture, $baseline, [Text.UTF8Encoding]::new($false))
        Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $fixture).Hash -eq $baselineHash) "rewriting baseline after mutation $i restores idempotent SHA256"
    }

    # Mutate execution_bundle_sha256 one hex digit → Verify-ProjectABundle fails closed.
    $copiedBundle = Join-Path $propMutationDir 'bundle-approval.json'
    $copiedExec = Join-Path $propMutationDir 'execution-approval.json'
    Copy-Item -LiteralPath (Join-Path $root 'project-a/harness/bundle-approval.json') -Destination $copiedBundle
    Copy-Item -LiteralPath (Join-Path $root 'project-a/harness/execution-approval.json') -Destination $copiedExec
    $mutatedExec = Get-Content -Raw -LiteralPath $copiedExec | ConvertFrom-Json
    $execHex = [char[]]([string]$mutatedExec.execution_bundle_sha256)
    $execHex[0] = if ($execHex[0] -eq 'A') { 'B' } else { 'A' }
    $mutatedExec.execution_bundle_sha256 = -join $execHex
    [IO.File]::WriteAllText($copiedExec, (($mutatedExec | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
    & pwsh -NoLogo -NoProfile -File (Join-Path $root 'scripts/Verify-ProjectABundle.ps1') -Root $root -BundleApprovalPath $copiedBundle -ExecutionApprovalPath $copiedExec | Out-Null
    Assert-True ($LASTEXITCODE -ne 0) 'Verify-ProjectABundle fails closed when execution_bundle_sha256 hex digit is mutated'

    # Also keep bundle-approval pin flip coverage.
    Copy-Item -LiteralPath (Join-Path $root 'project-a/harness/bundle-approval.json') -Destination $copiedBundle -Force
    Copy-Item -LiteralPath (Join-Path $root 'project-a/harness/execution-approval.json') -Destination $copiedExec -Force
    $mutatedBundle = Get-Content -Raw -LiteralPath $copiedBundle | ConvertFrom-Json
    $bundleHex = [char[]]([string]$mutatedBundle.spec_bundle_sha256)
    $bundleHex[0] = if ($bundleHex[0] -eq 'A') { 'B' } else { 'A' }
    $mutatedBundle.spec_bundle_sha256 = -join $bundleHex
    [IO.File]::WriteAllText($copiedBundle, (($mutatedBundle | ConvertTo-Json -Depth 5) + "`n"), [Text.UTF8Encoding]::new($false))
    & pwsh -NoLogo -NoProfile -File (Join-Path $root 'scripts/Verify-ProjectABundle.ps1') -Root $root -BundleApprovalPath $copiedBundle -ExecutionApprovalPath $copiedExec | Out-Null
    Assert-True ($LASTEXITCODE -ne 0) 'Verify-ProjectABundle fails closed when one approval hex digit is flipped'

    # Policy JSON field mutation: schema helper fails closed when available.
    $schemaPath = Join-Path $root 'project-a/harness/policy.schema.json'
    $policySrc = Join-Path $root 'project-a/harness/tasks/A-006.json'
    $policyCopy = Join-Path $propMutationDir 'mutated-policy.json'
    Copy-Item -LiteralPath $policySrc -Destination $policyCopy
    $policyObj = Get-Content -Raw -LiteralPath $policyCopy | ConvertFrom-Json
    $policyObj | Add-Member -NotePropertyName 'undeclared_mutation_probe' -NotePropertyValue $true -Force
    $mutatedPolicyJson = ($policyObj | ConvertTo-Json -Depth 10) + "`n"
    [IO.File]::WriteAllText($policyCopy, $mutatedPolicyJson, [Text.UTF8Encoding]::new($false))
    if (Get-Command Test-Json -ErrorAction SilentlyContinue) {
        Assert-True (-not (Test-Json -LiteralPath $policyCopy -SchemaFile $schemaPath -ErrorAction SilentlyContinue)) 'Test-Json schema rejects undeclared mutated policy field'
    } else {
        $roundtrip = (Get-Content -Raw -LiteralPath $policyCopy | ConvertFrom-Json | ConvertTo-Json -Compress)
        Assert-True ($roundtrip -match 'undeclared_mutation_probe') 'ConvertFrom-Json roundtrip preserves intentional policy mutation when Test-Json is unavailable'
        $invalidRejected = $false
        try { [void]('{not-json' | ConvertFrom-Json) } catch { $invalidRejected = $true }
        Assert-True $invalidRejected 'intentional invalid JSON is rejected by ConvertFrom-Json'
    }
} finally {
    Remove-Item -LiteralPath $propMutationDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Adversarial timeout: child sleep is killed by Invoke-ProcessWithTimeout.
if (Get-Command Invoke-ProcessWithTimeout -ErrorAction SilentlyContinue) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = (Get-Command pwsh -ErrorAction Stop).Source
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in @('-NoLogo', '-NoProfile', '-Command', 'Start-Sleep -Seconds 30')) {
        [void]$info.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    try {
        [void]$process.Start()
        $timeoutResult = Invoke-ProcessWithTimeout -Process $process -TimeoutSeconds 1
        Assert-True ($timeoutResult.timed_out -eq $true -and $timeoutResult.exit_code -eq 124) 'Invoke-ProcessWithTimeout kills a long-running child sleep'
    } finally {
        if (-not $process.HasExited) { try { $process.Kill($true) } catch {} }
        $process.Dispose()
    }
}

Write-Host "Contract tests passed: $passed assertions"
