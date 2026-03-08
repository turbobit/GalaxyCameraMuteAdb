@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "RELEASE_DIR=%SCRIPT_DIR%release"
set /p VERSION=<"%SCRIPT_DIR%VERSION"
set "APP_NAME=GalaxyCameraMuteAdb_v%VERSION%.exe"

pushd "%SCRIPT_DIR%" >nul
if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"

go build -ldflags "-X main.version=%VERSION%" -o "%RELEASE_DIR%\%APP_NAME%" .
if errorlevel 1 (
    echo Build failed.
    popd >nul
    exit /b 1
)

echo Build completed: %RELEASE_DIR%\%APP_NAME% ^(version %VERSION%^)
popd >nul
exit /b 0
