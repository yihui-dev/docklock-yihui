import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A strip along the Dock edge of one display that the pointer is kept out of.
///
/// macOS moves the Dock to another display when the pointer is pushed against that
/// display's Dock edge (the very last row of pixels at the bottom, for a bottom Dock).
/// Holding the pointer a couple of points away from that row on every display the
/// Dock must not go to removes the trigger entirely — no private API, no Dock restart.
///
/// Only **free** stretches of an edge are guarded: where another display sits directly
/// beyond the edge, that stretch is the route the pointer takes between the two screens
/// and must never be blocked (and the Dock cannot be summoned there anyway).
public struct ClampZone: Equatable, Sendable {
    public let displayID: UInt32
    public let displayUUID: String
    public let edge: DockEdge
    /// The display's full frame (CG global coordinates).
    public let displayFrame: CGRect
    /// The guarded stretch along the edge: x-range for a bottom edge, y-range for left/right.
    public let spanLow: CGFloat
    public let spanHigh: CGFloat
    /// Points kept clear at the edge.
    public let band: CGFloat

    public init(displayID: UInt32, displayUUID: String, edge: DockEdge, displayFrame: CGRect,
                spanLow: CGFloat, spanHigh: CGFloat, band: CGFloat) {
        self.displayID = displayID
        self.displayUUID = displayUUID
        self.edge = edge
        self.displayFrame = displayFrame
        self.spanLow = spanLow
        self.spanHigh = spanHigh
        self.band = band
    }

    /// The last coordinate the pointer may reach, across the edge axis.
    /// bottom: greatest y; left: smallest x; right: greatest x.
    public var limit: CGFloat {
        switch edge {
        case .bottom: return displayFrame.maxY - band
        case .left: return displayFrame.minX + band - 1
        case .right: return displayFrame.maxX - band
        }
    }

    /// Whether `point` lies in the guarded strip. Bounded to the display (plus a small
    /// overshoot beyond the free edge) so a stale zone can never pull the pointer across
    /// the desktop.
    public func contains(_ point: CGPoint) -> Bool {
        let f = displayFrame
        switch edge {
        case .bottom:
            return point.x >= spanLow && point.x < spanHigh && point.y > limit && point.y < f.maxY + band
        case .left:
            return point.y >= spanLow && point.y < spanHigh && point.x < limit && point.x > f.minX - band
        case .right:
            return point.y >= spanLow && point.y < spanHigh && point.x > limit && point.x < f.maxX + band
        }
    }

    /// `point` pulled back to the edge of the strip; the coordinate along the edge is untouched,
    /// so sliding the pointer along the bottom of a guarded display stays free.
    public func clamp(_ point: CGPoint) -> CGPoint {
        switch edge {
        case .bottom: return CGPoint(x: point.x, y: limit)
        case .left, .right: return CGPoint(x: limit, y: point.y)
        }
    }

    /// Whether `point` is within `size` points of either end (corner) of the display's edge.
    public func isNearCorner(_ point: CGPoint, size: CGFloat) -> Bool {
        let f = displayFrame
        switch edge {
        case .bottom:
            return point.x < f.minX + size || point.x >= f.maxX - size
        case .left, .right:
            return point.y < f.minY + size || point.y >= f.maxY - size
        }
    }
}

public enum EdgeGuardPlanner {
    /// Float noise tolerance when deciding whether displays touch.
    static let tolerance: CGFloat = 1

    /// The stretches of `display`'s `edge` with no other display directly beyond them,
    /// as (low, high) ranges along the edge.
    public static func freeSpans(of display: DisplaySnapshot, edge: DockEdge,
                                 in layout: DisplayLayout) -> [(low: CGFloat, high: CGFloat)] {
        let me = display.frame
        var blockers: [(low: CGFloat, high: CGFloat)] = []
        for other in layout.displays where other.uuid != display.uuid {
            let o = other.frame
            let beyond: Bool
            let low: CGFloat
            let high: CGFloat
            switch edge {
            case .bottom:
                beyond = o.minY < me.maxY + tolerance && o.maxY > me.maxY
                low = max(o.minX, me.minX)
                high = min(o.maxX, me.maxX)
            case .left:
                beyond = o.maxX > me.minX - tolerance && o.minX < me.minX
                low = max(o.minY, me.minY)
                high = min(o.maxY, me.maxY)
            case .right:
                beyond = o.minX < me.maxX + tolerance && o.maxX > me.maxX
                low = max(o.minY, me.minY)
                high = min(o.maxY, me.maxY)
            }
            if beyond && high - low > 0 { blockers.append((low, high)) }
        }
        blockers.sort { $0.low < $1.low }

        let start: CGFloat = edge == .bottom ? me.minX : me.minY
        let end: CGFloat = edge == .bottom ? me.maxX : me.maxY
        var spans: [(low: CGFloat, high: CGFloat)] = []
        var cursor = start
        for blocker in blockers {
            if blocker.low - cursor >= tolerance { spans.append((cursor, blocker.low)) }
            cursor = max(cursor, blocker.high)
        }
        if end - cursor >= tolerance { spans.append((cursor, end)) }
        return spans
    }

