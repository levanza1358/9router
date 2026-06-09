param(
  [Parameter(Position = 0)]
  [ValidateSet("start", "stop", "restart", "status", "build", "rebuild", "update", "logs", "open", "autorun-on", "autorun-off", "autorun-status", "help")]
  [string]$Command = "help"
)

$ErrorActionPreference = "Stop"

$AppDir = $env:NINEROUTER_APP_DIR
if (-not $AppDir) {
  $AppDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}

$Port = 20128
$PidFile = Join-Path $AppDir ".runtime-home\9router.pid"
$LogDir = Join-Path $AppDir ".runtime-home\logs"
$LogFile = Join-Path $LogDir "server.log"
$ErrLogFile = Join-Path $LogDir "server.err.log"
$TaskName = "9Router"

function Set-9RouterEnv {
  $homeDir = Join-Path $AppDir ".runtime-home"
  $env:HOME = $homeDir
  $env:USERPROFILE = $homeDir
  $env:APPDATA = Join-Path $homeDir "AppData\Roaming"
  $env:LOCALAPPDATA = Join-Path $homeDir "AppData\Local"
  $env:DATA_DIR = Join-Path $homeDir "data"
  $env:NODE_ENV = "production"
  $env:PORT = "$Port"
  $env:HOSTNAME = "0.0.0.0"
  $env:BASE_URL = "http://localhost:$Port"
  $env:NEXT_PUBLIC_BASE_URL = "http://localhost:$Port"
  $env:NEXT_TELEMETRY_DISABLED = "1"
  New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA,$env:DATA_DIR,$LogDir | Out-Null
}

function Get-PortProcessId {
  $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($conn) { return [int]$conn.OwningProcess }
  return $null
}

function Get-SavedProcessId {
  if (Test-Path $PidFile) {
    $raw = (Get-Content $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($raw -match '^\d+$') { return [int]$raw }
  }
  return $null
}

function Show-Status {
  $serverPid = Get-PortProcessId
  if ($serverPid) {
    $proc = Get-Process -Id $serverPid -ErrorAction SilentlyContinue
    Write-Host "9Router running"
    Write-Host "PID: $serverPid"
    if ($proc) { Write-Host "Process: $($proc.ProcessName)" }
    Write-Host "Dashboard: http://localhost:$Port/dashboard"
    Write-Host "API: http://localhost:$Port/v1"
  } else {
    Write-Host "9Router stopped"
  }
}

function Stop-Server {
  $ids = @()
  $portPid = Get-PortProcessId
  $savedPid = Get-SavedProcessId
  if ($portPid) { $ids += $portPid }
  if ($savedPid) { $ids += $savedPid }
  $ids = $ids | Select-Object -Unique

  if (-not $ids -or $ids.Count -eq 0) {
    Write-Host "9Router already stopped"
  } else {
    foreach ($id in $ids) {
      $proc = Get-Process -Id $id -ErrorAction SilentlyContinue
      if ($proc) {
        Stop-Process -Id $id -Force
        Write-Host "Stopped PID $id"
      }
    }
  }

  if (Test-Path $PidFile) { Remove-Item $PidFile -Force }
}

function Build-App {
  Push-Location $AppDir
  try {
    Set-9RouterEnv
    if (-not (Test-Path "node_modules")) {
      npm install
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    npm run build
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (Test-Path ".next\static") {
      New-Item -ItemType Directory -Force ".next\standalone\.next\static" | Out-Null
      Copy-Item ".next\static\*" ".next\standalone\.next\static" -Recurse -Force
    }
    if (Test-Path "public") {
      New-Item -ItemType Directory -Force ".next\standalone\public" | Out-Null
      Copy-Item "public\*" ".next\standalone\public" -Recurse -Force
    }
  } finally {
    Pop-Location
  }
}

function Update-App {
  Push-Location $AppDir
  try {
    $wasRunning = [bool](Get-PortProcessId)
    if ($wasRunning) { Stop-Server }

    if (Test-Path ".git") {
      git pull --ff-only
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } else {
      Write-Host "Skip git pull: not a git repo"
    }

    npm install
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    if (Test-Path ".next") { Remove-Item -Recurse -Force ".next" }
    Build-App

    if ($wasRunning) { Start-Server }
    Write-Host "9Router updated"
  } finally {
    Pop-Location
  }
}

function Start-Server {
  $existing = Get-PortProcessId
  if ($existing) {
    Write-Host "9Router already running on port $Port (PID $existing)"
    Write-Host "Dashboard: http://localhost:$Port/dashboard"
    return
  }

  Push-Location $AppDir
  try {
    Set-9RouterEnv
    if (-not (Test-Path ".next\standalone\server.js")) {
      Build-App
    } else {
      if (Test-Path ".next\static") {
        New-Item -ItemType Directory -Force ".next\standalone\.next\static" | Out-Null
        Copy-Item ".next\static\*" ".next\standalone\.next\static" -Recurse -Force
      }
      if (Test-Path "public") {
        New-Item -ItemType Directory -Force ".next\standalone\public" | Out-Null
        Copy-Item "public\*" ".next\standalone\public" -Recurse -Force
      }
    }

    $server = if (Test-Path ".next\standalone\server.js") { ".next\standalone\server.js" } else { "node_modules\next\dist\bin\next" }
    $args = if ($server -like "*.js") { @($server) } else { @($server, "start") }
    $proc = Start-Process -FilePath "node" -ArgumentList $args -WorkingDirectory $AppDir -RedirectStandardOutput $LogFile -RedirectStandardError $ErrLogFile -PassThru -WindowStyle Hidden
    Set-Content -Path $PidFile -Value $proc.Id
    Write-Host "9Router started"
    Write-Host "PID: $($proc.Id)"
    Write-Host "Dashboard: http://localhost:$Port/dashboard"
    Write-Host "Log: $LogFile"
  } finally {
    Pop-Location
  }
}

function Enable-Autorun {
  $shim = Join-Path $env:USERPROFILE ".9router\bin\9router.cmd"
  if (-not (Test-Path $shim)) {
    Write-Host "Install command first: .\install.ps1"
    return
  }

  $action = New-ScheduledTaskAction -Execute $shim -Argument "start" -WorkingDirectory $AppDir
  $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 365)
  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description "Start 9Router at Windows login" -Force | Out-Null
  Write-Host "Autorun enabled: Windows login -> 9router start"
}

function Disable-Autorun {
  $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  if ($task) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Autorun disabled"
  } else {
    Write-Host "Autorun already disabled"
  }
}

