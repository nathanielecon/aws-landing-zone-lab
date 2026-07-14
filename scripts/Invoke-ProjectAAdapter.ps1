[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CodexArguments)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.Common.psm1') -Force

$adapterRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$root = [System.IO.Path]::GetFullPath($env:HARNESS_ROOT)
$realCodex = [System.IO.Path]::GetFullPath($env:HARNESS_REAL_CODEX)
$runId = $env:HARNESS_RUN_ID; $logRoot = $env:HARNESS_LOG_DIR
$bundleHash = $env:HARNESS_BUNDLE_HASH; $validatorHash = $env:HARNESS_VALIDATOR_HASH
foreach ($value in @($runId,$logRoot,$bundleHash,$validatorHash)) { if ([string]::IsNullOrWhiteSpace($value)) { throw 'Missing Project A harness environment.' } }
if ($env:HARNESS_PROFILE_ID -ne 'project-a') { throw 'Project A adapter requires the explicit project-a profile.' }
if ($env:HARNESS_CONTRACT_ONLY -eq '1') {
    $fixture = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../tests/fixtures/fake-codex.cmd'))
    if (-not $realCodex.Equals($fixture, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Contract-only mode refuses live Codex.' }
} else {
    if (-not $root.Equals($adapterRoot, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Project A root transport value does not match the adapter repository.' }
    $profile = Read-HarnessProfile -Root $root -ProfileId 'project-a'
    if ($env:HARNESS_PROFILE_ID -ne [string]$profile.profile_id) { throw 'Project A profile transport value is not approved.' }
    $executionApproval = Read-JsonFile -Path (Resolve-PathUnderRoot -Root $root -RelativePath ([string]$profile.execution_approval_file))
    $execution = & (Join-Path $PSScriptRoot 'Get-ProjectAExecutionHash.ps1') -Root $root | ConvertFrom-Json
    if (-not [bool]$executionApproval.execution_approved -or [string]$executionApproval.execution_bundle_sha256 -ne [string]$execution.sha256 -or [string]$executionApproval.validator_implementation_sha256 -ne [string]$execution.members.'scripts/Invoke-ProjectAValidators.ps1') { throw 'Project A execution approval or implementation hash is not current.' }
    if ($bundleHash -ne [string]$execution.sha256 -or $validatorHash -ne [string]$execution.members.'scripts/Invoke-ProjectAValidators.ps1') { throw 'Project A hash transport values do not match approved local execution facts.' }
    $adapterDirectory = [System.IO.Path]::GetFullPath((Join-Path $root '.harness/bin'))
    $installedCodex = @(Get-Command codex.cmd -All -ErrorAction Stop | Where-Object { -not ([System.IO.Path]::GetFullPath($_.Source)).StartsWith($adapterDirectory, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1)[0]
    if (-not $installedCodex -or -not $realCodex.Equals([System.IO.Path]::GetFullPath($installedCodex.Source), [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Codex executable transport value does not match the installed non-adapter executable.' }
}
$stopFlag = Join-Path $root '.harness/runtime/stop.flag'
if (Test-Path -LiteralPath $stopFlag) { throw 'A prior task failed; the terminal sentinel blocks every additional model call until explicit resume.' }

$stdinText = if ($env:HARNESS_STDIN_OVERRIDE) { [string]$env:HARNESS_STDIN_OVERRIDE } else { [Console]::In.ReadToEnd() }
$manifestPath = $env:HARNESS_MANIFEST_PATH
try {
    $taskId = Get-TaskIdFromArguments -Arguments (@($CodexArguments) + @($stdinText))
} catch {
    if (-not $manifestPath -or -not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw }
    $manifest = Read-JsonFile -Path $manifestPath
    $candidate = @($manifest.tasks | Where-Object { -not [bool]$_.completed } | Select-Object -First 1)[0]
    if (-not $candidate) { throw 'No incomplete task exists in the approved Project A runtime manifest.' }
    $taskId = Get-TaskIdFromArguments -Arguments @([string]$candidate.title)
    if (-not $stdinText) { $stdinText = "$($candidate.title)`n$($candidate.description)" }
}
if ($taskId -notmatch '^A-00[1-7]$') { throw "Task does not belong to Project A: $taskId" }
$policyPath = Join-Path $root "project-a/harness/tasks/$taskId.json"
$policy = Read-JsonFile -Path $policyPath
$policySchemaPath = Join-Path $adapterRoot 'project-a/harness/policy.schema.json'
if (-not (Test-Path -LiteralPath $policySchemaPath -PathType Leaf)) {
    $policySchemaPath = Join-Path $root 'project-a/harness/policy.schema.json'
}
[void](Test-JsonSchema -InputObject $policy -SchemaPath $policySchemaPath -Context "Project A task policy $taskId")
$policyHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $policyPath).Hash
$allowedExecutablePaths = if ($policy.PSObject.Properties.Name -contains 'allowed_executable_paths') { @($policy.allowed_executable_paths | ForEach-Object { [string]$_ }) } else { @() }
$runtimeRoot = Join-Path $root '.harness/runtime/project-a'
$statePath = Join-Path $runtimeRoot "state/$taskId.json"
$takeoverPath = Join-Path $runtimeRoot "takeovers/$taskId.md"
$runtimeExcluded = @(Get-HarnessLifecycleExcludedPaths -Root $root -ProfileId 'project-a')
$taskLogRoot = Join-Path $logRoot $taskId
[System.IO.Directory]::CreateDirectory($taskLogRoot) | Out-Null
$localBase = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $env:USERPROFILE 'AppData/Local' }
$approvalRoot = Join-Path $localBase 'RalphyHarness/cloud/approvals/project-a'
$approvalNamespace = Join-Path $runId $taskId
$requestPath = Join-Path $approvalRoot "requests/$approvalNamespace.json"
$receiptPath = Join-Path $approvalRoot "receipts/$approvalNamespace.json"
$keyPath = Join-Path $approvalRoot "keys/$approvalNamespace.dpapi"
$legacyRequestPath = Join-Path $approvalRoot "requests/$taskId.json"
$legacyReceiptPath = Join-Path $approvalRoot "receipts/$taskId.json"
$legacyKeyPath = Join-Path $approvalRoot "keys/$taskId.dpapi"
$taskLockPath = Join-Path $runtimeRoot "locks/$taskId.lock"
$taskLock = Open-ExclusiveLock -Path $taskLockPath

function Save-State { Write-JsonNoBom -Path $statePath -Value $script:state }
function Stop-ForTimeout([string]$ErrorClass, [string]$Message) {
    $state.status='blocked'; $state.last_error_class=$ErrorClass; $state.last_failure=$Message; Save-State
    Write-HarnessStopSentinel -Root $root -ErrorClass $ErrorClass -Message $Message
    Write-JsonNoBom -Path (Join-Path $taskLogRoot 'summary.json') -Value ([ordered]@{task_id=$taskId;status='blocked';error_class=$ErrorClass;message=$Message})
}
function Invoke-TestKillPoint([string]$Name){if($env:HARNESS_CONTRACT_ONLY -eq '1' -and $env:HARNESS_TEST_KILL_POINT -eq $Name){exit 91}}
function Get-EscalationValue([string]$Name, $DefaultValue) {
    if ($policy.PSObject.Properties.Name -contains 'escalation' -and $policy.escalation -and $policy.escalation.PSObject.Properties.Name -contains $Name) {
        return $policy.escalation.$Name
    }
    return $DefaultValue
}
function Sync-ManifestIfPresent {
    if (-not [string]::IsNullOrWhiteSpace($manifestPath) -and (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        [void](Sync-ProjectAManifestWithTaskState -Root $root -ManifestPath $manifestPath -Branch $branch -BundleHash $bundleHash -ValidatorHash $validatorHash)
    }
}
function Resolve-StateApprovalPath([string]$PropertyName, [string]$DefaultPath) {
    if ($script:state -and $script:state.PSObject.Properties.Name -contains $PropertyName -and -not [string]::IsNullOrWhiteSpace([string]$script:state.$PropertyName)) {
        return [string]$script:state.$PropertyName
    }
    return $DefaultPath
}
function Sync-LegacyApprovalArtifact([string]$SourcePath, [string]$LegacyPath) {
    if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) { return }
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $LegacyPath)) | Out-Null
    Copy-Item -LiteralPath $SourcePath -Destination $LegacyPath -Force
}
function Assert-TaskDependenciesCompleted {
    foreach ($dependencyId in @($policy.depends_on | ForEach-Object { [string]$_ })) {
        if ([string]::IsNullOrWhiteSpace($dependencyId)) { throw "Task $taskId has an empty dependency identifier." }
        $dependencyPolicyPath = Join-Path $root "project-a/harness/tasks/$dependencyId.json"
        $dependencyStatePath = Join-Path $runtimeRoot "state/$dependencyId.json"
        if (-not (Test-Path -LiteralPath $dependencyPolicyPath -PathType Leaf) -or -not (Test-Path -LiteralPath $dependencyStatePath -PathType Leaf)) { throw "Task $taskId cannot run before dependency $dependencyId is completed." }
        $dependencyState = Read-JsonFile -Path $dependencyStatePath
        if (-not (Test-ProjectACompletedTaskState -Root $root -TaskState $dependencyState -TaskId $dependencyId -CurrentHead $head -Branch $branch -BundleHash $bundleHash -ValidatorHash $validatorHash)) { throw "Task $taskId cannot run before dependency $dependencyId has an eligible completed state." }
        & git -C $root merge-base --is-ancestor ([string]$dependencyState.commit_sha) $head 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Task $taskId cannot run before dependency $dependencyId is on this task's starting commit chain." }
    }
}
function Import-LegacyApprovalArtifacts {
    foreach ($pair in @(
        @{ current = (Resolve-StateApprovalPath -PropertyName 'approval_request' -DefaultPath $requestPath); legacy = $legacyRequestPath },
        @{ current = (Resolve-StateApprovalPath -PropertyName 'approval_receipt' -DefaultPath $receiptPath); legacy = $legacyReceiptPath },
        @{ current = (Resolve-StateApprovalPath -PropertyName 'approval_key' -DefaultPath $keyPath); legacy = $legacyKeyPath }
    )) {
        if (-not (Test-Path -LiteralPath $pair.current -PathType Leaf) -and (Test-Path -LiteralPath $pair.legacy -PathType Leaf)) {
            [System.IO.Directory]::CreateDirectory((Split-Path -Parent $pair.current)) | Out-Null
            Copy-Item -LiteralPath $pair.legacy -Destination $pair.current -Force
        }
    }
}

function Invoke-ModelProcess([string[]]$Arguments, [string]$Label, [string]$StandardInput = '') {
    if (Test-Path -LiteralPath $stopFlag) { throw 'A prior task failed; the terminal sentinel blocks every additional model call until explicit resume.' }
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($Arguments | ConvertTo-Json -Compress)))
    $info = [System.Diagnostics.ProcessStartInfo]::new()
    $info.FileName = (Get-Command pwsh -ErrorAction Stop).Source; $info.WorkingDirectory = $root; $info.UseShellExecute = $false
    $info.RedirectStandardInput = $true; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    foreach ($value in @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $PSScriptRoot 'Invoke-NativeCodex.ps1'),'-Executable',$realCodex,'-ArgumentsBase64',$encoded,'-CommonModulePath',(Join-Path $PSScriptRoot 'Harness.Common.psm1'))) { [void]$info.ArgumentList.Add($value) }
    Set-RepoOnlyProcessEnvironment -StartInfo $info -IsolationRoot (Join-Path $taskLogRoot "isolation/$Label")
    $process = [System.Diagnostics.Process]::new(); $process.StartInfo = $info
    try {
        [void]$process.Start(); if ($StandardInput) { $process.StandardInput.Write($StandardInput) }; $process.StandardInput.Close()
        $execution = Invoke-ProcessWithTimeout -Process $process -TimeoutSeconds (Get-PositiveTimeoutSeconds -Policy $policy -Name 'model_timeout_seconds' -DefaultSeconds 900)
        $stdout = Protect-LogText -Text $execution.stdout; $stderr = Protect-LogText -Text $execution.stderr; $code = $execution.exit_code
        if ($execution.timed_out) { Stop-ForTimeout 'MODEL_TIMEOUT' 'MODEL_TIMEOUT: Codex model process exceeded its hard timeout.'; throw 'MODEL_TIMEOUT: Codex model process exceeded its hard timeout.' }
    } finally { $process.Dispose() }
    Write-Utf8NoBom -Path (Join-Path $taskLogRoot "$Label.stdout.jsonl") -Text $stdout
    Write-Utf8NoBom -Path (Join-Path $taskLogRoot "$Label.stderr.log") -Text $stderr
    if ($stdout) { [Console]::Out.Write($stdout) }; if ($stderr) { [Console]::Error.Write($stderr) }
    return [pscustomobject]@{ exit_code=$code; stdout=$stdout; stderr=$stderr; thread_id=Get-ThreadIdFromJsonLines -Text $stdout }
}

function Invoke-Gate([switch]$Committed) {
    $arguments = @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $PSScriptRoot 'Invoke-ProjectAValidators.ps1'),'-Root',$root,'-PolicyPath',$policyPath,'-IsolationRoot',(Join-Path $taskLogRoot 'validators'))
    if ($Committed) { $arguments += '-Committed' }
    $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=(Get-Command pwsh).Source;$info.WorkingDirectory=$root;$info.UseShellExecute=$false;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    foreach($argument in $arguments){[void]$info.ArgumentList.Add($argument)}
    Set-RepoOnlyProcessEnvironment -StartInfo $info -IsolationRoot (Join-Path $taskLogRoot 'gate-environment')
    $process=[Diagnostics.Process]::new();$process.StartInfo=$info
    try{[void]$process.Start();$execution=Invoke-ProcessWithTimeout -Process $process -TimeoutSeconds (Get-PositiveTimeoutSeconds -Policy $policy -Name 'gate_timeout_seconds' -DefaultSeconds 900);$output=$execution.stdout;$stderr=$execution.stderr;$code=$execution.exit_code}finally{$process.Dispose()}
    if($execution.timed_out){Stop-ForTimeout 'GATE_TIMEOUT' 'GATE_TIMEOUT: Project A gate exceeded its hard timeout.';throw 'GATE_TIMEOUT: Project A gate exceeded its hard timeout.'}
    if($stderr){[Console]::Error.Write((Protect-LogText -Text $stderr))}
    $result = (($output -split "`r?`n" | Where-Object { $_ } | Select-Object -Last 1)) | ConvertFrom-Json
    return [pscustomobject]@{ exit_code=$code; result=$result }
}

