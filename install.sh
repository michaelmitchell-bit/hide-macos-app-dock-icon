#!/bin/bash
# dockless — run any macOS app with no Dock icon / no Cmd-Tab entry.
#
# Usage:  sudo ./install.sh /Applications/SomeApp.app
#
# What it does:
#   1. Builds a small universal dylib that forces -[NSApplication
#      setActivationPolicy:] to Accessory.
#   2. Installs it to /usr/local/lib/dockless-<bundlename>.dylib
#   3. Adds LSEnvironment -> DYLD_INSERT_LIBRARIES to the app's Info.plist so it
#      loads on every launch.
#   4. Ad-hoc re-signs the app (dropping hardened runtime so DYLD injection is
#      honored) and refreshes LaunchServices.
#
# Caveats:
#   * Re-signing changes the app's code identity, so macOS may ask you to
#     re-grant Privacy permissions (Screen Recording, Accessibility, etc.).
#   * An app auto-update overwrites Info.plist and reverts this. Use
#     launchagent/ to reapply automatically, or just re-run this script.
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
SRC="$(cd "$(dirname "$0")" && pwd)/src/dockless.m"

echo "==> Target : $APP"
echo "==> Dylib  : $DYLIB"

# Re-signing ad-hoc drops the developer's Team ID. Apps that keep logins in a
# Keychain access group or share an app group can no longer read them.
ENTS="$(codesign -d --entitlements - --xml "$APP" 2>/dev/null || true)"
RISKY=()
for key in keychain-access-groups com.apple.security.application-groups \
           com.apple.security.app-sandbox; do
  [[ "$ENTS" == *"<key>$key</key>"* ]] && RISKY+=("$key")
done
if (( ${#RISKY[@]} )); then
  echo "!!  This app uses: ${RISKY[*]}"
  echo "!!  Re-signing may log you out or break it (you may need to reinstall it)."
  if [[ -t 0 ]]; then
    read -r -p "    Continue anyway? [y/N] " reply
    [[ "$reply" == [yY]* ]] || { echo "Aborted."; exit 1; }
  fi
fi

echo "==> Building dylib"
mkdir -p /usr/local/lib
clang -arch arm64 -arch x86_64 -dynamiclib \
      -framework AppKit -framework Foundation -o "$DYLIB" "$SRC"
codesign --force --sign - "$DYLIB"

echo "==> Wiring LSEnvironment into Info.plist"
/usr/libexec/PlistBuddy -c "Delete :LSEnvironment" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :LSEnvironment dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :LSEnvironment:DYLD_INSERT_LIBRARIES string $DYLIB" "$PLIST"

echo "==> Ad-hoc re-signing app"
codesign --force --deep --sign - --preserve-metadata=entitlements "$APP"
codesign --verify --verbose "$APP" >/dev/null && echo "   signature OK"

echo "==> Refreshing LaunchServices + Dock"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
killall Dock 2>/dev/null || true

echo "==> Done. Restart the app. Verify with:"
echo "     lsappinfo info -app \"$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")\" | grep type="
echo "   Expect type=\"UIElement\" (was \"Foreground\")."
