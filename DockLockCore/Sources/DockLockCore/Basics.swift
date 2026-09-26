import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The screen edge the Dock is attached to ("Position on screen" in System Settings).
public enum DockEdge: String, Codable, CaseIterable, Sendable {
    case bottom
    case left
    case right

    /// Maps the CoreDock orientation constant (1 top, 2 bottom, 3 left, 4 right).
    public init?(coreDockOrientation value: Int) {
        switch value {
        case 2: self = .bottom
        case 3: self = .left
        case 4: self = .right
        default: return nil
        }
    }

    /// Maps the `orientation` value stored in the `com.apple.dock` defaults domain.
    public init?(defaultsValue: String) {
        switch defaultsValue.lowercased() {
        case "bottom": self = .bottom
        case "left": self = .left
        case "right": self = .right
        default: return nil
        }
    }

    public var isVertical: Bool { self != .bottom }
}

/// A direction used to pick the neighbouring display.
public enum Direction: String, Codable, CaseIterable, Sendable {
    case left
    case right
    case up
    case down

    public init?(token: String) {
        self.init(rawValue: token.lowercased())
    }
}

/// Keyboard modifiers, independent of AppKit / CoreGraphics / Carbon encodings.
public struct ModifierSet: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let shift = ModifierSet(rawValue: 1 << 0)
    public static let control = ModifierSet(rawValue: 1 << 1)
    public static let option = ModifierSet(rawValue: 1 << 2)
    public static let command = ModifierSet(rawValue: 1 << 3)

    /// Bit masks of `CGEventFlags` (identical to `NSEvent.ModifierFlags`).
    public static let cgShiftMask: UInt64 = 0x0002_0000
    public static let cgControlMask: UInt64 = 0x0004_0000
    public static let cgOptionMask: UInt64 = 0x0008_0000
    public static let cgCommandMask: UInt64 = 0x0010_0000

    public init(cgFlags: UInt64) {
        var set: ModifierSet = []
        if cgFlags & Self.cgShiftMask != 0 { set.insert(.shift) }
        if cgFlags & Self.cgControlMask != 0 { set.insert(.control) }
        if cgFlags & Self.cgOptionMask != 0 { set.insert(.option) }
        if cgFlags & Self.cgCommandMask != 0 { set.insert(.command) }
        self = set
    }

    /// Carbon `RegisterEventHotKey` modifier bits (cmdKey, shiftKey, optionKey, controlKey).
    public var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= 1 << 8 }
        if contains(.shift) { flags |= 1 << 9 }
        if contains(.option) { flags |= 1 << 11 }
        if contains(.control) { flags |= 1 << 12 }
        return flags
    }

    /// Symbols in the conventional macOS order: ⌃⌥⇧⌘.
    public var symbols: String {
        var text = ""
        if contains(.control) { text += "⌃" }
        if contains(.option) { text += "⌥" }
        if contains(.shift) { text += "⇧" }
        if contains(.command) { text += "⌘" }
        return text
    }

    /// Choices offered for "Allow Dock jumping while holding".
    public static let bypassChoices: [ModifierSet] = [
        [], .shift, .command, .option, .control,
        [.option, .command], [.control, .option], [.control, .command], [.shift, .command],
    ]
}

/// Version information shared by the app and the CLI.
public enum DockLockInfo {
    public static let version = "1.0.0"
    public static let appName = "DockLock"
    public static let bundleIdentifier = "dev.yihui.docklock"
    /// Mach port name used by the CLI to talk to the running app.
    public static let controlPortName = "dev.yihui.docklock.control"
    /// URL schemes the app answers to. `docklockplus` keeps DockLock Plus automations working.
    public static let urlSchemes = ["docklock", "docklockplus"]
    /// Bundle identifiers of the commercial DockLock apps, which must not run at the same time.
    public static let conflictingBundleIdentifiers = ["pro.docklock.lite", "pro.docklock.plus", "pro.docklock.pro"]
}
