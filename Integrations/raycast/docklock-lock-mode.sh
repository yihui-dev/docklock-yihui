#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Dock Lock Mode
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📌
# @raycast.packageName DockLock

open -g "docklock://setMode?mode=lock-selected"
