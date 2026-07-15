param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

$model = $null
$outputPath = $null
for ($index = 0; $index -lt $Arguments.Count - 1; $index++) {
    if ($Arguments[$index] -in @('--model', '-m')) { $model = $Arguments[$index + 1] }
    if ($Arguments[$index] -in @('--output-last-message', '-o')) { $outputPath = $Arguments[$index + 1] }
}
$stdinText = [Console]::In.ReadToEnd()
$joined = ($Arguments -join "`n") + "`n" + $stdinText
$taskId = if ($joined -match '\[TASK:(?<id>[SA]-00[1-7])\]') { $Matches.id } elseif ($joined -match '[SA]-00[1-7]') { $Matches[0] } else { throw 'Fake Codex could not identify task.' }
$root = (Get-Location).Path
$encoding = [System.Text.UTF8Encoding]::new($false)
if ($env:HARNESS_FAKE_CALL_COUNT) { Add-Content -LiteralPath (Join-Path $root $env:HARNESS_FAKE_CALL_COUNT) -Value 'call' }
if ($env:HARNESS_FAKE_OUTPUT) {
    [Console]::Out.WriteLine("token=$($env:HARNESS_FAKE_OUTPUT)")
    [Console]::Error.WriteLine("Authorization: Bearer $($env:HARNESS_FAKE_OUTPUT)")
}
if ($env:HARNESS_FAKE_BLOCK_SECONDS) {
    $child = Start-Process -FilePath (Get-Command pwsh).Source -ArgumentList '-NoLogo','-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 60' -PassThru
    if ($env:HARNESS_FAKE_CHILD_PID_PATH) { [System.IO.File]::WriteAllText((Join-Path $root $env:HARNESS_FAKE_CHILD_PID_PATH), [string]$child.Id, $encoding) }
    Start-Sleep -Seconds ([int]$env:HARNESS_FAKE_BLOCK_SECONDS)
}
if ($taskId.StartsWith('A-')) {
    if ($env:HARNESS_CONTRACT_ONLY -ne '1' -or -not $env:HARNESS_FAKE_ALLOWED_PATH) { throw 'Project A fake execution requires an explicit contract fixture path.' }
    $path = Join-Path $root $env:HARNESS_FAKE_ALLOWED_PATH
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
    [System.IO.File]::WriteAllText($path, "PROJECT_A_FAKE_OK`n", $encoding)
    if ($env:HARNESS_FAKE_ENV_DUMP) {
        $dump = Get-ChildItem Env: | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }
        [System.IO.File]::WriteAllLines((Join-Path $root $env:HARNESS_FAKE_ENV_DUMP), $dump, $encoding)
    }
} elseif ($taskId -eq 'S-001') {
    $path = Join-Path $root 'smoke/terra.txt'
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
    [System.IO.File]::WriteAllText($path, "TERRA_SMOKE_OK`n", $encoding)
} else {
    $path = Join-Path $root 'smoke/takeover.txt'
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
    $content = if ($model -eq 'gpt-5.6-sol') { "SOL_TAKEOVER_OK`n" } else { "TERRA_INITIAL_OK`n" }
    [System.IO.File]::WriteAllText($path, $content, $encoding)
}
if ($outputPath) {
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $outputPath)) | Out-Null
    [System.IO.File]::WriteAllText($outputPath, "fake $model completed $taskId`n", $encoding)
}
[pscustomobject]@{ type = 'thread.started'; thread_id = "00000000-0000-0000-0000-$($taskId.Replace('-', '').PadLeft(12, '0'))" } | ConvertTo-Json -Compress
[pscustomobject]@{ type = 'item.completed'; model = $model; task = $taskId } | ConvertTo-Json -Compress
exit 0
