# How DockLock works

[简体中文](ARCHITECTURE.zh-CN.md)

## Why the Dock jumps

With "Displays have separate Spaces" on (the macOS default), pushing the pointer against the very last row of pixels
at a display's Dock edge makes macOS move the Dock to that display. Only genuine pointer input triggers it, and there's
no public API to put the Dock on a given display.

## Edge guard (stopping the jumps)

`PointerGuard` runs a session-level `CGEventTap` on its own thread, which needs the Accessibility permission. It watches
pointer-moved and dragged events. `DockPolicy` decides which displays the Dock may **not** use, and
`EdgeGuardPlanner` builds clamp zones (`ClampZone`) along their Dock edges:

- **Only free edges are guarded.** Where another display touches the edge (stacked displays), that stretch is the
  pointer's route between screens and is never blocked.
- **Clamping.** An event that lands inside a zone has its location pulled back to `guardBand` points (3 by default)
  from the edge, so the pointer never reaches the trigger row. Movement along the edge isn't affected.
- **Bypass modifier.** While the configured modifiers are held, events pass untouched. DockLock records this, so a
  deliberate jump is treated as a manual placement.
- **Hot corners** get a short grace period (0.3 s by default), so they keep working.

Each event costs a handful of comparisons (`PointerClampEngine`, which is pure and unit-tested). When there's nothing
to guard, the tap is removed.

## Where the Dock is

`DockInspector` reads the Dock's frame with HIServices' `CoreDockGetRect`, resolved at runtime with `dlsym`, and falls
back to the Dock's accessibility tree. `DockLocator` picks the display whose Dock edge is closest to that frame, which
also works while the Dock is auto-hidden and off-screen.

## Moving the Dock

`DockMover` reproduces a real "push against the edge", but only while the pointer is at rest, no menu is open and the
screen is unlocked. It moves the pointer next to the target display's free edge and tries two strategies in turn:

1. **`hid-relative-push`.** Relative motion posted through IOKit `IOHIDPostEvent`, which takes the same HID path as a
   physical mouse. This is verified on macOS 15.
2. **`synthetic-push`.** Mouse-moved `CGEvent`s posted at the HID level.

Each attempt is verified by reading where the Dock actually is. The pointer is then put back, and the strategy that
worked is remembered and tried first next time. If every strategy fails, a hint appears on the target display. At that
point every other display is guarded, so a single push by the user can only bring the Dock there.

## State and commands

- `AppController` is the single source of truth and is used only on the main thread. The menu, hot keys, URL scheme,
  CLI and Shortcuts all end up executing the same `DockCommand`.
- Settings are one JSON document in `UserDefaults` (`settings.v1`). Allowed displays are stored per `ArrangementKey`,
  the set of connected display UUIDs.
- The CLI is the app's own executable. Run with a subcommand, it talks to the running app over a `CFMessagePort`
  (`dev.yihui.docklock.control`).
- The UI (AppKit menu + SwiftUI settings) is localized through `Localizable.strings` in 10 languages. English text is
  the key.

## Tests

- `DockLockCore/Tests`: geometry, clamp zones, policy, command parsing and settings compatibility. They run on macOS and
  Linux.
- `Tests/E2E/run_e2e.sh`: in CI, adds a virtual second display (`CGVirtualDisplay`) and grants Accessibility, then
  verifies the guard, hiding, automatic moves and follow mode end to end. It also screenshots every settings page in
  every language.
- `Scripts/check_localization.py`: every UI string must exist in every language, with the same placeholders.
