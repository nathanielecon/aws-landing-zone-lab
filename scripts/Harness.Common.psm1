Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Utf8NoBom {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $parent = Split-Path -Parent $Path
    if ($parent) { [System.IO.Directory]::CreateDirectory($parent) | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Write-JsonNoBom {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Value)
    Write-Utf8NoBom -Path $Path -Text (($Value | ConvertTo-Json -Depth 30) + "`n")
}

function Assert-JsonObjectContract {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Context,
        [Parameter(Mandatory)][string[]]$RequiredProperties,
        [string[]]$OptionalProperties = @()
    )
    if ($null -eq $Value) { throw "$Context must be a JSON object." }
    $properties = @($Value.PSObject.Properties.Name | ForEach-Object { [string]$_ })
    if ($properties.Count -eq 0 -and $RequiredProperties.Count -gt 0) { throw "$Context must be a JSON object." }
    $allowed = @($RequiredProperties + $OptionalProperties | Sort-Object -Unique)
    $unknown = @($properties | Where-Object { $_ -notin $allowed })
    if ($unknown.Count -gt 0) { throw "$Context contains unknown field(s): $($unknown -join ', ')" }
    $missing = @($RequiredProperties | Where-Object { $_ -notin $properties })
    if ($missing.Count -gt 0) { throw "$Context is missing required field(s): $($missing -join ', ')" }
}

function Assert-JsonStringField {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Context,
        [Parameter(Mandatory)][string]$Name,
        [string]$Pattern,
        [switch]$AllowNull
    )
    $present = $Value.PSObject.Properties.Name -contains $Name
    if (-not $present) { throw "$Context is missing required field: $Name" }
    $field = $Value.$Name
    if ($null -eq $field) {
        if ($AllowNull) { return }
        throw "$Context field '$Name' must be a string."
    }
    if ($field -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$field)) { throw "$Context field '$Name' must be a non-empty string." }
    if ($Pattern -and ([string]$field -notmatch $Pattern)) { throw "$Context field '$Name' is invalid." }
}

function Assert-JsonOptionalStringField {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Context,
        [Parameter(Mandatory)][string]$Name,
        [string]$Pattern
    )
    if ($Value.PSObject.Properties.Name -notcontains $Name) { throw "$Context is missing required field: $Name" }
    $field = $Value.$Name
    if ($null -eq $field) { return }
    if ($field -isnot [string]) { throw "$Context field '$Name' must be a string." }
    if ([string]::IsNullOrWhiteSpace([string]$field)) { return }
    if ($Pattern -and ([string]$field -notmatch $Pattern)) { throw "$Context field '$Name' is invalid." }
}

function Assert-JsonIso8601TimestampField {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Context,
        [Parameter(Mandatory)][string]$Name,
        [switch]$AllowNull
    )
    if ($Value.PSObject.Properties.Name -notcontains $Name) { throw "$Context is missing required field: $Name" }
    $field = $Value.$Name
    if ($null -eq $field) {
        if ($AllowNull) { return }
        throw "$Context field '$Name' must be an ISO 8601 timestamp string."
    }
    $text = switch ($field) {
        { $_ -is [datetimeoffset] } { $_.ToString('o'); break }
        { $_ -is [datetime] } { $_.ToString('o'); break }
        { $_ -is [string] } { [string]$_; break }
        default { throw "$Context field '$Name' must be an ISO 8601 timestamp string." }
    }
    if ([string]::IsNullOrWhiteSpace($text)) { throw "$Context field '$Name' must be an ISO 8601 timestamp string." }
    if ($text -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:Z|[+-]\d{2}:\d{2})$') {
        throw "$Context field '$Name' is invalid."
    }
    $parsed = [datetimeoffset]::MinValue
    if (-not [datetimeoffset]::TryParse($text, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsed)) {
        throw "$Context field '$Name' is invalid."
    }
}

function Assert-JsonBooleanField {
    param([Parameter(Mandatory)]$Value, [Parameter(Mandatory)][string]$Context, [Parameter(Mandatory)][string]$Name)
    if ($Value.PSObject.Properties.Name -notcontains $Name) { throw "$Context is missing required field: $Name" }
    if ($Value.$Name -isnot [bool]) { throw "$Context field '$Name' must be a boolean." }
}

function Assert-JsonIntegerField {
    param([Parameter(Mandatory)]$Value, [Parameter(Mandatory)][string]$Context, [Parameter(Mandatory)][string]$Name, [int]$Minimum = [int]::MinValue)
    if ($Value.PSObject.Properties.Name -notcontains $Name) { throw "$Context is missing required field: $Name" }
    $field = $Value.$Name
    if ($field -isnot [sbyte] -and $field -isnot [byte] -and $field -isnot [int16] -and $field -isnot [uint16] -and $field -isnot [int32] -and $field -isnot [uint32] -and $field -isnot [int64]) {
        throw "$Context field '$Name' must be an integer >= $Minimum."
    }
    if ([int64]$field -lt $Minimum) { throw "$Context field '$Name' must be an integer >= $Minimum." }
}

function Assert-JsonStringArrayField {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Context,
        [Parameter(Mandatory)][string]$Name,
        [switch]$AllowNull
    )
    if ($Value.PSObject.Properties.Name -notcontains $Name) { throw "$Context is missing required field: $Name" }
    $field = $Value.$Name
    if ($null -eq $field) {
        if ($AllowNull) { return }
        throw "$Context field '$Name' must be an array of strings."
    }
    $items = @($field)
    foreach ($item in $items) {
        if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$item)) { throw "$Context field '$Name' must contain only non-empty strings." }
    }
}

function Assert-ProjectATaskListContract {
    param([Parameter(Mandatory)]$Tasks, [Parameter(Mandatory)][string]$Context)
    foreach ($task in @($Tasks)) {
        Assert-JsonObjectContract -Value $task -Context $Context -RequiredProperties @('title', 'completed') -OptionalProperties @('description')
        Assert-JsonStringField -Value $task -Context $Context -Name 'title' -Pattern '^\[TASK:A-00[1-7]\]'
        Assert-JsonBooleanField -Value $task -Context $Context -Name 'completed'
        if ($task.PSObject.Properties.Name -contains 'description' -and $null -ne $task.description) {
            if ($task.description -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$task.description)) { throw "$Context field 'description' must be a non-empty string." }
        }
    }
}

