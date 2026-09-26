import Foundation

/// One active (non-mirroring) display.
///
/// `frame` uses Core Graphics global coordinates: points, origin at the top-left
/// corner of the main display, `y` growing downwards. This is the space of
/// `CGDisplayBounds`, event-tap locations and `CoreDockGetRect`.
public struct DisplaySnapshot: Equatable, Sendable {
    public var id: UInt32
    public var uuid: String
    public var name: String
    public var frame: CGRect
    public var isMain: Bool
    public var isBuiltin: Bool

    public init(id: UInt32, uuid: String, name: String, frame: CGRect, isMain: Bool = false, isBuiltin: Bool = false) {
        self.id = id
        self.uuid = uuid
        self.name = name
        self.frame = frame
        self.isMain = isMain
        self.isBuiltin = isBuiltin
    }
}

/// The current display arrangement plus the geometric questions DockLock asks about it.
public struct DisplayLayout: Equatable, Sendable {
    /// Displays ordered left-to-right, then top-to-bottom.
    public let displays: [DisplaySnapshot]

    public init(_ displays: [DisplaySnapshot]) {
        self.displays = displays.sorted { lhs, rhs in
            if lhs.frame.minX != rhs.frame.minX { return lhs.frame.minX < rhs.frame.minX }
            return lhs.frame.minY < rhs.frame.minY
        }
    }

    public static let empty = DisplayLayout([])

    public var count: Int { displays.count }
    public var isEmpty: Bool { displays.isEmpty }

    public var main: DisplaySnapshot? {
        displays.first(where: \.isMain) ?? displays.first(where: { $0.frame.origin == .zero }) ?? displays.first
    }

    /// Identifies this *combination* of displays. Preferences are remembered per key,
    /// so e.g. "laptop only", "laptop + office monitor" and "laptop + home TV" each keep
    /// their own allowed displays.
    public var arrangementKey: String {
        ArrangementKey.make(displays.map(\.uuid))
    }

    public var uuids: [String] { displays.map(\.uuid) }

    public func display(id: UInt32) -> DisplaySnapshot? {
        displays.first { $0.id == id }
    }

    public func display(uuid: String) -> DisplaySnapshot? {
        displays.first { $0.uuid == uuid }
    }

    /// The display containing `point` (half-open on the right/bottom so seams belong to one display).
    public func display(containing point: CGPoint) -> DisplaySnapshot? {
        displays.first { d in
            point.x >= d.frame.minX && point.x < d.frame.maxX && point.y >= d.frame.minY && point.y < d.frame.maxY
        }
    }

    /// The display containing `point`, or the closest one when the point is outside every display.
    public func nearestDisplay(to point: CGPoint) -> DisplaySnapshot? {
        if let hit = display(containing: point) { return hit }
        return displays.min { distance(from: point, to: $0.frame) < distance(from: point, to: $1.frame) }
    }

    /// The display a window mostly lives on (largest intersection; nearest centre as tie-breaker).
    public func display(bestMatching rect: CGRect) -> DisplaySnapshot? {
        guard !displays.isEmpty else { return nil }
        let scored = displays.map { d -> (DisplaySnapshot, CGFloat) in
            let i = d.frame.intersection(rect)
            return (d, i.isNull ? 0 : i.width * i.height)
        }
        if let best = scored.max(by: { $0.1 < $1.1 }), best.1 > 0 { return best.0 }
        return nearestDisplay(to: CGPoint(x: rect.midX, y: rect.midY))
    }

    /// User-facing names. Identical monitors get " (1)", " (2)" … in layout order.
    public func displayName(for display: DisplaySnapshot) -> String {
        let twins = displays.filter { $0.name == display.name }
        guard twins.count > 1, let index = twins.firstIndex(where: { $0.uuid == display.uuid }) else {
            return display.name
        }
        return "\(display.name) (\(index + 1))"
    }

