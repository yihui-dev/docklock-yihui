import Foundation

/// How DockLock decides where the Dock should be.
public enum DockMode: String, Codable, CaseIterable, Sendable {
    /// Keep the Dock on the allowed displays; it never jumps anywhere else.
    case lock = "lock-selected"
    /// Move the Dock to the (allowed) display the pointer rests on.
    case followsMouse = "follows-mouse"
    /// Move the Dock to the (allowed) display holding the focused window.
    case followsWindow = "follows-window"
    /// When an app becomes active, move the Dock to that app's display (or to the display a rule names).
    case followsApps = "follows-apps"

    public init?(token: String) {
        switch token.lowercased() {
        case "lock-selected", "lock", "locked", "lock_selected": self = .lock
        case "follows-mouse", "follow-mouse", "mouse", "follows_mouse": self = .followsMouse
        case "follows-window", "follow-window", "window", "follows-active-window", "follows_window": self = .followsWindow
        case "follows-apps", "follow-apps", "apps", "follows-app", "follows_apps": self = .followsApps
        default: return nil
        }
    }

    public var isFollowMode: Bool { self != .lock }
}

/// Preferences for one combination of connected displays.
public struct ArrangementPreferences: Codable, Equatable, Sendable {
    /// UUIDs of the displays the Dock may live on ("Allow Dock on Display").
    public var allowed: [String]
    /// The display the Dock returns to when it has to be moved back.
    public var home: String?
    /// Last known names, only used to describe remembered arrangements.
    public var names: [String: String]
    public var lastUsed: Date?

    public init(allowed: [String], home: String? = nil, names: [String: String] = [:], lastUsed: Date? = nil) {
        self.allowed = allowed
        self.home = home
        self.names = names
        self.lastUsed = lastUsed
    }

    public var allowedSet: Set<String> { Set(allowed) }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        allowed = try c.decodeIfPresent([String].self, forKey: .allowed) ?? []
        home = try c.decodeIfPresent(String.self, forKey: .home)
        names = try c.decodeIfPresent([String: String].self, forKey: .names) ?? [:]
        lastUsed = try c.decodeIfPresent(Date.self, forKey: .lastUsed)
    }

    private enum CodingKeys: String, CodingKey {
        case allowed, home, names, lastUsed
    }
}

/// What "Follows apps" / "Follows window" do for one particular app.
public enum AppRuleTarget: Codable, Equatable, Hashable, Sendable {
    /// Always move the Dock to this display when the app is active.
    case display(uuid: String, name: String)
    /// Move the Dock to the display showing the app's focused window.
    case appWindow
    /// Never move the Dock because of this app.
    case ignore
}

public struct AppRule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var bundleID: String
    public var appName: String
    public var target: AppRuleTarget
    public var enabled: Bool

    public init(id: UUID = UUID(), bundleID: String, appName: String, target: AppRuleTarget, enabled: Bool = true) {
        self.id = id
        self.bundleID = bundleID
        self.appName = appName
        self.target = target
        self.enabled = enabled
    }
}

public enum HotKeyAction: String, Codable, CaseIterable, Sendable {
    case toggleLock
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case moveToPointerDisplay
    case moveHome
    case toggleHideDock
    case cycleMode
}

public struct HotKeyBinding: Codable, Equatable, Sendable {
    public var action: HotKeyAction
    /// Virtual key code (kVK_*).
    public var keyCode: UInt32
    public var modifiers: ModifierSet
    public var enabled: Bool

    public init(action: HotKeyAction, keyCode: UInt32, modifiers: ModifierSet, enabled: Bool) {
        self.action = action
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.enabled = enabled
    }

    public var displayString: String { modifiers.symbols + KeyNames.name(for: keyCode) }

    /// ⌃⌥⌘ + arrows / letters. Off until the user turns them on, so nothing is grabbed unexpectedly.
    public static let defaults: [HotKeyBinding] = {
        let m: ModifierSet = [.control, .option, .command]
        return [
            HotKeyBinding(action: .toggleLock, keyCode: 37, modifiers: m, enabled: false),          // L
            HotKeyBinding(action: .moveLeft, keyCode: 123, modifiers: m, enabled: false),
            HotKeyBinding(action: .moveRight, keyCode: 124, modifiers: m, enabled: false),
            HotKeyBinding(action: .moveUp, keyCode: 126, modifiers: m, enabled: false),
            HotKeyBinding(action: .moveDown, keyCode: 125, modifiers: m, enabled: false),
            HotKeyBinding(action: .moveToPointerDisplay, keyCode: 2, modifiers: m, enabled: false), // D
            HotKeyBinding(action: .moveHome, keyCode: 4, modifiers: m, enabled: false),             // H
            HotKeyBinding(action: .toggleHideDock, keyCode: 46, modifiers: m, enabled: false),      // M
            HotKeyBinding(action: .cycleMode, keyCode: 32, modifiers: m, enabled: false),           // U
        ]
    }()
}

/// All persistent settings. Every field has a default, and decoding tolerates missing keys,
/// so settings written by older versions keep loading.
public struct DockLockSettings: Codable, Equatable, Sendable {
    // General
    public var isEnabled: Bool = true
    public var mode: DockMode = .lock
    public var bypassModifiers: ModifierSet = []
    public var showMenuBarIcon: Bool = true
    public var showDockIcon: Bool = false

    // Displays
    public var arrangements: [String: ArrangementPreferences] = [:]

    // Relocation
    public var autoRelocate: Bool = true
    /// Seconds the pointer must rest before DockLock moves the Dock by itself.
    public var relocationIdleDelay: Double = 1.5
    /// Seconds the pointer must rest on a display before "Follows mouse" moves the Dock there.
    public var followDelay: Double = 1.0
    public var notifyOnRelocationFailure: Bool = true
    public var showRelocationGuide: Bool = true
    /// The relocation strategy that worked last time on this Mac (tried first).
    public var preferredMoveStrategy: String?

