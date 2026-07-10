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
        $output = & git -C $Root @command
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
    foreach ($path in (& git -C $Root ls-files --others --exclude-standard | Sort-Object)) {
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
        if ($index -gt 0 -and ($argument -eq '--' -or -not $argument.StartsWith('-'))) {
            for (; $index -lt $Arguments.Count; $index++) { $clean.Add($Arguments[$index]) }
            break
        }
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

Export-ModuleMember -Function *