function Assert-StrictJsonContractForPath {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Value)
    $normalized = [System.IO.Path]::GetFullPath($Path) -replace '\\', '/'
    $hex64 = '^[A-F0-9]{64}$'
    $hex40 = '^[a-fA-F0-9]{40}$'
    $date = '^\d{4}-\d{2}-\d{2}$'
    $dateTime = '^\d{4}-\d{2}-\d{2}T'
    if ($normalized -like '*/project-a/harness/bundle-approval.json') {
        Assert-JsonObjectContract -Value $Value -Context 'Project A bundle approval' -RequiredProperties @('plan_id','status','spec_approved','execution_approved','spec_approved_by','spec_approved_at','approval_source','spec_bundle_sha256','execution_bundle_sha256','hash_implementation_sha256','validator_implementation_sha256','reason')
        Assert-JsonStringField -Value $Value -Context 'Project A bundle approval' -Name 'plan_id'
        Assert-JsonStringField -Value $Value -Context 'Project A bundle approval' -Name 'status' -Pattern '^(spec_approved_execution_blocked|spec_approved|execution_approved)$'
        Assert-JsonBooleanField -Value $Value -Context 'Project A bundle approval' -Name 'spec_approved'
        Assert-JsonBooleanField -Value $Value -Context 'Project A bundle approval' -Name 'execution_approved'
        Assert-JsonStringField -Value $Value -Context 'Project A bundle approval' -Name 'spec_approved_by'
        Assert-JsonStringField -Value $Value -Context 'Project A bundle approval' -Name 'spec_approved_at' -Pattern $date
        Assert-JsonStringField -Value $Value -Context 'Project A bundle approval' -Name 'approval_source'
        Assert-JsonStringField -Value $Value -Context 'Project A bundle approval' -Name 'spec_bundle_sha256' -Pattern $hex64
        if ($null -ne $Value.execution_bundle_sha256) { Assert-JsonStringField -Value $Value -Context 'Project A bundle approval' -Name 'execution_bundle_sha256' -Pattern $hex64 } else { [void]0 }
        Assert-JsonStringField -Value $Value -Context 'Project A bundle approval' -Name 'hash_implementation_sha256' -Pattern $hex64
        if ($null -ne $Value.validator_implementation_sha256) { Assert-JsonStringField -Value $Value -Context 'Project A bundle approval' -Name 'validator_implementation_sha256' -Pattern $hex64 } else { [void]0 }
        Assert-JsonStringField -Value $Value -Context 'Project A bundle approval' -Name 'reason'
        return
    }
    if ($normalized -like '*/project-a/harness/execution-approval.json') {
        Assert-JsonObjectContract -Value $Value -Context 'Project A execution approval' -RequiredProperties @('schema_version','status','execution_approved','spec_bundle_sha256','execution_bundle_sha256','validator_implementation_sha256','execution_hash_implementation_sha256','proven_with','approved_by','approved_at','approval_source','reason')
        Assert-JsonStringField -Value $Value -Context 'Project A execution approval' -Name 'schema_version' -Pattern '^project-a-execution-approval-v1$'
        Assert-JsonStringField -Value $Value -Context 'Project A execution approval' -Name 'status' -Pattern '^(revised_spec_execution_approval_required|execution_approved)$'
        Assert-JsonBooleanField -Value $Value -Context 'Project A execution approval' -Name 'execution_approved'
        Assert-JsonStringField -Value $Value -Context 'Project A execution approval' -Name 'spec_bundle_sha256' -Pattern $hex64
        Assert-JsonStringField -Value $Value -Context 'Project A execution approval' -Name 'execution_bundle_sha256' -Pattern $hex64
        Assert-JsonStringField -Value $Value -Context 'Project A execution approval' -Name 'validator_implementation_sha256' -Pattern $hex64
        Assert-JsonStringField -Value $Value -Context 'Project A execution approval' -Name 'execution_hash_implementation_sha256' -Pattern $hex64
        Assert-JsonObjectContract -Value $Value.proven_with -Context 'Project A execution approval.proven_with' -RequiredProperties @('live_models','fake_codex_only','cloud_credentials','project_a_harness_assertions')
        Assert-JsonBooleanField -Value $Value.proven_with -Context 'Project A execution approval.proven_with' -Name 'live_models'
        Assert-JsonBooleanField -Value $Value.proven_with -Context 'Project A execution approval.proven_with' -Name 'fake_codex_only'
        Assert-JsonBooleanField -Value $Value.proven_with -Context 'Project A execution approval.proven_with' -Name 'cloud_credentials'
        Assert-JsonIntegerField -Value $Value.proven_with -Context 'Project A execution approval.proven_with' -Name 'project_a_harness_assertions' -Minimum 1
        Assert-JsonStringField -Value $Value -Context 'Project A execution approval' -Name 'approved_by'
        Assert-JsonStringField -Value $Value -Context 'Project A execution approval' -Name 'approved_at' -Pattern $date
        Assert-JsonStringField -Value $Value -Context 'Project A execution approval' -Name 'approval_source'
        Assert-JsonStringField -Value $Value -Context 'Project A execution approval' -Name 'reason'
        return
    }
    if ($normalized -like '*/.harness/runtime/project-a/PRD.json') {
        Assert-JsonObjectContract -Value $Value -Context 'Project A runtime manifest' -RequiredProperties @('tasks')
        Assert-ProjectATaskListContract -Tasks $Value.tasks -Context 'Project A runtime manifest.tasks[]'
        return
    }
    if ($normalized -like '*/.harness/runtime/project-a/state/*.json') {
        Assert-JsonObjectContract -Value $Value -Context 'Project A task state' -RequiredProperties @('profile_id','bundle_hash','validator_sha256','policy_sha256','task_id','branch','starting_commit','started_at','status','phase','terra_attempts','sol_attempts','consecutive_failures','same_error_count','last_error_class','last_failure','terra_thread_id','sol_thread_id','validation_digest','diff_sha256','approval_receipt_digest','intended_tree','stage_paths','pending_evidence_path','pending_evidence_text','evidence_sha256','commit_sha','completed_at') -OptionalProperties @('approval_request','approval_receipt','approval_key','approval_confirmation','historical_reconstruction')
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'profile_id' -Pattern '^project-a$'
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'bundle_hash' -Pattern $hex64
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'validator_sha256' -Pattern $hex64
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'policy_sha256' -Pattern $hex64
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'task_id' -Pattern '^A-00[1-7]$'
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'branch'
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'starting_commit' -Pattern $hex40
        Assert-JsonIso8601TimestampField -Value $Value -Context 'Project A task state' -Name 'started_at'
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'status' -Pattern '^(running|awaiting_approval|preparing_commit|committing|completed|blocked)$'
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'phase' -Pattern '^(terra|sol)$'
        Assert-JsonIntegerField -Value $Value -Context 'Project A task state' -Name 'terra_attempts' -Minimum 0
        Assert-JsonIntegerField -Value $Value -Context 'Project A task state' -Name 'sol_attempts' -Minimum 0
        Assert-JsonIntegerField -Value $Value -Context 'Project A task state' -Name 'consecutive_failures' -Minimum 0
        Assert-JsonIntegerField -Value $Value -Context 'Project A task state' -Name 'same_error_count' -Minimum 0
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'last_error_class' -AllowNull
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'last_failure' -AllowNull
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'terra_thread_id' -AllowNull
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'sol_thread_id' -AllowNull
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'validation_digest' -AllowNull
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'diff_sha256' -Pattern $hex64 -AllowNull
        $requiresApprovalArtifacts = [string]$Value.status -in @('awaiting_approval','preparing_commit','committing')
        foreach ($propertyName in @('approval_request','approval_receipt','approval_key')) {
            $hasProperty = $Value.PSObject.Properties.Name -contains $propertyName
            if ($requiresApprovalArtifacts) {
                if (-not $hasProperty) { throw "Project A task state is missing required field: $propertyName" }
                Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name $propertyName
                continue
            }
            if ($hasProperty) {
                Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name $propertyName -AllowNull
            }
        }
        if ($Value.PSObject.Properties.Name -contains 'historical_reconstruction' -and $null -ne $Value.historical_reconstruction -and $Value.historical_reconstruction -isnot [bool]) {
            throw "Project A task state field 'historical_reconstruction' must be a boolean."
        }
        if ($Value.PSObject.Properties.Name -contains 'approval_confirmation' -and $null -ne $Value.approval_confirmation) { Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'approval_confirmation' }
        Assert-JsonOptionalStringField -Value $Value -Context 'Project A task state' -Name 'approval_receipt_digest' -Pattern $hex64
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'intended_tree' -Pattern $hex40 -AllowNull
        Assert-JsonStringArrayField -Value $Value -Context 'Project A task state' -Name 'stage_paths'
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'pending_evidence_path' -AllowNull
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'pending_evidence_text' -AllowNull
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'evidence_sha256' -Pattern $hex64 -AllowNull
        Assert-JsonStringField -Value $Value -Context 'Project A task state' -Name 'commit_sha' -Pattern $hex40 -AllowNull
        Assert-JsonIso8601TimestampField -Value $Value -Context 'Project A task state' -Name 'completed_at' -AllowNull
        return
    }
    if ($normalized -like '*/evidence/project-a/*.json') {
        Assert-JsonObjectContract -Value $Value -Context 'Project A evidence' -RequiredProperties @('schema_version','profile_id','mode','cloud_validated','aws_implemented','azure_implemented','execution_bundle_sha256','validator_implementation_sha256','policy_sha256','run_id','task_id','phase_passed','terra_attempts','sol_attempts','starting_commit','diff_sha256','changed_entries','validation_digest','approval_required','approval_receipt_digest','completed_at','commit_parent','commit_lookup')
        Assert-JsonStringField -Value $Value -Context 'Project A evidence' -Name 'schema_version' -Pattern '^project-a-evidence-v1$'
        Assert-JsonStringField -Value $Value -Context 'Project A evidence' -Name 'profile_id' -Pattern '^project-a$'
        Assert-JsonStringField -Value $Value -Context 'Project A evidence' -Name 'mode' -Pattern '^repo_only$'
        Assert-JsonBooleanField -Value $Value -Context 'Project A evidence' -Name 'cloud_validated'
        Assert-JsonBooleanField -Value $Value -Context 'Project A evidence' -Name 'aws_implemented'
        Assert-JsonBooleanField -Value $Value -Context 'Project A evidence' -Name 'azure_implemented'
        Assert-JsonStringField -Value $Value -Context 'Project A evidence' -Name 'execution_bundle_sha256' -Pattern $hex64
        Assert-JsonStringField -Value $Value -Context 'Project A evidence' -Name 'validator_implementation_sha256' -Pattern $hex64
        Assert-JsonStringField -Value $Value -Context 'Project A evidence' -Name 'policy_sha256' -Pattern $hex64
        Assert-JsonStringField -Value $Value -Context 'Project A evidence' -Name 'run_id'
        Assert-JsonStringField -Value $Value -Context 'Project A evidence' -Name 'task_id' -Pattern '^A-00[1-7]$'
        Assert-JsonStringField -Value $Value -Context 'Project A evidence' -Name 'phase_passed' -Pattern '^(terra|sol)$'
        Assert-JsonIntegerField -Value $Value -Context 'Project A evidence' -Name 'terra_attempts' -Minimum 0
        Assert-JsonIntegerField -Value $Value -Context 'Project A evidence' -Name 'sol_attempts' -Minimum 0
        Assert-JsonStringField -Value $Value -Context 'Project A evidence' -Name 'starting_commit' -Pattern $hex40
        Assert-JsonStringField -Value $Value -Context 'Project A evidence' -Name 'diff_sha256' -Pattern $hex64
        if ($null -eq $Value.changed_entries) { throw 'Project A evidence field ''changed_entries'' must be an array.' }
        Assert-JsonStringField -Value $Value -Context 'Project A evidence' -Name 'validation_digest'
        Assert-JsonBooleanField -Value $Value -Context 'Project A evidence' -Name 'approval_required'
        Assert-JsonOptionalStringField -Value $Value -Context 'Project A evidence' -Name 'approval_receipt_digest' -Pattern $hex64
        Assert-JsonIso8601TimestampField -Value $Value -Context 'Project A evidence' -Name 'completed_at'
        Assert-JsonStringField -Value $Value -Context 'Project A evidence' -Name 'commit_parent' -Pattern $hex40
        Assert-JsonStringField -Value $Value -Context 'Project A evidence' -Name 'commit_lookup'
        return
    }
    if ($normalized -like '*/RalphyHarness/cloud/approvals/project-a/requests/*.json') {
        Assert-JsonObjectContract -Value $Value -Context 'Project A approval request' -RequiredProperties @('schema_version','task_id','gate_id','execution_bundle_sha256','validator_implementation_sha256','policy_sha256','branch','starting_commit','head','diff_sha256','changed_entries','validation_digest','request_nonce','requested_at','run_id')
        Assert-JsonStringField -Value $Value -Context 'Project A approval request' -Name 'schema_version' -Pattern '^project-a-approval-request-v1$'
        Assert-JsonStringField -Value $Value -Context 'Project A approval request' -Name 'task_id' -Pattern '^A-00[1-7]$'
        Assert-JsonStringField -Value $Value -Context 'Project A approval request' -Name 'gate_id'
        Assert-JsonStringField -Value $Value -Context 'Project A approval request' -Name 'execution_bundle_sha256' -Pattern $hex64
        Assert-JsonStringField -Value $Value -Context 'Project A approval request' -Name 'validator_implementation_sha256' -Pattern $hex64
        Assert-JsonStringField -Value $Value -Context 'Project A approval request' -Name 'policy_sha256' -Pattern $hex64
        Assert-JsonStringField -Value $Value -Context 'Project A approval request' -Name 'branch'
        Assert-JsonStringField -Value $Value -Context 'Project A approval request' -Name 'starting_commit' -Pattern $hex40
        Assert-JsonStringField -Value $Value -Context 'Project A approval request' -Name 'head' -Pattern $hex40
        Assert-JsonStringField -Value $Value -Context 'Project A approval request' -Name 'diff_sha256' -Pattern $hex64
        if ($null -eq $Value.changed_entries) { throw 'Project A approval request field ''changed_entries'' must be an array.' }
        Assert-JsonStringField -Value $Value -Context 'Project A approval request' -Name 'validation_digest'
        Assert-JsonStringField -Value $Value -Context 'Project A approval request' -Name 'request_nonce' -Pattern '^[a-fA-F0-9]{32}$'
        Assert-JsonIso8601TimestampField -Value $Value -Context 'Project A approval request' -Name 'requested_at'
        Assert-JsonStringField -Value $Value -Context 'Project A approval request' -Name 'run_id'
        return
    }
    if ($normalized -like '*/RalphyHarness/cloud/approvals/project-a/receipts/*.json') {
        Assert-JsonObjectContract -Value $Value -Context 'Project A approval receipt' -RequiredProperties @('payload','signature')
        Assert-JsonObjectContract -Value $Value.payload -Context 'Project A approval receipt.payload' -RequiredProperties @('schema_version','decision','task_id','gate_id','execution_bundle_sha256','validator_implementation_sha256','policy_sha256','branch','starting_commit','head','diff_sha256','changed_entries','validation_digest','request_nonce','approved_at')
        Assert-JsonStringField -Value $Value.payload -Context 'Project A approval receipt.payload' -Name 'schema_version' -Pattern '^project-a-approval-v1$'
        Assert-JsonStringField -Value $Value.payload -Context 'Project A approval receipt.payload' -Name 'decision' -Pattern '^approved$'
        Assert-JsonStringField -Value $Value.payload -Context 'Project A approval receipt.payload' -Name 'task_id' -Pattern '^A-00[1-7]$'
        Assert-JsonStringField -Value $Value.payload -Context 'Project A approval receipt.payload' -Name 'gate_id'
        Assert-JsonStringField -Value $Value.payload -Context 'Project A approval receipt.payload' -Name 'execution_bundle_sha256' -Pattern $hex64
        Assert-JsonStringField -Value $Value.payload -Context 'Project A approval receipt.payload' -Name 'validator_implementation_sha256' -Pattern $hex64
        Assert-JsonStringField -Value $Value.payload -Context 'Project A approval receipt.payload' -Name 'policy_sha256' -Pattern $hex64
        Assert-JsonStringField -Value $Value.payload -Context 'Project A approval receipt.payload' -Name 'branch'
        Assert-JsonStringField -Value $Value.payload -Context 'Project A approval receipt.payload' -Name 'starting_commit' -Pattern $hex40
        Assert-JsonStringField -Value $Value.payload -Context 'Project A approval receipt.payload' -Name 'head' -Pattern $hex40
        Assert-JsonStringField -Value $Value.payload -Context 'Project A approval receipt.payload' -Name 'diff_sha256' -Pattern $hex64
        if ($null -eq $Value.payload.changed_entries) { throw 'Project A approval receipt.payload field ''changed_entries'' must be an array.' }
        Assert-JsonStringField -Value $Value.payload -Context 'Project A approval receipt.payload' -Name 'validation_digest'
        Assert-JsonStringField -Value $Value.payload -Context 'Project A approval receipt.payload' -Name 'request_nonce' -Pattern '^[a-fA-F0-9]{32}$'
        Assert-JsonIso8601TimestampField -Value $Value.payload -Context 'Project A approval receipt.payload' -Name 'approved_at'
        Assert-JsonStringField -Value $Value -Context 'Project A approval receipt' -Name 'signature' -AllowNull
    }
}

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "JSON file not found: $Path" }
    $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -DateKind String
    Assert-StrictJsonContractForPath -Path $Path -Value $value
    return $value
}

