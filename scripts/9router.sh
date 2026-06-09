#!/usr/bin/env bash
set -euo pipefail

CMD="${1:-help}"
APP_DIR="${NINEROUTER_APP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REAL_HOME="${SUDO_USER:+$(getent passwd "$SUDO_USER" | cut -d: -f6)}"
REAL_HOME="${REAL_HOME:-${HOME:-$(getent passwd "$(id -un)" | cut -d: -f6)}}"
PORT="20128"
RUNTIME_HOME="$APP_DIR/.runtime-home"
PID_FILE="$RUNTIME_HOME/9router.pid"
LOG_DIR="$RUNTIME_HOME/logs"
LOG_FILE="$LOG_DIR/server.log"
SERVICE_NAME="9router.service"
SERVICE_DIR="$REAL_HOME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/$SERVICE_NAME"
BIN_FILE="$REAL_HOME/.local/bin/9router"

set_env() {
  export HOME="$RUNTIME_HOME"
  export USERPROFILE="$RUNTIME_HOME"
  export APPDATA="$RUNTIME_HOME/AppData/Roaming"
  export LOCALAPPDATA="$RUNTIME_HOME/AppData/Local"
  export DATA_DIR="$RUNTIME_HOME/data"
  export NODE_ENV="production"
  export PORT="$PORT"
  export HOSTNAME="0.0.0.0"
  export BASE_URL="http://localhost:$PORT"
  export NEXT_PUBLIC_BASE_URL="http://localhost:$PORT"
  export NEXT_TELEMETRY_DISABLED="1"
  mkdir -p "$APPDATA" "$LOCALAPPDATA" "$DATA_DIR" "$LOG_DIR"
}

port_pid() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -ti tcp:"$PORT" -sTCP:LISTEN | head -n 1 || true
  else
    ss -ltnp 2>/dev/null | awk -v p=":$PORT" '$4 ~ p {print $NF}' | sed -n 's/.*pid=\([0-9]*\).*/\1/p' | head -n 1 || true
  fi
}

sync_assets() {
  if [ -d "$APP_DIR/.next/static" ]; then
    mkdir -p "$APP_DIR/.next/standalone/.next/static"
    cp -R "$APP_DIR/.next/static/." "$APP_DIR/.next/standalone/.next/static/"
  fi
  if [ -d "$APP_DIR/public" ]; then
    mkdir -p "$APP_DIR/.next/standalone/public"
    cp -R "$APP_DIR/public/." "$APP_DIR/.next/standalone/public/"
  fi
}

build_app() {
  cd "$APP_DIR"
  set_env
  [ -d node_modules ] || npm install
  npm run build
  sync_assets
}

update_app() {
  cd "$APP_DIR"
  local was_running=""
  was_running="$(port_pid)"
  if [ -n "$was_running" ]; then
    stop_server
  fi

  if [ -d ".git" ]; then
    git pull --ff-only
  else
    echo "Skip git pull: not a git repo"
  fi

  npm install
  rm -rf "$APP_DIR/.next"
  build_app

  if [ -n "$was_running" ]; then
    start_server
  fi
  echo "9Router updated"
}

start_server() {
  local existing
  existing="$(port_pid)"
  if [ -n "$existing" ]; then
    echo "9Router already running on port $PORT (PID $existing)"
    echo "Dashboard: http://localhost:$PORT/dashboard"
    return
  fi

  cd "$APP_DIR"
  set_env
  [ -f ".next/standalone/server.js" ] || build_app
  sync_assets
  nohup node ".next/standalone/server.js" > "$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
  echo "9Router started"
  echo "PID: $!"
  echo "Dashboard: http://localhost:$PORT/dashboard"
  echo "Log: $LOG_FILE"
}

stop_server() {
  local ids=""
  [ -f "$PID_FILE" ] && ids="$ids $(cat "$PID_FILE")"
  ids="$ids $(port_pid)"
  ids="$(echo "$ids" | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -u || true)"
  if [ -z "$ids" ]; then
    echo "9Router already stopped"
  else
    echo "$ids" | while read -r pid; do
      kill -9 "$pid" 2>/dev/null || true
      echo "Stopped PID $pid"
    done
  fi
  rm -f "$PID_FILE"
}

status_server() {
  local pid
  pid="$(port_pid)"
  if [ -n "$pid" ]; then
    echo "9Router running"
    echo "PID: $pid"
    echo "Dashboard: http://localhost:$PORT/dashboard"
    echo "API: http://localhost:$PORT/v1"
  else
    echo "9Router stopped"
  fi
}

autorun_on() {
  mkdir -p "$SERVICE_DIR"
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=9Router personal server
After=network-online.target

[Service]
Type=forking
Environment=NINEROUTER_APP_DIR=$APP_DIR
ExecStart=$BIN_FILE start
ExecStop=$BIN_FILE stop
PIDFile=$PID_FILE
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable --now "$SERVICE_NAME"
  loginctl enable-linger "$USER" >/dev/null 2>&1 || true
  echo "Autorun enabled: systemd user -> 9router start"
}

autorun_off() {
  systemctl --user disable --now "$SERVICE_NAME" >/dev/null 2>&1 || true
  rm -f "$SERVICE_FILE"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  echo "Autorun disabled"
}

autorun_status() {
  if systemctl --user is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
    echo "Autorun enabled"
    systemctl --user status "$SERVICE_NAME" --no-pager -n 5 || true
  else
    echo "Autorun disabled"
  fi
}

case "$CMD" in
  start) start_server ;;
  stop) stop_server ;;
  restart) stop_server; start_server ;;
  status) status_server ;;
  build) build_app ;;
  rebuild) rm -rf "$APP_DIR/.next"; build_app ;;
  update) update_app ;;
  logs) touch "$LOG_FILE"; tail -n 100 -f "$LOG_FILE" ;;
  open) python -m webbrowser "http://localhost:$PORT/dashboard" ;;
  autorun-on) autorun_on ;;
  autorun-off) autorun_off ;;
  autorun-status) autorun_status ;;
  *)
    echo "9Router commands:"
    echo "  9router start    Start production server"
    echo "  9router stop     Stop server"
    echo "  9router restart  Restart server"
    echo "  9router status   Show status"
    echo "  9router build    Build production"
    echo "  9router rebuild  Clean build production"
    echo "  9router update   Pull latest, install, rebuild, restart if needed"
    echo "  9router logs     Tail logs"
    echo "  9router open     Open dashboard"
    echo "  9router autorun-on      Start at login/boot"
    echo "  9router autorun-off     Disable autorun"
    echo "  9router autorun-status  Show autorun status"
    ;;
esac