    // Guard
    public var guardBand: Double = 3
    public var keepHotCorners: Bool = true
    public var hotCornerGrace: Double = 0.3

    // Automation
    public var appRules: [AppRule] = []
    public var hotKeys: [HotKeyBinding] = HotKeyBinding.defaults

    // Meetings / screen sharing
    public var hideDockWhileScreenSharing: Bool = false
    public var meetingAppBundleIDs: [String] = []
    public var autoHideWhileHidden: Bool = true

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DockLockSettings()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            // A single corrupt field must not wipe every other setting.
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        isEnabled = value(.isEnabled, d.isEnabled)
        mode = value(.mode, d.mode)
        bypassModifiers = value(.bypassModifiers, d.bypassModifiers)
        showMenuBarIcon = value(.showMenuBarIcon, d.showMenuBarIcon)
        showDockIcon = value(.showDockIcon, d.showDockIcon)
        arrangements = value(.arrangements, d.arrangements)
        autoRelocate = value(.autoRelocate, d.autoRelocate)
        relocationIdleDelay = value(.relocationIdleDelay, d.relocationIdleDelay)
        followDelay = value(.followDelay, d.followDelay)
        notifyOnRelocationFailure = value(.notifyOnRelocationFailure, d.notifyOnRelocationFailure)
        showRelocationGuide = value(.showRelocationGuide, d.showRelocationGuide)
        preferredMoveStrategy = value(.preferredMoveStrategy, d.preferredMoveStrategy)
        guardBand = value(.guardBand, d.guardBand)
        keepHotCorners = value(.keepHotCorners, d.keepHotCorners)
        hotCornerGrace = value(.hotCornerGrace, d.hotCornerGrace)
        appRules = value(.appRules, d.appRules)
        hotKeys = Self.mergedHotKeys(value(.hotKeys, d.hotKeys))
        hideDockWhileScreenSharing = value(.hideDockWhileScreenSharing, d.hideDockWhileScreenSharing)
        meetingAppBundleIDs = value(.meetingAppBundleIDs, d.meetingAppBundleIDs)
        autoHideWhileHidden = value(.autoHideWhileHidden, d.autoHideWhileHidden)
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, mode, bypassModifiers, showMenuBarIcon, showDockIcon
        case arrangements
        case autoRelocate, relocationIdleDelay, followDelay, notifyOnRelocationFailure, showRelocationGuide
        case preferredMoveStrategy
        case guardBand, keepHotCorners, hotCornerGrace
        case appRules, hotKeys
        case hideDockWhileScreenSharing, meetingAppBundleIDs, autoHideWhileHidden
    }

    /// Keeps saved bindings and adds defaults for actions introduced later.
    static func mergedHotKeys(_ saved: [HotKeyBinding]) -> [HotKeyBinding] {
        var result: [HotKeyBinding] = []
        for action in HotKeyAction.allCases {
            if let existing = saved.first(where: { $0.action == action }) {
                result.append(existing)
            } else if let fallback = HotKeyBinding.defaults.first(where: { $0.action == action }) {
                result.append(fallback)
            }
        }
        return result
    }

    public func rule(forBundleID bundleID: String) -> AppRule? {
        appRules.first { $0.enabled && $0.bundleID == bundleID }
    }

    // MARK: - Encoding helpers

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> DockLockSettings {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DockLockSettings.self, from: data)
    }
}

/// A well-known meeting / screen sharing app offered as a preset.
public struct MeetingAppPreset: Hashable, Sendable {
    public let bundleID: String
    public let name: String

    public init(_ bundleID: String, _ name: String) {
        self.bundleID = bundleID
        self.name = name
    }
}

public enum MeetingAppPresets {
    public static let all: [MeetingAppPreset] = [
        MeetingAppPreset("us.zoom.xos", "Zoom"),
        MeetingAppPreset("com.microsoft.teams2", "Microsoft Teams"),
        MeetingAppPreset("com.microsoft.teams", "Microsoft Teams (classic)"),
        MeetingAppPreset("com.cisco.webexmeetingsapp", "Webex Meetings"),
        MeetingAppPreset("Cisco-Systems.Spark", "Webex"),
        MeetingAppPreset("com.apple.FaceTime", "FaceTime"),
        MeetingAppPreset("com.tencent.meeting", "腾讯会议 / Tencent Meeting"),
        MeetingAppPreset("com.tencent.WeWorkMac", "企业微信 / WeCom"),
        MeetingAppPreset("com.alibaba.DingTalkMac", "钉钉 / DingTalk"),
        MeetingAppPreset("com.electron.lark", "飞书 / Lark"),
        MeetingAppPreset("com.bytedance.macos.feishu", "飞书 / Feishu"),
        MeetingAppPreset("com.logmein.GoToMeeting", "GoTo Meeting"),
        MeetingAppPreset("com.skype.skype", "Skype"),
        MeetingAppPreset("com.hnc.Discord", "Discord"),
        MeetingAppPreset("com.obsproject.obs-studio", "OBS Studio"),
    ]
}

/// Names for virtual key codes on an ANSI keyboard, used to show hot keys.
public enum KeyNames {
    public static func name(for keyCode: UInt32) -> String {
        table[keyCode] ?? "Key \(keyCode)"
    }

    static let table: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        105: "F13", 107: "F14", 109: "F10", 111: "F12", 113: "F15", 115: "↖", 116: "⇞",
        117: "⌦", 118: "F4", 119: "↘", 120: "F2", 121: "⇟", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}