function New-Takeover($Failure) {
    $changed = @(Get-ChangedPaths -Root $root -ExcludedPaths $runtimeExcluded)
    return @"
# Project A takeover: $taskId

Current state: Terra reached the approved escalation threshold in repo-only mode.
Attempted fixes: $($state.terra_attempts) Terra execution(s).
Failing checks: $($Failure.error_class) - $($Failure.message)
Changed files: $($changed -join ', ')
Suspected cause: deterministic validator failure within the locked task contract.
Recommended next move: change only $($policy.allowed_paths -join ', '), satisfy every declared artifact and validator, do not commit, do not use cloud credentials or live cloud commands.
"@
}

function Write-ApprovalRequest($GateResult, $Diff) {
    $request = [ordered]@{
        schema_version='project-a-approval-request-v1'; task_id=$taskId; gate_id=[string]$policy.approval.gate_id
        execution_bundle_sha256=$bundleHash; validator_implementation_sha256=$validatorHash; policy_sha256=$policyHash
        branch=$state.branch; starting_commit=$state.starting_commit; head=(& git -C $root rev-parse HEAD).Trim()
        diff_sha256=$Diff.sha256; changed_entries=$Diff.entries; validation_digest=[string]$GateResult.validation_digest
        request_nonce=[Guid]::NewGuid().ToString('N'); requested_at=[DateTimeOffset]::UtcNow.ToString('o'); run_id=$runId
    }
    Write-JsonNoBom -Path $requestPath -Value $request
    Sync-LegacyApprovalArtifact -SourcePath $requestPath -LegacyPath $legacyRequestPath
    $state.status='awaiting_approval'; $state.validation_digest=[string]$GateResult.validation_digest; $state.diff_sha256=$Diff.sha256; $state.approval_request=$requestPath; $state.approval_receipt=$receiptPath; $state.approval_key=$keyPath
    Save-State
    Write-Host "Task $taskId is validated and awaiting $($policy.approval.gate_id). Approve with:"
    Write-Host "  .\scripts\Approve-ProjectATask.ps1 -TaskId $taskId"
}

