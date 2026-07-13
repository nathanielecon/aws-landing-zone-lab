[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][string]$PolicyPath,
    [Parameter(Mandatory)][string]$IsolationRoot,
    [switch]$Committed
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.Common.psm1') -Force
$Root = [System.IO.Path]::GetFullPath($Root)
$policy = Read-JsonFile -Path $PolicyPath
$knownValidators = @('scope','credential_boundary','forbidden_operations','secret_scan','terraform_fmt_check','terraform_validate_offline','terraform_validate_all_offline','terraform_tests_offline','backend_state_semantics','organizations_semantics','iam_policy_semantics','governance_semantics','iam_negative_tests','network_boundary_semantics','network_negative_tests','audit_semantics','operations_semantics','cross_module_negative_tests','docs_links','required_evidence','claims_boundary','claim_language_semantics','diagram_links','graphify_evidence','final_repo_validation')
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result([string]$Id, [bool]$Passed, [string]$Message, [long]$DurationMs) {
    $results.Add([ordered]@{ id = $Id; passed = $Passed; message = $Message; duration_ms = $DurationMs; implementation = 'project-a-gates-v1' })
    if (-not $Passed) { throw "VALIDATOR_FAILED: $Id - $Message" }
}

function Invoke-ExternalCheck([string]$Id, [string]$FileName, [string[]]$Arguments, [string]$WorkingDirectory, [int]$TimeoutSeconds, [string]$EnvironmentId = $Id) {
    $info = [System.Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $FileName; $info.WorkingDirectory = $WorkingDirectory; $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$info.ArgumentList.Add($argument) }
    Set-RepoOnlyProcessEnvironment -StartInfo $info -IsolationRoot (Join-Path $IsolationRoot $EnvironmentId)
    $process = [System.Diagnostics.Process]::new(); $process.StartInfo = $info
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        [void]$process.Start()
        $execution = Invoke-ProcessWithTimeout -Process $process -TimeoutSeconds $TimeoutSeconds
        if ($execution.timed_out) { throw "VALIDATOR_TIMEOUT: $Id exceeded its hard timeout of $TimeoutSeconds seconds." }
        $stdout = Protect-LogText -Text $execution.stdout; $stderr = Protect-LogText -Text $execution.stderr
        if ($execution.exit_code -ne 0) { throw "Exit $($execution.exit_code): $stdout $stderr" }
        Add-Result -Id $Id -Passed $true -Message 'External check passed.' -DurationMs $timer.ElapsedMilliseconds
    } finally { $timer.Stop(); $process.Dispose() }
}

function Get-TaskFiles {
    $runtimeExcluded = @(Get-HarnessLifecycleExcludedPaths -Root $Root -ProfileId 'project-a')
    $paths = if ($Committed) { @($policy.expected_artifacts | ForEach-Object { [string]$_ }) } else { @(Get-ChangedPaths -Root $Root -ExcludedPaths $runtimeExcluded) }
    return @($paths | Where-Object { Test-Path -LiteralPath (Join-Path $Root $_) -PathType Leaf })
}

function Test-TextArtifact([string]$Path) {
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        if ($bytes.Length -eq 0) { return $true }
        if ($bytes -contains 0) { return $false }
        $sampleLength = [Math]::Min($bytes.Length, 4096)
        $controlBytes = 0
        for ($index = 0; $index -lt $sampleLength; $index++) {
            $byte = $bytes[$index]
            if (($byte -lt 9) -or ($byte -gt 13 -and $byte -lt 32)) { $controlBytes++ }
        }
        return ($controlBytes / $sampleLength) -lt 0.05
    } catch {
        return $false
    }
}

