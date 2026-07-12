[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CodexArguments)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.Common.psm1') -Force

if ($env:HARNESS_PROFILE_ID -eq 'project-a') {
    & (Join-Path $PSScriptRoot 'Invoke-ProjectAAdapter.ps1') @CodexArguments
    exit $LASTEXITCODE
}

if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'The Codex adapter requires PowerShell 7 or later.' }
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$realCodex = $env:HARNESS_REAL_CODEX
$runId = $env:HARNESS_RUN_ID
$logRoot = $env:HARNESS_LOG_DIR
$planHash = $env:HARNESS_PLAN_HASH
foreach ($required in @('realCodex', 'runId', 'logRoot', 'planHash')) {
    if ([string]::IsNullOrWhiteSpace((Get-Variable $required -ValueOnly))) { throw "Missing harness environment value: $required" }
}
$realCodex = [System.IO.Path]::GetFullPath($realCodex)
$fixturePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../tests/fixtures/fake-codex.cmd'))
$isFakeFixture = $realCodex.Equals($fixturePath, [System.StringComparison]::OrdinalIgnoreCase)
if ($isFakeFixture -and -not [string]::IsNullOrWhiteSpace($env:HARNESS_ROOT)) { $root = [System.IO.Path]::GetFullPath($env:HARNESS_ROOT) }
$expectedManifestPath = $env:HARNESS_MANIFEST_PATH
if (-not $isFakeFixture) {
    if ([string]::IsNullOrWhiteSpace($env:HARNESS_ROOT) -or -not $root.Equals([System.IO.Path]::GetFullPath($env:HARNESS_ROOT), [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Harness root transport value does not match the adapter repository.' }
    $profile = Read-HarnessProfile -Root $root -ProfileId 'smoke'
    if ($env:HARNESS_PROFILE_ID -ne [string]$profile.profile_id) { throw 'Harness profile transport value is not the approved smoke profile.' }
    $branch = (& git -C $root branch --show-current).Trim()
    if ($branch -notmatch [string]$profile.expected_branch_pattern) { throw "Smoke adapter rejects branch: $branch" }
    $approvalPath = Resolve-PathUnderRoot -Root $root -RelativePath ([string]$profile.approval_file)
    $planPath = Join-Path $root 'PLAN.md'
    $approvedPlanHash = [string](Read-JsonFile -Path $approvalPath).plan_sha256
    $actualPlanHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $planPath).Hash
    if ($approvedPlanHash -ne $actualPlanHash -or $planHash -ne $actualPlanHash) { throw 'Harness plan hash transport value is not the currently approved plan hash.' }
    $expectedManifestPath = Join-Path $root '.harness/runtime/PRD.json'
    if ([string]::IsNullOrWhiteSpace($env:HARNESS_MANIFEST_PATH) -or -not $expectedManifestPath.Equals([System.IO.Path]::GetFullPath($env:HARNESS_MANIFEST_PATH), [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Harness manifest transport value is not the approved runtime manifest location.' }
}
$adapterPath = [System.IO.Path]::GetFullPath((Join-Path $root '.harness/bin/codex.cmd'))
if ($realCodex.Equals($adapterPath, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Real Codex path resolves to the adapter; refusing recursion.' }
if (-not (Test-Path -LiteralPath $realCodex -PathType Leaf)) { throw "Real Codex executable not found: $realCodex" }
if ($env:HARNESS_CONTRACT_ONLY -eq '1') {
    $fixturePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../tests/fixtures/fake-codex.cmd'))
    if (-not $realCodex.Equals($fixturePath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Contract-only mode refuses every Codex executable except the committed fake fixture.'
    }
} elseif (-not $isFakeFixture) {
    $adapterDirectory = [System.IO.Path]::GetFullPath((Join-Path $root '.harness/bin'))
    $installedCodex = @(Get-Command codex.cmd -All -ErrorAction Stop | Where-Object { -not ([System.IO.Path]::GetFullPath($_.Source)).StartsWith($adapterDirectory, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1)[0]
    if (-not $installedCodex -or -not $realCodex.Equals([System.IO.Path]::GetFullPath($installedCodex.Source), [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Codex executable transport value does not match the installed non-adapter executable.' }
}

$stopFlag = Join-Path $root '.harness/runtime/stop.flag'
if (Test-Path -LiteralPath $stopFlag) { throw 'A prior task failed; the stop sentinel blocks additional model calls until explicit resume.' }
$stdinText = if ($env:HARNESS_STDIN_OVERRIDE) { [string]$env:HARNESS_STDIN_OVERRIDE } else { [Console]::In.ReadToEnd() }
$manifestPath = $expectedManifestPath
$manifestTask = $null
try {
    $taskId = Get-TaskIdFromArguments -Arguments (@($CodexArguments) + @($stdinText))
} catch {
    if (-not $manifestPath -or -not (Test-Path -LiteralPath $manifestPath)) { throw }
    $manifest = Read-JsonFile -Path $manifestPath
    foreach ($candidate in $manifest.tasks) {
        if ([bool]$candidate.completed) { continue }
        $candidateId = Get-TaskIdFromArguments -Arguments @([string]$candidate.title)
        $candidateStatePath = Join-Path $root ".harness/runtime/state/$candidateId.json"
        if (Test-Path -LiteralPath $candidateStatePath) {
            $candidateState = Read-JsonFile -Path $candidateStatePath
            if ($candidateState.status -eq 'completed') { continue }
        }
        $manifestTask = $candidate
        break
    }
    if (-not $manifestTask) { throw 'No incomplete task exists in the approved runtime manifest.' }
    $taskId = Get-TaskIdFromArguments -Arguments @([string]$manifestTask.title)
}
if ($manifestPath -and (Test-Path -LiteralPath $manifestPath) -and -not $manifestTask) {
    $manifest = Read-JsonFile -Path $manifestPath
    $manifestTask = @($manifest.tasks | Where-Object { ([string]$_.title) -match "\[TASK:$([regex]::Escape($taskId))\]" } | Select-Object -First 1)[0]
}
if (-not $stdinText -and $manifestTask) { $stdinText = "$($manifestTask.title)`n$($manifestTask.description)" }
$policyPath = Join-Path $root "harness/tasks/$taskId.json"
$policy = Read-JsonFile -Path $policyPath
if ([string]$policy.id -ne $taskId) { throw "Policy ID does not match task marker: $taskId" }
$statePath = Join-Path $root ".harness/runtime/state/$taskId.json"
$takeoverPath = Join-Path $root ".harness/runtime/takeovers/$taskId.md"
$runtimeExcluded = @(Get-HarnessLifecycleExcludedPaths -Root $root -ProfileId 'smoke')
$taskLogRoot = Join-Path $logRoot $taskId
[System.IO.Directory]::CreateDirectory($taskLogRoot) | Out-Null

function Save-State { Write-JsonNoBom -Path $statePath -Value $script:state }
function Stop-ForTimeout([string]$ErrorClass, [string]$Message) {
    $state.status = 'blocked'; $state.last_error_class = $ErrorClass; $state.last_failure = $Message
    Save-State
    Write-HarnessStopSentinel -Root $root -ErrorClass $ErrorClass -Message $Message
    Write-JsonNoBom -Path (Join-Path $taskLogRoot 'summary.json') -Value ([ordered]@{ task_id = $taskId; status = 'blocked'; error_class = $ErrorClass; message = $Message })
}
function Get-EscalationValue([string]$Name, $DefaultValue) {
    if ($policy.PSObject.Properties.Name -contains 'escalation' -and $policy.escalation -and $policy.escalation.PSObject.Properties.Name -contains $Name) {
        return $policy.escalation.$Name
    }
    return $DefaultValue
}
function Get-StateEvidencePath {
    if ($script:state -and -not [string]::IsNullOrWhiteSpace([string]$script:state.pending_evidence_path)) {
        return [string]$script:state.pending_evidence_path
    }
    return [string]$policy.expected_evidence
}

function Invoke-CodexProcess {
    param([Parameter(Mandatory)][string[]]$Arguments, [Parameter(Mandatory)][string]$Label, [AllowEmptyString()][string]$StandardInput = '')
    if (Test-Path -LiteralPath $stopFlag) { throw 'A prior task failed; the stop sentinel blocks additional model calls until explicit resume.' }
    $stdoutPath = Join-Path $taskLogRoot "$Label.stdout.jsonl"
    $stderrPath = Join-Path $taskLogRoot "$Label.stderr.log"
    $encodedArguments = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($Arguments | ConvertTo-Json -Compress)))
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = (Get-Command pwsh -ErrorAction Stop).Source
    $startInfo.WorkingDirectory = $root
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($value in @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', (Join-Path $PSScriptRoot 'Invoke-NativeCodex.ps1'), '-Executable', $realCodex, '-ArgumentsBase64', $encodedArguments, '-CommonModulePath', (Join-Path $PSScriptRoot 'Harness.Common.psm1'))) {
        [void]$startInfo.ArgumentList.Add($value)
    }
    Set-RepoOnlyProcessEnvironment -StartInfo $startInfo -IsolationRoot (Join-Path $taskLogRoot "isolation/$Label")
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        [void]$process.Start()
        if ($StandardInput) { $process.StandardInput.Write($StandardInput) }
        $process.StandardInput.Close()
        $result = Invoke-ProcessWithTimeout -Process $process -TimeoutSeconds (Get-PositiveTimeoutSeconds -Policy $policy -Name 'model_timeout_seconds' -DefaultSeconds 900)
        $stdout = $result.stdout; $stderr = $result.stderr; $exitCode = $result.exit_code
        if ($result.timed_out) { Stop-ForTimeout -ErrorClass 'MODEL_TIMEOUT' -Message 'MODEL_TIMEOUT: Codex model process exceeded its hard timeout.'; throw 'MODEL_TIMEOUT: Codex model process exceeded its hard timeout.' }
    } finally {
        $process.Dispose()
    }
    Write-Utf8NoBom -Path $stdoutPath -Text $stdout
    Write-Utf8NoBom -Path $stderrPath -Text $stderr
    if ($stdout) { [Console]::Out.Write($stdout) }
    if ($stderr) { [Console]::Error.Write($stderr) }
    return [pscustomobject]@{ exit_code = $exitCode; stdout = $stdout; stderr = $stderr; thread_id = Get-ThreadIdFromJsonLines -Text $stdout }
}

function Invoke-DeterministicGate {
    param([Parameter(Mandatory)][ValidateSet('terra', 'sol')][string]$Phase)
    $gateArgs = @('-NoLogo', '-NoProfile', '-File', (Join-Path $PSScriptRoot 'Invoke-TaskGate.ps1'), '-Root', $root, '-PolicyPath', $policyPath, '-Phase', $Phase)
    if ([bool]$state.force_applied) { $gateArgs += '-ForceAlreadyApplied' }
    $info = [System.Diagnostics.ProcessStartInfo]::new(); $info.FileName = (Get-Command pwsh -ErrorAction Stop).Source; $info.WorkingDirectory = $root; $info.UseShellExecute = $false; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    foreach ($argument in $gateArgs) { [void]$info.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new(); $process.StartInfo = $info
    try {
        [void]$process.Start()
        $execution = Invoke-ProcessWithTimeout -Process $process -TimeoutSeconds (Get-PositiveTimeoutSeconds -Policy $policy -Name 'gate_timeout_seconds' -DefaultSeconds 900)
    } finally { $process.Dispose() }
    if ($execution.timed_out) { Stop-ForTimeout -ErrorClass 'GATE_TIMEOUT' -Message 'GATE_TIMEOUT: Deterministic gate exceeded its hard timeout.'; throw 'GATE_TIMEOUT: Deterministic gate exceeded its hard timeout.' }
    $code = $execution.exit_code
    $json = (($execution.stdout -split "`r?`n" | Where-Object { $_ } | Select-Object -Last 1) | ConvertFrom-Json)
    return [pscustomobject]@{ exit_code = $code; result = $json }
}

function New-TakeoverText {
    param([Parameter(Mandatory)]$Failure)
    $changed = @(Get-ChangedPaths -Root $root -ExcludedPaths $runtimeExcluded)
    return @"
# Takeover: $taskId

Current state: Terra exhausted or triggered the approved escalation gate.
Attempted fixes: $($state.terra_attempts) Terra execution(s).
Failing checks: $($Failure.error_class) - $($Failure.message)
Files changed: $($changed -join ', ')
Suspected root cause: deterministic gate failure or explicit smoke escalation.
Recommended next move: edit only $($policy.allowed_paths -join ', ') and satisfy the Sol gate.

For this task, write $($policy.gate.path) as UTF-8 without BOM with exactly this content, including one final LF:
$($policy.gate.sol_content.Replace("`n", '\n'))

Do not commit. Do not change any other tracked path.
"@
}

function Test-CommittedTaskContent {
    param([Parameter(Mandatory)][ValidateSet('terra', 'sol')][string]$Phase)
    $fixturePath = Join-Path $root ([string]$policy.gate.path)
    if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) { return $false }
    $expectedText = if ($Phase -eq 'sol') { [string]$policy.gate.sol_content } else { [string]$policy.gate.terra_content }
    $expectedBytes = [System.Text.UTF8Encoding]::new($false).GetBytes($expectedText)
    $actualBytes = [System.IO.File]::ReadAllBytes($fixturePath)
    return [System.Linq.Enumerable]::SequenceEqual[byte]($actualBytes, $expectedBytes)
}

function Complete-GatedCommit {
    param([Parameter(Mandatory)][string]$Phase, [Parameter(Mandatory)]$GateResult)
    $allowedCode = @($policy.allowed_paths | ForEach-Object { [string]$_ })
    $changedCode = @(Assert-OnlyAllowedChanges -Root $root -AllowedPaths $allowedCode -ExcludedPaths $runtimeExcluded)
    if ($changedCode.Count -eq 0) { throw 'No task diff exists to commit.' }
    $evidencePath = [string]$policy.expected_evidence
    $evidence = [ordered]@{
        plan_hash = $planHash
        run_id = $runId
        task_id = $taskId
        phase_passed = $Phase
        terra_attempts = [int]$state.terra_attempts
        sol_attempts = [int]$state.sol_attempts
        forced_takeover = [bool]$state.force_applied
        validation = $GateResult.message
        changed_paths = $changedCode
        started_at = $state.started_at
        completed_at = [DateTimeOffset]::UtcNow.ToString('o')
        commit_sha = 'SELF'
        commit_lookup = "git log -1 --format=%H -- $evidencePath"
    }
    $fullEvidencePath = Join-Path $root $evidencePath
    Write-JsonNoBom -Path $fullEvidencePath -Value $evidence
    $allAllowed = @($allowedCode) + @($evidencePath)
    $allChanged = @(Assert-OnlyAllowedChanges -Root $root -AllowedPaths $allAllowed -ExcludedPaths $runtimeExcluded)
    $state.status = 'committing'
    $state.pending_evidence_path = $evidencePath
    $state.stage_paths = @($allChanged | Sort-Object -Unique)
    $state.evidence_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $fullEvidencePath).Hash
    foreach ($path in $allChanged) {
        & git -C $root add -- $path
        if ($LASTEXITCODE -ne 0) { throw "Failed to stage allowlisted path: $path" }
    }
    $state.intended_tree = (& git -C $root write-tree).Trim()
    Save-State
    & git -C $root commit -m ([string]$policy.commit_message)
    if ($LASTEXITCODE -ne 0) { throw 'Gated task commit failed.' }
    $commitSha = (& git -C $root rev-parse HEAD).Trim()
    $state.status = 'completed'
    $state.commit_sha = $commitSha
    $state.completed_at = [DateTimeOffset]::UtcNow.ToString('o')
    Save-State
    Write-JsonNoBom -Path (Join-Path $taskLogRoot 'summary.json') -Value ([ordered]@{ task_id = $taskId; status = 'completed'; commit_sha = $commitSha; evidence = $evidencePath; terra_attempts = $state.terra_attempts; sol_attempts = $state.sol_attempts })
}

$branch = (& git -C $root branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or -not $branch) { throw 'Unable to resolve current Git branch.' }
$head = (& git -C $root rev-parse HEAD).Trim()
$outputLastMessage = Get-OutputLastMessagePath -Arguments $CodexArguments

if (Test-Path -LiteralPath $statePath) {
    $state = Read-JsonFile -Path $statePath
    if ($state.plan_hash -ne $planHash -or $state.branch -ne $branch -or [string]$state.task_id -ne $taskId) { throw 'Persisted task state does not match the approved task, plan, or branch.' }
    if ($state.status -eq 'completed') { throw "Task $taskId already completed at $($state.commit_sha); duplicate invocation blocked." }
    if ([string]$state.starting_commit -ne $head) {
        $parent = (& git -C $root rev-parse "$head^" 2>$null).Trim()
        $subject = (& git -C $root log -1 --format=%s).Trim()
        $tree = (& git -C $root rev-parse "$head^{tree}" 2>$null).Trim()
        $commitPaths = @(& git -C $root diff-tree --no-commit-id --name-only -r $head | ForEach-Object { $_ -replace '\\', '/' } | Sort-Object)
        $expectedCommitPaths = @($state.stage_paths | Sort-Object)
        $evidencePath = Get-StateEvidencePath
        $fullEvidencePath = Join-Path $root $evidencePath
        $evidenceHash = if (Test-Path -LiteralPath $fullEvidencePath -PathType Leaf) { (Get-FileHash -Algorithm SHA256 -LiteralPath $fullEvidencePath).Hash } else { $null }
        $commitIsOwned = $parent -eq [string]$state.starting_commit -and
            $state.status -eq 'committing' -and
            $subject -eq [string]$policy.commit_message -and
            $tree -eq [string]$state.intended_tree -and
            ($commitPaths -join ',') -eq ($expectedCommitPaths -join ',') -and
            $evidenceHash -eq [string]$state.evidence_sha256 -and
            @(Get-ChangedPaths -Root $root -ExcludedPaths $runtimeExcluded).Count -eq 0
        if (-not $commitIsOwned) { throw 'Current HEAD does not match the interrupted task starting commit or its single gated commit.' }
        $reconcilePhase = if ($state.phase -eq 'sol') { 'sol' } else { 'terra' }
        if (-not (Test-CommittedTaskContent -Phase $reconcilePhase)) { throw 'The interrupted task commit no longer passes its deterministic content gate.' }
        $state.status = 'completed'
        $state.commit_sha = $head
        $state.completed_at = [DateTimeOffset]::UtcNow.ToString('o')
        Save-State
        Write-JsonNoBom -Path (Join-Path $taskLogRoot 'summary.json') -Value ([ordered]@{ task_id = $taskId; status = 'completed'; commit_sha = $head; evidence = [string]$policy.expected_evidence; terra_attempts = $state.terra_attempts; sol_attempts = $state.sol_attempts; reconciled_after_commit = $true })
        exit 0
    }
    $resumeAllowed = @($policy.allowed_paths | ForEach-Object { [string]$_ }) + @([string]$policy.expected_evidence)
    [void](Assert-OnlyAllowedChanges -Root $root -AllowedPaths $resumeAllowed -ExcludedPaths $runtimeExcluded)
} else {
    $preexisting = @(Get-ChangedPaths -Root $root -ExcludedPaths $runtimeExcluded)
    if ($preexisting.Count -gt 0) { throw "Fresh task requires a clean tree; found: $($preexisting -join ', ')" }
    $state = [pscustomobject][ordered]@{
        plan_hash = $planHash
        task_id = $taskId
        branch = $branch
        starting_commit = $head
        started_at = [DateTimeOffset]::UtcNow.ToString('o')
        status = 'running'
        phase = 'terra'
        terra_attempts = 0
        sol_attempts = 0
        consecutive_failures = 0
        last_error_class = $null
        same_error_count = 0
        force_applied = $false
        terra_thread_id = $null
        sol_thread_id = $null
        last_failure = $null
        stage_paths = @()
        pending_evidence_path = [string]$policy.expected_evidence
        evidence_sha256 = $null
        intended_tree = $null
        commit_sha = $null
        completed_at = $null
    }
    Save-State
}

if ($state.status -eq 'blocked') {
    $blockedGate = Invoke-DeterministicGate -Phase 'sol'
    if (-not [bool]$blockedGate.result.passed) { throw "Task remains blocked: $($blockedGate.result.message)" }
    Complete-GatedCommit -Phase 'sol' -GateResult $blockedGate.result
    exit 0
}

$resumeChanges = @(Get-ChangedPaths -Root $root -ExcludedPaths $runtimeExcluded)
if ($resumeChanges.Count -gt 0) {
    $resumePhase = if ($state.phase -eq 'sol') { 'sol' } else { 'terra' }
    $resumeGate = Invoke-DeterministicGate -Phase $resumePhase
    if ([bool]$resumeGate.result.passed) {
        Complete-GatedCommit -Phase $resumePhase -GateResult $resumeGate.result
        exit 0
    }
}

while ($true) {
    $elapsed = [DateTimeOffset]::UtcNow - [DateTimeOffset]::Parse([string]$state.started_at)
    $beforeFingerprint = Get-DiffFingerprint -Root $root -ExcludedPaths $runtimeExcluded
    if ($state.phase -eq 'terra') {
        $state.terra_attempts = [int]$state.terra_attempts + 1
        $label = "terra-$($state.terra_attempts)"
        if ($state.terra_attempts -eq 1 -and -not $state.terra_thread_id) {
            $arguments = New-RepoOnlyInitialCodexArguments -Arguments $CodexArguments -Model 'gpt-5.6-terra'
        } else {
            $repairPrompt = "Repair task $taskId without committing. Last gate: $($state.last_failure). Change only $($policy.allowed_paths -join ', '), then stop."
            $arguments = New-RepoOnlyResumeCodexArguments -Model 'gpt-5.6-terra' -ThreadId ([string]$state.terra_thread_id) -Prompt $repairPrompt -OutputLastMessage $outputLastMessage
        }
        Save-State
        $attemptInput = if ($state.terra_attempts -eq 1 -and -not $state.terra_thread_id) { $stdinText } else { '' }
        $execution = Invoke-CodexProcess -Arguments $arguments -Label $label -StandardInput $attemptInput
        if ($execution.thread_id) { $state.terra_thread_id = $execution.thread_id }
        if ($execution.exit_code -ne 0) {
            $fatalText = "$($execution.stdout)`n$($execution.stderr)"
            if ($fatalText -match '(?i)requires a newer version of Codex|not authenticated|run.+codex login|unknown model|model.+not available') {
                $state.status = 'blocked'
                $state.last_error_class = 'FATAL_CODEX_CONFIGURATION'
                $state.last_failure = 'Codex configuration or model availability prevents execution.'
                Save-State
                throw $state.last_failure
            }
            $gate = [pscustomobject]@{ passed = $false; error_class = "CODEX_EXIT_$($execution.exit_code)"; message = 'Terra exited non-zero.' }
        } else {
            $gateEnvelope = Invoke-DeterministicGate -Phase 'terra'
            $gate = $gateEnvelope.result
        }
        if ([bool]$gate.passed) { Complete-GatedCommit -Phase 'terra' -GateResult $gate; exit 0 }
        if ($gate.error_class -eq 'SMOKE_FORCE_SOL') { $state.force_applied = $true }
        $afterFingerprint = Get-DiffFingerprint -Root $root -ExcludedPaths $runtimeExcluded
        $noDiff = $beforeFingerprint -eq $afterFingerprint
        $state.consecutive_failures = [int]$state.consecutive_failures + 1
        if ($state.last_error_class -eq $gate.error_class) { $state.same_error_count = [int]$state.same_error_count + 1 } else { $state.same_error_count = 1 }
        $state.last_error_class = [string]$gate.error_class
        $state.last_failure = [string]$gate.message
        $escalate = Test-TerraEscalation -ForceApplied ([bool]$state.force_applied) -Attempts ([int]$state.terra_attempts) -AttemptLimit ([int]$policy.terra_attempt_limit) -ConsecutiveFailures ([int]$state.consecutive_failures) -ConsecutiveFailureLimit ([int](Get-EscalationValue -Name 'consecutive_failures' -DefaultValue 2)) -SameErrorCount ([int]$state.same_error_count) -SameErrorLimit ([int](Get-EscalationValue -Name 'same_error_count' -DefaultValue 2)) -NoDiff $noDiff -EscalateOnNoDiff ([int](Get-EscalationValue -Name 'no_diff_repairs' -DefaultValue 1) -gt 0) -ElapsedMinutes $elapsed.TotalMinutes -ElapsedLimitMinutes ([int]$policy.elapsed_limit_minutes) -EscalateOnScopeEscape ([bool](Get-EscalationValue -Name 'scope_escape' -DefaultValue $true)) -ErrorClass ([string]$gate.error_class)
        if ($escalate) {
            $state.phase = 'sol'
            $takeover = New-TakeoverText -Failure $gate
            Write-Utf8NoBom -Path $takeoverPath -Text $takeover
        }
        Save-State
        if (-not $escalate) { continue }
    }

    $state.sol_attempts = [int]$state.sol_attempts + 1
    $label = "sol-$($state.sol_attempts)"
    $takeoverPrompt = Get-Content -Raw -LiteralPath $takeoverPath
    if ($state.sol_attempts -eq 1 -or -not $state.sol_thread_id) {
        $arguments = New-RepoOnlyInitialCodexArguments -Arguments @('exec', '--json', $takeoverPrompt) -Model 'gpt-5.6-sol'
    } else {
        $arguments = New-RepoOnlyResumeCodexArguments -Model 'gpt-5.6-sol' -ThreadId ([string]$state.sol_thread_id) -Prompt "Repair $taskId. Last gate: $($state.last_failure). Do not commit." -OutputLastMessage $outputLastMessage
    }
    Save-State
    $execution = Invoke-CodexProcess -Arguments $arguments -Label $label
    if ($execution.thread_id) { $state.sol_thread_id = $execution.thread_id }
    if ($execution.exit_code -ne 0) {
        $gate = [pscustomobject]@{ passed = $false; error_class = "CODEX_EXIT_$($execution.exit_code)"; message = 'Sol exited non-zero.' }
    } else {
        $gateEnvelope = Invoke-DeterministicGate -Phase 'sol'
        $gate = $gateEnvelope.result
    }
    if ([bool]$gate.passed) { Complete-GatedCommit -Phase 'sol' -GateResult $gate; exit 0 }
    $state.last_error_class = [string]$gate.error_class
    $state.last_failure = [string]$gate.message
    if ($state.sol_attempts -ge 2) {
        $state.status = 'blocked'
        Save-State
        throw "Sol exhausted its implementation and repair passes: $($gate.message)"
    }
    Save-State
}