function Complete-Commit($GateResult, $Diff, [string]$ReceiptDigest) {
    if ($Diff.entries.Count -eq 0) { throw 'No approved task diff exists.' }
    $evidencePath = [string]$policy.expected_evidence
    if (Test-Path -LiteralPath (Join-Path $root $evidencePath)) { throw 'Adapter-owned evidence already exists before completion.' }
    $evidence = [ordered]@{
        schema_version='project-a-evidence-v1'; profile_id='project-a'; mode='repo_only'; cloud_validated=$false; aws_implemented=$false; azure_implemented=$false
        execution_bundle_sha256=$bundleHash; validator_implementation_sha256=$validatorHash; policy_sha256=$policyHash
        run_id=$runId; task_id=$taskId; phase_passed=$state.phase; terra_attempts=$state.terra_attempts; sol_attempts=$state.sol_attempts
        starting_commit=$state.starting_commit; diff_sha256=$Diff.sha256; changed_entries=$Diff.entries; validation_digest=[string]$GateResult.validation_digest
        approval_required=[bool]$policy.approval.required; approval_receipt_digest=$ReceiptDigest; completed_at=[DateTimeOffset]::UtcNow.ToString('o')
        commit_parent=$state.starting_commit; commit_lookup="git log -1 --format=%H -- $evidencePath"
    }
    $stagePaths = @($Diff.entries | ForEach-Object { [string]$_.path }) + @($evidencePath)
    $evidenceText=($evidence|ConvertTo-Json -Depth 30)+"`n"
    $state.status='preparing_commit';$state.diff_sha256=$Diff.sha256;$state.stage_paths=@($stagePaths|Sort-Object -Unique);$state.pending_evidence_path=$evidencePath;$state.pending_evidence_text=$evidenceText;$state.evidence_sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($evidenceText)));$state.approval_receipt_digest=$ReceiptDigest;Save-State
    Invoke-TestKillPoint 'after_preparing_state'
    Resume-PendingCommit
}

