$ErrorActionPreference = "Stop"

$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$targetDir = Join-Path $env:USERPROFILE ".9router\bin"
$target = Join-Path $targetDir "9router.cmd"

New-Item -ItemType Directory -Force $targetDir | Out-Null

@"
@echo off
set "NINEROUTER_APP_DIR=$appDir"
powershell -NoProfile -ExecutionPolicy Bypass -File "%NINEROUTER_APP_DIR%\scripts\9router.ps1" %*
"@ | Set-Content -Path $target -Encoding ASCII

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ";") -notcontains $targetDir) {
  [Environment]::SetEnvironmentVariable("Path", ($userPath.TrimEnd(";") + ";" + $targetDir), "User")
  $env:Path += ";$targetDir"
  Write-Host "Added to user PATH: $targetDir"
}

Write-Host "Installed 9router command: $target"
Write-Host "Use a new terminal, then run:"
Write-Host "  9router start"
Write-Host "  9router stop"
Write-Host "  9router status"
