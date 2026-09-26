import AppKit
import ApplicationServices
import ServiceManagement
import UserNotifications

/// Localized string from Localizable.strings (English text is the key).
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Localized format string.
func LF(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: arguments)
}

enum Permissions {
    static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that offers to open Privacy & Security › Accessibility.
    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openDesktopAndDockSettings() {
        let candidates = ["x-apple.systempreferences:com.apple.Desktop-Settings.extension",
                          "x-apple.systempreferences:com.apple.preference.dock"]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) { return }
        }
    }

    static func openDisplaysSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("DockLock: could not change login item: \(error.localizedDescription)")
            return false
        }
    }
}

enum Notifier {
    static func post(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}

/// Persists `DockLockSettings` as one JSON document in the app's defaults.
enum SettingsStore {
    private static let key = "settings.v1"

    static func load() -> DockLockSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? DockLockSettings.decode(data) else { return DockLockSettings() }
        return settings
    }

    static func save(_ settings: DockLockSettings) {
        guard let data = try? settings.encoded() else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Remembers that DockLock (not the user) switched on Dock auto-hide, so it can be restored
    /// even after a crash.
    static var autoHideEnabledByDockLock: Bool {
        get { UserDefaults.standard.bool(forKey: "autoHideEnabledByDockLock") }
        set { UserDefaults.standard.set(newValue, forKey: "autoHideEnabledByDockLock") }
    }
}

/// Decides whether the Dock should currently be hidden for a meeting / screen sharing.
final class MeetingMonitor {
    /// Called with a human-readable reason while hiding is needed, nil otherwise.
    var onChange: ((String?) -> Void)?
    private(set) var reason: String?

    private var watchScreenSharing = false
    private var bundleIDs: Set<String> = []
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.evaluate()
            })
        }
    }

    deinit {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    func configure(screenSharing: Bool, bundleIDs: [String]) {
        watchScreenSharing = screenSharing
        self.bundleIDs = Set(bundleIDs)
        timer?.invalidate()
        timer = nil
        if screenSharing {
            let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.evaluate() }
            timer.tolerance = 0.5
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        evaluate()
    }

    func evaluate() {
        var newReason: String?
        if watchScreenSharing && ScreenCaptureDetector.isCapturing() {
            newReason = L("Screen sharing or recording")
        } else if !bundleIDs.isEmpty,
                  let app = NSWorkspace.shared.runningApplications.first(where: { bundleIDs.contains($0.bundleIdentifier ?? "") }) {
            newReason = app.localizedName ?? app.bundleIdentifier
        }
        if newReason != reason {
            reason = newReason
            onChange?(newReason)
        }
    }
}
