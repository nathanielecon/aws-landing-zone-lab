@echo off
setlocal
set "PWSH=C:\Program Files\PowerShell\7\pwsh.exe"
if not exist "%PWSH%" (
  echo PowerShell 7 is required. Run from an elevated shell: choco install powershell-core -y --no-progress 1>&2
  exit /b 10
)
"%PWSH%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\scripts\Invoke-CodexAdapter.ps1" %*
set "ADAPTER_EXIT=%ERRORLEVEL%"
if not "%ADAPTER_EXIT%"=="0" (
  if defined HARNESS_ROOT (
    if not exist "%HARNESS_ROOT%\.harness\runtime" mkdir "%HARNESS_ROOT%\.harness\runtime"
    >"%HARNESS_ROOT%\.harness\runtime\stop.flag" echo adapter_failed
  )
)
exit /b %ADAPTER_EXIT%