function Get-ForbiddenOperationRules {
    $rules = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in @($policy.forbidden_operations)) {
        if ($null -eq $entry) { continue }
        if ($entry -is [string]) {
            $token = [string]$entry
            $normalized = $token.Trim().ToLowerInvariant()
            $regex = switch ($normalized) {
                'aws' { '(?im)(^|[^\w.-])(aws(\.cmd|\.exe)?)(?=[\s`"''(]|$)' }
                'az' { '(?im)(^|[^\w.-])(az(\.cmd|\.exe)?)(?=[\s`"''(]|$)' }
                'terraform apply' { '(?im)(^|[^\w.-])(terraform(\.exe)?)(?=[\s`"''(]|$).*?\bapply\b' }
                'terraform destroy' { '(?im)(^|[^\w.-])(terraform(\.exe)?)(?=[\s`"''(]|$).*?\bdestroy\b' }
                'terraform import' { '(?im)(^|[^\w.-])(terraform(\.exe)?)(?=[\s`"''(]|$).*?\bimport\b' }
                'terraform plan' { '(?im)(^|[^\w.-])(terraform(\.exe)?)(?=[\s`"''(]|$).*?\bplan\b' }
                'credential read' { '(?im)(aws\s+configure|get-credential|Get-Credential|Read-Host\s+.*(secret|token|password)|secret_access_key|client_secret)' }
                default { [regex]::Escape($token) }
            }
            $rules.Add([pscustomobject]@{
                id = $token
                pattern = $regex
                extensions = @()
                description = $token
            })
            continue
        }

        $propertyNames = @($entry.PSObject.Properties.Name)
        $patternProperty = if ($propertyNames -contains 'pattern') { 'pattern' } elseif ($propertyNames -contains 'regex') { 'regex' } else { $null }
        if (-not $patternProperty) { throw "Forbidden operation entry must provide a string token or a pattern/regex field." }
        $rules.Add([pscustomobject]@{
            id = if ($propertyNames -contains 'id') { [string]$entry.id } else { [string]$entry.description }
            pattern = [string]$entry.$patternProperty
            extensions = @($entry.extensions | ForEach-Object { ([string]$_).ToLowerInvariant() })
            description = if ($propertyNames -contains 'description') { [string]$entry.description } else { [string]$entry.$patternProperty }
        })
    }
    return @($rules)
}

function Assert-ExpectedArtifacts {
    $missing=@();$empty=@()
    foreach($relative in @($policy.expected_artifacts)){$path=Join-Path $Root ([string]$relative);if(-not(Test-Path -LiteralPath $path -PathType Leaf)){$missing+=[string]$relative}elseif((Get-Item -LiteralPath $path).Length -eq 0){$empty+=[string]$relative}}
    if($missing.Count -gt 0){throw "Expected artifacts missing: $($missing -join ', ')"};if($empty.Count -gt 0){throw "Expected artifacts empty: $($empty -join ', ')"}
}

function Get-ProjectText([string[]]$RelativeRoots,[string[]]$Extensions=@('.tf','.json','.md','.ps1','.tftest.hcl','.svg')){
    $chunks=[Collections.Generic.List[string]]::new()
    foreach($relative in $RelativeRoots){$path=Join-Path $Root $relative;if(Test-Path -LiteralPath $path -PathType Leaf){$chunks.Add((Get-Content -Raw -LiteralPath $path))}elseif(Test-Path -LiteralPath $path -PathType Container){foreach($file in Get-ChildItem -LiteralPath $path -Recurse -File|Where-Object{$_.Extension -in $Extensions -or $_.Name.EndsWith('.tftest.hcl')}){$chunks.Add((Get-Content -Raw -LiteralPath $file.FullName))}}}
    return $chunks -join "`n"
}

function Test-RequiredPatterns([string]$Text,[System.Collections.Specialized.OrderedDictionary]$Patterns){
    $missing=@();foreach($entry in $Patterns.GetEnumerator()){if($Text -notmatch $entry.Value){$missing+=$entry.Key}};Write-Output -NoEnumerate $missing
}

