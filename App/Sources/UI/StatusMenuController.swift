import AppKit

/// The menu bar item and its menu, rebuilt each time it opens so it always shows live state.
final class StatusMenuController: NSObject, NSMenuDelegate {
    private unowned let controller: AppController
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()

    init(controller: AppController) {
        self.controller = controller
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
    }

    func setVisible(_ visible: Bool) {
        if visible, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.menu = menu
            item.button?.toolTip = "DockLock"
            statusItem = item
            refreshIcon()
        } else if !visible, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    func refreshIcon() {
        guard let button = statusItem?.button else { return }
        let state: StatusIcon.State
        if !controller.accessibilityGranted && controller.settings.isEnabled {
            state = .attention
        } else if !controller.settings.isEnabled {
            state = .disabled
        } else if controller.isPaused {
            state = .paused
        } else if controller.isDockHidden {
            state = .hidden
        } else if controller.settings.mode.isFollowMode {
            state = .following
        } else {
            state = .locked
        }
        button.image = StatusIcon.image(for: state)
        button.toolTip = "DockLock — " + controller.statusSummary
    }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        build(menu)
        refreshIcon()
    }

    private func build(_ menu: NSMenu) {
        let c = controller
        let summary = NSMenuItem(title: c.statusSummary, action: nil, keyEquivalent: "")
        summary.isEnabled = false
        menu.addItem(summary)

        if !c.accessibilityGranted {
            menu.addItem(item(L("Grant Accessibility Access…"), #selector(openAccessibility), image: "exclamationmark.triangle.fill"))
        }
        if !c.separateSpaces {
            menu.addItem(item(L("Turn On \u{201C}Displays Have Separate Spaces\u{201D}…"), #selector(openDockSettings),
                              image: "exclamationmark.triangle"))
        }
        menu.addItem(.separator())

        let enabled = item(L("Enable Dock Locking"), #selector(toggleEnabled), key: "l")
        enabled.state = c.settings.isEnabled ? .on : .off
        menu.addItem(enabled)

        let modeItem = NSMenuItem(title: L("Mode"), action: nil, keyEquivalent: "")
        let modeMenu = NSMenu()
        for mode in DockMode.allCases {
            let entry = item(Self.title(for: mode), #selector(selectMode(_:)))
            entry.representedObject = mode.rawValue
            entry.state = c.settings.mode == mode ? .on : .off
            modeMenu.addItem(entry)
        }
        modeItem.submenu = modeMenu
        menu.addItem(modeItem)
        menu.addItem(.separator())

        let header = NSMenuItem(title: L("Allow Dock on Display"), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for display in c.layout.displays {
            var title = c.displayName(display)
            var tags: [String] = []
            if display.uuid == c.dockDisplayUUID { tags.append(L("Dock")) }
            if display.isMain { tags.append(L("Main")) }
            if !tags.isEmpty { title += "  (" + tags.joined(separator: ", ") + ")" }
            let entry = item(title, #selector(toggleAllowed(_:)))
            entry.representedObject = display.uuid
            entry.state = c.isAllowed(display) ? .on : .off
            entry.indentationLevel = 1
            menu.addItem(entry)
        }

        let moveItem = NSMenuItem(title: L("Move Dock To"), action: nil, keyEquivalent: "")
        let moveMenu = NSMenu()
        for display in c.layout.displays {
            let entry = item(c.displayName(display), #selector(moveToDisplay(_:)))
            entry.representedObject = display.uuid
            entry.state = display.uuid == c.dockDisplayUUID ? .on : .off
            moveMenu.addItem(entry)
        }
        moveMenu.addItem(.separator())
        let directions: [(Direction, String)] = [(.left, L("Display on the Left")), (.right, L("Display on the Right")),
                                                 (.up, L("Display Above")), (.down, L("Display Below"))]
        for (direction, title) in directions {
            let entry = item(title, #selector(moveDirection(_:)))
            entry.representedObject = direction.rawValue
            entry.isEnabled = c.dockDisplay.flatMap { c.layout.adjacent(to: $0, direction: direction) } != nil
            moveMenu.addItem(entry)
        }
        moveMenu.addItem(item(L("Display with the Pointer"), #selector(moveToPointer)))
        moveMenu.addItem(item(L("Home Display"), #selector(moveHome)))
        moveItem.submenu = moveMenu
        moveItem.isEnabled = c.layout.count > 1
        menu.addItem(moveItem)

        if let exclusive = c.runtime.exclusiveTarget, let display = c.layout.display(uuid: exclusive) {
            menu.addItem(item(LF("Release Dock from %@", c.displayName(display)), #selector(releasePlacement)))
        }
        menu.addItem(.separator())

        let hide = item(L("Hide Dock on All Displays"), #selector(toggleHide))
        hide.state = c.manualHide ? .on : .off
        menu.addItem(hide)

        let pauseItem = NSMenuItem(title: c.isPaused ? L("Resume Locking") : L("Pause Locking"),
                                   action: c.isPaused ? #selector(resume) : nil, keyEquivalent: "")
        pauseItem.target = self
        if !c.isPaused {
            let pauseMenu = NSMenu()
            let durations: [(Double, String)] = [(5, L("For 5 Minutes")), (15, L("For 15 Minutes")), (60, L("For 1 Hour"))]
            for (minutes, title) in durations {
                let entry = item(title, #selector(pauseFor(_:)))
                entry.representedObject = minutes
                pauseMenu.addItem(entry)
            }
            pauseMenu.addItem(item(L("Until Resumed"), #selector(pauseIndefinitely)))
            pauseItem.submenu = pauseMenu
        }
        pauseItem.isEnabled = c.settings.isEnabled
        menu.addItem(pauseItem)
        menu.addItem(.separator())

        menu.addItem(item(L("Settings…"), #selector(openSettings), key: ","))
        menu.addItem(item(L("Restart Dock"), #selector(restartDock)))
        menu.addItem(item(L("About DockLock"), #selector(openAbout)))
        menu.addItem(.separator())
        menu.addItem(item(L("Quit DockLock"), #selector(quit), key: "q"))
    }

    static func title(for mode: DockMode) -> String {
        switch mode {
        case .lock: return L("Lock to Allowed Displays")
        case .followsMouse: return L("Dock Follows Mouse")
        case .followsWindow: return L("Dock Follows Active Window")
        case .followsApps: return L("Dock Follows Apps When Active")
        }
    }

    private func item(_ title: String, _ action: Selector, key: String = "", image: String? = nil) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
        entry.target = self
        if let image { entry.image = NSImage(systemSymbolName: image, accessibilityDescription: nil) }
        return entry
    }

    // MARK: Actions

    @objc private func openAccessibility() {
        Permissions.requestAccessibility()
        Permissions.openAccessibilitySettings()
    }

    @objc private func openDockSettings() { Permissions.openDesktopAndDockSettings() }
    @objc private func toggleEnabled() { controller.execute(.toggleEnabled) }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = DockMode(rawValue: raw) else { return }
        controller.execute(.setMode(mode))
    }

    @objc private func toggleAllowed(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String, let display = controller.layout.display(uuid: uuid) else { return }
        controller.setAllowed(display, !controller.isAllowed(display))
    }

    @objc private func moveToDisplay(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String else { return }
        controller.execute(.move(.name(uuid)))
    }

    @objc private func moveDirection(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let direction = Direction(rawValue: raw) else { return }
        controller.execute(.move(.direction(direction)))
    }

    @objc private func moveToPointer() { controller.execute(.move(.pointer)) }
    @objc private func moveHome() { controller.execute(.relocateHome) }
    @objc private func releasePlacement() { controller.releaseManualPlacement() }
    @objc private func toggleHide() { controller.execute(.setHideDock(nil)) }
    @objc private func resume() { controller.execute(.resume) }

    @objc private func pauseFor(_ sender: NSMenuItem) {
        controller.execute(.pause(minutes: sender.representedObject as? Double))
    }

    @objc private func pauseIndefinitely() { controller.execute(.pause(minutes: nil)) }
    @objc private func openSettings() { controller.showSettings() }
    @objc private func openAbout() { controller.showSettings(tab: .about) }
    @objc private func restartDock() { controller.execute(.restartDock) }
    @objc private func quit() { NSApp.terminate(nil) }
}
