$ErrorActionPreference = "Stop"

$RepoUrl = if ($env:NINEROUTER_REPO_URL) { $env:NINEROUTER_REPO_URL } else { "https://github.com/levanza1358/9router.git" }
$InstallDir = if ($env:NINEROUTER_INSTALL_DIR) { $env:NINEROUTER_INSTALL_DIR } else { Join-Path $env:USERPROFILE "9router" }

function Require-Command($Name, $InstallHint) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "$Name is required. $InstallHint"
  }
}

Require-Command "git" "Install Git first: https://git-scm.com/download/win"
Require-Command "node" "Install Node.js 20+ first: https://nodejs.org/"
Require-Command "npm" "Install npm with Node.js first."

if (Test-Path (Join-Path $InstallDir ".git")) {
  Write-Host "Updating 9Router in $InstallDir"
  git -C $InstallDir pull --ff-only
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
  if (Test-Path $InstallDir) {
    throw "Install dir exists but is not a git repo: $InstallDir"
  }
  Write-Host "Installing 9Router to $InstallDir"
  git clone $RepoUrl $InstallDir
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Set-Location $InstallDir
npm install
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallDir "install.ps1")

Write-Host ""
Write-Host "Installed. Open a new terminal, then run:"
Write-Host "  9router start"
Write-Host "  9router status"
Write-Host "  9router autorun-on"