function Get-TaskIdFromArguments {
    param([Parameter(Mandatory)][string[]]$Arguments)
    foreach ($argument in $Arguments) {
        if ($argument -match '\[TASK:(?<id>[A-Z]+-\d{3})\]') { return $Matches.id }
    }
    throw 'No stable [TASK:X-000] marker was present in the Codex arguments.'
}

function Invoke-GitNullPathList {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string[]]$Arguments)
    $info = [System.Diagnostics.ProcessStartInfo]::new()
    $info.FileName = 'git'; $info.WorkingDirectory = $Root; $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    foreach ($argument in @('-c', 'core.quotepath=false') + $Arguments) { [void]$info.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new(); $process.StartInfo = $info
    try {
        [void]$process.Start()
        $bytes = [System.IO.MemoryStream]::new()
        $copy = $process.StandardOutput.BaseStream.CopyToAsync($bytes)
        $stderr = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit(); [void]$copy.GetAwaiter().GetResult(); $errorText = $stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) { throw "git $($Arguments -join ' ') failed: $errorText" }
        return @([System.Text.Encoding]::UTF8.GetString($bytes.ToArray()).Split([char]0, [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $_ -replace '\\', '/' })
    } finally { $process.Dispose() }
}

function Normalize-ExactExcludedPaths {
    param([string[]]$ExcludedPaths = @())
    $normalized = [System.Collections.Generic.List[string]]::new()
    foreach ($rawPath in @($ExcludedPaths)) {
        if ($null -eq $rawPath) { throw 'ExcludedPaths may contain only exact repository-relative file paths.' }
        $candidate = ([string]$rawPath).Trim()
        if ([string]::IsNullOrWhiteSpace($candidate)) { throw 'ExcludedPaths may contain only exact repository-relative file paths.' }
        $candidate = $candidate -replace '\\', '/'
        if ([System.IO.Path]::IsPathRooted($candidate) -or $candidate -match '^[A-Za-z]:' -or $candidate.StartsWith('/')) { throw "ExcludedPaths rejects absolute paths: $rawPath" }
        if ($candidate -in @('.', '..') -or $candidate -match '(^|/)\.\.?(/|$)') { throw "ExcludedPaths rejects traversal segments: $rawPath" }
        if ($candidate -match '[*?\[\]]') { throw "ExcludedPaths rejects wildcard paths: $rawPath" }
        if ($candidate.EndsWith('/')) { throw "ExcludedPaths rejects directory-prefix exclusions: $rawPath" }
        $normalized.Add($candidate)
    }
    return @($normalized | Sort-Object -Unique)
}

