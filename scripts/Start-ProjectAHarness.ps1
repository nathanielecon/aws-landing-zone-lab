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
$computedSpec = & (Join-Path $PSScriptRoot 'Get-ProjectASpecHash.ps1') -Root $root | ConvertFrom-Json
if ([string]$approval.spec_bundle_sha256 -ne [string]$computedSpec.sha256) { throw 'Approved Project A specification hash drifted.' }
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
$realCodex = (Get-Command codex.cmd -All | Where-Object { -not ([IO.Path]::GetFullPath($_.Source)).StartsWith([IO.Path]::GetFullPath($adapterDir),[StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1).Source
$realRalphy = (Get-Command ralphy.cmd -All | Select-Object -First 1).Source
if (-not $realCodex -or -not $realRalphy) { throw 'Codex and Ralphy must be installed before Project A execution.' }
$login = (& $realCodex login status 2>&1 | Out-String); if ($LASTEXITCODE -ne 0 -or $login -notmatch 'Logged in using ChatGPT') { throw 'Codex ChatGPT login is required.' }

$runtimeRoot = Join-Path $root '.harness/runtime/project-a'
$manifestPath = Join-Path $runtimeRoot 'PRD.json'
$lockPath = Join-Path $root '.harness/runtime/harness.lock'
$lock = Open-ExclusiveLock -Path $lockPath
try {
    $changed = @(Get-ChangedPaths -Root $root)
    if (-not $Resume -and $changed.Count -gt 0) { throw "Normal Project A launch requires a clean tree: $($changed -join ', ')" }
    if (-not (Test-Path -LiteralPath $manifestPath)) { [IO.Directory]::CreateDirectory($runtimeRoot)|Out-Null; Copy-Item -LiteralPath (Resolve-PathUnderRoot -Root $root -RelativePath ([string]$profile.manifest_template)) -Destination $manifestPath }
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
} finally { if($lock){$lock.Dispose()} }
