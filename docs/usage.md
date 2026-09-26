# DockLock User Guide

[简体中文](usage.zh-CN.md) · [README](../README.md)

This guide covers everything DockLock can do. If you only want to stop the Dock from jumping between displays,
[Quick start](#quick-start) is all you need.

- [Requirements](#requirements)
- [Install](#install)
- [Quick start](#quick-start)
- [The menu bar menu](#the-menu-bar-menu)
- [Settings](#settings)
  - [General](#general) · [Displays](#displays) · [Automation](#automation) · [Hide Dock](#hide-dock) · [Advanced](#advanced)
- [Recipes](#recipes)
- [Automation reference](#automation-reference)
  - [URL scheme](#url-scheme) · [Command line](#command-line) · [Shortcuts & Siri](#shortcuts--siri) · [Hot keys](#hot-keys) · [Raycast](#raycast)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)

---

## Requirements

- macOS 13 Ventura or later, Apple silicon or Intel.
- Two or more displays for Dock locking (hiding the Dock also works with one).
- **System Settings › Desktop & Dock › “Displays have separate Spaces”** turned on. This is the macOS default. It's also
  the only mode in which macOS moves the Dock between displays, so it's the only mode where locking is needed.

## Install

1. Download `DockLock.dmg` (or `DockLock.zip`) from the [Releases](https://github.com/yihui-dev/docklock-yihui/releases) page.
   The latest development build is attached to every run in **Actions › Build**.
2. Drag **DockLock** into **Applications**.
3. DockLock is signed ad hoc, not notarized by Apple, so macOS blocks the first launch. Either right-click the app and
   choose **Open**, or run:

   ```bash
   xattr -dr com.apple.quarantine /Applications/DockLock.app
   open /Applications/DockLock.app
   ```

To build it yourself you need Xcode 15 or later: `git clone`, then `Scripts/build.sh --install` (or open
`DockLock.xcodeproj` and press ⌘R).

## Quick start

1. **Grant Accessibility access.** On first launch DockLock shows a short walkthrough. Click **Open Accessibility
   Settings** and switch on **DockLock** under *Privacy & Security › Accessibility*. If it isn't in the list, click
   **+** and add `/Applications/DockLock.app`. DockLock notices the change within a few seconds, so there's no need to
   restart it.
2. **Choose the display for the Dock.** Open the DockLock menu in the menu bar and, under **Allow Dock on Display**,
   check only the display that should have the Dock. By default only the display the Dock is on now is checked.
3. That's it. Push the pointer against the bottom of any other display: the Dock stays where it is.

> DockLock keeps the pointer 2–3 points away from the Dock edge of every display the Dock isn't allowed on. macOS only
> moves the Dock when the pointer is pushed against the very last row of pixels, so it never happens. Moving the pointer
> between displays isn't affected. On stacked displays, the stretch of edge where one display touches another is left
> open, because that's the path the pointer takes between them.

## The menu bar menu

| Item | What it does |
|---|---|
| Status line | What DockLock is doing, e.g. *Dock locked · on Studio Display* |
| **Enable Dock Locking** (⌘L) | Master switch |
| **Mode ›** | Lock to allowed displays / Dock follows mouse / follows active window / follows apps |
| **Allow Dock on Display** | Check the displays the Dock may use. Uncheck all of them to keep the Dock hidden everywhere |
| **Move Dock To ›** | Move the Dock to a display by name, to the left/right/above/below, to the pointer's display, or to its home display |
| **Release Dock from …** | Shown after a manual move; returns to normal locking |
| **Hide Dock on All Displays** | Meeting / presentation mode |
| **Pause Locking ›** | For 5 min, 15 min, 1 hour, or until resumed |
| **Settings…** (⌘,) · **Restart Dock** · **About** · **Quit** | |

The icon shows the state: a lock means locked, an arrow means following, a pause sign means paused, a slashed Dock
means hidden, and **!** means DockLock needs Accessibility access.

## Settings

### General

- **Status card.** Shows the current state and has the master switch.
- **Mode**
  - **Lock to Allowed Displays.** The Dock stays on the allowed displays and never jumps anywhere else.
  - **Dock Follows Mouse.** The Dock moves to the allowed display where the pointer comes to rest.
  - **Dock Follows Active Window.** The Dock moves to the display of the window you're working in.
  - **Dock Follows Apps When Active.** When you switch apps, the Dock moves to that app's display, or to a display you
    assigned to the app under *Automation*.

  Every mode only uses displays checked under *Displays*. A deliberate move (menu, hot key, Shortcuts, URL, command
  line) holds the Dock on the chosen display until the display arrangement changes.
- **Allow Dock jumping while holding.** While you hold these keys (⌥⌘, for example), the Dock can move the usual way
  to any display. If the Dock ends up on a display that isn't allowed, DockLock keeps it there instead of moving it
  back. Shift alone isn't recommended: typing with the pointer near the bottom edge can then move the Dock by accident.
- **App.** Launch at login, menu bar icon, Dock icon, and **Language**. The language can be *System Default* or one of
  10 languages; restart DockLock to apply the change.

  If you hide the menu bar icon, open DockLock again from Finder, Spotlight or Launchpad to get back to Settings.

### Displays

- **Arrangement map.** A live picture of your displays. Blue displays may have the Dock and grey ones may not. An
  orange line marks a guarded edge, and a small Dock marks where the Dock is now. Click a display to allow or block
  it. Right-click it for **Move Dock Here**, **Set as Home Display** and **Allow/Disallow**.
- **Display list.** The same switches, with badges: *Dock* (it's here now), *Home* (where it returns to), *Main*,
  and *Held* (after a manual move).
- **Remembered arrangements.** Allowed displays are saved separately for every combination of connected displays, for
  example "laptop only", "laptop + office monitor" and "laptop + two monitors at home". Old combinations can be
  forgotten here.

### Automation

- **Hot keys.** Global shortcuts for:
  - toggling locking;
  - moving the Dock left, right, up or down, to the pointer's display, or home;
  - hiding the Dock;
  - cycling modes.

  They're off by default. Switch one on, click its shortcut to record a new one (Esc cancels).
- **Apps.** Rules for *Follows Apps* and *Follows Active Window*: for each app choose *Its window's display*, a fixed
  display, or *Ignore this app*.
- **Shortcuts, URL scheme and command line.** Examples, plus a button that copies the command installing the
  `docklock` command.

### Hide Dock

- **Hide the Dock on all displays now.** Every display's Dock edge is guarded, so the Dock can't pop up.
- **Turn on Dock auto-hide while hidden.** A Dock that's always visible would stay on screen, so DockLock switches on
  macOS auto-hide while hiding and restores your setting afterwards (even after a crash).
- **Hide automatically:**
  - while the screen is being shared or recorded;
  - while any selected app is running. Presets cover Zoom, Microsoft Teams, Webex, FaceTime, Tencent Meeting, WeCom,
    DingTalk, Feishu/Lark, Discord, OBS and more, and you can add your own.

### Advanced

- **Moving the Dock back:**
  - Automatically return the Dock after sleep, display changes or a Dock restart.
  - How long the pointer must rest first (default 1.5 s), and the delay for follow modes (default 1 s).
  - An on-screen hint and a notification if a move fails.
  - The move method that worked on this Mac.
- **Edge guard:**
  - How far the pointer is kept from the edge (default 3 pt).
  - Hot corners on guarded displays stay usable: the pointer may reach a corner for a short grace period (default 0.3 s).
- **Troubleshooting:** Restart Dock, open Accessibility or Displays settings, copy diagnostics, forget the learned
  method, and reset all settings.

## Recipes

**Keep the Dock on my external monitor, never on the laptop**
Allow only the external monitor. With the laptop's lid closed, a different arrangement is used and remembered
separately.

**Dock on the laptop when on the go, on the big monitor at the desk**
Nothing to do. Each display combination remembers its own allowed displays. Set them once in each place.

**Two monitors: let the Dock move only when I want**
Allow one monitor and set *Allow Dock jumping while holding* to ⌥⌘. Hold ⌥⌘ and push the pointer down to move the
Dock deliberately.

**The Dock should follow me between two monitors**
Allow both, choose **Dock Follows Mouse**, and adjust the follow delay under *Advanced* if needed.

**Presentations and screen sharing**
Turn on *While the screen is being shared or recorded* under **Hide Dock**, or bind **Hide / show the Dock** to a hot
key.

**Zoom always on the left monitor, with the Dock next to it**
Choose **Dock Follows Apps When Active**, add Zoom under *Automation › Apps*, and pick the left display.

## Automation reference

### URL scheme

`docklock://` URLs work from Shortcuts, Raycast, Alfred, a browser, `open` in Terminal, and so on. Every DockLock Plus
`DockLockPlus://` URL is also accepted.

| URL | Action |
|---|---|
| `docklock://enableDockLock` / `disableDockLock` / `toggleDockLock` | Locking on / off / toggle |
| `docklock://setMode?mode=lock-selected\|follows-mouse\|follows-window\|follows-apps\|disabled` | Set the mode |
| `docklock://enableDockFollowsMouse` / `disableDockFollowsMouse` | Follow mouse on / off |
| `docklock://enableDockFollowsActiveWindow` / `disableDockFollowsActiveWindow` | Follow window on / off |
| `docklock://enableDockFollowsApps` / `disableDockFollowsApps` | Follow apps on / off |
| `docklock://moveDockLeft` / `moveDockRight` / `moveDockUp` / `moveDockDown` | Move to the neighbouring display |
| `docklock://moveToDisplay?name=Studio%20Display` | Move to a display by name (also UUID, `#2`, `main`, `builtin`) |
| `docklock://moveToDisplay?x=1920&y=200` | Move to the display containing a point |
| `docklock://moveDockToPointer` / `moveDockHome` | Move to the pointer's display / home display |
| `docklock://enableDockLockOnDisplay?name=…` / `disableDockLockOnDisplay?x=…&y=…` | Allow / disallow a display |
| `docklock://hideDock` / `showDock` / `toggleHideDock` | Hide the Dock everywhere |
| `docklock://pause?minutes=15` / `pause` / `resume` | Pause for a while / until resumed / resume |
| `docklock://settings?tab=displays` | Open Settings (tabs: `general`, `displays`, `automation`, `hideDock`, `advanced`, `about`) |
| `docklock://restartDock` / `quit` | Restart the Dock / quit DockLock |

Coordinates are in points, with 0,0 at the top-left corner of the main display (`x=1&y=1` is the main display).

### Command line

Install the `docklock` command (a link to the app's own executable):

```bash
Scripts/install-cli.sh        # or: sudo ln -sf /Applications/DockLock.app/Contents/MacOS/DockLock /usr/local/bin/docklock
```

```text
docklock status [--json]            State, displays and where the Dock is
docklock displays [--json]          * = Dock is here, + = allowed, h = home
docklock display                    Name of the display that has the Dock
docklock mode [token]               Show or set: lock-selected | follows-mouse | follows-apps | follows-window | disabled
docklock enable | disable | toggle
docklock move left|right|up|down
docklock move <x> <y>
docklock move "<display name>"      Also a UUID, #n, main or builtin
docklock move --pointer | --home
docklock allow --display "<name>" on|off
docklock allow --xy <x> <y> on|off
docklock hide [on|off|toggle] ; docklock show
docklock pause [minutes] ; docklock resume
docklock relocate                   Move the Dock back home now
docklock settings | restart-dock | url <docklock://…>
docklock launch | quit | version | help
```

`move` waits until the Dock has actually arrived (add `--no-wait` to return immediately). Exit codes: `0` success,
`1` invalid usage, `2` command failed, `3` DockLock isn't running, `4` communication error. The syntax matches the
DockLock Plus CLI, so existing scripts keep working.

### Shortcuts & Siri

Search for **DockLock** in the Shortcuts app. The available actions are:

- Enable, disable or check DockLock.
- Enable, disable or check each follow mode: Dock Follows Mouse, Follows Active Window, and Follows Apps When Active.
- Launch or quit DockLock.
- Move the Dock to a display: by name (with a picker), to the adjacent display (left/right/up/down), at a coordinate,
  or to the display with the pointer.
- Get the display the Dock is on.
- Allow or disallow a display, by name or by coordinate.
- Hide or show the Dock on all displays.
- Move the Dock to its home display.

Moves return **true** once the Dock has arrived. Combine them with **Automation › App** (open/close Zoom, for example),
**Focus**, or keyboard shortcuts.

### Hot keys

Settings › Automation › Hot Keys. They default to ⌃⌥⌘ plus a key and are all off until you switch them on:

| Action | Default |
|---|---|
| Lock on/off | ⌃⌥⌘L |
| Move left / right / up / down | ⌃⌥⌘← / → / ↑ / ↓ |
| Move to the pointer's display | ⌃⌥⌘D |
| Move home | ⌃⌥⌘H |
| Hide / show the Dock | ⌃⌥⌘M |
| Next mode | ⌃⌥⌘U |

### Raycast

Add the `Integrations/raycast` folder in **Raycast › Extensions › Script Commands › Add Directory**. You get commands
to move the Dock left, right, up, down, here or home, move it to a named display, toggle locking, toggle hiding, and
switch between follow mouse and lock mode.

## Troubleshooting

| Problem | Fix |
|---|---|
| The Dock still jumps | Check the menu bar icon for **!** (no Accessibility access) and that *Displays have separate Spaces* is on. *Advanced › Edge Guard* should say *Active on N display(s)* |
| Locking stopped working after an update | macOS keeps the old app's permission. Remove DockLock from *Privacy & Security › Accessibility* and add it again |
| “The Dock cannot be summoned there” | Another display sits directly below that display's Dock edge; macOS can't put the Dock there |
| The Dock isn't moved back automatically | It happens only after the pointer has rested (see *Advanced*), never while a menu is open. If macOS refuses, a hint tells you to push the pointer once against the target display's edge |
| “DockLock Lite/Plus is running” | Quit the other app and remove it from *Login Items*. Two lockers fight over the Dock |
| Cmd+Tab appears on another display | The app switcher always follows the Dock; this is macOS behaviour |
| Something else | *Advanced › Copy Diagnostics* and [open an issue](https://github.com/yihui-dev/docklock-yihui/issues/new/choose) |

## Uninstall

```bash
docklock quit                                   # or quit from the menu bar
rm -rf /Applications/DockLock.app
defaults delete dev.yihui.docklock              # settings
sudo rm -f /usr/local/bin/docklock              # if you installed the command
```

Then remove DockLock from **System Settings › Privacy & Security › Accessibility** and from **Login Items**.