function Get-ReadableFileSha256 {
    param([Parameter(Mandatory)][string]$Path)
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($stream))
    } finally {
        $stream.Dispose()
    }
}

function Get-HarnessLifecycleExcludedPaths {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][ValidateSet('smoke', 'project-a')][string]$ProfileId,
        [switch]$IncludeStopFlag
    )
    $profile = Read-HarnessProfile -Root $Root -ProfileId $ProfileId
    $paths = [System.Collections.Generic.List[string]]::new()
    $paths.Add('.harness/runtime/harness.lock')
    if ($IncludeStopFlag) { $paths.Add('.harness/runtime/stop.flag') }
    if ($ProfileId -eq 'smoke') {
        $paths.Add('.harness/runtime/PRD.json')
        foreach ($taskId in @($profile.task_ids | ForEach-Object { [string]$_ })) {
            $paths.Add(".harness/runtime/state/$taskId.json")
            $paths.Add(".harness/runtime/takeovers/$taskId.md")
        }
    } else {
        $paths.Add('.harness/runtime/project-a/PRD.json')
        foreach ($taskId in @($profile.task_ids | ForEach-Object { [string]$_ })) {
            $paths.Add(".harness/runtime/project-a/state/$taskId.json")
            $paths.Add(".harness/runtime/project-a/locks/$taskId.lock")
            $paths.Add(".harness/runtime/project-a/takeovers/$taskId.md")
        }
    }
    return @(Normalize-ExactExcludedPaths -ExcludedPaths $paths.ToArray())
}

function Get-ChangedPaths {
    param([Parameter(Mandatory)][string]$Root, [string[]]$ExcludedPaths = @())
    $paths = [System.Collections.Generic.List[string]]::new()
    $excluded = @(Normalize-ExactExcludedPaths -ExcludedPaths $ExcludedPaths)
    foreach ($command in @(
        @('diff', '--name-only', '-z', '--relative', 'HEAD'),
        @('diff', '--cached', '--name-only', '-z', '--relative', 'HEAD'),
        @('ls-files', '--others', '--exclude-standard', '-z'),
        @('ls-files', '--others', '--ignored', '--exclude-standard', '-z')
    )) {
        foreach ($path in @(Invoke-GitNullPathList -Root $Root -Arguments $command)) { $paths.Add($path) }
    }
    # Preserve legacy log/message exclusions, but runtime paths must be exact and explicit.
    return @($paths | Where-Object {
        $_ -notmatch '^(\.logs/|\.codex-last-message-|last message\.txt$)' -and
        $_ -notin $excluded
    } | Sort-Object -Unique)
}

function Invoke-ProcessWithTimeout {
    param(
        [Parameter(Mandatory)][System.Diagnostics.Process]$Process,
        [Parameter(Mandatory)][int]$TimeoutSeconds
    )
    if ($TimeoutSeconds -lt 1) { throw 'Process timeout must be at least one second.' }
    $stdoutTask = $Process.StandardOutput.ReadToEndAsync()
    $stderrTask = $Process.StandardError.ReadToEndAsync()
    $timedOut = -not $Process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        # Kill the launcher and every child before accepting a timeout result.
        $Process.Kill($true)
        $Process.WaitForExit()
    }
    return [pscustomobject]@{
        timed_out = $timedOut
        exit_code = if ($timedOut) { 124 } else { $Process.ExitCode }
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
    }
}

function Get-PositiveTimeoutSeconds {
    param([Parameter(Mandatory)]$Policy, [Parameter(Mandatory)][string]$Name, [int]$DefaultSeconds)
    if ($Policy.PSObject.Properties.Name -contains $Name -and [int]$Policy.$Name -gt 0) { return [int]$Policy.$Name }
    return $DefaultSeconds
}

function Write-HarnessStopSentinel {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$ErrorClass, [Parameter(Mandatory)][string]$Message)
    Write-JsonNoBom -Path (Join-Path $Root '.harness/runtime/stop.flag') -Value ([ordered]@{ error_class = $ErrorClass; message = $Message; stopped_at = [DateTimeOffset]::UtcNow.ToString('o') })
}

