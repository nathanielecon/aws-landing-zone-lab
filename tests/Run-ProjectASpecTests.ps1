[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRoot = Join-Path $root 'project-a'
$passed = 0

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
    $script:passed++
}

$manifest = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'harness/PRD.template.json') | ConvertFrom-Json
$policyFiles = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'harness/tasks') -Filter 'A-*.json' | Sort-Object Name)
$policies = @($policyFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json })
Assert-True ($manifest.tasks.Count -eq 7) 'manifest contains exactly seven sequential tasks'
Assert-True ($policies.Count -eq 7) 'one policy exists for every Project A task'

$validatorAllowlist = @('scope','credential_boundary','forbidden_operations','secret_scan','terraform_fmt_check','terraform_validate_offline','terraform_validate_all_offline','terraform_tests_offline','backend_state_semantics','organizations_semantics','iam_policy_semantics','governance_semantics','iam_negative_tests','network_boundary_semantics','network_negative_tests','audit_semantics','operations_semantics','cross_module_negative_tests','docs_links','required_evidence','claims_boundary','claim_language_semantics','diagram_links','graphify_evidence','final_repo_validation')
$requiredForbidden = @('aws','az','terraform apply','terraform destroy','terraform import','terraform plan','credential read')
for ($index = 0; $index -lt 7; $index++) {
    $expectedId = 'A-{0:D3}' -f ($index + 1)
    $policy = $policies[$index]
    $task = $manifest.tasks[$index]
    Assert-True (Test-Json -LiteralPath $policyFiles[$index].FullName -SchemaFile (Join-Path $projectRoot 'harness/policy.schema.json') -ErrorAction SilentlyContinue) "$expectedId satisfies the published JSON Schema"
    Assert-True ([string]$policy.id -eq $expectedId) "$expectedId policy ordering"
    Assert-True ([string]$task.title -match "\[TASK:$expectedId\]") "$expectedId manifest marker"
    Assert-True ([string]$task.description -match [regex]::Escape("harness/tasks/$expectedId.json")) "$expectedId manifest references its immutable sidecar"
    Assert-True ([string]$policy.schema_version -eq 'project-a-task-policy-v1' -and [string]$policy.mode -eq 'repo_only') "$expectedId schema and repo-only mode"
    Assert-True ([int]$policy.terra_attempt_limit -eq 3 -and [int]$policy.elapsed_limit_minutes -eq 25) "$expectedId takeover thresholds"
    Assert-True (@($policy.allowed_paths).Count -gt 0 -and @($policy.expected_artifacts).Count -gt 0) "$expectedId scoped paths and artifacts"
    Assert-True ([string]$policy.expected_evidence -eq "evidence/project-a/$expectedId.json") "$expectedId deterministic evidence path"
    Assert-True ((@($policy.adapter_owned_paths) -join ',') -eq [string]$policy.expected_evidence -and @($policy.allowed_paths) -notcontains [string]$policy.expected_evidence) "$expectedId evidence is adapter-owned, not agent-writable"
    Assert-True ([string]$policy.validator_mutation_policy -eq 'no_tracked_writes') "$expectedId validators are check-only"
    Assert-True (-not [bool]$policy.claims.cloud_validated -and -not [bool]$policy.claims.aws_implemented -and -not [bool]$policy.claims.azure_implemented) "$expectedId claims remain repo-only"
    Assert-True (@($policy.validators | Where-Object { -not $_.required -or $_.id -notin $validatorAllowlist }).Count -eq 0) "$expectedId uses only required allowlisted validators"
    foreach ($operation in $requiredForbidden) { Assert-True (@($policy.forbidden_operations) -contains $operation) "$expectedId forbids $operation" }
    $expectedDependencies = if ($index -eq 0) { @() } else { @('A-{0:D3}' -f $index) }
    Assert-True ((@($policy.depends_on) -join ',') -eq ($expectedDependencies -join ',')) "$expectedId depends only on its sequential predecessor"
}

