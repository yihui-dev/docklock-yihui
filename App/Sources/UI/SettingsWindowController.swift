import AppKit
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, displays, automation, hideDock, advanced, about
    var id: String { rawValue }
}

/// Keeps the selected tab so the menu can open a specific one.
final class SettingsNavigation: ObservableObject {
    @Published var tab: SettingsTab = .general
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let navigation = SettingsNavigation()

    init(controller: AppController) {
        let root = SettingsView()
            .environmentObject(controller)
            .environmentObject(navigation)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = L("DockLock Settings")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 600))
        window.minSize = NSSize(width: 640, height: 480)
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(tab: SettingsTab?) {
        if let tab { navigation.tab = tab }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}
