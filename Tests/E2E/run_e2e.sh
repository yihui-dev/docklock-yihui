#!/bin/bash
# End-to-end check on a CI runner: add a virtual second display, grant DockLock Accessibility
# through the TCC database (CI runners have SIP disabled), and verify that the pointer guard
# keeps the pointer off the bottom edge of the display the Dock is not allowed on.
set -uo pipefail
APP="${1:?path to DockLock.app}"
BIN="$APP/Contents/MacOS/DockLock"
HERE="$(cd "$(dirname "$0")" && pwd)"
TOOL="$PWD/e2e_tool"
fail() { echo "E2E FAIL: $*"; exit 1; }

sw_vers
csrutil status || true
clang -fobjc-arc -framework Foundation -framework CoreGraphics -framework ApplicationServices \
  "$HERE/e2e_tool.m" -o "$TOOL" || fail "could not build e2e_tool"

# Grant Accessibility (and event posting) to DockLock and the helper tool.
TCC="/Library/Application Support/com.apple.TCC/TCC.db"
NOW=$(date +%s)
for service in kTCCServiceAccessibility kTCCServicePostEvent; do
  sudo sqlite3 "$TCC" "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, policy_id, indirect_object_identifier_type, indirect_object_identifier, indirect_object_code_identity, flags, last_modified) VALUES ('$service', 'dev.yihui.docklock', 0, 2, 4, 1, NULL, NULL, 0, 'UNUSED', NULL, 0, $NOW);" \
    || echo "::warning::TCC insert failed for DockLock ($service)"
  for client in "$BIN" "$TOOL"; do
    sudo sqlite3 "$TCC" "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, policy_id, indirect_object_identifier_type, indirect_object_identifier, indirect_object_code_identity, flags, last_modified) VALUES ('$service', '$client', 1, 2, 4, 1, NULL, NULL, 0, 'UNUSED', NULL, 0, $NOW);" \
      || echo "::warning::TCC insert failed for $client ($service)"
  done
done

# Second display.
"$TOOL" vdisplay > vdisplay.log 2>&1 &
VPID=$!
for i in $(seq 1 20); do grep -q ready vdisplay.log && break; sleep 1; done
cat vdisplay.log
grep -q ready vdisplay.log || { echo "::warning::virtual display unavailable on this runner — skipping E2E"; exit 0; }
"$TOOL" displays
VID=$(awk '/^created/{print $2}' vdisplay.log)
read -r _ VX VY VW VH _ < <("$TOOL" displays | awk -v id="$VID" '$1==id')
read -r _ MX MY MW MH _ < <("$TOOL" displays | awk '/main/')
echo "virtual #$VID at $VX,$VY ${VW}x$VH; main at $MX,$MY ${MW}x$MH"

# Start DockLock (default: the Dock is allowed only where it is now, i.e. the main display).
open -g "$APP"
for i in $(seq 1 30); do "$BIN" mode >/dev/null 2>&1 && break; sleep 1; done
sleep 3
"$BIN" status
"$TOOL" dock

STATUS_JSON=$("$BIN" status --json)
echo "$STATUS_JSON" | grep -q '"accessibilityGranted" : true' || { echo "::warning::Accessibility could not be granted on this runner — skipping guard checks"; "$BIN" quit; kill $VPID; exit 0; }
echo "$STATUS_JSON" | grep -q '"guardActive" : true' || fail "guard is not active with two displays"

# 1. Pointer pushed to the bottom row of the guarded (virtual) display is held 3 pt above it.
X=$((VX + VW / 2)); Y=$((VY + VH - 1))
read -r PX PY < <("$TOOL" post "$X" "$Y")
echo "guarded display: asked $X,$Y -> pointer at $PX,$PY"
awk -v y="$PY" -v max="$((VY + VH))" 'BEGIN { exit !(y <= max - 3 + 0.01) }' || fail "pointer reached the bottom edge of the guarded display"

# 2. The allowed (main) display's bottom edge stays reachable.
X=$((MX + MW / 2)); Y=$((MY + MH - 1))
read -r PX PY < <("$TOOL" post "$X" "$Y")
echo "allowed display: asked $X,$Y -> pointer at $PX,$PY"
awk -v y="$PY" -v want="$Y" 'BEGIN { exit !(y >= want - 0.01) }' || fail "the allowed display's edge was blocked"

# 3. Crossing between the displays is never blocked.
read -r PX PY < <("$TOOL" post "$((VX + 50))" "$((VY + 300))")
echo "crossing: pointer at $PX,$PY"
awk -v x="$PX" -v vx="$VX" 'BEGIN { exit !(x >= vx) }' || fail "pointer could not cross to the other display"

# 4. Disabling DockLock releases the edge.
"$BIN" disable
sleep 1
read -r PX PY < <("$TOOL" post "$((VX + VW / 2))" "$((VY + VH - 1))")
echo "disabled: pointer at $PX,$PY"
awk -v y="$PY" -v want="$((VY + VH - 1))" 'BEGIN { exit !(y >= want - 0.01) }' || fail "edge still guarded while disabled"
"$BIN" enable
sleep 1

# 5. Hiding the Dock guards every display, including the allowed one.
"$BIN" hide on
sleep 1
read -r PX PY < <("$TOOL" post "$((MX + MW / 2))" "$((MY + MH - 1))")
echo "hidden: pointer at $PX,$PY"
awk -v y="$PY" -v max="$((MY + MH))" 'BEGIN { exit !(y <= max - 3 + 0.01) }' || fail "main display not guarded while the Dock is hidden"
"$BIN" hide off
sleep 1

echo "E2E guard checks passed"

# Informational: can the Dock be moved automatically on this macOS version / VM?
"$BIN" move "#2" && echo "MOVE RESULT: moved to the virtual display" || echo "MOVE RESULT: automatic move not accepted here"
"$TOOL" dock
"$BIN" move main && echo "MOVE BACK RESULT: ok" || echo "MOVE BACK RESULT: not accepted"
"$BIN" status

# Informational: "Dock follows mouse" between two allowed displays.
"$BIN" allow --display "#2" on
"$BIN" mode follows-mouse
"$TOOL" post "$((VX + VW / 2))" "$((VY + VH / 2))" >/dev/null
FOLLOWED=no
for i in $(seq 1 20); do
  [ "$("$BIN" display)" = "DockLock E2E Display" ] && { FOLLOWED=yes; break; }
  sleep 1
done
echo "FOLLOW RESULT: Dock followed the pointer to the virtual display: $FOLLOWED"
"$TOOL" dock
"$BIN" mode lock-selected

"$BIN" quit
kill $VPID 2>/dev/null
exit 0