function Resume-PendingCommit {
    if ($state.status -notin @('preparing_commit','committing')) { throw 'No pending commit transaction exists.' }
    $evidencePath=[string]$state.pending_evidence_path;$fullEvidence=Join-Path $root $evidencePath
    foreach($path in @($state.stage_paths)){& git -C $root reset -q HEAD -- $path 2>$null}
    if(Test-Path -LiteralPath $fullEvidence){$actual=(Get-FileHash -Algorithm SHA256 -LiteralPath $fullEvidence).Hash;if($actual -ne [string]$state.evidence_sha256){throw 'Pending adapter evidence digest mismatch.'};Remove-Item -LiteralPath $fullEvidence -Force}
    $diff=Get-CanonicalDiffRecord -Root $root -AllowedPaths @($policy.allowed_paths) -AdapterOwnedPaths @($policy.adapter_owned_paths) -AllowedExecutablePaths $allowedExecutablePaths -ExcludedPaths $runtimeExcluded
    if($diff.sha256 -ne [string]$state.diff_sha256){throw 'Pending task diff changed before commit recovery.'}
    Write-Utf8NoBom -Path $fullEvidence -Text ([string]$state.pending_evidence_text)
    if((Get-FileHash -Algorithm SHA256 -LiteralPath $fullEvidence).Hash -ne [string]$state.evidence_sha256){throw 'Reconstructed adapter evidence digest mismatch.'}
    Invoke-TestKillPoint 'after_evidence'
    foreach($path in @($state.stage_paths)){& git -C $root add -- $path;if($LASTEXITCODE-ne 0){throw "Staging failed: $path"}}
    Invoke-TestKillPoint 'after_staging'
    $indexed=@(Invoke-GitNullPathList -Root $root -Arguments @('diff','--cached','--name-only','-z') | Sort-Object)
    if(($indexed-join',')-ne(@($state.stage_paths|Sort-Object)-join',')){throw 'Recovered staging index does not match the pending transaction.'}
    $tree=(& git -C $root write-tree).Trim();if($state.intended_tree -and $tree -ne [string]$state.intended_tree){throw 'Recovered Git tree differs from the persisted transaction.'}
    $state.status='committing';$state.intended_tree=$tree;Save-State
    Invoke-TestKillPoint 'after_committing_state'
    & git -C $root commit -m ([string]$policy.commit_message);if($LASTEXITCODE-ne 0){throw 'Gated Project A commit failed.'}
    Invoke-TestKillPoint 'after_commit'
    $state.status='completed';$state.commit_sha=(& git -C $root rev-parse HEAD).Trim();$state.completed_at=[DateTimeOffset]::UtcNow.ToString('o');Save-State
    Sync-ManifestIfPresent
    Write-JsonNoBom -Path (Join-Path $taskLogRoot 'summary.json') -Value ([ordered]@{task_id=$taskId;status='completed';commit_sha=$state.commit_sha;terra_attempts=$state.terra_attempts;sol_attempts=$state.sol_attempts;approval_receipt_digest=$state.approval_receipt_digest})
    foreach($path in @(
        (Resolve-StateApprovalPath -PropertyName 'approval_request' -DefaultPath $requestPath),
        (Resolve-StateApprovalPath -PropertyName 'approval_receipt' -DefaultPath $receiptPath),
        (Resolve-StateApprovalPath -PropertyName 'approval_key' -DefaultPath $keyPath),
        $legacyRequestPath,
        $legacyReceiptPath,
        $legacyKeyPath
    )){Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue}
}

