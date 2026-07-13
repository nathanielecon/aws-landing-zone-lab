[CmdletBinding()]
param([switch]$DryRun, [switch]$Resume)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.Common.psm1') -Force
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$profile = Read-HarnessProfile -Root $root -ProfileId 'project-a'
$branch = (& git -C $root branch --show-current).Trim()
if ($branch -notmatch [string]$profile.expected_branch_pattern) { throw "Project A profile rejects branch: $branch" }
$approval = Read-JsonFile -Path (Resolve-PathUnderRoot -Root $root -RelativePath ([string]$profile.approval_file))
if (-not [bool]$approval.spec_approved) { throw 'Project A specification is not approved.' }
$executionApproval = Read-JsonFile -Path (Resolve-PathUnderRoot -Root $root -RelativePath ([string]$profile.execution_approval_file))
$toolVersions = Read-JsonFile -Path (Resolve-PathUnderRoot -Root $root -RelativePath ([string]$profile.tool_versions_file))
$computedSpec = & (Join-Path $PSScriptRoot 'Get-ProjectASpecHash.ps1') -Root $root | ConvertFrom-Json
if ([string]$approval.spec_bundle_sha256 -ne [string]$computedSpec.sha256) { throw 'Approved Project A specification hash drifted.' }
if ([string]$executionApproval.spec_bundle_sha256 -ne [string]$approval.spec_bundle_sha256) { throw 'Execution approval was issued for a different Project A specification bundle.' }
$execution = & (Join-Path $PSScriptRoot 'Get-ProjectAExecutionHash.ps1') -Root $root | ConvertFrom-Json
if ([string]$executionApproval.execution_hash_implementation_sha256 -ne [string]$execution.members.'scripts/Get-ProjectAExecutionHash.ps1') { throw 'Execution hash implementation drifted.' }
if ([string]$executionApproval.validator_implementation_sha256 -ne [string]$execution.members.'scripts/Invoke-ProjectAValidators.ps1') { throw 'Validator implementation drifted.' }
if ([string]$executionApproval.execution_bundle_sha256 -ne [string]$execution.sha256) { throw 'Project A execution bundle hash drifted.' }
if (-not $DryRun -and -not [bool]$executionApproval.execution_approved) { throw 'Project A execution is not approved. Phase 4 review must complete before any model call.' }

$terraform = Get-Command terraform.exe -ErrorAction SilentlyContinue
if (-not $terraform) {
    Write-Host 'Terraform 1.15.5 is missing. Recovery from an elevated shell:'
    Write-Host '  choco install terraform --version=1.15.5 -y --no-progress'
    if (-not $DryRun) { exit 12 }
} elseif ((& $terraform.Source version -json | ConvertFrom-Json).terraform_version -ne '1.15.5') { throw 'Terraform must be exactly 1.15.5 for this execution bundle.' }

