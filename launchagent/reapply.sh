#!/bin/bash
# Reapply the dockless injection if it's missing (e.g. after an app update
# overwrote Info.plist). Invoked by the LaunchDaemon set up by
# setup-autoreapply.sh. Runs as root.
set -euo pipefail
APP="${1:-}"
REPO="${2:-}"
[[ -d "$APP" && -x "$REPO/install.sh" ]] || exit 0
PLIST="$APP/Contents/Info.plist"

# Already injected? nothing to do.
if /usr/libexec/PlistBuddy -c "Print :LSEnvironment:DYLD_INSERT_LIBRARIES" "$PLIST" >/dev/null 2>&1; then
  exit 0
fi

# Injection missing -> reapply.
bash "$REPO/install.sh" "$APP"
