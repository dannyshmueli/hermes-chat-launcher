#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Hermes Chat"
APP_PATH="/Applications/${APP_NAME}.app"
LAUNCHER_DEST="$HOME/bin/hermes-chat-launcher.sh"

mkdir -p "$HOME/bin" "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$ROOT/scripts/hermes-chat-launcher.sh" "$LAUNCHER_DEST"
chmod +x "$LAUNCHER_DEST"
cp "$ROOT/assets/HermesChat.icns" "$APP_PATH/Contents/Resources/HermesChat.icns"

cat > "$APP_PATH/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>Hermes Chat</string>
  <key>CFBundleDisplayName</key>
  <string>Hermes Chat</string>
  <key>CFBundleIdentifier</key>
  <string>local.hermes.chat.launcher</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>HermesChat</string>
  <key>CFBundleIconFile</key>
  <string>HermesChat</string>
  <key>LSMinimumSystemVersion</key>
  <string>10.15</string>
  <key>LSUIElement</key>
  <false/>
</dict>
</plist>
PLIST

cat > "$APP_PATH/Contents/MacOS/HermesChat" <<'SH'
#!/usr/bin/env bash
exec "$HOME/bin/hermes-chat-launcher.sh"
SH
chmod +x "$APP_PATH/Contents/MacOS/HermesChat"
xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true
touch "$APP_PATH"

echo "Installed $APP_PATH"
echo "Installed $LAUNCHER_DEST"
