@echo off
setlocal

set "APP_DIR=%~dp0"
set "APP_DIR=%APP_DIR:~0,-1%"
set "CMD_NAME=9router.cmd"
set "TARGET_DIR=%USERPROFILE%\.9router\bin"
set "TARGET=%TARGET_DIR%\%CMD_NAME%"

if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

> "%TARGET%" echo @echo off
>> "%TARGET%" echo set "NINEROUTER_APP_DIR=%APP_DIR%"
>> "%TARGET%" echo powershell -NoProfile -ExecutionPolicy Bypass -File "%%NINEROUTER_APP_DIR%%\scripts\9router.ps1" %%*

echo Installed 9router command to:
echo   %TARGET%
echo.
echo Add this to your user PATH if not already present:
echo   %TARGET_DIR%
echo.
echo PowerShell current session:
echo   $env:Path += ";%TARGET_DIR%"
echo.
echo Then use:
echo   9router start
echo   9router stop
echo   9router status
