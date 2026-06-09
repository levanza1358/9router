#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${NINEROUTER_REPO_URL:-https://github.com/levanza1358/9router.git}"
INSTALL_DIR="${NINEROUTER_INSTALL_DIR:-$HOME/9router}"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required. Install git first."
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "node is required. Install Node.js 20+ first."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required. Install npm first."
  exit 1
fi

if [ -d "$INSTALL_DIR/.git" ]; then
  echo "Updating 9Router in $INSTALL_DIR"
  git -C "$INSTALL_DIR" pull --ff-only
else
  if [ -e "$INSTALL_DIR" ]; then
    echo "Install dir exists but is not a git repo: $INSTALL_DIR"
    exit 1
  fi
  echo "Installing 9Router to $INSTALL_DIR"
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"
npm install
bash install.sh

echo ""
echo "Installed. Ensure ~/.local/bin is in PATH, then run:"
echo "  9router start"
echo "  9router status"
echo "  9router autorun-on"