    /// Resolves a display reference typed by a person or a script.
    ///
    /// Accepts, case-insensitively: the (disambiguated) display name, the raw name when it is
    /// unique, a display UUID, a numeric display ID, a 1-based position ("#2"), "main", "builtin"/"built-in".
    public func display(named reference: String) -> DisplaySnapshot? {
        let query = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        let lower = query.lowercased()

        if let exact = displays.first(where: { displayName(for: $0).lowercased() == lower }) { return exact }
        let rawMatches = displays.filter { $0.name.lowercased() == lower }
        if rawMatches.count >= 1 { return rawMatches[0] }
        if let byUUID = displays.first(where: { $0.uuid.lowercased() == lower }) { return byUUID }
        switch lower {
        case "main", "primary", "main display":
            return main
        case "builtin", "built-in", "internal", "built-in display", "laptop":
            return displays.first(where: \.isBuiltin)
        default:
            break
        }
        if lower.hasPrefix("#"), let n = Int(lower.dropFirst()), n >= 1, n <= displays.count {
            return displays[n - 1]
        }
        if let id = UInt32(lower), let byID = display(id: id) { return byID }
        // Last resort: a unique prefix / substring match ("studio" → "Studio Display").
        let partial = displays.filter { displayName(for: $0).lowercased().contains(lower) }
        return partial.count == 1 ? partial[0] : nil
    }

    /// The neighbouring display in `direction`, preferring displays that overlap on the
    /// perpendicular axis, then the closest one.
    public func adjacent(to origin: DisplaySnapshot, direction: Direction) -> DisplaySnapshot? {
        let o = origin.frame
        var best: (display: DisplaySnapshot, overlapPenalty: CGFloat, distance: CGFloat)?
        for candidate in displays where candidate.uuid != origin.uuid {
            let c = candidate.frame
            let primary: CGFloat
            let penalty: CGFloat
            switch direction {
            case .right:
                primary = c.midX - o.midX
                penalty = intervalGap(c.minY, c.maxY, o.minY, o.maxY)
            case .left:
                primary = o.midX - c.midX
                penalty = intervalGap(c.minY, c.maxY, o.minY, o.maxY)
            case .down:
                primary = c.midY - o.midY
                penalty = intervalGap(c.minX, c.maxX, o.minX, o.maxX)
            case .up:
                primary = o.midY - c.midY
                penalty = intervalGap(c.minX, c.maxX, o.minX, o.maxX)
            }
            guard primary > 0.5 else { continue }
            if let current = best {
                if (penalty, primary) < (current.overlapPenalty, current.distance) {
                    best = (candidate, penalty, primary)
                }
            } else {
                best = (candidate, penalty, primary)
            }
        }
        return best?.display
    }

    /// Ordered display list used when the user does not care which allowed display is picked:
    /// the main display first, then left-to-right.
    public var preferenceOrder: [DisplaySnapshot] {
        displays.sorted { lhs, rhs in
            if lhs.isMain != rhs.isMain { return lhs.isMain }
            if lhs.frame.minX != rhs.frame.minX { return lhs.frame.minX < rhs.frame.minX }
            return lhs.frame.minY < rhs.frame.minY
        }
    }

    // MARK: - Helpers

    private func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }

    /// 0 when the intervals overlap, otherwise the size of the gap between them.
    private func intervalGap(_ aMin: CGFloat, _ aMax: CGFloat, _ bMin: CGFloat, _ bMax: CGFloat) -> CGFloat {
        let overlap = min(aMax, bMax) - max(aMin, bMin)
        return overlap > 0 ? 0 : -overlap
    }
}

public enum ArrangementKey {
    public static func make(_ uuids: [String]) -> String {
        uuids.map { $0.uppercased() }.sorted().joined(separator: "+")
    }

    public static func uuids(in key: String) -> [String] {
        key.split(separator: "+").map(String.init)
    }
}
