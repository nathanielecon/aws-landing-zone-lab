param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

$model = $null
$outputPath = $null
for ($index = 0; $index -lt $Arguments.Count - 1; $index++) {
    if ($Arguments[$index] -in @('--model', '-m')) { $model = $Arguments[$index + 1] }
    if ($Arguments[$index] -in @('--output-last-message', '-o')) { $outputPath = $Arguments[$index + 1] }
}
$stdinText = [Console]::In.ReadToEnd()
$joined = ($Arguments -join "`n") + "`n" + $stdinText
$taskId = if ($joined -match '\[TASK:(?<id>S-00[12])\]') { $Matches.id } elseif ($joined -match 'S-00[12]') { $Matches[0] } else { throw 'Fake Codex could not identify task.' }
$root = (Get-Location).Path
$encoding = [System.Text.UTF8Encoding]::new($false)
if ($taskId -eq 'S-001') {
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
