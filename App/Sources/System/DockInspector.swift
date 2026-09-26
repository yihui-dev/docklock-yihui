import AppKit
import ApplicationServices

/// Read-mostly access to the Dock: where it is, which edge, auto-hide, and the Spaces setting.
///
/// Uses the `CoreDock*` functions exported by HIServices (looked up at runtime, so a missing
/// symbol degrades gracefully) and falls back to the Dock's accessibility tree and defaults.
enum DockInspector {
    // MARK: CoreDock (private, resolved with dlsym)

    private typealias GetRectFn = @convention(c) (UnsafeMutablePointer<CGRect>) -> Void
    private typealias GetOrientationFn = @convention(c) (UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Void
    private typealias GetAutoHideFn = @convention(c) () -> Bool
    private typealias SetAutoHideFn = @convention(c) (Bool) -> Void

    private static let handle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY)

    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        _ = handle
        guard let pointer = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil } // RTLD_DEFAULT
        return unsafeBitCast(pointer, to: type)
    }

    private static let getRect = symbol("CoreDockGetRect", as: GetRectFn.self)
    private static let getOrientation = symbol("CoreDockGetOrientationAndPinning", as: GetOrientationFn.self)
    private static let getAutoHide = symbol("CoreDockGetAutoHideEnabled", as: GetAutoHideFn.self)
    private static let setAutoHide = symbol("CoreDockSetAutoHideEnabled", as: SetAutoHideFn.self)

    // MARK: Queries

    /// The Dock's frame in CG global coordinates.
    static func dockFrame() -> CGRect? {
        if let getRect {
            var rect = CGRect.zero
            getRect(&rect)
            if rect.width > 1, rect.height > 1 { return rect }
        }
        return accessibilityDockFrame()
    }

    static func edge() -> DockEdge {
        if let getOrientation {
            var orientation: Int32 = 0
            var pinning: Int32 = 0
            getOrientation(&orientation, &pinning)
            if let edge = DockEdge(coreDockOrientation: Int(orientation)) { return edge }
        }
        if let value = CFPreferencesCopyAppValue("orientation" as CFString, "com.apple.dock" as CFString) as? String,
           let edge = DockEdge(defaultsValue: value) {
            return edge
        }
        return .bottom
    }

    static func isAutoHideEnabled() -> Bool {
        if let getAutoHide { return getAutoHide() }
        return (CFPreferencesCopyAppValue("autohide" as CFString, "com.apple.dock" as CFString) as? Bool) ?? false
    }

    @discardableResult
    static func setAutoHideEnabled(_ enabled: Bool) -> Bool {
        if let setAutoHide {
            setAutoHide(enabled)
            return true
        }
        // Fallback: AppleScript through System Events.
        let script = "tell application \"System Events\" to set autohide of dock preferences to \(enabled)"
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        return error == nil
    }

    /// "Displays have separate Spaces" (System Settings › Desktop & Dock). On by default.
    static func displaysHaveSeparateSpaces() -> Bool {
        CFPreferencesAppSynchronize("com.apple.spaces" as CFString)
        let spans = CFPreferencesCopyAppValue("spans-displays" as CFString, "com.apple.spaces" as CFString)
        if let flag = spans as? Bool { return !flag }
        if let number = spans as? NSNumber { return number.intValue == 0 }
        return true
    }

    static var dockApplication: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
    }

    /// Restarts the Dock (launchd relaunches it immediately).
    static func restartDock() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["Dock"]
        try? task.run()
    }

    // MARK: Accessibility fallback

    private static func accessibilityDockFrame() -> CGRect? {
        guard AXIsProcessTrusted(), let dock = dockApplication else { return nil }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.25)
        guard let children = AX.children(of: app) else { return nil }
        for child in children where AX.string(child, kAXRoleAttribute) == (kAXListRole as String) {
            if let frame = AX.frame(of: child), frame.width > 1, frame.height > 1 { return frame }
        }
        return nil
    }
}

/// Small helpers over the AXUIElement C API.
enum AX {
    static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        value(element, attribute) as? String
    }

    static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let raw = value(element, attribute), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        return (raw as! AXUIElement)
    }

    static func children(of element: AXUIElement) -> [AXUIElement]? {
        guard let raw = value(element, kAXChildrenAttribute as String) as? [AnyObject] else { return nil }
        return raw.compactMap { item in
            CFGetTypeID(item) == AXUIElementGetTypeID() ? (item as! AXUIElement) : nil
        }
    }

    static func frame(of element: AXUIElement) -> CGRect? {
        guard let positionRef = value(element, kAXPositionAttribute as String),
              let sizeRef = value(element, kAXSizeAttribute as String),
              CFGetTypeID(positionRef) == AXValueGetTypeID(),
              CFGetTypeID(sizeRef) == AXValueGetTypeID() else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// Frame (CG global coordinates) of the focused window of the frontmost app, or of `pid`.
    static func focusedWindowFrame(pid: pid_t? = nil) -> CGRect? {
        guard AXIsProcessTrusted() else { return nil }
        let appElement: AXUIElement
        if let pid {
            appElement = AXUIElementCreateApplication(pid)
        } else {
            let systemWide = AXUIElementCreateSystemWide()
            guard let focusedApp = element(systemWide, kAXFocusedApplicationAttribute as String) else { return nil }
            appElement = focusedApp
        }
        AXUIElementSetMessagingTimeout(appElement, 0.3)
        let window = element(appElement, kAXFocusedWindowAttribute as String)
            ?? element(appElement, kAXMainWindowAttribute as String)
        guard let window, let frame = frame(of: window), frame.width >= 80, frame.height >= 60 else { return nil }
        return frame
    }
}
