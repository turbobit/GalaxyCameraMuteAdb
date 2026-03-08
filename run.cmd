@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set /p VERSION=<"%SCRIPT_DIR%VERSION"

pushd "%SCRIPT_DIR%" >nul
go run -ldflags "-X main.version=%VERSION%" .
set "EXIT_CODE=%ERRORLEVEL%"
popd >nul

exit /b %EXIT_CODE%
