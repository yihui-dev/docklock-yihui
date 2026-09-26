#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Move Dock to Display
# @raycast.mode silent
# @raycast.argument1 { "type": "text", "placeholder": "Display name" }

# Optional parameters:
# @raycast.icon 🖥️
# @raycast.packageName DockLock

name=$(osascript -l JavaScript -e 'function run(argv) { return encodeURIComponent(argv[0]) }' "$1")
open -g "docklock://moveToDisplay?name=$name"
