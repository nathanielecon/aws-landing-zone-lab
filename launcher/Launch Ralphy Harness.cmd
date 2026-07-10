@echo off
setlocal
set "PWSH=C:\Program Files\PowerShell\7\pwsh.exe"
if not exist "%PWSH%" (
  echo PowerShell 7 is required.
  echo Run this from an elevated shell: choco install powershell-core -y --no-progress
  pause
  exit /b 10
)
"%PWSH%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Start-Harness.ps1" %*
set "EXITCODE=%ERRORLEVEL%"
if not "%EXITCODE%"=="0" pause
exit /b %EXITCODE%
