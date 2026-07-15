#Requires -Version 7
# Compatibility shim: prefer Invoke-ContinuityOpsValidate.ps1
& (Join-Path $PSScriptRoot 'Invoke-ContinuityOpsValidate.ps1') @args
exit $LASTEXITCODE
