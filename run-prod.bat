@echo off
setlocal

cd /d "%~dp0"

set "NINEROUTER_HOME=%CD%\.runtime-home"
set "HOME=%NINEROUTER_HOME%"
set "USERPROFILE=%NINEROUTER_HOME%"
set "APPDATA=%NINEROUTER_HOME%\AppData\Roaming"
set "LOCALAPPDATA=%NINEROUTER_HOME%\AppData\Local"
set "DATA_DIR=%NINEROUTER_HOME%\data"
set "NODE_ENV=production"
set "PORT=20128"
set "HOSTNAME=0.0.0.0"
set "BASE_URL=http://localhost:20128"
set "NEXT_PUBLIC_BASE_URL=http://localhost:20128"
set "NEXT_TELEMETRY_DISABLED=1"

if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"

if not exist node_modules (
  echo Installing dependencies...
  call npm install
  if errorlevel 1 exit /b %errorlevel%
)

if not exist ".next\standalone\server.js" (
  echo Building production bundle...
  call npm run build
  if errorlevel 1 exit /b %errorlevel%
) else (
  echo Existing production build found. Skipping build...
)

echo Starting 9Router production server on http://localhost:20128
if exist ".next\standalone\server.js" (
  node .next\standalone\server.js
) else (
  call npm run start
)
