#!/bin/bash
# Captures every settings page (per language and appearance) into ./screenshots for review.
# Usage: screenshots.sh <DockLock.app> <e2e_tool> [languages…]
set -uo pipefail
APP="$1"; TOOL="$2"; shift 2
LANGS=("${@:-en}")
BIN="$APP/Contents/MacOS/DockLock"
mkdir -p screenshots
for lang in "${LANGS[@]}"; do
  for style in Light Dark; do
    "$BIN" quit >/dev/null 2>&1; sleep 1
    args=(-AppleLanguages "($lang)")
    [ "$style" = Dark ] && args+=(-DockLockAppearance dark) || args+=(-DockLockAppearance light)
    open -g "$APP" --args "${args[@]}"
    for i in $(seq 1 30); do "$BIN" mode >/dev/null 2>&1 && break; sleep 1; done
    for tab in general displays automation hideDock advanced about; do
      open -g "docklock://settings?tab=$tab"
      sleep 1.5
      wid=$("$TOOL" windows DockLock | head -1)
      [ -n "$wid" ] && screencapture -o -x -l "$wid" "screenshots/$lang-$style-$tab.png"
    done
  done
done
"$BIN" quit >/dev/null 2>&1
ls -la screenshots
