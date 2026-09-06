param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$tempRoot = [System.IO.Path]::GetTempPath()
$terraform = (Get-Command terraform -ErrorAction Stop).Source
$modules = @(
  '.',
  'terraform/bootstrap',
  'terraform/organization',
  'terraform/identity',
  'terraform/network',
  'terraform/audit',
  'sandbox/landing-zone-lab/retained-evidence'
)

function Invoke-ProjectATerraform {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string[]]$Arguments,
    [string]$DataDir
  )

  $originalTfDataDir = $env:TF_DATA_DIR
  $activeDataDir = if ([string]::IsNullOrWhiteSpace($DataDir)) {
    Join-Path $tempRoot ('project-a-tfdata-' + [Guid]::NewGuid().ToString('N'))
  } else {
    $DataDir
  }
  try {
    $env:TF_DATA_DIR = $activeDataDir
    & $terraform "-chdir=$Path" @Arguments
  } finally {
    if ($null -eq $originalTfDataDir) {
      Remove-Item Env:TF_DATA_DIR -ErrorAction SilentlyContinue
    } else {
      $env:TF_DATA_DIR = $originalTfDataDir
    }
    if ([string]::IsNullOrWhiteSpace($DataDir)) {
      Remove-Item -LiteralPath $activeDataDir -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

& $terraform "-chdir=$root" fmt -check -recursive
if ($LASTEXITCODE -ne 0) { throw 'terraform fmt failed.' }

foreach ($relative in $modules) {
  $path = if ($relative -eq '.') { $root } else { Join-Path $root $relative }
  $dataDir = Join-Path $tempRoot ('project-a-tfdata-' + [Guid]::NewGuid().ToString('N'))
  try {
    Invoke-ProjectATerraform -Path $path -Arguments @('init','-backend=false','-input=false','-lockfile=readonly') -DataDir $dataDir
    if ($LASTEXITCODE -ne 0) { throw "terraform init failed for $relative" }
    Invoke-ProjectATerraform -Path $path -Arguments @('validate','-no-color') -DataDir $dataDir
    if ($LASTEXITCODE -ne 0) { throw "terraform validate failed for $relative" }
  } finally {
    Remove-Item -LiteralPath $dataDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Invoke-ProjectATerraform -Path $root -Arguments @('test','-no-color')
if ($LASTEXITCODE -ne 0) { throw 'terraform test failed for project-a root.' }

Invoke-ProjectATerraform -Path $root -Arguments @('test','-no-color','-test-directory=tests/integration')
if ($LASTEXITCODE -ne 0) { throw 'terraform integration tests failed.' }
