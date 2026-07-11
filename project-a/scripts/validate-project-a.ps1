param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$terraform = (Get-Command terraform.exe -ErrorAction Stop).Source
$modules = @(
  'project-a',
  'project-a/terraform/bootstrap',
  'project-a/terraform/organization',
  'project-a/terraform/identity',
  'project-a/terraform/network',
  'project-a/terraform/audit'
)

& $terraform -chdir=$root fmt -check -recursive
if ($LASTEXITCODE -ne 0) { throw 'terraform fmt failed.' }

foreach ($relative in $modules) {
  $path = Join-Path ([System.IO.Path]::GetDirectoryName($root)) $relative
  & $terraform -chdir=$path init -backend=false -input=false -lockfile=readonly
  if ($LASTEXITCODE -ne 0) { throw "terraform init failed for $relative" }
  & $terraform -chdir=$path validate -no-color
  if ($LASTEXITCODE -ne 0) { throw "terraform validate failed for $relative" }
}

& $terraform -chdir=$root test -no-color
if ($LASTEXITCODE -ne 0) { throw 'terraform test failed for project-a root.' }

& $terraform -chdir=$root test -no-color -test-directory=tests/integration
if ($LASTEXITCODE -ne 0) { throw 'terraform integration tests failed.' }
