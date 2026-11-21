#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_NAME="MicRouter"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
BUNDLE_ID="com.microuter.app"
VERSION="${VERSION:-1.2.4}"
VERSION="${VERSION#v}"

mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

echo "==> Generating AppIcon.icns..."
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
swift "$ROOT_DIR/scripts/gen-icon.swift" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR"

echo "==> Compiling ${APP_NAME}.app (${VERSION})..."
swiftc -O \
    -target "$(uname -m)-apple-macos13.0" \
    "$ROOT_DIR/Sources/Core/AudioDeviceManager.swift" \
    "$ROOT_DIR/Sources/Core/RemoteHIDMonitor.swift" \
    "$ROOT_DIR/Sources/Core/MicRouterEngine.swift" \
    "$ROOT_DIR/Sources/App/Localization.swift" \
    "$ROOT_DIR/Sources/App/StatusIconRenderer.swift" \
    "$ROOT_DIR/Sources/App/PermissionWindowController.swift" \
    "$ROOT_DIR/Sources/App/main.swift" \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>MIT License</string>
</dict>
</plist>
EOF

echo "==> Code signing ${APP_NAME}.app (ad-hoc with stable identifier)..."
codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"

echo "==> Built: $APP_BUNDLE"
