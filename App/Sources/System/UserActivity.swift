import AppKit
import CoreGraphics
import IOKit

/// Answers "is it a good moment to move the pointer?".
enum UserActivity {
    private static let pointerEvents: [CGEventType] = [
        .mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged,
        .rightMouseDown, .rightMouseUp, .rightMouseDragged,
        .otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel,
    ]

    /// Seconds since the user last touched the mouse / trackpad.
    static func secondsSincePointerActivity() -> TimeInterval {
        pointerEvents
            .map { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) }
            .min() ?? .greatestFiniteMagnitude
    }

    static var anyMouseButtonDown: Bool { NSEvent.pressedMouseButtons != 0 }

    /// A menu (including the menu bar, status items and Control Center) is open. The Dock
    /// does not react to the pointer while a menu tracks it.
    static func isMenuOpen() -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else { return false }
        let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        return windows.contains { ($0[kCGWindowLayer as String] as? Int) == menuLevel }
    }

    static func isScreenLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        if let locked = session["CGSSessionScreenIsLocked"] as? Bool, locked { return true }
        if let onConsole = session["kCGSSessionOnConsoleKey"] as? Bool, !onConsole { return true }
        return false
    }
}

/// Screen capture detection (screen sharing, recording, some meeting apps).
enum ScreenCaptureDetector {
    private typealias IsWatcherPresentFn = @convention(c) () -> Bool

    private static let handle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private static let isWatcherPresent: IsWatcherPresentFn? = {
        _ = handle
        guard let pointer = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSIsScreenWatcherPresent") else { return nil }
        return unsafeBitCast(pointer, to: IsWatcherPresentFn.self)
    }()

    static var isAvailable: Bool { isWatcherPresent != nil }

    static func isCapturing() -> Bool {
        isWatcherPresent?() ?? false
    }
}

/// Posts pointer motion through the HID system (IOKit), which reaches the window server the
/// way hardware input does. Used as one of the Dock relocation strategies.
final class HIDEventPoster {
    static let shared: HIDEventPoster? = HIDEventPoster()

    private typealias PostFn = @convention(c) (UInt32, UInt32, UInt32, UnsafeRawPointer?, UInt32, UInt32, UInt32) -> Int32

    private let connect: UInt32
    private let post: PostFn

    private init?() {
        _ = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY)
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "IOHIDPostEvent") else { return nil }
        post = unsafeBitCast(symbol, to: PostFn.self)
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var handle: io_connect_t = 0
        // 1 = kIOHIDParamConnectType
        guard IOServiceOpen(service, mach_task_self_, 1, &handle) == KERN_SUCCESS else { return nil }
        connect = handle
    }

    /// Moves the pointer by (dx, dy) points, like a physical mouse would.
    @discardableResult
    func postRelativeMove(dx: Int32, dy: Int32) -> Bool {
        // NXEventData.mouseMove starts with SInt32 dx, SInt32 dy; the rest stays zero.
        var data = [UInt8](repeating: 0, count: 128)
        data.withUnsafeMutableBytes { raw in
            raw.storeBytes(of: dx, toByteOffset: 0, as: Int32.self)
            raw.storeBytes(of: dy, toByteOffset: 4, as: Int32.self)
        }
        let result = data.withUnsafeBytes { raw in
            // 5 = NX_MOUSEMOVED, 2 = kNXEventDataVersion, 4 = kIOHIDSetRelativeCursorPosition.
            // The IOGPoint location (ignored for relative moves) is passed as a packed 32-bit value.
            post(connect, 5, 0, raw.baseAddress, 2, 0, 4)
        }
        return result == KERN_SUCCESS
    }
}
