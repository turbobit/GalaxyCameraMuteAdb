@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set /p VERSION=<"%SCRIPT_DIR%VERSION"

:: Find adb path
where adb >nul 2>&1
if %ERRORLEVEL%==0 (
    for /f "delims=" %%i in ('where adb') do (
        set "ADB_BIN=%%i"
        goto :adb_found
    )
)

if defined ADB_PATH (
    if exist "%ADB_PATH%" (
        set "ADB_BIN=%ADB_PATH%"
        goto :adb_found
    )
)

if exist "%SCRIPT_DIR%platform-tools\adb.exe" (
    set "ADB_BIN=%SCRIPT_DIR%platform-tools\adb.exe"
    goto :adb_found
)

if exist "%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools\adb.exe" (
    set "ADB_BIN=%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools\adb.exe"
    goto :adb_found
)

if exist "%USERPROFILE%\platform-tools\adb.exe" (
    set "ADB_BIN=%USERPROFILE%\platform-tools\adb.exe"
    goto :adb_found
)

if exist "%USERPROFILE%\Downloads\platform-tools\adb.exe" (
    set "ADB_BIN=%USERPROFILE%\Downloads\platform-tools\adb.exe"
    goto :adb_found
)

echo [adb] ERROR: adb not found
exit /b 1

:adb_found
echo [adb] using: %ADB_BIN%
echo [adb] stopping server...
"%ADB_BIN%" kill-server >nul 2>&1
echo [adb] starting server...
"%ADB_BIN%" start-server >nul 2>&1
timeout /t 1 /nobreak >nul
echo [adb] devices:
"%ADB_BIN%" devices

pushd "%SCRIPT_DIR%" >nul
go run -ldflags "-X main.version=%VERSION%" .
set "EXIT_CODE=%ERRORLEVEL%"
popd >nul

exit /b %EXIT_CODE%