$adapterDir = Join-Path $root '.harness/bin'
$system32 = Join-Path $env:SystemRoot 'System32'; if (-not (($env:PATH -split ';') -contains $system32)) { $env:PATH="$system32;$env:PATH" }
$resolvedCodex = (Get-Command codex.cmd -All | Where-Object { -not ([IO.Path]::GetFullPath($_.Source)).StartsWith([IO.Path]::GetFullPath($adapterDir),[StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1)
$realCodex = if ($resolvedCodex) {
    $resolvedCodexPath = [IO.Path]::GetFullPath($resolvedCodex.Source)
    $fixtureShim = Join-Path $root 'tests/fixtures/fake-codex.cmd'
    if ($resolvedCodexPath.Equals((Join-Path $root 'tests/fixtures/codex.cmd'), [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $fixtureShim -PathType Leaf)) {
        [IO.Path]::GetFullPath($fixtureShim)
    } else {
        $resolvedCodexPath
    }
} else {
    $null
}
$realRalphy = (Get-Command ralphy.cmd -All | Select-Object -First 1).Source
if (-not $realCodex -or -not $realRalphy) { throw 'Codex and Ralphy must be installed before Project A execution.' }
$codexVersion = (& $realCodex --version 2>&1 | Out-String).Trim()
if ($codexVersion -notmatch [string]$toolVersions.codex_regex) { throw "Unsupported Codex CLI: $codexVersion. Expected $($toolVersions.codex_regex)." }
$ralphyVersion = (& $realRalphy --version 2>&1 | Out-String).Trim()
if ($ralphyVersion -ne [string]$toolVersions.ralphy) { throw "Unsupported Ralphy CLI: $ralphyVersion" }
$login = (& $realCodex login status 2>&1 | Out-String); if ($LASTEXITCODE -ne 0 -or $login -notmatch 'Logged in using ChatGPT') { throw 'Codex ChatGPT login is required.' }

$runtimeRoot = Join-Path $root '.harness/runtime/project-a'
$manifestPath = Join-Path $runtimeRoot 'PRD.json'
$lockPath = Join-Path $root '.harness/runtime/harness.lock'
$runtimeExcluded = @(Get-HarnessLifecycleExcludedPaths -Root $root -ProfileId 'project-a')
$resumeExcluded = @(Get-HarnessLifecycleExcludedPaths -Root $root -ProfileId 'project-a' -IncludeStopFlag)
$lock = Open-ExclusiveLock -Path $lockPath
try {
    function Get-TaskPolicyPath {
        param([Parameter(Mandatory)][string]$TaskId)
        return (Join-Path $root "project-a/harness/tasks/$TaskId.json")
    }
    function Get-TaskPolicy {
        param([Parameter(Mandatory)][string]$TaskId)
        return (Read-JsonFile -Path (Get-TaskPolicyPath -TaskId $TaskId))
    }
    function Get-TaskPolicyHash {
        param([Parameter(Mandatory)][string]$TaskId)
        return (Get-FileHash -Algorithm SHA256 -LiteralPath (Get-TaskPolicyPath -TaskId $TaskId)).Hash
    }
    function Test-EligibleCompletedTaskState {
        param([Parameter(Mandatory)]$TaskState, [Parameter(Mandatory)][string]$TaskId, [Parameter(Mandatory)][string]$CurrentHead)
        return (Test-ProjectACompletedTaskState -Root $root -TaskState $TaskState -TaskId $TaskId -CurrentHead $CurrentHead -Branch $branch -BundleHash ([string]$execution.sha256) -ValidatorHash ([string]$execution.members.'scripts/Invoke-ProjectAValidators.ps1'))
    }
    function Get-ActiveResumeStates {
        $stateDir = Join-Path $runtimeRoot 'state'
        if (-not (Test-Path -LiteralPath $stateDir -PathType Container)) { return @() }
        $active = [System.Collections.Generic.List[object]]::new()
        foreach ($taskFile in Get-ChildItem -LiteralPath $stateDir -Filter *.json -File) {
            $taskState = Read-JsonFile -Path $taskFile.FullName
            if ([string]$taskState.profile_id -ne 'project-a') { continue }
            if ([string]$taskState.branch -ne $branch) { continue }
            if ([string]$taskState.bundle_hash -ne [string]$execution.sha256) { continue }
            if ([string]$taskState.validator_sha256 -ne [string]$execution.members.'scripts/Invoke-ProjectAValidators.ps1') { continue }
            if ([string]$taskState.policy_sha256 -ne (Get-TaskPolicyHash -TaskId ([string]$taskState.task_id))) { continue }
            if ([string]$taskState.status -in @('running','awaiting_approval','preparing_commit','committing')) { $active.Add($taskState) }
        }
        return @($active)
    }
    function Assert-NoForbiddenIsolationDirs {
        foreach ($forbidden in @('.ralphy-worktrees', '.ralphy-sandboxes')) {
            if (Test-Path -LiteralPath (Join-Path $root $forbidden)) { throw "Forbidden isolation directory was created: $forbidden" }
        }
    }
    function Assert-ResumeEligible {
        param([Parameter(Mandatory)][string[]]$ChangedPaths, [Parameter(Mandatory)][object[]]$ActiveStates, [Parameter(Mandatory)][string]$StopFlagPath)
        if (-not (Test-Path -LiteralPath $StopFlagPath -PathType Leaf)) { throw 'Resume requires an existing terminal sentinel.' }
        if ($ActiveStates.Count -ne 1) { throw 'Resume requires exactly one eligible active Project A task state.' }
        $activeState = $ActiveStates[0]
        $taskPolicy = Read-JsonFile -Path (Join-Path $root "project-a/harness/tasks/$($activeState.task_id).json")
        $allowed = @($taskPolicy.allowed_paths | ForEach-Object { [string]$_ }) + @([string]$taskPolicy.expected_evidence)
        $outside = @($ChangedPaths | Where-Object { -not (Test-AllowedPath -Path $_ -AllowedPaths $allowed) })
        if ($outside.Count -gt 0) { throw "Resume found unrelated dirty paths: $($outside -join ', ')" }
        $persistedDiff = [string]$activeState.diff_sha256
        if (-not [string]::IsNullOrWhiteSpace($persistedDiff)) {
            $allowedExecutablePaths = if ($taskPolicy.PSObject.Properties.Name -contains 'allowed_executable_paths') { @($taskPolicy.allowed_executable_paths | ForEach-Object { [string]$_ }) } else { @() }
            $identityExcluded = @($runtimeExcluded)
            if ([string]$activeState.status -in @('preparing_commit', 'committing') -and -not [string]::IsNullOrWhiteSpace([string]$activeState.pending_evidence_path)) {
                $identityExcluded += @([string]$activeState.pending_evidence_path)
                $fullPendingEvidence = Join-Path $root ([string]$activeState.pending_evidence_path)
                if (Test-Path -LiteralPath $fullPendingEvidence -PathType Leaf) {
                    if ([string]::IsNullOrWhiteSpace([string]$activeState.evidence_sha256)) { throw 'Resume pending evidence is missing its persisted digest binding.' }
                    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $fullPendingEvidence).Hash -ne [string]$activeState.evidence_sha256) { throw 'Resume pending evidence no longer matches the persisted transaction.' }
                }
            }
            $resumeDiff = Get-CanonicalDiffRecord -Root $root -AllowedPaths @($taskPolicy.allowed_paths) -AdapterOwnedPaths @($taskPolicy.adapter_owned_paths) -AllowedExecutablePaths $allowedExecutablePaths -ExcludedPaths $identityExcluded
            if ($resumeDiff.sha256 -ne $persistedDiff) { throw 'Resume dirty-set binding no longer matches the persisted task identity.' }
        } elseif ($ChangedPaths.Count -gt 0) {
            throw 'Resume found task changes without a persisted dirty-set identity.'
        }
        if ([string]$activeState.status -eq 'awaiting_approval') {
            foreach ($property in @('approval_request','approval_receipt','approval_key')) {
                if ([string]::IsNullOrWhiteSpace([string]$activeState.$property)) { throw "Resume approval state is missing $property." }
            }
        }
    }
    function Assert-CompletionContract {
        param([Parameter(Mandatory)]$Manifest, [Parameter(Mandatory)][string]$StopFlagPath)
        if (Test-Path -LiteralPath $StopFlagPath) { throw 'Project A completion contract failed: stop sentinel still exists.' }
        Assert-NoForbiddenIsolationDirs
        $currentHead = (& git -C $root rev-parse HEAD).Trim()
        $incomplete = @($Manifest.tasks | Where-Object { -not [bool]$_.completed })
        if ($incomplete.Count -gt 0) { throw "Project A completion contract failed: incomplete tasks remain: $($incomplete.title -join ', ')" }
        $expectedTaskCount = @($profile.task_ids).Count
        if (@($Manifest.tasks).Count -ne $expectedTaskCount) { throw "Project A completion contract failed: expected $expectedTaskCount tasks, found $(@($Manifest.tasks).Count)." }
        $states = [System.Collections.Generic.List[object]]::new()
        $previousCommit = $null
        foreach ($task in $Manifest.tasks) {
            $taskId = Get-TaskIdFromArguments -Arguments @([string]$task.title)
            $taskStatePath = Join-Path $runtimeRoot "state/$taskId.json"
            if (-not (Test-Path -LiteralPath $taskStatePath -PathType Leaf)) { throw "Project A completion contract failed: missing state for $taskId." }
            $taskState = Read-JsonFile -Path $taskStatePath
            if (-not (Test-EligibleCompletedTaskState -TaskState $taskState -TaskId $taskId -CurrentHead $currentHead)) { throw "Project A completion contract failed: stale or incomplete state for $taskId." }
            if ($previousCommit) {
                $matchesDirectChain = [string]$taskState.starting_commit -eq $previousCommit
                if (-not $matchesDirectChain) {
                    $allowHistoricalAncestor = $taskState.PSObject.Properties.Name -contains 'historical_reconstruction' -and [bool]$taskState.historical_reconstruction
                    if (-not $allowHistoricalAncestor) { throw "Project A completion contract failed: commit chain is broken before $taskId." }
                    & git -C $root merge-base --is-ancestor ([string]$taskState.starting_commit) $previousCommit 2>$null | Out-Null
                    $matchesHistoricalChain = $LASTEXITCODE -eq 0
                    if (-not $matchesHistoricalChain) {
                        & git -C $root merge-base --is-ancestor $previousCommit ([string]$taskState.starting_commit) 2>$null | Out-Null
                        $matchesHistoricalChain = $LASTEXITCODE -eq 0
                    }
                    if (-not $matchesHistoricalChain) { throw "Project A completion contract failed: commit chain is broken before $taskId." }
                }
            }
            foreach ($property in @('approval_request','approval_receipt','approval_key')) {
                $artifactPath = [string]$taskState.$property
                if (-not [string]::IsNullOrWhiteSpace($artifactPath) -and (Test-Path -LiteralPath $artifactPath)) { throw "Project A completion contract failed: leftover approval artifact for $taskId." }
            }
            $states.Add($taskState)
            $previousCommit = [string]$taskState.commit_sha
        }
        & git -C $root merge-base --is-ancestor $previousCommit $currentHead 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Project A completion contract failed: HEAD does not contain the final gated task commit.' }
        $finalChanges = @(Get-ChangedPaths -Root $root -ExcludedPaths $runtimeExcluded)
        if ($finalChanges.Count -gt 0) { throw "Project A completion contract failed: dirty tree remains: $($finalChanges -join ', ')" }
        $lingering = @(Get-LingeringHarnessProcesses -CurrentProcessId $PID)
        if ($lingering.Count -gt 0) {
            $processes = @($lingering | ForEach-Object { '{0}:{1}' -f $_.name, $_.process_id }) -join ', '
            throw "Project A completion contract failed: lingering harness processes remain: $processes"
        }
        return @($states)
    }
    $changed = @(if ($Resume) {
        Get-ChangedPaths -Root $root -ExcludedPaths $resumeExcluded
    } else {
        Get-ChangedPaths -Root $root -ExcludedPaths $runtimeExcluded
    })
    if (-not $Resume -and $changed.Count -gt 0) { throw "Normal Project A launch requires a clean tree: $($changed -join ', ')" }
    if (-not (Test-Path -LiteralPath $manifestPath)) { [IO.Directory]::CreateDirectory($runtimeRoot)|Out-Null }
    Copy-Item -LiteralPath (Resolve-PathUnderRoot -Root $root -RelativePath ([string]$profile.manifest_template)) -Destination $manifestPath -Force
    $manifest=Sync-ProjectAManifestWithTaskState -Root $root -ManifestPath $manifestPath -Branch $branch -BundleHash ([string]$execution.sha256) -ValidatorHash ([string]$execution.members.'scripts/Invoke-ProjectAValidators.ps1')
    $stopFlag=Join-Path $root '.harness/runtime/stop.flag'
    Assert-NoForbiddenIsolationDirs
    if($Resume){
        Assert-ResumeEligible -ChangedPaths $changed -ActiveStates (Get-ActiveResumeStates) -StopFlagPath $stopFlag
        Remove-Item -LiteralPath $stopFlag -Force
    }elseif(Test-Path -LiteralPath $stopFlag){throw 'A terminal sentinel exists. Use -Resume only after reviewing the failed task.'}
    $runId=[DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
    $localBase=if($env:LOCALAPPDATA){$env:LOCALAPPDATA}else{Join-Path $env:USERPROFILE 'AppData/Local'}
    $logRoot=Join-Path $localBase "RalphyHarness/cloud/$runId"; [IO.Directory]::CreateDirectory($logRoot)|Out-Null
    $env:HARNESS_ROOT=$root; $env:HARNESS_PROFILE_ID='project-a'; $env:HARNESS_REAL_CODEX=$realCodex; $env:HARNESS_RUN_ID=$runId; $env:HARNESS_LOG_DIR=$logRoot
    $env:HARNESS_BUNDLE_HASH=[string]$execution.sha256; $env:HARNESS_VALIDATOR_HASH=[string]$execution.members.'scripts/Invoke-ProjectAValidators.ps1'
    $env:HARNESS_MANIFEST_PATH=$manifestPath; $env:PATH="$adapterDir;$env:PATH"
    $arguments=@('--codex','--json',$manifestPath,'--model','gpt-5.6-terra','--max-retries','0','--no-commit','--no-tests','--no-lint','--no-browser')
    if($DryRun){$arguments+=@('--dry-run','--max-iterations','7')}
    & $realRalphy @arguments; $code=$LASTEXITCODE
    if($DryRun){Write-Host "Project A dry run passed. Execution approved: $([bool]$executionApproval.execution_approved). Bundle: $($execution.sha256)";exit $code}
    if($code -ne 0){Write-Host 'Project A paused or failed. Review the current task evidence, approve if requested, then resume:';Write-Host '  .\scripts\Start-ProjectAHarness.ps1 -Resume';exit $code}
    $manifest = Read-JsonFile -Path $manifestPath
    $states = Assert-CompletionContract -Manifest $manifest -StopFlagPath $stopFlag
    Write-JsonNoBom -Path (Join-Path $logRoot 'run-summary.json') -Value ([ordered]@{ run_id = $runId; execution_bundle_sha256 = [string]$execution.sha256; status = 'completed'; branch = $branch; tasks = @($states | Select-Object task_id, terra_attempts, sol_attempts, commit_sha, completed_at) })
} finally { if($lock){$lock.Dispose()} }