function Finish-Or-Pause($GateResult) {
    $diff = Get-CanonicalDiffRecord -Root $root -AllowedPaths @($policy.allowed_paths) -AdapterOwnedPaths @($policy.adapter_owned_paths) -AllowedExecutablePaths $allowedExecutablePaths -ExcludedPaths $runtimeExcluded
    if ([bool]$policy.approval.required) {
        if ($state.status -ne 'awaiting_approval') { Write-ApprovalRequest -GateResult $GateResult -Diff $diff; return 75 }
        $currentRequestPath = Resolve-StateApprovalPath -PropertyName 'approval_request' -DefaultPath $requestPath
        $currentReceiptPath = Resolve-StateApprovalPath -PropertyName 'approval_receipt' -DefaultPath $receiptPath
        $currentKeyPath = Resolve-StateApprovalPath -PropertyName 'approval_key' -DefaultPath $keyPath
        $verifyOutput = & (Join-Path $PSScriptRoot 'Test-ProjectAApproval.ps1') -Root $root -PolicyPath $policyPath -RequestPath $currentRequestPath -ReceiptPath $currentReceiptPath -KeyPath $currentKeyPath
        if ($LASTEXITCODE -ne 0) { throw "Approval verification failed: $verifyOutput" }
        $verified = $verifyOutput | ConvertFrom-Json
        Complete-Commit -GateResult $GateResult -Diff $diff -ReceiptDigest ([string]$verified.receipt_digest)
        return 0
    }
    Complete-Commit -GateResult $GateResult -Diff $diff -ReceiptDigest $null
    return 0
}

