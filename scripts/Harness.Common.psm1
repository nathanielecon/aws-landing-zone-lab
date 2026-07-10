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

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "JSON file not found: $Path" }
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Get-TaskIdFromArguments {
    param([Parameter(Mandatory)][string[]]$Arguments)
    foreach ($argument in $Arguments) {
        if ($argument -match '\[TASK:(?<id>[A-Z]+-\d{3})\]') { return $Matches.id }
    }
    throw 'No stable [TASK:X-000] marker was present in the Codex arguments.'
}

function Get-ChangedPaths {
    param([Parameter(Mandatory)][string]$Root)
    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($command in @(
        @('diff', '--name-only', '--relative', 'HEAD'),
        @('diff', '--cached', '--name-only', '--relative', 'HEAD'),
        @('ls-files', '--others', '--exclude-standard')
    )) {
        $output = & git -C $Root -c core.quotepath=false @command
        if ($LASTEXITCODE -ne 0) { throw "git $($command -join ' ') failed" }
        foreach ($path in $output) {
            if ($path) { $paths.Add(($path -replace '\\', '/')) }
        }
    }
    return @($paths | Sort-Object -Unique)
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
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string[]]$AllowedPaths)
    $changed = @(Get-ChangedPaths -Root $Root)
    $outside = @($changed | Where-Object { -not (Test-AllowedPath -Path $_ -AllowedPaths $AllowedPaths) })
    if ($outside.Count -gt 0) { throw "Changed paths outside task scope: $($outside -join ', ')" }
    return $changed
}

function Get-DiffFingerprint {
    param([Parameter(Mandatory)][string]$Root)
    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.AppendLine((& git -C $Root diff --binary HEAD | Out-String))
    foreach ($path in (& git -C $Root -c core.quotepath=false ls-files --others --exclude-standard | Sort-Object)) {
        $fullPath = Join-Path $Root $path
        [void]$builder.AppendLine("UNTRACKED:$path")
        if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
            [void]$builder.AppendLine((Get-FileHash -Algorithm SHA256 -LiteralPath $fullPath).Hash)
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
        return [System.IO.File]::Open($Path, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
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
        [int]$SameErrorCount,
        [bool]$NoDiff,
        [double]$ElapsedMinutes,
        [int]$ElapsedLimitMinutes,
        [AllowNull()][string]$ErrorClass
    )
    return $ForceApplied -or
        $Attempts -ge $AttemptLimit -or
        $ConsecutiveFailures -ge 2 -or
        $SameErrorCount -ge 2 -or
        $NoDiff -or
        $ElapsedMinutes -ge $ElapsedLimitMinutes -or
        $ErrorClass -eq 'SCOPE_ESCAPE'
}

function Sync-RalphyManifestWithTaskState {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$ManifestPath)
    $manifest = Read-JsonFile -Path $ManifestPath
    foreach ($task in $manifest.tasks) {
        $id = Get-TaskIdFromArguments -Arguments @([string]$task.title)
        $statePath = Join-Path $Root ".harness/runtime/state/$id.json"
        $completed = $false
        if (Test-Path -LiteralPath $statePath) {
            $state = Read-JsonFile -Path $statePath
            $completed = $state.status -eq 'completed'
        }
        $task.completed = $completed
    }
    Write-JsonNoBom -Path $ManifestPath -Value $manifest
    return $manifest
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
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string[]]$AllowedPaths, [string[]]$AdapterOwnedPaths = @())
    $paths = @(Assert-OnlyAllowedChanges -Root $Root -AllowedPaths $AllowedPaths)
    $adapterChanges = @()
    if (@($AdapterOwnedPaths).Count -gt 0) { $adapterChanges = @($paths | Where-Object { Test-AllowedPath -Path $_ -AllowedPaths $AdapterOwnedPaths }) }
    if (@($adapterChanges).Count -gt 0) { throw "Agent changed adapter-owned path: $($adapterChanges -join ', ')" }
    $caseGroups = @($paths | Group-Object { $_.ToLowerInvariant() } | Where-Object Count -gt 1)
    if (@($caseGroups).Count -gt 0) { throw 'Case-colliding paths are not allowed.' }
    $entries = foreach ($relative in $paths) {
        if ($relative -match '(^|/)(\.git|\.harness)(/|$)' -or $relative -match ':' -or $relative -match '(^|/)\.\.(/|$)') { throw "Unsafe changed path: $relative" }
        $full = Resolve-PathUnderRoot -Root $Root -RelativePath $relative
        $raw=@(& git -C $Root diff --raw --no-abbrev HEAD -- $relative)
        $rawLine=if($raw.Count){[string]$raw[-1]}else{''}
        $oldMode='000000';$newMode=if(Test-Path -LiteralPath $full){'100644'}else{'000000'};$gitStatus=if(Test-Path -LiteralPath $full){'untracked'}else{'deleted'}
        if($rawLine -match '^:(?<old>[0-9]{6})\s+(?<new>[0-9]{6})\s+[0-9a-f]+\s+[0-9a-f]+\s+(?<status>[A-Z])'){$oldMode=$Matches.old;$newMode=$Matches.new;$gitStatus=$Matches.status}
        if($newMode -in @('120000','160000') -or $oldMode -in @('120000','160000')){throw "Symlink/submodule modes are not allowed: $relative"}
        if (Test-Path -LiteralPath $full) {
            $item = Get-Item -LiteralPath $full -Force
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { throw "Reparse points are not allowed: $relative" }
            if ($item.PSIsContainer) { throw "Changed directories are not valid task artifacts: $relative" }
            [ordered]@{ path = $relative; status = 'present'; git_status=$gitStatus; old_mode=$oldMode; new_mode=$newMode; length = $item.Length; content_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $full).Hash }
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
