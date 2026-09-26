import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public struct DisplayReport: Codable, Equatable, Sendable {
    public var name: String
    public var uuid: String
    public var id: UInt32
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var isMain: Bool
    public var isBuiltin: Bool
    public var allowed: Bool
    public var temporarilyAllowed: Bool
    public var hasDock: Bool
    public var isHome: Bool

    public init(name: String, uuid: String, id: UInt32, x: Double, y: Double, width: Double, height: Double,
                isMain: Bool, isBuiltin: Bool, allowed: Bool, temporarilyAllowed: Bool, hasDock: Bool, isHome: Bool) {
        self.name = name
        self.uuid = uuid
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.isMain = isMain
        self.isBuiltin = isBuiltin
        self.allowed = allowed
        self.temporarilyAllowed = temporarilyAllowed
        self.hasDock = hasDock
        self.isHome = isHome
    }
}

/// Snapshot of everything interesting, for `docklock status`, diagnostics and Shortcuts.
public struct StatusReport: Codable, Equatable, Sendable {
    public var version: String
    public var enabled: Bool
    public var mode: String
    public var paused: Bool
    public var pausedUntil: Date?
    public var dockHidden: Bool
    public var accessibilityGranted: Bool
    public var guardActive: Bool
    public var guardedDisplays: Int
    public var separateSpaces: Bool
    public var dockEdge: String
    public var dockAutoHide: Bool
    public var dockDisplay: String?
    public var arrangement: String
    public var displays: [DisplayReport]
    public var lastRelocation: String?
    public var warnings: [String]

    public init(version: String, enabled: Bool, mode: String, paused: Bool, pausedUntil: Date?, dockHidden: Bool,
                accessibilityGranted: Bool, guardActive: Bool, guardedDisplays: Int, separateSpaces: Bool,
                dockEdge: String, dockAutoHide: Bool, dockDisplay: String?, arrangement: String,
                displays: [DisplayReport], lastRelocation: String?, warnings: [String]) {
        self.version = version
        self.enabled = enabled
        self.mode = mode
        self.paused = paused
        self.pausedUntil = pausedUntil
        self.dockHidden = dockHidden
        self.accessibilityGranted = accessibilityGranted
        self.guardActive = guardActive
        self.guardedDisplays = guardedDisplays
        self.separateSpaces = separateSpaces
        self.dockEdge = dockEdge
        self.dockAutoHide = dockAutoHide
        self.dockDisplay = dockDisplay
        self.arrangement = arrangement
        self.displays = displays
        self.lastRelocation = lastRelocation
        self.warnings = warnings
    }
}

public enum StatusFormatter {
    public static func text(_ report: StatusReport) -> String {
        var lines: [String] = []
        lines.append("DockLock \(report.version)")
        lines.append("Locking:        \(report.enabled ? "enabled" : "disabled")\(report.paused ? " (paused)" : "")")
        lines.append("Mode:           \(report.enabled ? report.mode : "disabled")")
        lines.append("Dock hidden:    \(report.dockHidden ? "yes" : "no")")
        lines.append("Dock display:   \(report.dockDisplay ?? "unknown")")
        lines.append("Dock position:  \(report.dockEdge)\(report.dockAutoHide ? ", auto-hide" : "")")
        lines.append("Guard:          \(report.guardActive ? "active on \(report.guardedDisplays) display(s)" : "idle")")
        lines.append("Accessibility:  \(report.accessibilityGranted ? "granted" : "NOT granted")")
        lines.append("Separate Spaces:\(report.separateSpaces ? " on" : " off")")
        if let last = report.lastRelocation {
            lines.append("Last move:      \(last)")
        }
        lines.append("")
        lines.append(displayList(report.displays))
        if !report.warnings.isEmpty {
            lines.append("")
            lines.append(contentsOf: report.warnings.map { "! \($0)" })
        }
        return lines.joined(separator: "\n")
    }

    public static func displayList(_ displays: [DisplayReport]) -> String {
        guard !displays.isEmpty else { return "(no displays)" }
        return displays.map { d in
            let flags = (d.hasDock ? "*" : " ") + (d.allowed ? "+" : (d.temporarilyAllowed ? "~" : " ")) + (d.isHome ? "h" : " ")
            var tags: [String] = []
            if d.isMain { tags.append("main") }
            if d.isBuiltin { tags.append("built-in") }
            let tagText = tags.isEmpty ? "" : " [\(tags.joined(separator: ", "))]"
            let geometry = "x=\(Int(d.x)) y=\(Int(d.y)) \(Int(d.width))x\(Int(d.height))"
            return "\(flags) \(d.name)\(tagText)  \(geometry)  \(d.uuid)"
        }.joined(separator: "\n")
    }
}
