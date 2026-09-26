import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController { AppController.shared }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ensureSingleInstance() else { return }
        warnAboutConflictingApps()
        controller.start()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(controller.handle(url:))
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller.showSettings()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.shutdown()
    }

    /// Only one copy may drive the pointer guard.
    private func ensureSingleInstance() -> Bool {
        let me = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0.processIdentifier != me }
        guard let other = others.first else { return true }
        other.activate(options: [])
        let alert = NSAlert()
        alert.messageText = L("DockLock is already running")
        alert.informativeText = L("Use the DockLock icon in the menu bar. Only one copy can run at a time.")
        alert.runModal()
        NSApp.terminate(nil)
        return false
    }

    /// The commercial DockLock apps use the same technique; two copies would fight over the pointer.
    private func warnAboutConflictingApps() {
        let running = NSWorkspace.shared.runningApplications.filter {
            DockLockInfo.conflictingBundleIdentifiers.contains($0.bundleIdentifier ?? "")
        }
        guard !running.isEmpty else { return }
        let names = running.compactMap(\.localizedName).joined(separator: ", ")
        let alert = NSAlert()
        alert.messageText = LF("%@ is running", names)
        alert.informativeText = L("Running two Dock lockers at the same time makes them fight over the Dock. Quit the other app (and remove it from Login Items) to use DockLock.")
        alert.addButton(withTitle: L("Quit the Other App"))
        alert.addButton(withTitle: L("Keep Both"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            running.forEach { $0.terminate() }
        }
    }
}
