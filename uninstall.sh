#!/bin/bash
# Revert what install.sh did to an app.
# Usage: sudo ./uninstall.sh /Applications/SomeApp.app
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "usage: sudo $0 /Applications/SomeApp.app" >&2
  exit 1
fi
APP="$(cd "$APP" && pwd)"
PLIST="$APP/Contents/Info.plist"
BUNDLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$PLIST" 2>/dev/null \
          || basename "$APP" .app)"
SLUG="$(echo "$BUNDLE" | tr '[:upper:] ' '[:lower:]-')"
DYLIB="/usr/local/lib/dockless-$SLUG.dylib"

echo "==> Removing LSEnvironment from Info.plist"
/usr/libexec/PlistBuddy -c "Delete :LSEnvironment" "$PLIST" 2>/dev/null || true

echo "==> Removing dylib"
rm -f "$DYLIB"

echo "==> Re-signing app ad-hoc"
codesign --force --deep --sign - "$APP"

echo "==> Refreshing LaunchServices + Dock"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
killall Dock 2>/dev/null || true

echo "==> Done. The app's Dock icon returns on next launch."
echo "   (For a fully pristine bundle, reinstall the app so its original"
echo "    Developer ID signature is restored.)"
