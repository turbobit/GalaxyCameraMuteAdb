@echo off
setlocal

set "WIN_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%WIN_PS%" (
    "%WIN_PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0release.ps1" %*
    exit /b %ERRORLEVEL%
)

where powershell.exe >nul 2>nul
if %ERRORLEVEL%==0 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0release.ps1" %*
    exit /b %ERRORLEVEL%
)

where pwsh.exe >nul 2>nul
if %ERRORLEVEL%==0 (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0release.ps1" %*
    exit /b %ERRORLEVEL%
)

echo PowerShell executable not found.
exit /b 1