function Test-AllowedPath {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string[]]$AllowedPaths)
    $normalized = $Path -replace '\\', '/'
    foreach ($allowed in $AllowedPaths) {
        $candidate = $allowed -replace '\\', '/'
        if ($candidate.EndsWith('/**')) {
            $prefix = $candidate.Substring(0, $candidate.Length - 3).TrimEnd('/')
            if ($normalized -eq $prefix -or $normalized.StartsWith("$prefix/", [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        } elseif ($normalized.Equals($candidate, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Assert-OnlyAllowedChanges {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string[]]$AllowedPaths, [string[]]$ExcludedPaths = @())
    $changed = @(Get-ChangedPaths -Root $Root -ExcludedPaths $ExcludedPaths)
    $outside = @($changed | Where-Object { -not (Test-AllowedPath -Path $_ -AllowedPaths $AllowedPaths) })
    if ($outside.Count -gt 0) { throw "Changed paths outside task scope: $($outside -join ', ')" }
    return $changed
}

function Get-DiffFingerprint {
    param([Parameter(Mandatory)][string]$Root, [string[]]$ExcludedPaths = @())
    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.AppendLine((& git -C $Root diff --binary HEAD | Out-String))
    foreach ($path in @(Get-ChangedPaths -Root $Root -ExcludedPaths $ExcludedPaths)) {
        $fullPath = Join-Path $Root $path
        [void]$builder.AppendLine("PATH:$path")
        if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
            [void]$builder.AppendLine((Get-ReadableFileSha256 -Path $fullPath))
        }
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($builder.ToString())
    return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes))
}

function Protect-LogText {
    param([AllowEmptyString()][string]$Text)
    if ($null -eq $Text) { return '' }
    $safe = $Text -replace '(?i)Bearer\s+[A-Za-z0-9._~+/-]+=*', 'Bearer [REDACTED]'
    $safe = $safe -replace '(?i)(api[_-]?key|authorization|cookie|password|secret|token)(["''\s:=]+)([^,\s"''}]+)', '$1$2[REDACTED]'
    $safe = $safe -replace '(?i)\b(AKIA|ASIA)[A-Z0-9]{16}\b', '[REDACTED_AWS_ACCESS_KEY]'
    $safe = $safe -replace '(?i)\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b', '[REDACTED_JWT]'
    $safe = $safe -replace '(?i)(https?://)([^/@:\s]+):([^/@\s]+)@', '$1[REDACTED]@'
    $safe = $safe -replace '(?i)Set-Cookie:\s*[^\r\n]+', 'Set-Cookie: [REDACTED]'
    $safe = $safe -replace '-----BEGIN [A-Z ]*PRIVATE KEY-----', '[REDACTED_PRIVATE_KEY]'
    return $safe
}

function Get-ThreadIdFromJsonLines {
    param([AllowEmptyString()][string]$Text)
    foreach ($line in ($Text -split "`r?`n")) {
        if (-not $line.TrimStart().StartsWith('{')) { continue }
        try {
            $event = $line | ConvertFrom-Json
            if ($event.type -eq 'thread.started' -and $event.thread_id) { return [string]$event.thread_id }
        } catch { }
    }
    return $null
}

function Get-OutputLastMessagePath {
    param([Parameter(Mandatory)][string[]]$Arguments)
    for ($index = 0; $index -lt $Arguments.Count - 1; $index++) {
        if ($Arguments[$index] -in @('--output-last-message', '-o')) { return $Arguments[$index + 1] }
    }
    return $null
}

function New-SafeInitialCodexArguments {
    param([Parameter(Mandatory)][string[]]$Arguments, [Parameter(Mandatory)][string]$Model)
    $clean = [System.Collections.Generic.List[string]]::new()
    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        $argument = $Arguments[$index]
        if ($argument -in @('--full-auto', '--dangerously-bypass-approvals-and-sandbox', '--dangerously-bypass-hook-trust')) { continue }
        if ($argument -match '^(--full-auto|--dangerously-bypass-approvals-and-sandbox|--dangerously-bypass-hook-trust)=') { continue }
        if ($argument -in @('--model', '-m', '--sandbox', '-s')) {
            if ($index + 1 -ge $Arguments.Count) { throw "Codex option is missing its value: $argument" }
            $index++
            continue
        }
        if ($argument -match '^(--model|--sandbox)=') { continue }
        if ($argument -match '^-(m|s)=?.+') { continue }
        if ($argument -in @('--add-dir', '-C', '--cd', '-c', '--config', '-p', '--profile')) {
            throw "Ralphy supplied a disallowed Codex authority option: $argument"
        }
        if ($argument -match '^(--add-dir|--cd|--config|--profile)=' -or $argument -match '^-(C|c|p)=?.+') {
            throw "Ralphy supplied a disallowed Codex authority option: $argument"
        }
        $clean.Add($argument)
    }
    if ($clean.Count -eq 0 -or $clean[0] -ne 'exec') { throw 'Ralphy did not invoke the expected codex exec contract.' }
    $result = [System.Collections.Generic.List[string]]::new()
    $result.Add('exec')
    $result.Add('--sandbox')
    $result.Add('workspace-write')
    $result.Add('--model')
    $result.Add($Model)
    for ($index = 1; $index -lt $clean.Count; $index++) { $result.Add($clean[$index]) }
    return $result.ToArray()
}

function New-SafeResumeCodexArguments {
    param(
        [Parameter(Mandatory)][string]$Model,
        [Parameter(Mandatory)][string]$ThreadId,
        [Parameter(Mandatory)][string]$Prompt,
        [AllowNull()][string]$OutputLastMessage
    )
    $result = [System.Collections.Generic.List[string]]::new()
    foreach ($argument in @('exec', 'resume', '-c', 'sandbox_mode="workspace-write"', '--model', $Model, '--json')) { $result.Add($argument) }
    if ($OutputLastMessage) { foreach ($argument in @('--output-last-message', $OutputLastMessage)) { $result.Add($argument) } }
    foreach ($argument in @($ThreadId, $Prompt)) { $result.Add($argument) }
    return $result.ToArray()
}

function Open-ExclusiveLock {
    param([Parameter(Mandatory)][string]$Path)
    $parent = Split-Path -Parent $Path
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    try {
        return [System.IO.File]::Open($Path, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Read)
    } catch {
        throw "Another harness instance owns the lock: $Path"
    }
}

function Test-TerraEscalation {
    param(
        [bool]$ForceApplied,
        [int]$Attempts,
        [int]$AttemptLimit,
        [int]$ConsecutiveFailures,
        [int]$ConsecutiveFailureLimit = 2,
        [int]$SameErrorCount,
        [int]$SameErrorLimit = 2,
        [bool]$NoDiff,
        [bool]$EscalateOnNoDiff = $true,
        [double]$ElapsedMinutes,
        [int]$ElapsedLimitMinutes,
        [bool]$EscalateOnScopeEscape = $true,
        [AllowNull()][string]$ErrorClass
    )
    return $ForceApplied -or
        $Attempts -ge $AttemptLimit -or
        $ConsecutiveFailures -ge $ConsecutiveFailureLimit -or
        $SameErrorCount -ge $SameErrorLimit -or
        ($EscalateOnNoDiff -and $NoDiff) -or
        $ElapsedMinutes -ge $ElapsedLimitMinutes -or
        ($EscalateOnScopeEscape -and $ErrorClass -eq 'SCOPE_ESCAPE')
}

function Sync-RalphyManifestWithTaskState {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$ManifestPath)
    $manifest = Read-JsonFile -Path $ManifestPath
    $currentBranch = (& git -C $Root branch --show-current 2>$null | Out-String).Trim()
    $currentHead = (& git -C $Root rev-parse HEAD 2>$null | Out-String).Trim()
    $approvedPlanHash = $null
    $approvalPath = Join-Path $Root 'harness/plan-approval.json'
    $planPath = Join-Path $Root 'PLAN.md'
    if ((Test-Path -LiteralPath $approvalPath -PathType Leaf) -and (Test-Path -LiteralPath $planPath -PathType Leaf)) {
        $approval = Read-JsonFile -Path $approvalPath
        $actualPlanHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $planPath).Hash
        if ([string]$approval.plan_sha256 -eq $actualPlanHash) { $approvedPlanHash = [string]$approval.plan_sha256 }
    }
    foreach ($task in $manifest.tasks) {
        $id = Get-TaskIdFromArguments -Arguments @([string]$task.title)
        # Project A has a stronger completion contract and is synchronized by
        # Sync-ProjectAManifestWithTaskState below.
        $statePath = Join-Path $Root ".harness/runtime/state/$id.json"
        $completed = $false
        if (Test-Path -LiteralPath $statePath) {
            $state = Read-JsonFile -Path $statePath
            if ($state.status -eq 'completed') {
                $completed = $true
                if ($state.PSObject.Properties.Name -contains 'task_id' -and [string]$state.task_id -ne $id) { $completed = $false }
                if ($completed -and $state.PSObject.Properties.Name -contains 'branch' -and $currentBranch -and [string]$state.branch -ne $currentBranch) { $completed = $false }
                if ($completed -and $approvedPlanHash -and $state.PSObject.Properties.Name -contains 'plan_hash' -and [string]$state.plan_hash -ne $approvedPlanHash) { $completed = $false }
                $policyPath = Join-Path $Root "harness/tasks/$id.json"
                if ($completed -and (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
                    $policy = Read-JsonFile -Path $policyPath
                    $commitSha = [string]$state.commit_sha
                    if ([string]::IsNullOrWhiteSpace($commitSha)) { $completed = $false }
                    if ($completed -and $currentHead) {
                        & git -C $Root merge-base --is-ancestor $commitSha $currentHead 2>$null | Out-Null
                        if ($LASTEXITCODE -ne 0) { $completed = $false }
                    }
                    if ($completed) {
                        $subject = (& git -C $Root log -1 --format=%s $commitSha 2>$null | Out-String).Trim()
                        if ($subject -ne [string]$policy.commit_message) { $completed = $false }
                    }
                    if ($completed) {
                        $evidencePath = Join-Path $Root ([string]$policy.expected_evidence)
                        if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) { $completed = $false }
                    }
                }
            }
        }
        $task.completed = $completed
    }
    Write-JsonNoBom -Path $ManifestPath -Value $manifest
    return $manifest
}