$approvalRequired = @($policies | Where-Object { $_.approval.required } | ForEach-Object { $_.id })
Assert-True (($approvalRequired -join ',') -eq 'A-001,A-002,A-003,A-004,A-005,A-007') 'risk and final tasks require diff-bound human approval'
$approvalGates = @($policies | Where-Object { $_.approval.required } | ForEach-Object { $_.approval.gate_id })
Assert-True (($approvalGates -join ',') -eq 'H0,H1,H2,H3,H4,H5' -and @($approvalGates | Sort-Object -Unique).Count -eq 6) 'human gate IDs are unique and bound to the intended task order'
foreach ($policy in $policies | Where-Object { $_.approval.required }) {
    Assert-True ([string]$policy.approval.stage -eq 'post_validation_pre_commit' -and [string]$policy.approval.approver -eq 'human') "$($policy.id) approval occurs after validation and before commit"
}

$approval = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'harness/bundle-approval.json') | ConvertFrom-Json
Assert-True (-not [bool]$approval.execution_approved -and (
    ([bool]$approval.spec_approved -and [string]$approval.status -eq 'spec_approved_execution_blocked') -or
    (-not [bool]$approval.spec_approved -and [string]$approval.status -eq 'revision_pending_approval')
)) 'spec approval state is internally consistent and never authorizes execution'
$computedBundle = & (Join-Path $root 'scripts/Get-ProjectASpecHash.ps1') -Root $root | ConvertFrom-Json
Assert-True ([string]$approval.spec_bundle_sha256 -eq [string]$computedBundle.sha256) 'candidate spec aggregate hash matches every declared bundle member'
$expectedMembers = @('project-a/PROJECT_A_PLAN.md','project-a/PROJECT_A_ADDITIONS.md','project-a/SOURCES.md','project-a/harness/PRD.template.json','project-a/harness/policy.schema.json','project-a/harness/tool-versions.json','tests/Run-ProjectASpecTests.ps1','scripts/Get-ProjectASpecHash.ps1') + @(1..7 | ForEach-Object { 'project-a/harness/tasks/A-{0:D3}.json' -f $_ })
$actualMembers = @($computedBundle.members.psobject.Properties.Name | Sort-Object)
Assert-True (($actualMembers -join ',') -eq (($expectedMembers | Sort-Object) -join ',')) 'aggregate hash contains exactly the declared spec members'
$hashImplementation = [string]$computedBundle.members.'scripts/Get-ProjectASpecHash.ps1'
Assert-True ([string]$approval.hash_implementation_sha256 -eq $hashImplementation) 'hash implementation is independently pinned'
Assert-True ($null -eq $approval.validator_implementation_sha256) 'revised validator implementation remains intentionally unapproved'

$additions = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'PROJECT_A_ADDITIONS.md')
foreach($signal in @('Backend and state discipline','Policy and validation as code','Network decisions','Secrets discipline','Logging and audit proof','Cost and teardown discipline','Operator troubleshooting','Claim boundaries')) { Assert-True ($additions.Contains($signal)) "gap-closure spec includes $signal" }
Assert-True (@($policies[0].validators.id) -contains 'backend_state_semantics' -and @($policies[0].expected_artifacts) -contains 'project-a/docs/decisions/secrets.md') 'A-001 gates backend, state, environment separation, and secrets discipline'
Assert-True (@($policies[2].validators.id) -contains 'governance_semantics' -and @($policies[2].expected_artifacts) -contains 'project-a/docs/guardrails/policy-validation.md') 'A-003 gates validation-as-code and blocked-change examples'
Assert-True (@($policies[3].expected_artifacts) -contains 'project-a/docs/operations/network-failure-cases.md') 'A-004 requires concrete connectivity failure cases'
Assert-True (@($policies[5].validators.id) -contains 'operations_semantics' -and @($policies[5].expected_artifacts) -contains 'project-a/docs/operations/cost-and-teardown.md') 'A-006 gates troubleshooting and cost/teardown discipline'
Assert-True (@($policies[6].validators.id) -contains 'claim_language_semantics' -and @($policies[6].expected_artifacts) -contains 'project-a/docs/portfolio/claims-boundary.md') 'A-007 gates accurate portfolio claim language'

$invalidPolicy = (Get-Content -Raw -LiteralPath $policyFiles[0].FullName) -replace '"title":', '"unexpected":true,"title":'
Assert-True (-not (Test-Json -Json $invalidPolicy -SchemaFile (Join-Path $projectRoot 'harness/policy.schema.json') -ErrorAction SilentlyContinue)) 'schema rejects undeclared policy properties'

Write-Host "Project A specification tests passed: $passed assertions"
