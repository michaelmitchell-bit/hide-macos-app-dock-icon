#!/bin/bash
# Install a root LaunchDaemon that watches an app bundle and re-runs the
# dockless injection whenever an app update wipes it out.
#
# Usage: sudo ./launchagent/setup-autoreapply.sh /Applications/SomeApp.app
#
# (Must be a LaunchDaemon, not a user LaunchAgent, because reapplying edits a
#  root-owned bundle and re-signs it — that needs root without a password prompt.)
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "usage: sudo $0 /Applications/SomeApp.app" >&2
  exit 1
fi
APP="$(cd "$APP" && pwd)"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="$APP/Contents/Info.plist"
BUNDLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$PLIST" 2>/dev/null || basename "$APP" .app)"
SLUG="$(echo "$BUNDLE" | tr '[:upper:] ' '[:lower:]-')"
LABEL="com.dockless-agent.$SLUG"
DAEMON="/Library/LaunchDaemons/$LABEL.plist"

cat > "$DAEMON" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$REPO/launchagent/reapply.sh</string>
    <string>$APP</string>
    <string>$REPO</string>
  </array>
  <key>WatchPaths</key>
  <array>
    <string>$APP/Contents/Info.plist</string>
    <string>$APP/Contents/MacOS</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF

chown root:wheel "$DAEMON"
chmod 644 "$DAEMON"
launchctl bootout system "$DAEMON" 2>/dev/null || true
launchctl bootstrap system "$DAEMON"
echo "Installed + loaded $DAEMON"
echo "It will re-apply dockless to $APP whenever the app updates."
echo "Remove with: sudo launchctl bootout system \"$DAEMON\" && sudo rm \"$DAEMON\""