function Invoke-TerraformBehavioralTests([string]$Id,[string]$ModuleRelative,[string]$TestsRelative,[int]$TimeoutSeconds){
    $terraform=(Get-Command terraform.exe -ErrorAction Stop).Source
    $module=Resolve-PathUnderRoot -Root $Root -RelativePath $ModuleRelative
    $tests=Resolve-PathUnderRoot -Root $Root -RelativePath $TestsRelative
    $testFiles=@(Get-ChildItem -LiteralPath $tests -Recurse -File -Filter *.tftest.hcl)
    if($testFiles.Count -eq 0){throw "VALIDATOR_FAILED: $Id - no .tftest.hcl files exist"}
    $assertions=@($testFiles|Where-Object{(Get-Content -Raw -LiteralPath $_.FullName)-match '(?m)^\s*assert\s*\{'})
    if($assertions.Count -eq 0){throw "VALIDATOR_FAILED: $Id - Terraform tests contain no assert blocks"}
    $moduleRoot=$module.TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
    $scratch=Join-Path $IsolationRoot "$Id-scratch";$workingModule=Join-Path $scratch 'module'
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue;[IO.Directory]::CreateDirectory($workingModule)|Out-Null
    Copy-Item -Path (Join-Path $module '*') -Destination $workingModule -Recurse -Force
    if($tests.StartsWith($moduleRoot,[StringComparison]::OrdinalIgnoreCase)){
        $testDirectory=[IO.Path]::GetRelativePath($module,$tests).Replace('\','/')
    }else{
        $testTarget=Join-Path $workingModule '.harness-tests'
        Copy-Item -LiteralPath $tests -Destination $testTarget -Recurse -Force
        $testDirectory='.harness-tests'
    }
    Invoke-ExternalCheck "$id-init" $terraform @('init','-backend=false','-input=false') $workingModule $TimeoutSeconds "$Id-environment"
    Invoke-ExternalCheck $id $terraform @('test','-no-color',"-test-directory=$testDirectory") $workingModule $TimeoutSeconds "$Id-environment"
}

try {
    $beforeFingerprint = $null
    $beforeFingerprint = Get-DiffFingerprint -Root $Root
    $allowed = @($policy.allowed_paths | ForEach-Object { [string]$_ })
    $adapterOwned = @($policy.adapter_owned_paths | ForEach-Object { [string]$_ })
    $allowedExecutablePaths = if ($policy.PSObject.Properties.Name -contains 'allowed_executable_paths') { @($policy.allowed_executable_paths | ForEach-Object { [string]$_ }) } else { @() }
    $runtimeExcluded = @(Get-HarnessLifecycleExcludedPaths -Root $Root -ProfileId 'project-a')
    if (-not $Committed) {
        $changed = @(Get-ChangedPaths -Root $Root -ExcludedPaths $runtimeExcluded)
        $agentOwned = @($changed | Where-Object { Test-AllowedPath -Path $_ -AllowedPaths $allowed })
        $outside = @($changed | Where-Object { -not (Test-AllowedPath -Path $_ -AllowedPaths $allowed) })
        if ($outside.Count -gt 0) { throw "SCOPE_ESCAPE: $($outside -join ', ')" }
        if ($agentOwned.Count -eq 0) { throw 'NO_MEANINGFUL_DIFF: no task change exists' }
        foreach ($path in $adapterOwned) { if ($changed -contains $path) { throw "SCOPE_ESCAPE: agent changed adapter-owned evidence $path" } }
    }

    foreach ($validator in $policy.validators) {
        $id = [string]$validator.id
        if ($id -notin $knownValidators) { throw "UNKNOWN_VALIDATOR: $id" }
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        switch ($id) {
            'scope' {
                if (-not $Committed) { [void](Get-CanonicalDiffRecord -Root $Root -AllowedPaths $allowed -AdapterOwnedPaths $adapterOwned -AllowedExecutablePaths $allowedExecutablePaths -ExcludedPaths $runtimeExcluded) }
                Add-Result $id $true 'Changed paths are agent-owned and canonical.' $timer.ElapsedMilliseconds
            }
            'credential_boundary' {
                $leaked = @(Get-ChildItem Env: | Where-Object { $_.Name -match '^(AWS_|AZURE_|ARM_|TF_VAR_|GH_TOKEN$|GITHUB_TOKEN$|OPENAI_API_KEY$|ANTHROPIC_API_KEY$)' -and $_.Name -notin @('AWS_CONFIG_FILE','AWS_SHARED_CREDENTIALS_FILE','AWS_EC2_METADATA_DISABLED','AZURE_CONFIG_DIR','AZURE_DEVOPS_CACHE_DIR','AZURE_EXTENSION_DIR') -and $_.Value })
                $message = if ($leaked) { "Credential variables visible: $($leaked.Name -join ', ')" } else { 'Cloud credential variables are absent.' }
                Add-Result $id ($leaked.Count -eq 0) $message $timer.ElapsedMilliseconds
            }
            'forbidden_operations' {
                $rules = @(Get-ForbiddenOperationRules)
                if ($rules.Count -eq 0) { throw 'Forbidden operations policy is empty.' }
                $violations = [System.Collections.Generic.List[string]]::new()
                foreach ($relative in Get-TaskFiles) {
                    if ($relative -match '^(?:\.harness/|harness/|project-a/harness/)') { continue }
                    $path = Join-Path $Root $relative
                    if (-not (Test-TextArtifact -Path $path)) { continue }
                    $extension = [System.IO.Path]::GetExtension($relative).ToLowerInvariant()
                    $text = Get-Content -Raw -LiteralPath $path
                    foreach ($rule in $rules) {
                        if ($rule.extensions.Count -gt 0 -and $extension -notin $rule.extensions) { continue }
                        if ($text -match $rule.pattern) {
                            $label = if ($rule.id) { $rule.id } else { $rule.description }
                            $violations.Add(('{0} [{1}]' -f $relative, $label))
                        }
                    }
                }
                $message = if ($violations) { "Forbidden operation text: $($violations -join ', ')" } else { 'No policy-defined forbidden operation text found in changed text artifacts.' }
                Add-Result $id ($violations.Count -eq 0) $message $timer.ElapsedMilliseconds
            }
            'secret_scan' {
                $hits = [System.Collections.Generic.List[string]]::new()
                foreach ($relative in Get-TaskFiles) {
                    $text = Get-Content -Raw -LiteralPath (Join-Path $Root $relative) -ErrorAction SilentlyContinue
                    if ($text -match '(?i)\b(AKIA|ASIA)[A-Z0-9]{16}\b|-----BEGIN [A-Z ]*PRIVATE KEY-----|(?m)(client_secret|secret_access_key|password)\s*[=:]\s*["''][^"'']{8,}') { $hits.Add($relative) }
                }
                $message = if ($hits) { "Credential-shaped content: $($hits -join ', ')" } else { 'No credential-shaped content found.' }
                Add-Result $id ($hits.Count -eq 0) $message $timer.ElapsedMilliseconds
            }
            'terraform_fmt_check' {
                $terraform = (Get-Command terraform.exe -ErrorAction Stop).Source
                $target = Resolve-PathUnderRoot -Root $Root -RelativePath ([string]$validator.args[0])
                Invoke-ExternalCheck $id $terraform @('fmt','-check','-recursive',$target) $Root ([int]$validator.timeout_seconds)
            }
            { $_ -in @('terraform_validate_offline','terraform_validate_all_offline') } {
                $terraform = (Get-Command terraform.exe -ErrorAction Stop).Source
                $target = Resolve-PathUnderRoot -Root $Root -RelativePath ([string]$validator.args[0])
                Invoke-ExternalCheck "$id-init" $terraform @('init','-backend=false','-input=false','-lockfile=readonly') $target ([int]$validator.timeout_seconds) $id
                Invoke-ExternalCheck $id $terraform @('validate','-no-color') $target ([int]$validator.timeout_seconds)
            }
            'terraform_tests_offline' {
                $terraform = (Get-Command terraform.exe -ErrorAction Stop).Source
                $target = Resolve-PathUnderRoot -Root $Root -RelativePath ([string]$validator.args[0])
                Invoke-ExternalCheck $id $terraform @('test','-no-color') $target ([int]$validator.timeout_seconds)
            }
            'backend_state_semantics' {
                Assert-ExpectedArtifacts;$text=Get-ProjectText @('project-a/docs/decisions/backend.md','project-a/docs/decisions/secrets.md','project-a/terraform/bootstrap','project-a/examples/backend');$missing=Test-RequiredPatterns $text ([ordered]@{s3='(?i)S3';lockfile='(?i)(use_lockfile|lockfile|concurren)';versioning='(?i)version';encryption='(?i)(encrypt|KMS)';environment_separation='(?i)(nonproduction|production).*(key|state)|state.*(nonproduction|production)';recovery='(?i)(recover|rollback|overwrite|drift)';secret_store='(?i)(Secrets Manager|Parameter Store|secret store)';do_not_commit='(?i)(do not|never).*(commit|tfvars|state).*secret';least_privilege='(?i)least.?privilege'});$message=if($missing){"Backend/secrets contract missing: $($missing -join ', ')"}else{'Backend concurrency, recovery, environment separation, and secrets boundaries are documented.'};Add-Result $id ($missing.Count -eq 0) $message $timer.ElapsedMilliseconds
            }
            'organizations_semantics' {
                Assert-ExpectedArtifacts;$text=Get-ProjectText @('project-a/terraform/organization','project-a/docs/architecture/accounts.md','project-a/docs/guardrails/organizations.md')
                $missing=Test-RequiredPatterns $text ([ordered]@{organization='aws_organizations_organization';ou='aws_organizations_organizational_unit';account='aws_organizations_account';scp='aws_organizations_policy';attachment='aws_organizations_policy_attachment'})
                $message=if($missing){"Missing organization constructs: $($missing -join ', ')"}else{'Organization, OU, account, SCP, and attachment constructs are present.'};Add-Result $id ($missing.Count -eq 0) $message $timer.ElapsedMilliseconds
            }
            'iam_policy_semantics' {
                Assert-ExpectedArtifacts;$text=Get-ProjectText @('project-a/terraform/identity','project-a/policies','project-a/docs/guardrails/iam.md')
                $missing=Test-RequiredPatterns $text ([ordered]@{iam_policy='aws_iam_policy';boundary='permission.?boundar';trust='trust';break_glass='break.?glass';least_privilege='least.?privilege'})
                $unsafe=$false;foreach($file in Get-ChildItem (Join-Path $Root 'project-a/policies') -Recurse -Filter *.json -File -ErrorAction SilentlyContinue){try{$doc=Get-Content -Raw $file.FullName|ConvertFrom-Json;foreach($statement in @($doc.Statement)){if($statement.Effect -eq 'Allow' -and (@($statement.Action)-contains '*' -or @($statement.Resource)-contains '*')){$unsafe=$true}}}catch{throw "Invalid IAM policy JSON: $($file.FullName)"}}
                $message=if($unsafe){'Allow statement contains wildcard Action or Resource.'}elseif($missing){"Missing IAM constructs: $($missing -join ', ')"}else{'IAM policy, boundary, trust, break-glass, and least-privilege contracts are present.'};Add-Result $id ($missing.Count -eq 0 -and -not $unsafe) $message $timer.ElapsedMilliseconds
            }
            'governance_semantics' {
                Assert-ExpectedArtifacts;$text=Get-ProjectText @('project-a/docs/guardrails/policy-validation.md','project-a/tests/governance','project-a/tests/iam');$missing=Test-RequiredPatterns $text ([ordered]@{fmt='(?i)terraform fmt';validate='(?i)terraform validate';lint='(?i)(tflint|lint)';required_tags='(?i)required tags?|tagging';naming='(?i)naming';blocked_example='(?i)(blocked|reject|fail).*(change|example|test)|change.*(blocked|rejected)';assert='(?m)^\s*assert\s*\{'});$message=if($missing){"Governance-as-code contract missing: $($missing -join ', ')"}else{'Validation, lint, naming/tagging, and blocked-change examples are present.'};Add-Result $id ($missing.Count -eq 0) $message $timer.ElapsedMilliseconds
            }
            'iam_negative_tests' {
                Assert-ExpectedArtifacts;Invoke-TerraformBehavioralTests $id 'project-a/terraform/identity' 'project-a/tests/iam' ([int]$validator.timeout_seconds)
            }
            'network_boundary_semantics' {
                Assert-ExpectedArtifacts;$text=Get-ProjectText @('project-a/terraform/network','project-a/docs/architecture/network.md');$missing=Test-RequiredPatterns $text ([ordered]@{vpc='aws_vpc';subnet='aws_subnet';route='aws_route_table';flow_logs='aws_flow_log';private='private';egress='egress';ingress='ingress'})
                $unsafe=$text -match '(?is)ingress\s*\{[^}]*cidr_blocks\s*=\s*\[\s*"0\.0\.0\.0/0"'
                $message=if($unsafe){'Unrestricted IPv4 ingress is forbidden.'}elseif($missing){"Network constructs missing: $($missing -join ', ')"}else{'VPC, subnet, route, private-boundary, and flow-log constructs are present.'};Add-Result $id ($missing.Count -eq 0 -and -not $unsafe) $message $timer.ElapsedMilliseconds
            }
            'network_negative_tests' {
                Assert-ExpectedArtifacts;Invoke-TerraformBehavioralTests $id 'project-a/terraform/network' 'project-a/tests/network' ([int]$validator.timeout_seconds)
            }
            'audit_semantics' {
                Assert-ExpectedArtifacts;$text=Get-ProjectText @('project-a/terraform/audit','project-a/docs/operations/audit-review.md','project-a/docs/architecture/logging.md');$missing=Test-RequiredPatterns $text ([ordered]@{trail='aws_cloudtrail';multi_region='is_multi_region_trail';integrity='enable_log_file_validation';kms='aws_kms_key';public_block='aws_s3_bucket_public_access_block';config='aws_config';retention='retention';recovery='recover'})
                $message=if($missing){"Audit constructs missing: $($missing -join ', ')"}else{'CloudTrail, Config, KMS, public blocking, integrity, retention, and recovery are present.'};Add-Result $id ($missing.Count -eq 0) $message $timer.ElapsedMilliseconds
            }
            'operations_semantics' {
                Assert-ExpectedArtifacts;$text=Get-ProjectText @('project-a/docs/operations','project-a/docs/validation.md','project-a/docs/architecture/logging.md');$missing=Test-RequiredPatterns $text ([ordered]@{provisioning='(?i)provision.*(fail|first check|troubleshoot)';access='(?i)access.*(fail|first check|troubleshoot)';audit_missing='(?i)(audit|logging).*(missing|first check|troubleshoot)';cost='(?i)(cost|charge|billing)';teardown='(?i)(tear.?down|destroy after validation|remove after validation)';cost_drivers='(?i)(NAT Gateway|Transit Gateway|log storage|KMS|cost driver)';captured_events='(?i)(events captured|captures?).*(CloudTrail|Config|flow)';log_destination='(?i)(log archive|destination|S3)';stop_condition='(?i)(stop|escalat).*(condition|when|if)'});$message=if($missing){"Operator/cost/logging contract missing: $($missing -join ', ')"}else{'Troubleshooting, audit proof, cost drivers, teardown, and escalation guidance are present.'};Add-Result $id ($missing.Count -eq 0) $message $timer.ElapsedMilliseconds
            }
            'cross_module_negative_tests' {
                Assert-ExpectedArtifacts;Invoke-TerraformBehavioralTests $id 'project-a' 'project-a/tests/integration' ([int]$validator.timeout_seconds)
            }
            'docs_links' {
                Assert-ExpectedArtifacts;$text=Get-ProjectText @($policy.expected_artifacts);$hasLinks=$text -match '\[[^]]+\]\([^)]+\)|https://'
                $message=if($hasLinks){'Documentation contains inspectable references.'}else{'Documentation has no inspectable links or references.'};Add-Result $id $hasLinks $message $timer.ElapsedMilliseconds
            }
            'required_evidence' {
                Assert-ExpectedArtifacts;$missing=@(1..6|ForEach-Object{"evidence/project-a/A-{0:D3}.json"-f $_}|Where-Object{-not(Test-Path -LiteralPath (Join-Path $Root $_)-PathType Leaf)})
                $message=if($missing){"Prior evidence missing: $($missing -join ', ')"}else{'All prior task evidence exists.'};Add-Result $id ($missing.Count -eq 0) $message $timer.ElapsedMilliseconds
            }
            'claims_boundary' {
                Assert-ExpectedArtifacts;$text=Get-ProjectText @('project-a/docs/azure-government','project-a/evidence-index.md');$required=$text -match '(?i)not implemented' -and $text -match '(?i)not (cloud )?validated';$overclaim=$text -match '(?i)azure government (is|was|has been) (implemented|deployed|validated)'
                $message=if($required -and -not $overclaim){'Azure Government claims remain translation-only.'}else{'Azure Government non-implementation/non-validation wording is missing or contradicted.'};Add-Result $id ($required -and -not $overclaim) $message $timer.ElapsedMilliseconds
            }
            'claim_language_semantics' {
                Assert-ExpectedArtifacts;$text=Get-ProjectText @('project-a/docs/portfolio/claims-boundary.md','project-a/docs/review','project-a/README.md');$missing=Test-RequiredPatterns $text ([ordered]@{proves='(?i)what (this )?(project|repository) proves';does_not_prove='(?i)(does not|doesn.t) prove';junior_mid='(?i)junior.?to.?mid|junior.*mid';avoid_claims='(?i)(avoid|do not claim|unsupported).*(production|senior|enterprise)';repo_only='(?i)repo.?only';not_cloud_validated='(?i)not (cloud )?validated'});$message=if($missing){"Claim-language contract missing: $($missing -join ', ')"}else{'Portfolio wording states supported and unsupported claims at the intended level.'};Add-Result $id ($missing.Count -eq 0) $message $timer.ElapsedMilliseconds
            }
            'diagram_links' {
                Assert-ExpectedArtifacts;$required=@('platform.svg','network.svg');$docs=Get-ProjectText @('project-a/README.md','project-a/docs') @('.md');$errors=@()
                foreach($name in $required){$path=Join-Path $Root "project-a/docs/diagrams/$name";if(-not(Test-Path $path -PathType Leaf)){$errors+="missing $name";continue};try{[xml]$svg=Get-Content -Raw -LiteralPath $path;if($svg.DocumentElement.LocalName -ne 'svg'){throw 'root is not svg'}}catch{$errors+="invalid XML $name"};if($docs -notmatch [regex]::Escape("diagrams/$name")){$errors+="unlinked $name"}}
                $message=if($errors){$errors -join ', '}else{'Required SVG diagrams parse as XML and are linked from documentation.'};Add-Result $id ($errors.Count -eq 0) $message $timer.ElapsedMilliseconds
            }
            'graphify_evidence' {
                Assert-ExpectedArtifacts;$report=Join-Path $Root 'project-a/graphify-out/GRAPH_REPORT.md';$text=if(Test-Path $report -PathType Leaf){Get-Content -Raw -LiteralPath $report}else{''};$missing=Test-RequiredPatterns $text ([ordered]@{generator='(?i)graphify';nodes='(?im)^.*nodes?\s*[:|].*\d+';edges='(?im)^.*edges?\s*[:|].*\d+';source='(?i)(source|input).*(project-a|terraform)';generated='(?i)(generated|created).*(utc|\d{4}-\d{2}-\d{2})'})
                $message=if($missing){"Graphify report lacks machine-verifiable fields: $($missing -join ', ')"}else{'Graphify report records generator, source, generation time, nodes, and edges.'};Add-Result $id ($missing.Count -eq 0) $message $timer.ElapsedMilliseconds
            }
            'final_repo_validation' {
                Assert-ExpectedArtifacts;$forbidden=@(Get-ChildItem (Join-Path $Root 'project-a') -Recurse -Force -ErrorAction SilentlyContinue|Where-Object{$_.Name -in @('.terraform','terraform.tfstate','terraform.tfstate.backup') -or $_.Extension -in @('.tfplan')})
                $evidenceErrors=@();foreach($n in 1..6){$taskId='A-{0:D3}'-f $n;$path=Join-Path $Root "evidence/project-a/$taskId.json";if(-not(Test-Path $path -PathType Leaf)){$evidenceErrors+="missing $taskId";continue};try{$e=Get-Content -Raw -LiteralPath $path|ConvertFrom-Json;if([string]$e.task_id -ne $taskId){$evidenceErrors+="task mismatch $taskId"};if($null -eq $e.validation_digest -or [string]$e.validation_digest -notmatch '^[A-Fa-f0-9]{64}$'){$evidenceErrors+="validation digest $taskId"};foreach($claim in @('cloud_validated','aws_implemented','azure_implemented')){$property=$e.PSObject.Properties[$claim];if($null -eq $property -or [bool]$property.Value){$evidenceErrors+="claim $claim $taskId"}}}catch{$evidenceErrors+="invalid JSON $taskId"}}
                $message=if($forbidden){'Generated Terraform state/data artifacts are forbidden.'}elseif($evidenceErrors){"Evidence contract failures: $($evidenceErrors -join ', ')"}else{'Final repository state, evidence schema, validation digests, and claims boundary passed.'};Add-Result $id ($forbidden.Count -eq 0 -and $evidenceErrors.Count -eq 0) $message $timer.ElapsedMilliseconds
            }
            default { throw "UNKNOWN_VALIDATOR: $id" }
            }
        $timer.Stop()
    }
    $afterFingerprint = Get-DiffFingerprint -Root $Root
    if ($beforeFingerprint -ne $afterFingerprint) { throw 'VALIDATOR_MUTATION: a validator changed repository content' }
    $digestResults = @($results | ForEach-Object { [ordered]@{ id=$_.id; passed=$_.passed; message=$_.message; implementation=$_.implementation } })
    $resultJson = $digestResults | ConvertTo-Json -Compress -Depth 8
    $digest = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($resultJson)))
    [pscustomobject]@{ passed = $true; error_class = $null; message = 'All Project A validators passed.'; validation_digest = $digest; results = @($results) } | ConvertTo-Json -Compress -Depth 10
    exit 0
} catch {
    $message = $_.Exception.Message
    if ($null -ne $beforeFingerprint) {
        try {
            if((Get-DiffFingerprint -Root $Root) -ne $beforeFingerprint){$message='VALIDATOR_MUTATION: a validator changed repository content'}
        } catch { }
    }
    $errorClass = if ($message -match '^(?<class>[A-Z_]+):') { $Matches.class } else { 'GATE_EXCEPTION' }
    [pscustomobject]@{ passed = $false; error_class = $errorClass; message = $message; validation_digest = $null; results = @($results) } | ConvertTo-Json -Compress -Depth 10
    exit 1
}