function Show-AutorunStatus {
  $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  if ($task) {
    Write-Host "Autorun enabled"
    Write-Host "State: $($task.State)"
  } else {
    Write-Host "Autorun disabled"
  }
}

switch ($Command) {
  "start" { Start-Server }
  "stop" { Stop-Server }
  "restart" { Stop-Server; Start-Server }
  "status" { Show-Status }
  "build" { Build-App }
  "rebuild" { Push-Location $AppDir; try { if (Test-Path ".next") { Remove-Item -Recurse -Force ".next" }; Build-App } finally { Pop-Location } }
  "update" { Update-App }
  "logs" { if (Test-Path $LogFile) { Get-Content $LogFile -Tail 100 -Wait } elseif (Test-Path $ErrLogFile) { Get-Content $ErrLogFile -Tail 100 -Wait } else { Write-Host "No log yet: $LogFile" } }
  "open" { Start-Process "http://localhost:$Port/dashboard" }
  "autorun-on" { Enable-Autorun }
  "autorun-off" { Disable-Autorun }
  "autorun-status" { Show-AutorunStatus }
  default {
    Write-Host "9Router commands:"
    Write-Host "  9router start    Start production server"
    Write-Host "  9router stop     Stop server"
    Write-Host "  9router restart  Restart server"
    Write-Host "  9router status   Show status"
    Write-Host "  9router build    Build production"
    Write-Host "  9router rebuild  Clean build production"
    Write-Host "  9router update   Pull latest, install, rebuild, restart if needed"
    Write-Host "  9router logs     Tail logs"
    Write-Host "  9router open     Open dashboard"
    Write-Host "  9router autorun-on      Start at login"
    Write-Host "  9router autorun-off     Disable start at login"
    Write-Host "  9router autorun-status  Show autorun status"
  }
}
