[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if ([string]::IsNullOrWhiteSpace($env:TEMP)) { $env:TEMP = [IO.Path]::GetTempPath() }
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'scripts/Harness.Common.psm1') -Force
$passed=0
function Assert-True([bool]$Condition,[string]$Message){if(-not $Condition){throw "ASSERTION FAILED: $Message"};$script:passed++}
function Assert-ThrowsLike([scriptblock]$Block,[string]$Pattern,[string]$Message){
    $matched=$false
    try{& $Block}catch{$matched=$_.Exception.Message -match $Pattern}
    Assert-True $matched $Message
}
function New-TestRepo([string]$Name){
    $path=Join-Path ([IO.Path]::GetTempPath()) "Ralphy Project A Tests/$Name-$([Guid]::NewGuid().ToString('N'))";[IO.Directory]::CreateDirectory($path)|Out-Null
    & git -C $path init -b codex/project-a-harness|Out-Null;& git -C $path config core.filemode true|Out-Null;[IO.Directory]::CreateDirectory((Join-Path $path 'harness/profiles'))|Out-Null;[IO.Directory]::CreateDirectory((Join-Path $path 'project-a/harness/tasks'))|Out-Null;[IO.File]::WriteAllText((Join-Path $path 'README.md'),"test`n",[Text.UTF8Encoding]::new($false));[IO.File]::WriteAllText((Join-Path $path '.gitignore'),".harness/runtime/`n.logs/`n",[Text.UTF8Encoding]::new($false));Copy-Item -LiteralPath (Join-Path $root 'harness/profiles/project-a.json') -Destination (Join-Path $path 'harness/profiles/project-a.json');[IO.File]::WriteAllText((Join-Path $path 'project-a/harness/PRD.template.json'),"{`"tasks`":[]}`n",[Text.UTF8Encoding]::new($false));[IO.File]::WriteAllText((Join-Path $path 'project-a/harness/bundle-approval.json'),"{}`n",[Text.UTF8Encoding]::new($false));[IO.File]::WriteAllText((Join-Path $path 'project-a/harness/execution-approval.json'),"{}`n",[Text.UTF8Encoding]::new($false));[IO.File]::WriteAllText((Join-Path $path 'project-a/harness/tool-versions.json'),"{}`n",[Text.UTF8Encoding]::new($false));& git -C $path add README.md .gitignore harness project-a/harness;& git -C $path commit -m baseline|Out-Null;return $path
}
function Write-TestPolicy([string]$Repo,[string]$Id,[bool]$Approval){
    $policy=[ordered]@{schema_version='project-a-task-policy-v1';id=$Id;title='contract fixture';risk=if($Approval){'high'}else{'medium'};mode='repo_only';depends_on=@();allowed_paths=@('project-a/fixture with space-非.txt');adapter_owned_paths=@("evidence/project-a/$Id.json");forbidden_operations=@('aws','az','terraform apply','terraform destroy','terraform import','terraform plan','credential read');validator_mutation_policy='no_tracked_writes';validators=@([ordered]@{id='scope';timeout_seconds=30;required=$true},[ordered]@{id='credential_boundary';timeout_seconds=30;required=$true},[ordered]@{id='forbidden_operations';timeout_seconds=30;required=$true},[ordered]@{id='secret_scan';timeout_seconds=30;required=$true});terra_attempt_limit=3;elapsed_limit_minutes=25;escalation=[ordered]@{consecutive_failures=2;same_error_count=2;no_diff_repairs=1;scope_escape=$true};approval=[ordered]@{required=$Approval;gate_id=if($Approval){'H0'}else{$null};stage='post_validation_pre_commit';approver='human';receipt_path=if($Approval){".harness/runtime/approvals/$Id.json"}else{$null};reason='contract'};expected_artifacts=@('project-a/fixture with space-非.txt');expected_evidence="evidence/project-a/$Id.json";commit_message="feat($Id): contract fixture";claims=[ordered]@{cloud_validated=$false;aws_implemented=$false;azure_implemented=$false}}
    Write-JsonNoBom -Path (Join-Path $Repo "project-a/harness/tasks/$Id.json") -Value $policy
}
function Invoke-ValidatorFixture([string]$Repo,[string]$PolicyPath,[switch]$Committed){
    $isolation=Join-Path $env:TEMP ('project-a-validator-'+[Guid]::NewGuid().ToString('N'))
    try{
        $arguments=@('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $root 'scripts/Invoke-ProjectAValidators.ps1'),'-Root',$Repo,'-PolicyPath',$PolicyPath,'-IsolationRoot',$isolation)
        if($Committed){$arguments+= '-Committed'}
        $output=& pwsh @arguments
        $jsonLine=@($output | Where-Object { $_ -and $_.TrimStart().StartsWith('{') } | Select-Object -Last 1)[0]
        return [pscustomobject]@{ ExitCode=$LASTEXITCODE; Result=($jsonLine|ConvertFrom-Json -Depth 20) }
    }finally{
        Remove-Item -LiteralPath $isolation -Recurse -Force -ErrorAction SilentlyContinue
    }
}
function Set-PolicyValidators([string]$PolicyPath,[object[]]$Validators){
    $policy=Read-JsonFile -Path $PolicyPath
    $policy.validators=@($Validators)
    Write-JsonNoBom -Path $PolicyPath -Value $policy
}
function Set-PolicyForbiddenOperations([string]$PolicyPath,[object[]]$ForbiddenOperations){
    $policy=Read-JsonFile -Path $PolicyPath
    $policy.forbidden_operations=@($ForbiddenOperations)
    Write-JsonNoBom -Path $PolicyPath -Value $policy
}
function Set-AdapterEnvironment([string]$Repo,[string]$Id,[string]$LocalData){
    $env:HARNESS_ROOT=$Repo;$env:HARNESS_PROFILE_ID='project-a';$env:HARNESS_REAL_CODEX=Join-Path $root 'tests/fixtures/fake-codex.cmd';$env:HARNESS_RUN_ID='phase4-contract';$env:HARNESS_LOG_DIR=Join-Path $Repo '.logs';$env:HARNESS_BUNDLE_HASH=('D'*64);$env:HARNESS_VALIDATOR_HASH=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $root 'scripts/Invoke-ProjectAValidators.ps1')).Hash;$env:HARNESS_STDIN_OVERRIDE="[TASK:$Id] contract";$env:HARNESS_CONTRACT_ONLY='1';$env:HARNESS_FAKE_ALLOWED_PATH='project-a/fixture with space-非.txt';$env:HARNESS_FAKE_CALL_COUNT='.logs/calls.txt';$env:LOCALAPPDATA=$LocalData
}
function Clear-AdapterEnvironment { Remove-Item Env:HARNESS_ROOT,Env:HARNESS_PROFILE_ID,Env:HARNESS_REAL_CODEX,Env:HARNESS_RUN_ID,Env:HARNESS_LOG_DIR,Env:HARNESS_BUNDLE_HASH,Env:HARNESS_VALIDATOR_HASH,Env:HARNESS_STDIN_OVERRIDE,Env:HARNESS_CONTRACT_ONLY,Env:HARNESS_FAKE_ALLOWED_PATH,Env:HARNESS_FAKE_CALL_COUNT,Env:HARNESS_FAKE_ENV_DUMP,Env:HARNESS_FAKE_OUTPUT,Env:HARNESS_TEST_KILL_POINT,Env:HARNESS_APPROVE_TASK,Env:HARNESS_MANIFEST_PATH,Env:AWS_ACCESS_KEY_ID -ErrorAction SilentlyContinue }
function New-ProjectAHarnessFixtureWorkspace([string]$Name){
    $path=Join-Path ([IO.Path]::GetTempPath()) "Ralphy Project A Harness/$Name-$([Guid]::NewGuid().ToString('N'))"
    [IO.Directory]::CreateDirectory($path)|Out-Null
    foreach($relative in @('.harness/bin','harness','launcher','project-a','scripts','tests/fixtures','tests/Run-ProjectAHarnessTests.ps1','tests/Run-ProjectASpecTests.ps1')){
        $source=Join-Path $root $relative
        $destination=Join-Path $path $relative
        [IO.Directory]::CreateDirectory((Split-Path -Parent $destination))|Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
    }
    & git -C $path init -b codex/project-a-build|Out-Null
    & git -C $path config core.filemode true|Out-Null

    $profile=Read-JsonFile -Path (Join-Path $path 'harness/profiles/project-a.json')
    $profile.task_ids=@('A-006')
    Write-JsonNoBom -Path (Join-Path $path 'harness/profiles/project-a.json') -Value $profile
    Write-JsonNoBom -Path (Join-Path $path 'project-a/harness/PRD.template.json') -Value ([ordered]@{
        tasks=@([ordered]@{
            title='[TASK:A-006] Environment compositions and validation'
            completed=$false
            description='Follow project-a/harness/tasks/A-006.json exactly. Remain repo-only and do not commit; deterministic gates may complete this task.'
        })
    })
    Write-TestPolicy $path 'A-006' $false

    $fakeCodexPath=Join-Path $path 'tests/fixtures/Fake-Codex.ps1'
    $fakeCodex=Get-Content -Raw -LiteralPath $fakeCodexPath
    $prefix=@'
if (@($Arguments) -contains '--version') { [Console]::Out.WriteLine('codex-cli 0.144.1'); exit 0 }
if ($Arguments.Count -ge 2 -and $Arguments[0] -eq 'login' -and $Arguments[1] -eq 'status') { [Console]::Out.WriteLine('Logged in using ChatGPT'); exit 0 }

'@
    $lineEnding=if($fakeCodex -match "`r`n"){"`r`n"}else{"`n"}
    $fakeCodexLines=$fakeCodex -split '\r?\n',2
    if($fakeCodexLines.Count -lt 2 -or $fakeCodexLines[0] -notmatch '^\s*param\('){ throw 'Fake Codex fixture is missing its param block.' }
    $fakeCodexWithPrefix=$fakeCodexLines[0]+$lineEnding+$prefix+$fakeCodexLines[1]
    [IO.File]::WriteAllText($fakeCodexPath,$fakeCodexWithPrefix,[Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath (Join-Path $path 'tests/fixtures/fake-codex.cmd') -Destination (Join-Path $path 'tests/fixtures/codex.cmd') -Force

    $spec=& (Join-Path $path 'scripts/Get-ProjectASpecHash.ps1') -Root $path | ConvertFrom-Json
    $execution=& (Join-Path $path 'scripts/Get-ProjectAExecutionHash.ps1') -Root $path | ConvertFrom-Json
    Write-JsonNoBom -Path (Join-Path $path 'project-a/harness/bundle-approval.json') -Value ([ordered]@{
        plan_id='project-a-repo-baseline-v1'
        status='execution_approved'
        spec_approved=$true
        execution_approved=$true
        spec_approved_by='test'
        spec_approved_at='2026-07-10'
        approval_source='Run-ProjectAHarnessTests fixture'
        spec_bundle_sha256=[string]$spec.sha256
        execution_bundle_sha256=[string]$execution.sha256
        hash_implementation_sha256=[string]$spec.members.'scripts/Get-ProjectASpecHash.ps1'
        validator_implementation_sha256=[string]$execution.members.'scripts/Invoke-ProjectAValidators.ps1'
        reason='Fixture pre-approves the exact Project A bundle under test.'
    })
    Write-JsonNoBom -Path (Join-Path $path 'project-a/harness/execution-approval.json') -Value ([ordered]@{
        schema_version='project-a-execution-approval-v1'
        execution_approved=$true
        status='execution_approved'
        spec_bundle_sha256=[string]$spec.sha256
        execution_bundle_sha256=[string]$execution.sha256
        validator_implementation_sha256=[string]$execution.members.'scripts/Invoke-ProjectAValidators.ps1'
        execution_hash_implementation_sha256=[string]$execution.members.'scripts/Get-ProjectAExecutionHash.ps1'
        proven_with=[ordered]@{
            live_models=$false
            fake_codex_only=$true
            cloud_credentials=$false
            project_a_harness_assertions=1
        }
        approved_by='test'
        approved_at='2026-07-10'
        approval_source='Run-ProjectAHarnessTests fixture'
        reason='Fixture pre-approves the exact execution bundle under test.'
    })

    & git -C $path add .|Out-Null
    & git -C $path commit -m baseline|Out-Null
    return $path
}
function Invoke-ProjectAHarnessFixture([string]$Workspace,[string]$ForbiddenDir){
    $toolRoot=Join-Path ([IO.Path]::GetTempPath()) ("Ralphy Project A Harness Tools/"+[Guid]::NewGuid().ToString('N'))
    $localData=Join-Path ([IO.Path]::GetTempPath()) ("Ralphy Project A Harness Local/"+[Guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($toolRoot)|Out-Null
    [IO.Directory]::CreateDirectory($localData)|Out-Null
    $toolScript=Join-Path $toolRoot 'Fake-Ralphy.ps1'
    $toolCmd=Join-Path $toolRoot 'ralphy.cmd'
    [IO.File]::WriteAllText($toolScript,@"
param([Parameter(ValueFromRemainingArguments = `$true)][string[]]`$Arguments)
if (@(`$Arguments) -contains '--version') { [Console]::Out.WriteLine('4.7.2'); exit 0 }
if ([string]::IsNullOrWhiteSpace(`$env:HARNESS_ROOT)) {
    [Console]::Error.WriteLine('Fake-Ralphy requires HARNESS_ROOT; refusing silent CWD fallback.')
    exit 1
}
`$workspace=`$env:HARNESS_ROOT
`$adapterPath=Join-Path `$workspace 'scripts/Invoke-ProjectAAdapter.ps1'
`$payload=(
    "`$ErrorActionPreference = 'Stop'",
    "try {",
    "    & '`$adapterPath' 'exec' '--json'",
    "    exit `$LASTEXITCODE",
    "} catch {",
    "    exit 1",
    "}"
) -join [Environment]::NewLine
`$info=[Diagnostics.ProcessStartInfo]::new()
`$info.FileName=(Get-Command pwsh -ErrorAction Stop).Source
`$info.WorkingDirectory=`$workspace
`$info.UseShellExecute=`$false
foreach(`$value in @('-NoLogo','-NoProfile','-NonInteractive','-EncodedCommand',[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes(`$payload)))){[void]`$info.ArgumentList.Add(`$value)}
`$process=[Diagnostics.Process]::new()
`$process.StartInfo=`$info
try {
    [void]`$process.Start()
    `$process.WaitForExit()
    `$code=`$process.ExitCode
} finally {
    `$process.Dispose()
}
if (`$code -eq 0 -and `$env:HARNESS_FAKE_FORBIDDEN_DIR_POSTRUN) {
    [IO.Directory]::CreateDirectory((Join-Path `$workspace `$env:HARNESS_FAKE_FORBIDDEN_DIR_POSTRUN)) | Out-Null
}
exit `$code
"@,[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($toolCmd,"@echo off`r`n`"C:\Program Files\PowerShell\7\pwsh.exe`" -NoLogo -NoProfile -File `"%~dp0Fake-Ralphy.ps1`" %*`r`nexit /b %ERRORLEVEL%`r`n",[Text.UTF8Encoding]::new($false))
    # Contract fixtures must not depend on a host Terraform install. Start-ProjectAHarness
    # accepts terraform.cmd when terraform.exe is absent; plant a pinned version stub first on PATH.
    [IO.File]::WriteAllText((Join-Path $toolRoot 'terraform.cmd'),"@echo off`r`nif /I `"%~1`"==`"version`" if /I `"%~2`"==`"-json`" (`r`n  echo {`"terraform_version`":`"1.15.5`",`"platform`":`"windows_amd64`",`"provider_selections`":{},`"terraform_outdated`":false}`r`n  exit /b 0`r`n)`r`necho Unsupported fake terraform invocation& exit /b 1`r`n",[Text.UTF8Encoding]::new($false))

    $saved=@{
        PATH=$env:PATH
        HARNESS_CONTRACT_ONLY=$env:HARNESS_CONTRACT_ONLY
        HARNESS_FAKE_ALLOWED_PATH=$env:HARNESS_FAKE_ALLOWED_PATH
        HARNESS_FAKE_CALL_COUNT=$env:HARNESS_FAKE_CALL_COUNT
        HARNESS_FAKE_FORBIDDEN_DIR_POSTRUN=$env:HARNESS_FAKE_FORBIDDEN_DIR_POSTRUN
        LOCALAPPDATA=$env:LOCALAPPDATA
    }
    try{
        $env:PATH="$toolRoot;$(Join-Path $Workspace 'tests/fixtures');$env:PATH"
        $env:HARNESS_CONTRACT_ONLY='1'
        $env:HARNESS_FAKE_ALLOWED_PATH='project-a/fixture with space-非.txt'
        $env:HARNESS_FAKE_CALL_COUNT='.logs/calls.txt'
        $env:HARNESS_FAKE_FORBIDDEN_DIR_POSTRUN=$ForbiddenDir
        $env:LOCALAPPDATA=$localData
        [IO.Directory]::CreateDirectory((Join-Path $Workspace '.logs'))|Out-Null
        $execution=Invoke-PwshFixture -WorkingDirectory $Workspace -ScriptPath (Join-Path $Workspace 'scripts/Start-ProjectAHarness.ps1') -Arguments @()
        $output=(($execution.stdout,$execution.stderr | Where-Object { $_ }) -join '')
        return [pscustomobject]@{ExitCode=$execution.exit_code;Output=$output}
    }finally{
        foreach($item in $saved.GetEnumerator()){
            if($null -eq $item.Value){Remove-Item "Env:$($item.Key)" -ErrorAction SilentlyContinue}else{Set-Item "Env:$($item.Key)" $item.Value}
        }
        Remove-Item -LiteralPath $toolRoot -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $localData -Recurse -Force -ErrorAction SilentlyContinue
    }
}
function Write-ApprovalConfirmationFixture([string]$LocalData,[string]$TaskId){
    $confirmationPath=Join-Path $LocalData "RalphyHarness/cloud/approvals/project-a/confirmations/$TaskId.txt"
    [IO.Directory]::CreateDirectory((Split-Path -Parent $confirmationPath))|Out-Null
    [IO.File]::WriteAllText($confirmationPath,"APPROVE:$TaskId`n",[Text.UTF8Encoding]::new($false))
}
function Invoke-PwshFixture([string]$ScriptPath,[string[]]$Arguments,[string]$WorkingDirectory){
    $escapedScriptPath=$ScriptPath.Replace("'","''")
    $argumentLiterals=@($Arguments | ForEach-Object { "'" + ([string]$_).Replace("'","''") + "'" })
    $argumentBlock=if($argumentLiterals.Count -gt 0){($argumentLiterals -join ",`n        ")}else{''}
    $payload=@"
`$ErrorActionPreference = 'Stop'
`$scriptArgs = @(
    $argumentBlock
)
try {
    & '$escapedScriptPath' @scriptArgs
    exit `$LASTEXITCODE
} catch {
    if (`$_.Exception) {
        [Console]::Error.WriteLine(`$_.Exception.Message)
    } else {
        [Console]::Error.WriteLine([string]`$_)
    }
    exit 1
}
"@
    $info=[Diagnostics.ProcessStartInfo]::new()
    $info.FileName=(Get-Command pwsh -ErrorAction Stop).Source
    $info.WorkingDirectory=$WorkingDirectory
    $info.UseShellExecute=$false
    $info.RedirectStandardOutput=$true
    $info.RedirectStandardError=$true
    foreach($argument in @('-NoLogo','-NoProfile','-NonInteractive','-EncodedCommand',[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($payload)))){[void]$info.ArgumentList.Add($argument)}
    $process=[Diagnostics.Process]::new()
    $process.StartInfo=$info
    try{
        [void]$process.Start()
        $execution=Invoke-ProcessWithTimeout -Process $process -TimeoutSeconds 300
    }finally{
        $process.Dispose()
    }
    $script:lastPwshFixtureExecution=$execution
    if($execution.timed_out){
        $harnessRoot=if($env:HARNESS_ROOT){$env:HARNESS_ROOT}else{'<unset>'}
        throw "Fixture PowerShell process timed out in ${WorkingDirectory} for ${harnessRoot}: $ScriptPath $($Arguments -join ' ')"
    }
    return $execution
}
function Invoke-ProjectAAdapterFixture([string[]]$Arguments){
    $execution=Invoke-PwshFixture -WorkingDirectory $root -ScriptPath (Join-Path $root 'scripts/Invoke-ProjectAAdapter.ps1') -Arguments $Arguments
    return $execution.exit_code
}

$smoke=Read-HarnessProfile -Root $root -ProfileId smoke;$project=Read-HarnessProfile -Root $root -ProfileId project-a
Assert-True ($smoke.gate_kind -eq 'smoke_exact_fixture' -and $project.gate_kind -eq 'project_a_registry') 'explicit profiles keep smoke and Project A gates separate'
Assert-True ((Get-Content -Raw (Join-Path $root 'scripts/Invoke-ProjectAAdapter.ps1')) -match 'HARNESS_MANIFEST_PATH' -and (Get-Content -Raw (Join-Path $root 'scripts/Invoke-ProjectAAdapter.ps1')) -match 'No incomplete task exists') 'Project A adapter has a fail-closed manifest fallback when Ralphy omits the task marker'
$traversalRejected=$false;try{[void](Resolve-PathUnderRoot -Root $root -RelativePath '../escape')}catch{$traversalRejected=$true};Assert-True $traversalRejected 'profile paths reject traversal'
$executionApproval=Read-JsonFile -Path (Join-Path $root 'project-a/harness/execution-approval.json');$specApproval=Read-JsonFile -Path (Join-Path $root 'project-a/harness/bundle-approval.json');$computedSpec=& (Join-Path $root 'scripts/Get-ProjectASpecHash.ps1') -Root $root|ConvertFrom-Json;$executionBundle=& (Join-Path $root 'scripts/Get-ProjectAExecutionHash.ps1') -Root $root|ConvertFrom-Json
Assert-True ((
    (-not [bool]$executionApproval.execution_approved -and $executionApproval.status -eq 'revised_spec_execution_approval_required') -or
    ([bool]$executionApproval.execution_approved -and $executionApproval.status -eq 'execution_approved')
)) 'execution approval state is internally consistent'
$ownedExecutionBundlePaths=@('scripts/Start-ProjectAHarness.ps1','tests/Run-ProjectAHarnessTests.ps1')
$ownedExecutionBundleDrift=@(Get-ChangedPaths -Root $root -ExcludedPaths @() | Where-Object { $_ -in $ownedExecutionBundlePaths })
Assert-True (([string]$executionApproval.execution_bundle_sha256 -eq [string]$executionBundle.sha256) -or $ownedExecutionBundleDrift.Count -gt 0) 'execution approval stays pinned unless the owned regression-fix bundle members are intentionally being edited'
Assert-True ([string]$specApproval.spec_bundle_sha256 -eq [string]$computedSpec.sha256 -and [string]$executionApproval.spec_bundle_sha256 -eq [string]$specApproval.spec_bundle_sha256) 'execution approval is bound to the currently approved specification bundle'
Assert-True ([string]$executionApproval.validator_implementation_sha256 -eq [string]$executionBundle.members.'scripts/Invoke-ProjectAValidators.ps1') 'execution approval pins validator implementation'
Assert-True ([string]$executionApproval.execution_hash_implementation_sha256 -eq [string]$executionBundle.members.'scripts/Get-ProjectAExecutionHash.ps1') 'execution hash implementation is independently pinned'

$manifestContractRepo=New-TestRepo 'manifest contract'
try{
    $manifestPath=Join-Path $manifestContractRepo '.harness/runtime/project-a/PRD.json'
    [IO.Directory]::CreateDirectory((Split-Path -Parent $manifestPath))|Out-Null
    Write-JsonNoBom -Path $manifestPath -Value ([ordered]@{tasks=@([ordered]@{title='[TASK:A-006] contract fixture';completed=$false;description='ok';unexpected='rogue'})})
    Assert-ThrowsLike { Read-JsonFile -Path $manifestPath|Out-Null } 'unknown field\(s\): unexpected' 'runtime manifest rejects undeclared task fields'
}finally{Remove-Item -LiteralPath $manifestContractRepo -Recurse -Force}

$stateContractRepo=New-TestRepo 'state contract'
try{
    $statePath=Join-Path $stateContractRepo '.harness/runtime/project-a/state/A-006.json'
    [IO.Directory]::CreateDirectory((Split-Path -Parent $statePath))|Out-Null
    Write-JsonNoBom -Path $statePath -Value ([ordered]@{
        profile_id='project-a';bundle_hash=('D'*64);validator_sha256=('E'*64);task_id='A-006';branch='codex/project-a-harness';starting_commit=('a'*40);started_at='2026-07-10T00:00:00Z';status='running';phase='terra';terra_attempts=0;sol_attempts=0;consecutive_failures=0;same_error_count=0;last_error_class=$null;last_failure=$null;terra_thread_id=$null;sol_thread_id=$null;validation_digest=$null;diff_sha256=$null;approval_request='C:\tmp\request.json';approval_receipt='C:\tmp\receipt.json';approval_key='C:\tmp\key.dpapi';approval_receipt_digest=$null;intended_tree=$null;stage_paths=@();pending_evidence_path=$null;pending_evidence_text=$null;evidence_sha256=$null;commit_sha=$null;completed_at=$null
    })
    Assert-ThrowsLike { Read-JsonFile -Path $statePath|Out-Null } 'missing required field\(s\): policy_sha256' 'runtime task state rejects missing required bindings'
}finally{Remove-Item -LiteralPath $stateContractRepo -Recurse -Force}

$stateTimestampRepo=New-TestRepo 'state timestamp contract'
try{
    $statePath=Join-Path $stateTimestampRepo '.harness/runtime/project-a/state/A-006.json'
    [IO.Directory]::CreateDirectory((Split-Path -Parent $statePath))|Out-Null
    Write-JsonNoBom -Path $statePath -Value ([ordered]@{
        profile_id='project-a';bundle_hash=('D'*64);validator_sha256=('E'*64);policy_sha256=('F'*64);task_id='A-006';branch='codex/project-a-harness';starting_commit=('a'*40);started_at='2026-07-10T00:00:00.1234567-04:00';status='completed';phase='terra';terra_attempts=0;sol_attempts=0;consecutive_failures=0;same_error_count=0;last_error_class=$null;last_failure=$null;terra_thread_id=$null;sol_thread_id=$null;validation_digest=$null;diff_sha256=$null;approval_request='C:\tmp\request.json';approval_receipt='C:\tmp\receipt.json';approval_key='C:\tmp\key.dpapi';approval_receipt_digest=$null;intended_tree=$null;stage_paths=@();pending_evidence_path=$null;pending_evidence_text=$null;evidence_sha256=$null;commit_sha=$null;completed_at='2026-07-10T04:05:06.0000000Z'
    })
    $state=Read-JsonFile -Path $statePath
    $startedAt=[datetimeoffset]$state.started_at
    $completedAt=[datetimeoffset]$state.completed_at
    Assert-True ($startedAt.ToString('o') -eq '2026-07-10T00:00:00.1234567-04:00' -and $completedAt.ToString('o') -eq '2026-07-10T04:05:06.0000000+00:00') 'runtime task state accepts valid ISO 8601 timestamps with offsets and fractional seconds'
}finally{Remove-Item -LiteralPath $stateTimestampRepo -Recurse -Force}

$initial=@(New-RepoOnlyInitialCodexArguments -Arguments @('exec','--full-auto','--sandbox=danger-full-access','--json','[TASK:A-001]') -Model 'gpt-5.6-terra');$initialText=$initial -join ' '
Assert-True ($initialText -match 'workspace-write' -and $initialText -notmatch 'danger-full-access|--full-auto') 'repo-only initial calls enforce workspace-write'
Assert-True ((@(New-RepoOnlyInitialCodexArguments -Arguments @('exec','prompt text','--model','wrong','--sandbox','danger-full-access','--json') -Model 'gpt-5.6-terra') -join ' ') -notmatch 'wrong|danger-full-access') 'model and sandbox overrides are stripped even when Ralphy places them after the prompt'
Assert-True ($initialText -match 'network_access=false' -and $initialText -match 'web_search="disabled"' -and $initialText -match 'features.apps=false') 'repo-only initial calls explicitly disable command network, web, and apps'
Assert-True ($initialText -match 'windows.sandbox="elevated"') 'Windows workspace-write explicitly selects the tested elevated sandbox implementation'
Assert-True ($initialText -match 'shell_environment_policy.inherit="core"' -and $initialText -match 'CODEX_HOME') 'model shell receives a filtered core environment without Codex home'
Assert-True ((Get-Content -Raw (Join-Path $root '.harness/bin/codex.cmd')) -notmatch 'if "%ADAPTER_EXIT%"=="75" exit') 'human approval pauses also set the terminal sentinel before Ralphy can advance'
Assert-True ((Get-Content -Raw (Join-Path $root 'scripts/Start-ProjectAHarness.ps1')) -match 'Unsupported Ralphy CLI' -and (Get-Content -Raw (Join-Path $root 'scripts/Start-ProjectAHarness.ps1')) -match 'Project A completion contract failed') 'launcher fails closed on tool drift and post-run completion reconciliation'
Assert-True ((Get-Content -Raw (Join-Path $root 'scripts/Start-ProjectAHarness.ps1')) -notmatch '''blocked''\)\s*\{ \$active\.Add') 'launcher resume screening excludes blocked task states that require operator recovery'
Assert-True ((Get-Content -Raw (Join-Path $root 'scripts/Start-ProjectAHarness.ps1')) -match 'profile\.task_ids' -and (Get-Content -Raw (Join-Path $root 'scripts/Start-ProjectAHarness.ps1')) -notmatch 'expected 7 tasks') 'completion contract derives the task count from the approved profile instead of a hardcoded literal'
Assert-True ((Get-Content -Raw (Join-Path $root 'scripts/Start-ProjectAHarness.ps1')) -match 'Get-CanonicalDiffRecord' -and (Get-Content -Raw (Join-Path $root 'scripts/Start-ProjectAHarness.ps1')) -match 'Resume dirty-set binding no longer matches the persisted task identity' -and (Get-Content -Raw (Join-Path $root 'scripts/Start-ProjectAHarness.ps1')) -match 'Resume found task changes without a persisted dirty-set identity') 'launcher resume clears the sentinel only when dirty changes still match a persisted diff identity'
Assert-True ((Get-Content -Raw (Join-Path $root 'scripts/Start-ProjectAHarness.ps1')) -match '\.ralphy-worktrees' -and (Get-Content -Raw (Join-Path $root 'scripts/Start-ProjectAHarness.ps1')) -match '\.ralphy-sandboxes' -and (Get-Content -Raw (Join-Path $root 'scripts/Start-ProjectAHarness.ps1')) -match 'Forbidden isolation directory was created') 'launcher rejects forbidden Ralphy isolation directories before and after execution'
$projectAStartText=Get-Content -Raw (Join-Path $root 'scripts/Start-ProjectAHarness.ps1')
$smokeStartText=Get-Content -Raw (Join-Path $root 'scripts/Start-Harness.ps1')
Assert-True ($projectAStartText -match 'Forbidden Ralphy CLI flag refused' -and $projectAStartText -match '--parallel' -and $projectAStartText -match '--worktree' -and $projectAStartText -match '--sandbox' -and $projectAStartText -match '--branch-per-task') 'Project A launcher explicitly refuses forbidden Ralphy parallel/worktree/sandbox/branch-per-task flags'
Assert-True ($smokeStartText -match 'Forbidden Ralphy CLI flag refused' -and $smokeStartText -match '--parallel' -and $smokeStartText -match '--branch-per-task') 'smoke launcher explicitly refuses the same forbidden Ralphy CLI flags'
$projectAArgLine=@($projectAStartText -split "`r?`n" | Where-Object { $_ -match '\$arguments=@\(' }) -join ''
Assert-True ($projectAArgLine -match '--codex' -and $projectAArgLine -match '--no-browser' -and $projectAArgLine -notmatch '--parallel|--worktree|--sandbox|--branch-per-task') 'Project A Ralphy argv is a fixed sequential allowlist without forbidden isolation flags'
$resume=@(New-RepoOnlyResumeCodexArguments -Model 'gpt-5.6-sol' -ThreadId 'thread' -Prompt 'repair' -OutputLastMessage $null) -join ' '
Assert-True ($resume -match 'sandbox_mode="workspace-write"' -and $resume -match 'network_access=false') 'resume calls preserve filesystem and network boundaries'

$psi=[Diagnostics.ProcessStartInfo]::new();$psi.Environment['AWS_ACCESS_KEY_ID']='AKIAABCDEFGHIJKLMNOP';$psi.Environment['ARM_CLIENT_SECRET']='azure-secret';$psi.Environment['GH_TOKEN']='github-secret';$isolation=Join-Path $env:TEMP ('phase4-env-'+[Guid]::NewGuid().ToString('N'));Set-RepoOnlyProcessEnvironment -StartInfo $psi -IsolationRoot $isolation
Assert-True (-not $psi.Environment.ContainsKey('AWS_ACCESS_KEY_ID') -and -not $psi.Environment.ContainsKey('ARM_CLIENT_SECRET') -and -not $psi.Environment.ContainsKey('GH_TOKEN')) 'Codex process environment scrubs seeded cloud and GitHub credentials'
Assert-True ($psi.Environment['AWS_EC2_METADATA_DISABLED'] -eq 'true' -and (Test-Path $psi.Environment['AWS_CONFIG_FILE'])) 'Codex process disables metadata and redirects credential files'
Assert-True ($psi.Environment['USERPROFILE'] -eq $psi.Environment['HOME'] -and $psi.Environment['USERPROFILE'] -like "$isolation*") 'Codex process uses an isolated Windows profile and home'
Remove-Item -LiteralPath $isolation -Recurse -Force

$syntheticProcesses=@(
    [pscustomobject]@{ ProcessId=900; ParentProcessId=0; Name='pwsh.exe'; CommandLine='current launcher' },
    [pscustomobject]@{ ProcessId=901; ParentProcessId=900; Name='ralphy.exe'; CommandLine='owned child' },
    [pscustomobject]@{ ProcessId=902; ParentProcessId=901; Name='codex.exe'; CommandLine='owned grandchild' },
    [pscustomobject]@{ ProcessId=903; ParentProcessId=0; Name='codex.exe'; CommandLine='unrelated session' }
)
$ownedProcesses=@(Get-LingeringHarnessProcesses -CurrentProcessId 900 -Processes $syntheticProcesses)
Assert-True ($ownedProcesses.Count -eq 2 -and @($ownedProcesses.process_id) -contains 901 -and @($ownedProcesses.process_id) -contains 902 -and -not (@($ownedProcesses.process_id) -contains 903)) 'lingering-process audit only flags harness-descended codex and ralphy processes'

$corpus='AKIAABCDEFGHIJKLMNOP eyJabcdefgh.ijklmnop.qrstuvwx https://user:pass@example.test Set-Cookie: sid=abc -----BEGIN PRIVATE KEY-----'
$safe=Protect-LogText -Text $corpus;Assert-True ($safe -notmatch 'AKIAABCDEFGHIJKLMNOP|eyJabcdefgh|user:pass|sid=abc|BEGIN PRIVATE KEY') 'redactor covers cloud keys, JWTs, URI credentials, cookies, and private-key headers'
Assert-True (Test-AllowedPath -Path 'project-a/docs/diagrams/network.svg' -AllowedPaths @('project-a/docs/diagrams/network.svg')) 'allowlist accepts the exact A-004 network diagram path'
Assert-True (-not (Test-AllowedPath -Path 'project-a/docs/diagrams/network.png' -AllowedPaths @('project-a/docs/diagrams/network.svg'))) 'allowlist still rejects unrelated A-004 diagram siblings'

$diffRepo=New-TestRepo 'canonical diff'
try{[IO.Directory]::CreateDirectory((Join-Path $diffRepo 'project-a'))|Out-Null;[IO.File]::WriteAllText((Join-Path $diffRepo 'project-a/fixture with space-非.txt'),"ok`n",[Text.UTF8Encoding]::new($false));$diff=Get-CanonicalDiffRecord -Root $diffRepo -AllowedPaths @('project-a/**');Assert-True ($diff.entries.Count -eq 1 -and $diff.entries[0].path -eq 'project-a/fixture with space-非.txt') 'canonical diff preserves spaces and non-ASCII paths';$first=$diff.sha256;[IO.File]::AppendAllText((Join-Path $diffRepo 'project-a/fixture with space-非.txt'),'x');$second=(Get-CanonicalDiffRecord -Root $diffRepo -AllowedPaths @('project-a/**')).sha256;Assert-True ($first -ne $second) 'one-byte changes invalidate exact diff fingerprints';&git -C $diffRepo add project-a;&git -C $diffRepo commit -m fixture|Out-Null;&git -C $diffRepo update-index --chmod=+x 'project-a/fixture with space-非.txt';$modeRejected=$false;try{[void](Get-CanonicalDiffRecord -Root $diffRepo -AllowedPaths @('project-a/**'))}catch{$modeRejected=$_.Exception.Message -match 'UNAPPROVED_EXECUTABLE_BIT'};Assert-True $modeRejected 'canonical diff rejects unapproved executable-bit changes';$modeDiff=Get-CanonicalDiffRecord -Root $diffRepo -AllowedPaths @('project-a/**') -AllowedExecutablePaths @('project-a/fixture with space-非.txt');Assert-True ($modeDiff.entries[0].old_mode -eq '100644' -and $modeDiff.entries[0].new_mode -eq '100755') 'canonical approval records explicitly authorized Git mode-only changes'}finally{Remove-Item -LiteralPath $diffRepo -Recurse -Force}

$projectRuntimeRepo=New-TestRepo 'project runtime exclusions'
try{[IO.Directory]::CreateDirectory((Join-Path $projectRuntimeRepo '.harness/runtime/project-a/state'))|Out-Null;[IO.Directory]::CreateDirectory((Join-Path $projectRuntimeRepo '.harness/runtime/project-a/locks'))|Out-Null;[IO.Directory]::CreateDirectory((Join-Path $projectRuntimeRepo '.harness/runtime/project-a/takeovers'))|Out-Null;$projectExcluded=@(Get-HarnessLifecycleExcludedPaths -Root $root -ProfileId 'project-a');foreach($path in @('.harness/runtime/harness.lock','.harness/runtime/project-a/PRD.json','.harness/runtime/project-a/state/A-001.json','.harness/runtime/project-a/state/A-002.json','.harness/runtime/project-a/locks/A-001.lock','.harness/runtime/project-a/locks/A-002.lock','.harness/runtime/project-a/takeovers/A-001.md','.harness/runtime/project-a/takeovers/A-002.md')){$full=Join-Path $projectRuntimeRepo $path;[IO.Directory]::CreateDirectory((Split-Path -Parent $full))|Out-Null;[IO.File]::WriteAllText($full,"owned`n",[Text.UTF8Encoding]::new($false))};$visible=@(Get-ChangedPaths -Root $projectRuntimeRepo);Assert-True ($visible -contains '.harness/runtime/project-a/PRD.json' -and $visible -contains '.harness/runtime/project-a/state/A-001.json') 'known Project A runtime files are visible by default';Assert-True (@(Get-ChangedPaths -Root $projectRuntimeRepo -ExcludedPaths $projectExcluded).Count -eq 0) 'known Project A lifecycle paths can be excluded exactly';$before=Get-DiffFingerprint -Root $projectRuntimeRepo -ExcludedPaths $projectExcluded;[IO.File]::WriteAllText((Join-Path $projectRuntimeRepo '.harness/runtime/project-a/state/A-999.json'),"rogue`n",[Text.UTF8Encoding]::new($false));$after=Get-DiffFingerprint -Root $projectRuntimeRepo -ExcludedPaths $projectExcluded;Assert-True (@(Get-ChangedPaths -Root $projectRuntimeRepo -ExcludedPaths $projectExcluded) -contains '.harness/runtime/project-a/state/A-999.json') 'unknown Project A task state files stay in changed-path inventory';Assert-True ($before -ne $after) 'unknown Project A runtime mutations change the diff fingerprint';Remove-Item -LiteralPath (Join-Path $projectRuntimeRepo '.harness/runtime/project-a/state/A-999.json') -Force;[IO.Directory]::CreateDirectory((Join-Path $projectRuntimeRepo '.harness/runtime/project-a/rogue'))|Out-Null;[IO.File]::WriteAllText((Join-Path $projectRuntimeRepo '.harness/runtime/project-a/rogue/file.txt'),"rogue`n",[Text.UTF8Encoding]::new($false));Assert-True (@(Get-ChangedPaths -Root $projectRuntimeRepo -ExcludedPaths $projectExcluded) -contains '.harness/runtime/project-a/rogue/file.txt') 'unknown Project A runtime subdirectories stay in changed-path inventory'}finally{Remove-Item -LiteralPath $projectRuntimeRepo -Recurse -Force}

$unknownRepo=New-TestRepo 'unknown validator'
try{Write-TestPolicy $unknownRepo 'A-006' $false;$unknownPath=Join-Path $unknownRepo 'project-a/harness/tasks/A-006.json';Set-PolicyValidators $unknownPath @([pscustomobject]@{id='invented_shell_command';timeout_seconds=30;required=$true});& git -C $unknownRepo add project-a/harness/tasks/A-006.json;& git -C $unknownRepo commit -m policy|Out-Null;[IO.Directory]::CreateDirectory((Join-Path $unknownRepo 'project-a'))|Out-Null;[IO.File]::WriteAllText((Join-Path $unknownRepo 'project-a/fixture with space-非.txt'),"ok`n",[Text.UTF8Encoding]::new($false));$unknownResult=Invoke-ValidatorFixture -Repo $unknownRepo -PolicyPath $unknownPath;Assert-True ($unknownResult.ExitCode -ne 0 -and $unknownResult.Result.error_class -eq 'UNKNOWN_VALIDATOR') 'validator registry fails closed on unknown IDs'}finally{Remove-Item -LiteralPath $unknownRepo -Recurse -Force}

$credentialBoundaryRepo=New-TestRepo 'credential boundary allowlist'
try{
    Write-TestPolicy $credentialBoundaryRepo 'A-006' $false
    $credentialBoundaryPath=Join-Path $credentialBoundaryRepo 'project-a/harness/tasks/A-006.json'
    & git -C $credentialBoundaryRepo add project-a/harness/tasks/A-006.json
    & git -C $credentialBoundaryRepo commit -m policy|Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $credentialBoundaryRepo 'project-a'))|Out-Null
    [IO.File]::WriteAllText((Join-Path $credentialBoundaryRepo 'project-a/fixture with space-非.txt'),"ok`n",[Text.UTF8Encoding]::new($false))
    $savedCredentialBoundaryEnv=@{AZURE_DEVOPS_CACHE_DIR=$env:AZURE_DEVOPS_CACHE_DIR;AZURE_EXTENSION_DIR=$env:AZURE_EXTENSION_DIR}
    try{
        $env:AZURE_DEVOPS_CACHE_DIR='C:\ci-cache'
        $env:AZURE_EXTENSION_DIR='C:\ci-extensions'
        $credentialBoundaryResult=Invoke-ValidatorFixture -Repo $credentialBoundaryRepo -PolicyPath $credentialBoundaryPath
        Assert-True ($credentialBoundaryResult.ExitCode -eq 0) 'credential boundary allows GitHub runner Azure cache directories'
    }finally{
        foreach($item in $savedCredentialBoundaryEnv.GetEnumerator()){
            if($null -eq $item.Value){Remove-Item "Env:$($item.Key)" -ErrorAction SilentlyContinue}else{Set-Item "Env:$($item.Key)" $item.Value}
        }
    }
}finally{Remove-Item -LiteralPath $credentialBoundaryRepo -Recurse -Force}

$forbiddenRepo=New-TestRepo 'forbidden operations'
try{
    Write-TestPolicy $forbiddenRepo 'A-006' $false
    $forbiddenPath=Join-Path $forbiddenRepo 'project-a/harness/tasks/A-006.json'
    $forbiddenPolicy=Read-JsonFile -Path $forbiddenPath
    $forbiddenPolicy.allowed_paths=@('project-a/fixture with space-非.txt','project-a/docs/**','project-a/harness/tasks/A-006.json')
    Write-JsonNoBom -Path $forbiddenPath -Value $forbiddenPolicy
    & git -C $forbiddenRepo add project-a/harness/tasks/A-006.json
    & git -C $forbiddenRepo commit -m policy|Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $forbiddenRepo 'project-a/docs'))|Out-Null
    [IO.File]::WriteAllText((Join-Path $forbiddenRepo 'project-a/fixture with space-非.txt'),"safe`n",[Text.UTF8Encoding]::new($false))
    $cleanResult=Invoke-ValidatorFixture -Repo $forbiddenRepo -PolicyPath $forbiddenPath
    $cleanChanged=@(Get-ChangedPaths -Root $forbiddenRepo -ExcludedPaths @(Get-HarnessLifecycleExcludedPaths -Root $forbiddenRepo -ProfileId 'project-a')) -join ', '
    $cleanMessage=if($null -ne $cleanResult.Result){[string]$cleanResult.Result.message}else{'<no validator result>'}
    Assert-True ($cleanResult.ExitCode -eq 0) "default forbidden-operations policy allows clean text artifacts (exit=$($cleanResult.ExitCode); message=$cleanMessage; changed=$cleanChanged)"
    [IO.File]::WriteAllText((Join-Path $forbiddenRepo 'project-a/docs/runbook.md'),"Use terraform plan only in examples.`n",[Text.UTF8Encoding]::new($false))
    $planResult=Invoke-ValidatorFixture -Repo $forbiddenRepo -PolicyPath $forbiddenPath
    Assert-True ($planResult.ExitCode -ne 0 -and $planResult.Result.message -match 'project-a/docs/runbook\.md \[terraform plan\]') 'forbidden-operations validator scans changed documentation artifacts, not only shell files'
    Remove-Item -LiteralPath (Join-Path $forbiddenRepo 'project-a/docs/runbook.md') -Force
    Set-PolicyForbiddenOperations $forbiddenPath @([ordered]@{id='custom-live-cli';pattern='(?i)\blive-cli\b';extensions=@('.md')})
    [IO.File]::WriteAllText((Join-Path $forbiddenRepo 'project-a/docs/guide.md'),"Never run live-cli here.`n",[Text.UTF8Encoding]::new($false))
    $customResult=Invoke-ValidatorFixture -Repo $forbiddenRepo -PolicyPath $forbiddenPath
    Assert-True ($customResult.ExitCode -ne 0 -and $customResult.Result.message -match 'project-a/docs/guide\.md \[custom-live-cli\]') 'forbidden-operations validator honors policy-defined regex rules'
    Remove-Item -LiteralPath (Join-Path $forbiddenRepo 'project-a/docs/guide.md') -Force
    Set-PolicyForbiddenOperations $forbiddenPath @([ordered]@{id='missing-pattern';description='broken entry'})
    $brokenPolicyResult=Invoke-ValidatorFixture -Repo $forbiddenRepo -PolicyPath $forbiddenPath
    Assert-True ($brokenPolicyResult.ExitCode -ne 0 -and $brokenPolicyResult.Result.message -match 'pattern/regex field') 'forbidden-operations policy rejects undocumented entries without an executable matcher'
}finally{
    Remove-Item -LiteralPath $forbiddenRepo -Recurse -Force
}

$semanticRepo=New-TestRepo 'semantic rejection';$semanticIsolation=Join-Path $env:TEMP ('semantic-validator-'+[Guid]::NewGuid().ToString('N'))
try{Write-TestPolicy $semanticRepo 'A-002' $true;$semanticPath=Join-Path $semanticRepo 'project-a/harness/tasks/A-002.json';$semantic=Read-JsonFile -Path $semanticPath;$semantic.validators=@([pscustomobject]@{id='organizations_semantics';timeout_seconds=30;required=$true});Write-JsonNoBom -Path $semanticPath -Value $semantic;& git -C $semanticRepo add project-a/harness/tasks/A-002.json;& git -C $semanticRepo commit -m policy|Out-Null;[IO.Directory]::CreateDirectory((Join-Path $semanticRepo 'project-a'))|Out-Null;[IO.File]::WriteAllText((Join-Path $semanticRepo 'project-a/fixture with space-非.txt'),"garbage`n",[Text.UTF8Encoding]::new($false));& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $root 'scripts/Invoke-ProjectAValidators.ps1') -Root $semanticRepo -PolicyPath $semanticPath -IsolationRoot $semanticIsolation|Out-Null;Assert-True ($LASTEXITCODE -ne 0) 'semantic validators reject non-empty garbage artifacts'}finally{Remove-Item -LiteralPath $semanticRepo -Recurse -Force;Remove-Item -LiteralPath $semanticIsolation -Recurse -Force -ErrorAction SilentlyContinue}

$directStopRepo=New-TestRepo 'direct stop flag';$directStopLocal=Join-Path $env:TEMP ('phase4-stop-'+[Guid]::NewGuid().ToString('N'))
try{Write-TestPolicy $directStopRepo 'A-006' $false;& git -C $directStopRepo add project-a/harness/tasks/A-006.json;& git -C $directStopRepo commit -m policy|Out-Null;[IO.Directory]::CreateDirectory((Join-Path $directStopRepo '.harness/runtime'))|Out-Null;[IO.File]::WriteAllText((Join-Path $directStopRepo '.harness/runtime/stop.flag'),'blocked',[Text.UTF8Encoding]::new($false));Set-AdapterEnvironment $directStopRepo 'A-006' $directStopLocal;$code=Invoke-ProjectAAdapterFixture -Arguments @('exec','--json','[TASK:A-006]');Assert-True ($code -ne 0 -and -not (Test-Path -LiteralPath (Join-Path $directStopRepo '.logs/calls.txt'))) 'direct adapter entry refuses another model call after the terminal sentinel exists'}finally{Clear-AdapterEnvironment;Remove-Item -LiteralPath $directStopRepo -Recurse -Force;Remove-Item -LiteralPath $directStopLocal -Recurse -Force -ErrorAction SilentlyContinue}

$runtimeRejectRepo=New-TestRepo 'runtime rejection';$runtimeRejectLocal=Join-Path $env:TEMP ('phase4-runtime-reject-'+[Guid]::NewGuid().ToString('N'))
try{Write-TestPolicy $runtimeRejectRepo 'A-006' $false;& git -C $runtimeRejectRepo add project-a/harness/tasks/A-006.json;& git -C $runtimeRejectRepo commit -m policy|Out-Null;[IO.Directory]::CreateDirectory((Join-Path $runtimeRejectRepo '.harness/runtime/project-a/state'))|Out-Null;[IO.File]::WriteAllText((Join-Path $runtimeRejectRepo '.harness/runtime/project-a/state/A-999.json'),'rogue',[Text.UTF8Encoding]::new($false));Set-AdapterEnvironment $runtimeRejectRepo 'A-006' $runtimeRejectLocal;$code=Invoke-ProjectAAdapterFixture -Arguments @('exec','--json','[TASK:A-006]');Assert-True ($code -ne 0 -and -not (Test-Path -LiteralPath (Join-Path $runtimeRejectRepo '.logs/calls.txt'))) 'unknown Project A runtime state is rejected before any model call';Remove-Item -LiteralPath (Join-Path $runtimeRejectRepo '.harness/runtime/project-a/state/A-999.json') -Force;[IO.Directory]::CreateDirectory((Join-Path $runtimeRejectRepo '.harness/runtime/project-a/rogue'))|Out-Null;[IO.File]::WriteAllText((Join-Path $runtimeRejectRepo '.harness/runtime/project-a/rogue/file.txt'),'rogue',[Text.UTF8Encoding]::new($false));$code=Invoke-ProjectAAdapterFixture -Arguments @('exec','--json','[TASK:A-006]');Assert-True ($code -ne 0 -and -not (Test-Path -LiteralPath (Join-Path $runtimeRejectRepo '.logs/calls.txt'))) 'unknown Project A runtime subdirectories are rejected before any model call'}finally{Clear-AdapterEnvironment;Remove-Item -LiteralPath $runtimeRejectRepo -Recurse -Force;Remove-Item -LiteralPath $runtimeRejectLocal -Recurse -Force -ErrorAction SilentlyContinue}

$lockRepo=New-TestRepo 'adapter lock';$lockLocal=Join-Path $env:TEMP ('phase4-lock-'+[Guid]::NewGuid().ToString('N'))
try{Write-TestPolicy $lockRepo 'A-006' $false;& git -C $lockRepo add project-a/harness/tasks/A-006.json;& git -C $lockRepo commit -m policy|Out-Null;Set-AdapterEnvironment $lockRepo 'A-006' $lockLocal;$lockPath=Join-Path $lockRepo '.harness/runtime/project-a/locks/A-006.lock';[IO.Directory]::CreateDirectory((Split-Path -Parent $lockPath))|Out-Null;$heldLock=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);try{$code=Invoke-ProjectAAdapterFixture -Arguments @('exec','--json','[TASK:A-006]');Assert-True ($code -ne 0 -and -not (Test-Path -LiteralPath (Join-Path $lockRepo '.logs/calls.txt'))) 'per-task adapter lock fails closed before any model call'}finally{$heldLock.Dispose()}}finally{Clear-AdapterEnvironment;Remove-Item -LiteralPath $lockRepo -Recurse -Force;Remove-Item -LiteralPath $lockLocal -Recurse -Force -ErrorAction SilentlyContinue}

$exclusiveLockRepo=New-TestRepo 'exclusive lock share';$exclusiveLockLocal=Join-Path $env:TEMP ('phase4-exclusive-lock-'+[Guid]::NewGuid().ToString('N'))
try{$exclusiveLockPath=Join-Path $exclusiveLockRepo '.harness/runtime/project-a/locks/A-006.lock';$heldExclusive=Open-ExclusiveLock -Path $exclusiveLockPath;try{Assert-ThrowsLike { Open-ExclusiveLock -Path $exclusiveLockPath | Out-Null } 'Another harness instance owns the lock' 'Open-ExclusiveLock FileShare.None rejects a second open'}finally{$heldExclusive.Dispose()}}finally{Remove-Item -LiteralPath $exclusiveLockRepo -Recurse -Force;Remove-Item -LiteralPath $exclusiveLockLocal -Recurse -Force -ErrorAction SilentlyContinue}

$dependencyRepo=New-TestRepo 'adapter dependency';$dependencyLocal=Join-Path $env:TEMP ('phase4-dependency-'+[Guid]::NewGuid().ToString('N'))
try{Write-TestPolicy $dependencyRepo 'A-006' $false;$dependencyPolicyPath=Join-Path $dependencyRepo 'project-a/harness/tasks/A-006.json';$dependencyPolicy=Read-JsonFile -Path $dependencyPolicyPath;$dependencyPolicy.depends_on=@('A-005');Write-JsonNoBom -Path $dependencyPolicyPath -Value $dependencyPolicy;& git -C $dependencyRepo add project-a/harness/tasks/A-006.json;& git -C $dependencyRepo commit -m policy|Out-Null;Set-AdapterEnvironment $dependencyRepo 'A-006' $dependencyLocal;$code=Invoke-ProjectAAdapterFixture -Arguments @('exec','--json','[TASK:A-006]');Assert-True ($code -ne 0 -and -not (Test-Path -LiteralPath (Join-Path $dependencyRepo '.logs/calls.txt'))) 'adapter refuses an out-of-order task before any model call'}finally{Clear-AdapterEnvironment;Remove-Item -LiteralPath $dependencyRepo -Recurse -Force;Remove-Item -LiteralPath $dependencyLocal -Recurse -Force -ErrorAction SilentlyContinue}

$forgedDependencyRepo=New-TestRepo 'forged dependency';$forgedDependencyLocal=Join-Path $env:TEMP ('phase4-forged-dependency-'+[Guid]::NewGuid().ToString('N'))
try{Write-TestPolicy $forgedDependencyRepo 'A-005' $false;Write-TestPolicy $forgedDependencyRepo 'A-006' $false;$dependencyPolicyPath=Join-Path $forgedDependencyRepo 'project-a/harness/tasks/A-006.json';$dependencyPolicy=Read-JsonFile -Path $dependencyPolicyPath;$dependencyPolicy.depends_on=@('A-005');Write-JsonNoBom -Path $dependencyPolicyPath -Value $dependencyPolicy;& git -C $forgedDependencyRepo add project-a/harness/tasks;& git -C $forgedDependencyRepo commit -m policy|Out-Null;$dependencyHead=(& git -C $forgedDependencyRepo rev-parse HEAD).Trim();$dependencyStatePath=Join-Path $forgedDependencyRepo '.harness/runtime/project-a/state/A-005.json';Write-JsonNoBom -Path $dependencyStatePath -Value ([ordered]@{profile_id='project-a';task_id='A-005';branch='codex/project-a-harness';bundle_hash=('D'*64);validator_sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $root 'scripts/Invoke-ProjectAValidators.ps1')).Hash;policy_sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $forgedDependencyRepo 'project-a/harness/tasks/A-005.json')).Hash;starting_commit=$dependencyHead;started_at='2026-07-10T00:00:00Z';status='completed';phase='terra';terra_attempts=0;sol_attempts=0;consecutive_failures=0;same_error_count=0;last_error_class=$null;last_failure=$null;terra_thread_id=$null;sol_thread_id=$null;validation_digest=$null;diff_sha256=$null;approval_request='.harness/runtime/approvals/A-005.request.json';approval_receipt='.harness/runtime/approvals/A-005.receipt.json';approval_key='.harness/runtime/approvals/A-005.dpapi';approval_receipt_digest=$null;intended_tree=$null;stage_paths=@();pending_evidence_path=$null;pending_evidence_text=$null;evidence_sha256=('0'*64);commit_sha=$dependencyHead;completed_at='2026-07-10T00:01:00Z'});Set-AdapterEnvironment $forgedDependencyRepo 'A-006' $forgedDependencyLocal;$code=Invoke-ProjectAAdapterFixture -Arguments @('exec','--json','[TASK:A-006]');Assert-True ($code -ne 0 -and -not (Test-Path -LiteralPath (Join-Path $forgedDependencyRepo '.logs/calls.txt'))) 'forged completed dependency without valid commit and evidence is rejected before any model call'}finally{Clear-AdapterEnvironment;Remove-Item -LiteralPath $forgedDependencyRepo -Recurse -Force;Remove-Item -LiteralPath $forgedDependencyLocal -Recurse -Force -ErrorAction SilentlyContinue}

$forgedManifestRepo=New-TestRepo 'forged manifest completion'
try{Write-TestPolicy $forgedManifestRepo 'A-005' $false;& git -C $forgedManifestRepo add project-a/harness/tasks/A-005.json;& git -C $forgedManifestRepo commit -m policy|Out-Null;$manifestPath=Join-Path $forgedManifestRepo '.harness/runtime/project-a/PRD.json';Write-JsonNoBom -Path $manifestPath -Value ([ordered]@{tasks=@([ordered]@{title='[TASK:A-005] contract fixture';completed=$true})});$manifestHead=(& git -C $forgedManifestRepo rev-parse HEAD).Trim();Write-JsonNoBom -Path (Join-Path $forgedManifestRepo '.harness/runtime/project-a/state/A-005.json') -Value ([ordered]@{profile_id='project-a';task_id='A-005';branch='codex/project-a-harness';bundle_hash=('D'*64);validator_sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $root 'scripts/Invoke-ProjectAValidators.ps1')).Hash;policy_sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $forgedManifestRepo 'project-a/harness/tasks/A-005.json')).Hash;starting_commit=$manifestHead;started_at='2026-07-10T00:00:00Z';status='completed';phase='terra';terra_attempts=0;sol_attempts=0;consecutive_failures=0;same_error_count=0;last_error_class=$null;last_failure=$null;terra_thread_id=$null;sol_thread_id=$null;validation_digest=$null;diff_sha256=$null;approval_request='.harness/runtime/approvals/A-005.request.json';approval_receipt='.harness/runtime/approvals/A-005.receipt.json';approval_key='.harness/runtime/approvals/A-005.dpapi';approval_receipt_digest=$null;intended_tree=$null;stage_paths=@();pending_evidence_path=$null;pending_evidence_text=$null;evidence_sha256=('0'*64);commit_sha=$manifestHead;completed_at='2026-07-10T00:01:00Z'});$synced=Sync-ProjectAManifestWithTaskState -Root $forgedManifestRepo -ManifestPath $manifestPath -Branch 'codex/project-a-harness' -BundleHash ('D'*64) -ValidatorHash (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $root 'scripts/Invoke-ProjectAValidators.ps1')).Hash;Assert-True (-not [bool]$synced.tasks[0].completed) 'forged completed Project A state cannot mark the manifest complete'}finally{Remove-Item -LiteralPath $forgedManifestRepo -Recurse -Force}

$completionForbiddenRepo=New-ProjectAHarnessFixtureWorkspace 'completion forbidden isolation'
try{
    $completionForbiddenResult=Invoke-ProjectAHarnessFixture -Workspace $completionForbiddenRepo -ForbiddenDir '.ralphy-worktrees'
    $completionForbiddenContext="exit=$($completionForbiddenResult.ExitCode); output=$($completionForbiddenResult.Output)"
    Assert-True ($completionForbiddenResult.ExitCode -ne 0 -and $completionForbiddenResult.Output -match 'Forbidden isolation directory was created: \.ralphy-worktrees') "completion reconciliation rechecks forbidden isolation directories created after task execution ($completionForbiddenContext)"
}finally{
    Remove-Item -LiteralPath $completionForbiddenRepo -Recurse -Force -ErrorAction SilentlyContinue
}

$noApprovalRepo=New-TestRepo 'adapter no approval';$localData=Join-Path $env:TEMP ('phase4-local-'+[Guid]::NewGuid().ToString('N'))
try{Write-TestPolicy $noApprovalRepo 'A-006' $false;& git -C $noApprovalRepo add project-a/harness/tasks/A-006.json;& git -C $noApprovalRepo commit -m policy|Out-Null;[IO.Directory]::CreateDirectory((Join-Path $noApprovalRepo '.harness/runtime/project-a'))|Out-Null;$manifestPath=Join-Path $noApprovalRepo '.harness/runtime/project-a/PRD.json';Write-JsonNoBom -Path $manifestPath -Value ([ordered]@{tasks=@([ordered]@{title='[TASK:A-006] contract fixture';completed=$false})});$projectExcluded=@(Get-HarnessLifecycleExcludedPaths -Root $root -ProfileId 'project-a');Set-AdapterEnvironment $noApprovalRepo 'A-006' $localData;$env:HARNESS_MANIFEST_PATH=$manifestPath;$env:AWS_ACCESS_KEY_ID='AKIAABCDEFGHIJKLMNOP';$env:HARNESS_FAKE_ENV_DUMP='.logs/env.txt';$env:HARNESS_FAKE_OUTPUT='raw-model-secret';$code=Invoke-ProjectAAdapterFixture -Arguments @('exec','--json','[TASK:A-006]');Assert-True ($code -eq 0) 'A-006 deterministic adapter path completes without human receipt';Assert-True ((Read-JsonFile -Path $manifestPath).tasks[0].completed -eq $true) 'direct adapter completion resynchronizes the runtime manifest';Assert-True ((& git -C $noApprovalRepo log -1 --format=%s).Trim() -eq 'feat(A-006): contract fixture') 'adapter owns the gated A-006 commit';Assert-True (@(Get-ChangedPaths -Root $noApprovalRepo -ExcludedPaths $projectExcluded).Count -eq 0) 'A-006 adapter leaves a clean tree';$evidence=Get-Content -Raw (Join-Path $noApprovalRepo 'evidence/project-a/A-006.json')|ConvertFrom-Json;Assert-True ($evidence.cloud_validated -eq $false -and $evidence.aws_implemented -eq $false -and $evidence.azure_implemented -eq $false) 'adapter evidence matches the final validator claims schema';$dump=Get-Content -Raw -LiteralPath (Join-Path $noApprovalRepo '.logs/env.txt');Assert-True ($dump -notmatch 'AKIAABCDEFGHIJKLMNOP|AWS_ACCESS_KEY_ID') 'fake Codex process cannot observe seeded AWS credentials';$envMap=@{};foreach($line in ($dump -split '[\r\n]+')){if(-not $line){continue};$parts=$line -split '=',2;if($parts.Count -eq 2){$envMap[$parts[0]]=$parts[1]}};Assert-True ($envMap['HOME'] -like '*\isolation\*\profile' -and $envMap['USERPROFILE'] -eq $envMap['HOME'] -and $envMap['LOCALAPPDATA'] -like '*\isolation\*\profile\AppData\Local' -and $envMap['AWS_EC2_METADATA_DISABLED'] -eq 'true' -and $envMap['AWS_CONFIG_FILE'] -like '*\isolation\*\aws-config' -and $envMap['TF_DATA_DIR'] -like '*\isolation\*\terraform-data') 'repo-only model execution hardens the runtime environment';$modelLogs=(Get-Content -Raw (Join-Path $noApprovalRepo '.logs/A-006/terra-1.stdout.jsonl'))+(Get-Content -Raw (Join-Path $noApprovalRepo '.logs/A-006/terra-1.stderr.log'));Assert-True ($modelLogs -notmatch 'raw-model-secret' -and $modelLogs -match '\[REDACTED\]') 'adapter sanitizes model stdout and stderr before persistence'}finally{Clear-AdapterEnvironment;Remove-Item -LiteralPath $noApprovalRepo -Recurse -Force;Remove-Item -LiteralPath $localData -Recurse -Force -ErrorAction SilentlyContinue}

foreach($killPoint in @('after_preparing_state','after_evidence','after_staging','after_committing_state','after_commit')){
    $killRepo=New-TestRepo "kill $killPoint";$killLocal=Join-Path $env:TEMP ('phase4-kill-'+[Guid]::NewGuid().ToString('N'))
    try{Write-TestPolicy $killRepo 'A-006' $false;&git -C $killRepo add project-a/harness/tasks/A-006.json;&git -C $killRepo commit -m policy|Out-Null;$projectExcluded=@(Get-HarnessLifecycleExcludedPaths -Root $root -ProfileId 'project-a');Set-AdapterEnvironment $killRepo 'A-006' $killLocal;$env:HARNESS_TEST_KILL_POINT=$killPoint;$code=Invoke-ProjectAAdapterFixture -Arguments @('exec','--json','[TASK:A-006]');Assert-True ($code -eq 91) "$killPoint interruption is injected at the transaction boundary";Remove-Item Env:HARNESS_TEST_KILL_POINT;$code=Invoke-ProjectAAdapterFixture -Arguments @('exec','--json','[TASK:A-006]');Assert-True ($code -eq 0 -and @(Get-Content (Join-Path $killRepo '.logs/calls.txt')).Count -eq 1 -and @(Get-ChangedPaths -Root $killRepo -ExcludedPaths $projectExcluded).Count -eq 0) "$killPoint resumes exact commit without another model call"}finally{Clear-AdapterEnvironment;Remove-Item -LiteralPath $killRepo -Recurse -Force;Remove-Item -LiteralPath $killLocal -Recurse -Force -ErrorAction SilentlyContinue}
}

$approvalRepo=New-TestRepo 'adapter approval';$localData=Join-Path $env:TEMP ('phase4-approval-'+[Guid]::NewGuid().ToString('N'))
try{Write-TestPolicy $approvalRepo 'A-001' $true;& git -C $approvalRepo add project-a/harness/tasks/A-001.json;& git -C $approvalRepo commit -m policy|Out-Null;Set-AdapterEnvironment $approvalRepo 'A-001' $localData;$code=Invoke-ProjectAAdapterFixture -Arguments @('exec','--json','[TASK:A-001]');Assert-True ($code -eq 75) 'high-risk task pauses after validation and before commit';$state=Read-JsonFile -Path (Join-Path $approvalRepo '.harness/runtime/project-a/state/A-001.json');Assert-True ($state.status -eq 'awaiting_approval') 'approval pause is distinct from failure';Assert-True ([string]$state.approval_request -match [regex]::Escape('phase4-contract\A-001.json') -and [string]$state.approval_receipt -match [regex]::Escape('phase4-contract\A-001.json') -and [string]$state.approval_key -match [regex]::Escape('phase4-contract\A-001.dpapi')) 'approval artifacts are namespaced by run id and persisted in state';Assert-True (@(Get-Content -LiteralPath (Join-Path $approvalRepo '.logs/calls.txt')).Count -eq 1) 'Terra ran exactly once before approval';$legacyRequest=Join-Path $localData 'RalphyHarness/cloud/approvals/project-a/requests/A-001.json';$legacyReceipt=Join-Path $localData 'RalphyHarness/cloud/approvals/project-a/receipts/A-001.json';$legacyKey=Join-Path $localData 'RalphyHarness/cloud/approvals/project-a/keys/A-001.dpapi';[IO.Directory]::CreateDirectory((Split-Path -Parent $legacyRequest))|Out-Null;[IO.Directory]::CreateDirectory((Split-Path -Parent $legacyReceipt))|Out-Null;[IO.Directory]::CreateDirectory((Split-Path -Parent $legacyKey))|Out-Null;[IO.File]::WriteAllText($legacyRequest,'{"task_id":"A-001","branch":"forged","head":"forged","diff_sha256":"forged"}',[Text.UTF8Encoding]::new($false));[IO.File]::WriteAllText($legacyReceipt,'{"payload":{"task_id":"A-001"},"signature":"00"}',[Text.UTF8Encoding]::new($false));[IO.File]::WriteAllText($legacyKey,'Zm9yZ2Vk',[Text.UTF8Encoding]::new($false));$env:HARNESS_APPROVE_TASK='APPROVE:A-001';& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $root 'scripts/Approve-ProjectATask.ps1') -TaskId A-001 -Root $approvalRepo 2>$null|Out-Null;Assert-True ($LASTEXITCODE -ne 0) 'approval broker no longer accepts env-only confirmation injection';Write-ApprovalConfirmationFixture -LocalData $localData -TaskId 'A-001';& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $root 'scripts/Approve-ProjectATask.ps1') -TaskId A-001 -Root $approvalRepo|Out-Null;Assert-True ($LASTEXITCODE -eq 0) 'out-of-workspace broker signs exact-diff approval';Assert-True ((Get-Content -Raw -LiteralPath $state.approval_request|ConvertFrom-Json).branch -ne 'forged') 'approval broker reads the namespaced request from persisted state instead of a legacy sibling';Assert-True (-not (Test-Path -LiteralPath $legacyReceipt) -or (Get-Content -Raw -LiteralPath $legacyReceipt) -notmatch '"approved_at"') 'approval does not require writing the legacy sibling receipt path';$receipt=Read-JsonFile -Path $state.approval_receipt;$receipt.payload.decision='rejected';Write-JsonNoBom -Path $state.approval_receipt -Value $receipt;& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $root 'scripts/Test-ProjectAApproval.ps1') -Root $approvalRepo -PolicyPath (Join-Path $approvalRepo 'project-a/harness/tasks/A-001.json') -RequestPath $state.approval_request -ReceiptPath $state.approval_receipt -KeyPath $state.approval_key|Out-Null;Assert-True ($LASTEXITCODE -ne 0) 'approval verifier rejects receipts whose decision is not approved';Write-ApprovalConfirmationFixture -LocalData $localData -TaskId 'A-001';& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $root 'scripts/Approve-ProjectATask.ps1') -TaskId A-001 -Root $approvalRepo|Out-Null;Assert-True ($LASTEXITCODE -eq 0) 'approval can be reissued after semantic receipt tampering';$fixture=Join-Path $approvalRepo 'project-a/fixture with space-非.txt';[IO.File]::AppendAllText($fixture,'x');& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $root 'scripts/Test-ProjectAApproval.ps1') -Root $approvalRepo -PolicyPath (Join-Path $approvalRepo 'project-a/harness/tasks/A-001.json') -RequestPath $state.approval_request -ReceiptPath $state.approval_receipt -KeyPath $state.approval_key|Out-Null;Assert-True ($LASTEXITCODE -ne 0) 'one-byte post-approval edit invalidates receipt';[IO.File]::WriteAllText($fixture,"PROJECT_A_FAKE_OK`n",[Text.UTF8Encoding]::new($false));$code=Invoke-ProjectAAdapterFixture -Arguments @('exec','--json','[TASK:A-001]');Assert-True ($code -eq 0) 'exact receipt resumes and commits';$approvedEvidence=Read-JsonFile -Path (Join-Path $approvalRepo 'evidence/project-a/A-001.json');$approvedState=Read-JsonFile -Path (Join-Path $approvalRepo '.harness/runtime/project-a/state/A-001.json');Assert-True (-not [string]::IsNullOrWhiteSpace([string]$approvedEvidence.approval_receipt_digest) -and [string]$approvedEvidence.approval_receipt_digest -eq [string]$approvedState.approval_receipt_digest) 'approved completion preserves a receipt digest in both evidence and state';Assert-True (@(Get-Content -LiteralPath (Join-Path $approvalRepo '.logs/calls.txt')).Count -eq 1) 'approval resume makes no second model call';Assert-True ((& git -C $approvalRepo log -1 --format=%s).Trim() -eq 'feat(A-001): contract fixture') 'approved task uses policy commit message'}finally{Clear-AdapterEnvironment;Remove-Item -LiteralPath $approvalRepo -Recurse -Force;Remove-Item -LiteralPath $localData -Recurse -Force -ErrorAction SilentlyContinue}

$digestRecoveryRepo=New-TestRepo 'approval digest recovery';$digestRecoveryLocal=Join-Path $env:TEMP ('phase4-digest-recovery-'+[Guid]::NewGuid().ToString('N'))
try{Write-TestPolicy $digestRecoveryRepo 'A-001' $true;& git -C $digestRecoveryRepo add project-a/harness/tasks/A-001.json;& git -C $digestRecoveryRepo commit -m policy|Out-Null;Set-AdapterEnvironment $digestRecoveryRepo 'A-001' $digestRecoveryLocal;$code=Invoke-ProjectAAdapterFixture -Arguments @('exec','--json','[TASK:A-001]');Assert-True ($code -eq 75) 'digest recovery fixture reaches approval pause';Write-ApprovalConfirmationFixture -LocalData $digestRecoveryLocal -TaskId 'A-001';& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $root 'scripts/Approve-ProjectATask.ps1') -TaskId A-001 -Root $digestRecoveryRepo|Out-Null;Assert-True ($LASTEXITCODE -eq 0) 'digest recovery fixture receives an approval';$env:HARNESS_TEST_KILL_POINT='after_commit';$code=Invoke-ProjectAAdapterFixture -Arguments @('exec','--json','[TASK:A-001]');Assert-True ($code -eq 91) 'approval recovery interruption occurs after commit';Remove-Item Env:HARNESS_TEST_KILL_POINT;$statePath=Join-Path $digestRecoveryRepo '.harness/runtime/project-a/state/A-001.json';$tamperedState=Read-JsonFile -Path $statePath;$tamperedState.approval_receipt_digest=('0'*64);Write-JsonNoBom -Path $statePath -Value $tamperedState;$code=Invoke-ProjectAAdapterFixture -Arguments @('exec','--json','[TASK:A-001]');$recoveredState=Read-JsonFile -Path $statePath;Assert-True ($code -ne 0 -and $recoveredState.status -ne 'completed' -and @(Get-Content -LiteralPath (Join-Path $digestRecoveryRepo '.logs/calls.txt')).Count -eq 1) 'tampered approval digest rejects interrupted-commit recovery without another model call'}finally{Clear-AdapterEnvironment;Remove-Item -LiteralPath $digestRecoveryRepo -Recurse -Force;Remove-Item -LiteralPath $digestRecoveryLocal -Recurse -Force -ErrorAction SilentlyContinue}

$forgedRepo=New-TestRepo 'forged recovery';$forgedLocal=Join-Path $env:TEMP ('phase4-forged-'+[Guid]::NewGuid().ToString('N'))
try{Write-TestPolicy $forgedRepo 'A-001' $true;& git -C $forgedRepo add project-a/harness/tasks/A-001.json;& git -C $forgedRepo commit -m policy|Out-Null;Set-AdapterEnvironment $forgedRepo 'A-001' $forgedLocal;$code=Invoke-ProjectAAdapterFixture -Arguments @('exec','--json','[TASK:A-001]');Assert-True ($code -eq 75) 'forged recovery fixture reaches approval pause';Write-JsonNoBom -Path (Join-Path $forgedRepo 'evidence/project-a/A-001.json') -Value ([ordered]@{forged=$true});& git -C $forgedRepo add project-a 'evidence/project-a/A-001.json';& git -C $forgedRepo commit -m 'feat(A-001): contract fixture'|Out-Null;$code=Invoke-ProjectAAdapterFixture -Arguments @('exec','--json','[TASK:A-001]');Assert-True ($code -ne 0) 'same-subject manual commit is rejected without persisted intended tree and evidence digest';$forgedState=Read-JsonFile -Path (Join-Path $forgedRepo '.harness/runtime/project-a/state/A-001.json');Assert-True ($forgedState.status -ne 'completed') 'forged recovery cannot mark task complete'}finally{Clear-AdapterEnvironment;Remove-Item -LiteralPath $forgedRepo -Recurse -Force;Remove-Item -LiteralPath $forgedLocal -Recurse -Force -ErrorAction SilentlyContinue}

Write-Host "Project A harness tests passed: $passed assertions"
