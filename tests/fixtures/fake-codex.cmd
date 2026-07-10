@echo off
"C:\Program Files\PowerShell\7\pwsh.exe" -NoLogo -NoProfile -File "%~dp0Fake-Codex.ps1" %*
exit /b %ERRORLEVEL%