function Test-ProjectACompletedTaskState {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)]$TaskState,
        [Parameter(Mandatory)][string]$TaskId,
        [Parameter(Mandatory)][string]$CurrentHead,
        [Parameter(Mandatory)][string]$Branch,
        [Parameter(Mandatory)][string]$BundleHash,
        [Parameter(Mandatory)][string]$ValidatorHash,
        [AllowNull()][string]$CommitSha,
        [switch]$AllowCommitting
    )
    $commit = if ($CommitSha) { $CommitSha } else { [string]$TaskState.commit_sha }
    if ([string]$TaskState.task_id -ne $TaskId -or [string]$TaskState.profile_id -ne 'project-a') { return $false }
    if ([string]$TaskState.bundle_hash -ne $BundleHash -or [string]$TaskState.validator_sha256 -ne $ValidatorHash -or [string]$TaskState.branch -ne $Branch) { return $false }
    if ($AllowCommitting) { if ([string]$TaskState.status -notin @('committing','completed')) { return $false } } elseif ([string]$TaskState.status -ne 'completed') { return $false }
    $policyPath = Join-Path $Root "project-a/harness/tasks/$TaskId.json"
    if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) { return $false }
    $policy = Read-JsonFile -Path $policyPath
    if ([string]$TaskState.policy_sha256 -ne (Get-FileHash -Algorithm SHA256 -LiteralPath $policyPath).Hash -or [string]::IsNullOrWhiteSpace($commit)) { return $false }
    & git -C $Root merge-base --is-ancestor $commit $CurrentHead 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    $parent = (& git -C $Root rev-parse "$commit^" 2>$null | Out-String).Trim()
    $subject = (& git -C $Root log -1 --format=%s $commit 2>$null | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($parent) -or $subject -ne [string]$policy.commit_message) { return $false }
    $matchesRecordedParent = $parent -eq [string]$TaskState.starting_commit
    if (-not $matchesRecordedParent) {
        $allowHistoricalAncestor = $TaskState.PSObject.Properties.Name -contains 'historical_reconstruction' -and [bool]$TaskState.historical_reconstruction
        if (-not $allowHistoricalAncestor) { return $false }
        & git -C $Root merge-base --is-ancestor ([string]$TaskState.starting_commit) $commit 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { return $false }
    }
    $evidencePath = Join-Path $Root ([string]$policy.expected_evidence)
    if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf) -or [string]::IsNullOrWhiteSpace([string]$TaskState.evidence_sha256)) { return $false }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $evidencePath).Hash -ne [string]$TaskState.evidence_sha256) { return $false }
    try { $evidence = Read-JsonFile -Path $evidencePath } catch { return $false }
    if ([string]$evidence.task_id -ne $TaskId -or [string]$evidence.commit_parent -ne [string]$TaskState.starting_commit) { return $false }
    if ([bool]$evidence.approval_required -ne [bool]$policy.approval.required) { return $false }
    $stateDigest = [string]$TaskState.approval_receipt_digest
    $evidenceDigest = [string]$evidence.approval_receipt_digest
    if ([bool]$policy.approval.required) {
        if ([string]::IsNullOrWhiteSpace($stateDigest) -or $stateDigest -ne $evidenceDigest) { return $false }
    } elseif (-not [string]::IsNullOrWhiteSpace($stateDigest) -or -not [string]::IsNullOrWhiteSpace($evidenceDigest)) { return $false }
    return $true
}

