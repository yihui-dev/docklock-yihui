import Foundation

/// Runtime state that is not persisted but changes what DockLock does.
public struct RuntimeState: Equatable, Sendable {
    /// Set by a deliberate move in "lock" mode (menu, hot key, CLI, Shortcuts, modifier-key jump):
    /// the Dock is held on this display alone until the display arrangement changes or the
    /// user releases it.
    public var exclusiveTarget: String?
    /// Extra displays the Dock may visit until the arrangement changes (deliberate moves in the
    /// follow modes).
    public var temporarilyAllowed: Set<String> = []
    /// "Hide Dock" / meeting mode: the Dock may not appear anywhere.
    public var hideDock: Bool = false
    /// Locking paused (e.g. "Pause for 15 minutes").
    public var paused: Bool = false

    public init(exclusiveTarget: String? = nil, temporarilyAllowed: Set<String> = [],
                hideDock: Bool = false, paused: Bool = false) {
        self.exclusiveTarget = exclusiveTarget
        self.temporarilyAllowed = temporarilyAllowed
        self.hideDock = hideDock
        self.paused = paused
    }
}

/// The pure decision rules. Everything platform-specific feeds values in; nothing here
/// touches the system.
public enum DockPolicy {
    /// Preferences for an arrangement seen for the first time: keep the Dock where it is.
    public static func defaultPreferences(for layout: DisplayLayout, dockDisplayUUID: String?) -> ArrangementPreferences {
        let initial = dockDisplayUUID.flatMap { layout.display(uuid: $0) } ?? layout.main
        var names: [String: String] = [:]
        for d in layout.displays { names[d.uuid] = layout.displayName(for: d) }
        return ArrangementPreferences(allowed: initial.map { [$0.uuid] } ?? [],
                                      home: initial?.uuid, names: names, lastUsed: Date())
    }

    /// Displays the Dock may be on right now (connected ones only).
    public static func effectiveAllowed(layout: DisplayLayout, preferences: ArrangementPreferences,
                                        runtime: RuntimeState) -> Set<String> {
        let connected = Set(layout.uuids)
        if let exclusive = runtime.exclusiveTarget, connected.contains(exclusive) {
            return [exclusive]
        }
        return preferences.allowedSet.union(runtime.temporarilyAllowed).intersection(connected)
    }

    /// Displays whose Dock edge must be guarded.
    public static func guardedDisplays(settings: DockLockSettings, layout: DisplayLayout,
                                       preferences: ArrangementPreferences, runtime: RuntimeState) -> Set<String> {
        guard settings.isEnabled, !runtime.paused, !layout.isEmpty else { return [] }
        if runtime.hideDock { return Set(layout.uuids) }
        guard layout.count > 1 else { return [] }
        let allowed = effectiveAllowed(layout: layout, preferences: preferences, runtime: runtime)
        return Set(layout.uuids).subtracting(allowed)
    }

    public static func guardConfiguration(settings: DockLockSettings, layout: DisplayLayout,
                                          preferences: ArrangementPreferences, runtime: RuntimeState,
                                          dockEdge: DockEdge) -> GuardConfiguration {
        let guarded = guardedDisplays(settings: settings, layout: layout, preferences: preferences, runtime: runtime)
        let zones = EdgeGuardPlanner.zones(for: guarded, edge: dockEdge, in: layout, band: CGFloat(settings.guardBand))
        return GuardConfiguration(zones: zones,
                                  bypassModifiers: runtime.hideDock ? [] : settings.bypassModifiers,
                                  keepHotCorners: settings.keepHotCorners,
                                  cornerSize: 6,
                                  cornerGrace: settings.hotCornerGrace)
    }

    /// Where the Dock should go back to, or nil when it is fine where it is.
    public static func homeTarget(dockDisplayUUID: String?, settings: DockLockSettings, layout: DisplayLayout,
                                  preferences: ArrangementPreferences, runtime: RuntimeState) -> DisplaySnapshot? {
        guard settings.isEnabled, !runtime.paused, !runtime.hideDock, layout.count > 1 else { return nil }
        let allowed = effectiveAllowed(layout: layout, preferences: preferences, runtime: runtime)
        guard !allowed.isEmpty else { return nil }
        if let current = dockDisplayUUID, allowed.contains(current) { return nil }
        return preferredAllowedDisplay(layout: layout, preferences: preferences, allowed: allowed)
    }

    /// The home display if allowed, otherwise the first allowed display (main first).
    public static func preferredAllowedDisplay(layout: DisplayLayout, preferences: ArrangementPreferences,
                                               allowed: Set<String>) -> DisplaySnapshot? {
        if let home = preferences.home, allowed.contains(home), let display = layout.display(uuid: home) {
            return display
        }
        return layout.preferenceOrder.first { allowed.contains($0.uuid) }
    }

    /// Target for the follow modes: the candidate display if the Dock may go there and is not there yet.
    public static func followTarget(candidate: DisplaySnapshot?, dockDisplayUUID: String?,
                                    settings: DockLockSettings, layout: DisplayLayout,
                                    preferences: ArrangementPreferences, runtime: RuntimeState) -> DisplaySnapshot? {
        guard settings.isEnabled, settings.mode.isFollowMode, !runtime.paused, !runtime.hideDock,
              let candidate, candidate.uuid != dockDisplayUUID else { return nil }
        let allowed = effectiveAllowed(layout: layout, preferences: preferences, runtime: runtime)
        return allowed.contains(candidate.uuid) ? candidate : nil
    }

    /// Guards against fighting another tool that keeps moving the Dock: at most `limit`
    /// automatic relocations inside `window` seconds.
    public static func allowsAutomaticRelocation(history: [Date], now: Date, limit: Int = 6,
                                                 window: TimeInterval = 300) -> Bool {
        history.filter { now.timeIntervalSince($0) < window }.count < limit
    }
}