$branch = (& git -C $root branch --show-current).Trim(); $head = (& git -C $root rev-parse HEAD).Trim()
if ($branch -notmatch '^codex/project-a-(harness|build)$') { throw "Project A adapter rejects branch: $branch" }
try {
Assert-TaskDependenciesCompleted
if (Test-Path -LiteralPath $statePath) {
    $state = Read-JsonFile -Path $statePath
    foreach ($binding in @{profile_id='project-a';bundle_hash=$bundleHash;policy_sha256=$policyHash;validator_sha256=$validatorHash;branch=$branch}.GetEnumerator()) {
        if ([string]$state.($binding.Key) -ne [string]$binding.Value) { throw "Persisted state binding mismatch: $($binding.Key)" }
    }
    if ($state.status -eq 'blocked') { throw "Task $taskId is blocked and requires explicit operator recovery: $($state.last_failure)" }
    if ($state.status -eq 'completed') { throw "Task $taskId is already completed." }
    if ([string]$state.starting_commit -ne $head) {
        $parent = (& git -C $root rev-parse "$head^").Trim(); $subject = (& git -C $root log -1 --format=%s).Trim()
        $tree=(& git -C $root rev-parse "$head^{tree}").Trim();$commitPaths=@(Invoke-GitNullPathList -Root $root -Arguments @('diff-tree','--no-commit-id','--name-only','-z','-r',$head) | Sort-Object)
        $evidencePath=[string]$policy.expected_evidence;$evidenceHash=if(Test-Path -LiteralPath (Join-Path $root $evidencePath)){(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $root $evidencePath)).Hash}else{$null}
        if ($state.status -ne 'committing' -or $parent -ne [string]$state.starting_commit -or $subject -ne [string]$policy.commit_message -or $tree -ne [string]$state.intended_tree -or ($commitPaths -join ',') -ne (@($state.stage_paths|Sort-Object)-join ',') -or $evidenceHash -ne [string]$state.evidence_sha256 -or @(Get-ChangedPaths -Root $root -ExcludedPaths $runtimeExcluded).Count -ne 0 -or -not (Test-ProjectACompletedTaskState -Root $root -TaskState $state -TaskId $taskId -CurrentHead $head -Branch $branch -BundleHash $bundleHash -ValidatorHash $validatorHash -CommitSha $head -AllowCommitting)) { throw 'HEAD no longer matches the exact owned interrupted commit.' }
        $state.status='completed'; $state.commit_sha=$head; $state.completed_at=[DateTimeOffset]::UtcNow.ToString('o'); Save-State; Sync-ManifestIfPresent; exit 0
    }
} else {
    if (@(Get-ChangedPaths -Root $root -ExcludedPaths $runtimeExcluded).Count -gt 0) { throw 'Fresh Project A task requires a clean tree.' }
    $state = [pscustomobject][ordered]@{profile_id='project-a';bundle_hash=$bundleHash;validator_sha256=$validatorHash;policy_sha256=$policyHash;task_id=$taskId;branch=$branch;starting_commit=$head;started_at=[DateTimeOffset]::UtcNow.ToString('o');status='running';phase='terra';terra_attempts=0;sol_attempts=0;consecutive_failures=0;same_error_count=0;last_error_class=$null;last_failure=$null;terra_thread_id=$null;sol_thread_id=$null;validation_digest=$null;diff_sha256=$null;approval_request=$requestPath;approval_receipt=$receiptPath;approval_key=$keyPath;approval_receipt_digest=$null;intended_tree=$null;stage_paths=@();pending_evidence_path=$null;pending_evidence_text=$null;evidence_sha256=$null;commit_sha=$null;completed_at=$null}; Save-State
}

