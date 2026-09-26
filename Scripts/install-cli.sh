#!/bin/bash
# Creates the `docklock` command (a symlink to the app's executable).
set -euo pipefail
APP="${1:-/Applications/DockLock.app}"
BIN="$APP/Contents/MacOS/DockLock"
test -x "$BIN" || { echo "DockLock.app not found at $APP"; exit 1; }
sudo mkdir -p /usr/local/bin
sudo ln -sf "$BIN" /usr/local/bin/docklock
echo "Installed: /usr/local/bin/docklock -> $BIN"
docklock --version