function Get-ReconstructedProjectACompletedState {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$TaskId,
        [Parameter(Mandatory)][string]$Branch,
        [Parameter(Mandatory)][string]$BundleHash,
        [Parameter(Mandatory)][string]$ValidatorHash
    )
    $policyPath = Join-Path $Root "project-a/harness/tasks/$TaskId.json"
    if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) { return $null }
    $policy = Read-JsonFile -Path $policyPath
    $evidenceRelativePath = [string]$policy.expected_evidence
    if ([string]::IsNullOrWhiteSpace($evidenceRelativePath)) { return $null }
    $evidencePath = Join-Path $Root $evidenceRelativePath
    if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) { return $null }
    try {
        $evidence = Read-JsonFile -Path $evidencePath
    } catch {
        return $null
    }
    if ([string]$evidence.task_id -ne $TaskId) { return $null }
    $completedAt = switch ($evidence.completed_at) {
        { $_ -is [datetimeoffset] } { $_.ToString('o'); break }
        { $_ -is [datetime] } { $_.ToString('o'); break }
        default { [string]$_; break }
    }
    $commit = $null
    $evidenceIndexPath = Join-Path $Root 'project-a/evidence-index.md'
    if (Test-Path -LiteralPath $evidenceIndexPath -PathType Leaf) {
        $taskPattern = '^\|\s*' + [regex]::Escape($TaskId) + '\s*\|\s*`([0-9a-fA-F]{7,40})`'
        foreach ($line in Get-Content -LiteralPath $evidenceIndexPath) {
            $match = [regex]::Match([string]$line, $taskPattern)
            if ($match.Success) {
                $candidate = (& git -C $Root rev-parse $match.Groups[1].Value 2>$null | Out-String).Trim()
                if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                    $commit = $candidate
                    break
                }
            }
        }
    }
    if ([string]::IsNullOrWhiteSpace([string]$commit)) {
        $commit = (& git -C $Root log -1 --format=%H -- $evidenceRelativePath 2>$null | Out-String).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($commit)) { return $null }
    $tree = (& git -C $Root rev-parse "$commit^{tree}" 2>$null | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($tree)) { return $null }
    $changedPaths = @()
    if ($null -ne $evidence.changed_entries) {
        $changedPaths = @($evidence.changed_entries | ForEach-Object { [string]$_.path } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    return [pscustomobject]@{
        profile_id = 'project-a'
        bundle_hash = $BundleHash
        validator_sha256 = $ValidatorHash
        policy_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $policyPath).Hash
        task_id = $TaskId
        branch = $Branch
        starting_commit = [string]$evidence.commit_parent
        started_at = $completedAt
        status = 'completed'
        phase = [string]$evidence.phase_passed
        terra_attempts = [int]$evidence.terra_attempts
        sol_attempts = [int]$evidence.sol_attempts
        consecutive_failures = 0
        same_error_count = 0
        last_error_class = $null
        last_failure = $null
        terra_thread_id = $null
        sol_thread_id = $null
        validation_digest = [string]$evidence.validation_digest
        diff_sha256 = [string]$evidence.diff_sha256
        approval_request = $null
        approval_receipt = $null
        approval_key = $null
        approval_receipt_digest = [string]$evidence.approval_receipt_digest
        intended_tree = $tree
        stage_paths = @($changedPaths + @($evidenceRelativePath) | Sort-Object -Unique)
        pending_evidence_path = $null
        pending_evidence_text = $null
        evidence_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $evidencePath).Hash
        commit_sha = $commit
        completed_at = $completedAt
        historical_reconstruction = $true
    }
}

function Sync-ProjectAManifestWithTaskState {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$ManifestPath, [Parameter(Mandatory)][string]$Branch, [Parameter(Mandatory)][string]$BundleHash, [Parameter(Mandatory)][string]$ValidatorHash)
    $manifest = Read-JsonFile -Path $ManifestPath
    $head = (& git -C $Root rev-parse HEAD 2>$null | Out-String).Trim()
    foreach ($task in $manifest.tasks) {
        $id = Get-TaskIdFromArguments -Arguments @([string]$task.title)
        $statePath = Join-Path $Root ".harness/runtime/project-a/state/$id.json"
        $task.completed = $false
        if (Test-Path -LiteralPath $statePath -PathType Leaf) {
            $task.completed = Test-ProjectACompletedTaskState -Root $Root -TaskState (Read-JsonFile -Path $statePath) -TaskId $id -CurrentHead $head -Branch $Branch -BundleHash $BundleHash -ValidatorHash $ValidatorHash
        }
        if (-not $task.completed) {
            $reconstructedState = Get-ReconstructedProjectACompletedState -Root $Root -TaskId $id -Branch $Branch -BundleHash $BundleHash -ValidatorHash $ValidatorHash
            if ($null -ne $reconstructedState) {
                $task.completed = Test-ProjectACompletedTaskState -Root $Root -TaskState $reconstructedState -TaskId $id -CurrentHead $head -Branch $Branch -BundleHash $BundleHash -ValidatorHash $ValidatorHash
                if ($task.completed) {
                    Write-JsonNoBom -Path $statePath -Value $reconstructedState
                }
            }
        }
    }
    Write-JsonNoBom -Path $ManifestPath -Value $manifest
    return $manifest
}

function Get-LingeringHarnessProcesses {
    param(
        [int]$CurrentProcessId = $PID,
        [AllowNull()][object[]]$Processes = $null
    )
    $results = [System.Collections.Generic.List[object]]::new()
    $allProcesses = if ($null -ne $Processes) { @($Processes) } else { @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue) }
    $parentMap = @{}
    foreach ($process in $allProcesses) {
        if (-not $process) { continue }
        $parentMap[[int]$process.ProcessId] = if ($null -ne $process.ParentProcessId) { [int]$process.ParentProcessId } else { 0 }
    }
    function Test-DescendsFromCurrentProcess([int]$ProcessId) {
        $visited = [System.Collections.Generic.HashSet[int]]::new()
        $cursor = $ProcessId
        while ($parentMap.ContainsKey($cursor) -and $visited.Add($cursor)) {
            $cursor = [int]$parentMap[$cursor]
            if ($cursor -eq $CurrentProcessId) { return $true }
            if ($cursor -le 0) { break }
        }
        return $false
    }
    foreach ($process in $allProcesses) {
        if (-not $process -or $process.ProcessId -eq $CurrentProcessId) { continue }
        $name = [string]$process.Name
        $commandLine = [string]$process.CommandLine
        $descendsFromCurrent = Test-DescendsFromCurrentProcess -ProcessId ([int]$process.ProcessId)
        $matchesHarnessProcess = $descendsFromCurrent -and ($name -match '^(ralphy|codex|pwsh|powershell)(?:\.cmd|\.exe)?$')
        $matchesHarnessPwsh = $descendsFromCurrent -and $name -match '^(pwsh|powershell)(?:\.exe)?$' -and $commandLine -match '(Start-Harness|Start-ProjectAHarness|Invoke-ProjectAAdapter|Invoke-ProjectAValidators)\.ps1'
        if ($matchesHarnessProcess -or $matchesHarnessPwsh) {
            $results.Add([pscustomobject]@{
                process_id = [int]$process.ProcessId
                name = $name
                command_line = $commandLine
            })
        }
    }
    return @($results)
}

function Resolve-PathUnderRoot {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$RelativePath)
    if ([System.IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '(^|[\\/])\.\.([\\/]|$)' -or $RelativePath -match ':') { throw "Unsafe repository-relative path: $RelativePath" }
    $resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd([char]'\', [char]'/')
    $resolved = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot $RelativePath))
    if (-not $resolved.StartsWith("$resolvedRoot$([System.IO.Path]::DirectorySeparatorChar)", [System.StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes repository root: $RelativePath" }
    return $resolved
}

function Read-HarnessProfile {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][ValidateSet('smoke', 'project-a')][string]$ProfileId)
    $path = Resolve-PathUnderRoot -Root $Root -RelativePath "harness/profiles/$ProfileId.json"
    $profile = Read-JsonFile -Path $path
    if ([string]$profile.profile_id -ne $ProfileId) { throw "Profile ID mismatch: $ProfileId" }
    foreach ($field in @('manifest_template', 'policy_root', 'approval_file', 'tool_versions_file')) { [void](Resolve-PathUnderRoot -Root $Root -RelativePath ([string]$profile.$field)) }
    if ($profile.PSObject.Properties.Name -contains 'execution_approval_file') { [void](Resolve-PathUnderRoot -Root $Root -RelativePath ([string]$profile.execution_approval_file)) }
    return $profile
}