if($state.status -in @('preparing_commit','committing')){Resume-PendingCommit;exit 0}

if ($state.status -eq 'awaiting_approval') {
    Import-LegacyApprovalArtifacts
    $gateEnvelope = Invoke-Gate
    if (-not [bool]$gateEnvelope.result.passed) { throw "Validated diff changed before approval: $($gateEnvelope.result.message)" }
    if ([string]$gateEnvelope.result.validation_digest -ne [string]$state.validation_digest) { throw 'Validation results changed after the approval request.' }
    exit (Finish-Or-Pause -GateResult $gateEnvelope.result)
}

$existing = @(Get-ChangedPaths -Root $root -ExcludedPaths $runtimeExcluded)
if ($existing.Count -gt 0) {
    $gateEnvelope = Invoke-Gate
    if ([bool]$gateEnvelope.result.passed) { exit (Finish-Or-Pause -GateResult $gateEnvelope.result) }
}

$outputLastMessage = Get-OutputLastMessagePath -Arguments $CodexArguments
while ($true) {
    $before = Get-DiffFingerprint -Root $root -ExcludedPaths $runtimeExcluded
    if ($state.phase -eq 'terra') {
        $state.terra_attempts=[int]$state.terra_attempts+1; $label="terra-$($state.terra_attempts)"; Save-State
        if ($state.terra_attempts -eq 1 -and -not $state.terra_thread_id) { $arguments=New-RepoOnlyInitialCodexArguments -Arguments $CodexArguments -Model 'gpt-5.6-terra'; $input=$stdinText }
        else { $arguments=New-RepoOnlyResumeCodexArguments -Model 'gpt-5.6-terra' -ThreadId ([string]$state.terra_thread_id) -Prompt "Repair $taskId within its policy. Last gate: $($state.last_failure). Do not commit." -OutputLastMessage $outputLastMessage; $input='' }
        $execution=Invoke-ModelProcess -Arguments $arguments -Label $label -StandardInput $input; if ($execution.thread_id) { $state.terra_thread_id=$execution.thread_id }
        if ($execution.exit_code -ne 0) { $gate=[pscustomobject]@{passed=$false;error_class="CODEX_EXIT_$($execution.exit_code)";message='Terra exited non-zero.'} }
        else { $gateEnvelope=Invoke-Gate; $gate=$gateEnvelope.result }
        if ([bool]$gate.passed) { Save-State; exit (Finish-Or-Pause -GateResult $gate) }
        $after=Get-DiffFingerprint -Root $root -ExcludedPaths $runtimeExcluded; $noDiff=$before -eq $after; $state.consecutive_failures=[int]$state.consecutive_failures+1
        if ($state.last_error_class -eq $gate.error_class) { $state.same_error_count=[int]$state.same_error_count+1 } else { $state.same_error_count=1 }
        $state.last_error_class=[string]$gate.error_class; $state.last_failure=[string]$gate.message
        $elapsed=([DateTimeOffset]::UtcNow-[DateTimeOffset]::Parse([string]$state.started_at)).TotalMinutes
        $escalate=Test-TerraEscalation -ForceApplied $false -Attempts $state.terra_attempts -AttemptLimit $policy.terra_attempt_limit -ConsecutiveFailures $state.consecutive_failures -ConsecutiveFailureLimit ([int](Get-EscalationValue -Name 'consecutive_failures' -DefaultValue 2)) -SameErrorCount $state.same_error_count -SameErrorLimit ([int](Get-EscalationValue -Name 'same_error_count' -DefaultValue 2)) -NoDiff $noDiff -EscalateOnNoDiff ([int](Get-EscalationValue -Name 'no_diff_repairs' -DefaultValue 1) -gt 0) -ElapsedMinutes $elapsed -ElapsedLimitMinutes $policy.elapsed_limit_minutes -EscalateOnScopeEscape ([bool](Get-EscalationValue -Name 'scope_escape' -DefaultValue $true)) -ErrorClass ([string]$gate.error_class)
        if (-not $escalate) { Save-State; continue }
        $state.phase='sol'; Write-Utf8NoBom -Path $takeoverPath -Text (New-Takeover -Failure $gate); Save-State
    }
    $state.sol_attempts=[int]$state.sol_attempts+1; $label="sol-$($state.sol_attempts)"; Save-State
    $prompt=if ($state.sol_attempts -eq 1) { Get-Content -Raw -LiteralPath $takeoverPath } else { "Repair $taskId after: $($state.last_failure). Do not commit." }
    if ($state.sol_attempts -eq 1 -or -not $state.sol_thread_id) { $arguments=New-RepoOnlyInitialCodexArguments -Arguments @('exec','--json',$prompt) -Model 'gpt-5.6-sol' }
    else { $arguments=New-RepoOnlyResumeCodexArguments -Model 'gpt-5.6-sol' -ThreadId ([string]$state.sol_thread_id) -Prompt $prompt -OutputLastMessage $outputLastMessage }
    $execution=Invoke-ModelProcess -Arguments $arguments -Label $label; if ($execution.thread_id) { $state.sol_thread_id=$execution.thread_id }
    if ($execution.exit_code -ne 0) { $gate=[pscustomobject]@{passed=$false;error_class="CODEX_EXIT_$($execution.exit_code)";message='Sol exited non-zero.'} } else { $gateEnvelope=Invoke-Gate; $gate=$gateEnvelope.result }
    if ([bool]$gate.passed) { Save-State; exit (Finish-Or-Pause -GateResult $gate) }
    $state.last_error_class=[string]$gate.error_class; $state.last_failure=[string]$gate.message
    if ($state.sol_attempts -ge 2) { $state.status='blocked'; Save-State; throw "Sol exhausted both passes: $($gate.message)" }
    Save-State
}
} finally {
    if ($taskLock) { $taskLock.Dispose() }
}
