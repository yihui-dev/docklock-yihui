#!/bin/bash
# Builds DockLock.app (ad-hoc signed). Usage: Scripts/build.sh [--install]
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild -project DockLock.xcodeproj -scheme DockLock -configuration Release \
  -derivedDataPath build -destination 'generic/platform=macOS' \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build | grep -E "error|warning: |BUILD" || true

APP="build/Build/Products/Release/DockLock.app"
test -d "$APP" || { echo "Build failed"; exit 1; }
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  osascript -e 'tell application "DockLock" to quit' >/dev/null 2>&1 || true
  sleep 1
  rm -rf /Applications/DockLock.app
  cp -R "$APP" /Applications/
  echo "Installed to /Applications/DockLock.app"
  echo "If Dock locking does not work after an update, remove DockLock from"
  echo "System Settings › Privacy & Security › Accessibility and add it again."
  open /Applications/DockLock.app
fi
