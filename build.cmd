@echo off
setlocal

set "APP_NAME=GalaxyCameraMuteAdb.exe"
set "SCRIPT_DIR=%~dp0"

pushd "%SCRIPT_DIR%" >nul
go build -o "%APP_NAME%" .
if errorlevel 1 (
    echo Build failed.
    popd >nul
    exit /b 1
)

echo Build completed: %SCRIPT_DIR%%APP_NAME%
popd >nul
exit /b 0