    /// Clamp zones for every display in `guardedUUIDs`.
    public static func zones(for guardedUUIDs: Set<String>, edge: DockEdge,
                             in layout: DisplayLayout, band: CGFloat) -> [ClampZone] {
        let safeBand = min(max(band, 2), 40)
        var zones: [ClampZone] = []
        for display in layout.displays where guardedUUIDs.contains(display.uuid) {
            for span in freeSpans(of: display, edge: edge, in: layout) {
                zones.append(ClampZone(displayID: display.id, displayUUID: display.uuid, edge: edge,
                                       displayFrame: display.frame, spanLow: span.low, spanHigh: span.high,
                                       band: safeBand))
            }
        }
        return zones
    }

    /// Displays whose Dock edge is fully covered by neighbours — the Dock cannot be
    /// summoned there, and nothing is guarded on them.
    public static func fullyBlockedDisplays(edge: DockEdge, in layout: DisplayLayout) -> [DisplaySnapshot] {
        layout.displays.filter { freeSpans(of: $0, edge: edge, in: layout).isEmpty }
    }
}

/// Everything the event tap needs, as one immutable value.
public struct GuardConfiguration: Equatable, Sendable {
    public var zones: [ClampZone]
    /// Holding (at least) these modifiers lets the pointer through, so the Dock can be moved
    /// deliberately. Empty = no bypass.
    public var bypassModifiers: ModifierSet
    /// Keep bottom hot corners usable: inside a corner square the pointer may reach the edge
    /// for `cornerGrace` seconds before it is held back again.
    public var keepHotCorners: Bool
    public var cornerSize: CGFloat
    public var cornerGrace: TimeInterval

    public init(zones: [ClampZone] = [], bypassModifiers: ModifierSet = [], keepHotCorners: Bool = true,
                cornerSize: CGFloat = 6, cornerGrace: TimeInterval = 0.3) {
        self.zones = zones
        self.bypassModifiers = bypassModifiers
        self.keepHotCorners = keepHotCorners
        self.cornerSize = cornerSize
        self.cornerGrace = cornerGrace
    }

    public static let inactive = GuardConfiguration()

    public var isActive: Bool { !zones.isEmpty }
}

/// The per-event decision, kept pure so it can be tested without an event tap.
public struct PointerClampEngine: Sendable {
    public enum Outcome: Equatable, Sendable {
        /// Leave the event alone.
        case pass
        /// The event would have been clamped, but the bypass modifier is held.
        case bypassed(displayUUID: String)
        /// Move the event (and so the pointer) to this location.
        case clamp(CGPoint)
    }

    public var configuration: GuardConfiguration {
        didSet { cornerEnteredAt = nil }
    }
    private var cornerEnteredAt: TimeInterval?

    public init(configuration: GuardConfiguration = .inactive) {
        self.configuration = configuration
    }

    public mutating func process(point: CGPoint, modifiers: ModifierSet, now: TimeInterval) -> Outcome {
        guard let zone = configuration.zones.first(where: { $0.contains(point) }) else {
            cornerEnteredAt = nil
            return .pass
        }
        let bypass = configuration.bypassModifiers
        if !bypass.isEmpty && modifiers.isSuperset(of: bypass) {
            return .bypassed(displayUUID: zone.displayUUID)
        }
        if configuration.keepHotCorners && zone.isNearCorner(point, size: configuration.cornerSize) {
            if let entered = cornerEnteredAt {
                if now - entered < configuration.cornerGrace { return .pass }
            } else {
                cornerEnteredAt = now
                return .pass
            }
        } else {
            cornerEnteredAt = nil
        }
        return .clamp(zone.clamp(point))
    }
}
