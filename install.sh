#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.local/bin"
TARGET="$TARGET_DIR/9router"

mkdir -p "$TARGET_DIR"
cat > "$TARGET" <<EOF
#!/usr/bin/env bash
export NINEROUTER_APP_DIR="$APP_DIR"
exec bash "\$NINEROUTER_APP_DIR/scripts/9router.sh" "\$@"
EOF
chmod +x "$TARGET"

echo "Installed 9router command: $TARGET"
echo "Ensure this is in PATH: $TARGET_DIR"
echo "Then use:"
echo "  9router start"
echo "  9router stop"
echo "  9router status"
