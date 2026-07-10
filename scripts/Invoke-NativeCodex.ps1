[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Executable,
    [Parameter(Mandatory)][string]$ArgumentsBase64,
    [Parameter(Mandatory)][string]$CommonModulePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module $CommonModulePath -Force

$argumentJson = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($ArgumentsBase64))
$nativeArguments = @($argumentJson | ConvertFrom-Json | ForEach-Object { [string]$_ })
& $Executable @nativeArguments 2>&1 | ForEach-Object {
    $safeLine = Protect-LogText -Text ([string]$_)
    if ($_ -is [System.Management.Automation.ErrorRecord]) {
        [Console]::Error.WriteLine($safeLine)
    } else {
        [Console]::Out.WriteLine($safeLine)
    }
}
$nativeExitCode = $LASTEXITCODE
exit $nativeExitCode