function Get-RepoOnlyCodexConfigArguments {
    return @(
        '--ignore-user-config', '--ignore-rules',
        '-c', 'approval_policy="never"',
        '-c', 'windows.sandbox="elevated"',
        '-c', 'sandbox_workspace_write.network_access=false',
        '-c', 'web_search="disabled"',
        '-c', 'features.apps=false',
        '-c', 'features.network_proxy=false',
        '-c', 'allow_login_shell=false',
        '-c', 'shell_environment_policy.inherit="core"',
        '-c', 'shell_environment_policy.ignore_default_excludes=false',
        '-c', "shell_environment_policy.exclude=['AWS_*','AZURE_*','ARM_*','TF_VAR_*','TF_CLI_ARGS*','GOOGLE_*','GH_*','GITHUB_*','CODEX_HOME','OPENAI_*','ANTHROPIC_*','*TOKEN*','*SECRET*','*KEY*','*PASSWORD*','HTTP_PROXY','HTTPS_PROXY','ALL_PROXY']"
    )
}

function New-RepoOnlyInitialCodexArguments {
    param([Parameter(Mandatory)][string[]]$Arguments, [Parameter(Mandatory)][string]$Model)
    $safe = @(New-SafeInitialCodexArguments -Arguments $Arguments -Model $Model)
    return @('exec') + @(Get-RepoOnlyCodexConfigArguments) + @($safe[1..($safe.Count - 1)])
}

function New-RepoOnlyResumeCodexArguments {
    param([Parameter(Mandatory)][string]$Model, [Parameter(Mandatory)][string]$ThreadId, [Parameter(Mandatory)][string]$Prompt, [AllowNull()][string]$OutputLastMessage)
    $result = @('exec', 'resume') + @(Get-RepoOnlyCodexConfigArguments) + @('-c', 'sandbox_mode="workspace-write"', '--model', $Model, '--json')
    if ($OutputLastMessage) { $result += @('--output-last-message', $OutputLastMessage) }
    return @($result) + @($ThreadId, $Prompt)
}

function Set-RepoOnlyProcessEnvironment {
    param([Parameter(Mandatory)][System.Diagnostics.ProcessStartInfo]$StartInfo, [Parameter(Mandatory)][string]$IsolationRoot)
    [System.IO.Directory]::CreateDirectory($IsolationRoot) | Out-Null
    $patterns = @('AWS_*','AZURE_*','ARM_*','TF_VAR_*','TF_CLI_ARGS*','GOOGLE_*','GH_*','GITHUB_*','OPENAI_API_KEY','ANTHROPIC_API_KEY','*PASSWORD*','*SECRET*','*TOKEN*','HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')
    foreach ($name in @($StartInfo.Environment.Keys)) {
        if (@($patterns | Where-Object { $name -like $_ }).Count -gt 0) { [void]$StartInfo.Environment.Remove($name) }
    }
    $emptyAwsConfig = Join-Path $IsolationRoot 'aws-config'
    $emptyAwsCredentials = Join-Path $IsolationRoot 'aws-credentials'
    Write-Utf8NoBom -Path $emptyAwsConfig -Text ''
    Write-Utf8NoBom -Path $emptyAwsCredentials -Text ''
    $azureConfig = Join-Path $IsolationRoot 'azure'
    [System.IO.Directory]::CreateDirectory($azureConfig) | Out-Null
    $profile = Join-Path $IsolationRoot 'profile'
    $localAppData = Join-Path $profile 'AppData/Local'
    [System.IO.Directory]::CreateDirectory($localAppData) | Out-Null
    $StartInfo.Environment['USERPROFILE'] = $profile
    $StartInfo.Environment['HOME'] = $profile
    $StartInfo.Environment['LOCALAPPDATA'] = $localAppData
    $StartInfo.Environment['APPDATA'] = Join-Path $profile 'AppData/Roaming'
    $StartInfo.Environment['AWS_CONFIG_FILE'] = $emptyAwsConfig
    $StartInfo.Environment['AWS_SHARED_CREDENTIALS_FILE'] = $emptyAwsCredentials
    $StartInfo.Environment['AWS_EC2_METADATA_DISABLED'] = 'true'
    $StartInfo.Environment['AZURE_CONFIG_DIR'] = $azureConfig
    $StartInfo.Environment['TF_DATA_DIR'] = Join-Path $IsolationRoot 'terraform-data'
}

function Get-CanonicalDiffRecord {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string[]]$AllowedPaths, [string[]]$AdapterOwnedPaths = @(), [string[]]$AllowedExecutablePaths = @(), [string[]]$ExcludedPaths = @())
    $paths = @(Assert-OnlyAllowedChanges -Root $Root -AllowedPaths $AllowedPaths -ExcludedPaths $ExcludedPaths)
    $adapterChanges = @()
    if (@($AdapterOwnedPaths).Count -gt 0) { $adapterChanges = @($paths | Where-Object { Test-AllowedPath -Path $_ -AllowedPaths $AdapterOwnedPaths }) }
    if (@($adapterChanges).Count -gt 0) { throw "Agent changed adapter-owned path: $($adapterChanges -join ', ')" }
    $caseGroups = @($paths | Group-Object { $_.ToLowerInvariant() } | Where-Object Count -gt 1)
    if (@($caseGroups).Count -gt 0) { throw 'Case-colliding paths are not allowed.' }
    $entries = foreach ($relative in $paths) {
        if ($relative -match '(^|/)(\.git|\.harness)(/|$)' -or $relative -match ':' -or $relative -match '(^|/)\.\.(/|$)') { throw "Unsafe changed path: $relative" }
        $full = Resolve-PathUnderRoot -Root $Root -RelativePath $relative
        $raw=@(& git -C $Root diff --raw --no-abbrev HEAD -- $relative)
        if (-not $raw.Count) { $raw = @(& git -C $Root diff --cached --raw --no-abbrev HEAD -- $relative) }
        $rawLine=if($raw.Count){[string]$raw[-1]}else{''}
        $oldMode='000000';$newMode=if(Test-Path -LiteralPath $full){'100644'}else{'000000'};$gitStatus=if(Test-Path -LiteralPath $full){'untracked'}else{'deleted'}
        if($rawLine -match '^:(?<old>[0-9]{6})\s+(?<new>[0-9]{6})\s+[0-9a-f]+\s+[0-9a-f]+\s+(?<status>[A-Z])'){$oldMode=$Matches.old;$newMode=$Matches.new;$gitStatus=$Matches.status}
        if($newMode -in @('120000','160000') -or $oldMode -in @('120000','160000')){throw "Symlink/submodule modes are not allowed: $relative"}
        if (($oldMode -match '^1007' -or $newMode -match '^1007') -and (@($AllowedExecutablePaths).Count -eq 0 -or -not (Test-AllowedPath -Path $relative -AllowedPaths $AllowedExecutablePaths))) { throw "UNAPPROVED_EXECUTABLE_BIT: $relative" }
        if (Test-Path -LiteralPath $full) {
            $item = Get-Item -LiteralPath $full -Force
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { throw "Reparse points are not allowed: $relative" }
            if ($item.PSIsContainer) { throw "Changed directories are not valid task artifacts: $relative" }
            [ordered]@{ path = $relative; status = 'present'; git_status=$gitStatus; old_mode=$oldMode; new_mode=$newMode; length = $item.Length; content_sha256 = (Get-ReadableFileSha256 -Path $full) }
        } else { [ordered]@{ path = $relative; status = 'deleted'; git_status=$gitStatus; old_mode=$oldMode; new_mode=$newMode; length = 0; content_sha256 = 'DELETED' } }
    }
    $json = @($entries) | ConvertTo-Json -Compress -Depth 5
    $digest = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($json)))
    return [pscustomobject]@{ sha256 = $digest; entries = @($entries); json = $json }
}

function Get-HmacSha256 {
    param([Parameter(Mandatory)][byte[]]$Key, [Parameter(Mandatory)][string]$Text)
    $hmac = [System.Security.Cryptography.HMACSHA256]::new($Key)
    try { return [Convert]::ToHexString($hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))) } finally { $hmac.Dispose() }
}

Export-ModuleMember -Function *
