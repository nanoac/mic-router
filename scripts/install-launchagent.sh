#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="com.microuter.cli"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/mic-router"
LOG_PATH="$HOME/Library/Logs/mic-router-cli.log"

if [[ "${1:-}" == "--uninstall" ]]; then
    echo "==> Uninstalling LaunchAgent ($LABEL)..."
    launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
    rm -f "$PLIST" "$BIN_PATH"
    echo "==> Done."
    exit 0
fi

if [[ ! -x "$ROOT_DIR/build/mic-router" ]]; then
    echo "==> Building CLI binary first..."
    make -C "$ROOT_DIR" cli
fi

mkdir -p "$BIN_DIR" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cp "$ROOT_DIR/build/mic-router" "$BIN_PATH"
chmod +x "$BIN_PATH"
codesign --force --sign - --identifier "$LABEL" "$BIN_PATH"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BIN_PATH}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${LOG_PATH}</string>
    <key>StandardErrorPath</key>
    <string>${LOG_PATH}</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "==> Installed and started $LABEL"
echo "    Binary: $BIN_PATH"
echo "    Plist:  $PLIST"
echo "    Log:    $LOG_PATH"
echo "    Note:   If HID access fails, grant Input Monitoring to $BIN_PATH in System Settings."
