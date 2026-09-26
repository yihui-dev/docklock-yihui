import AppKit
import CoreGraphics

/// Moves the Dock to another display by reproducing what a person does: rest the pointer on the
/// target display's Dock edge and keep pushing against it.
///
/// macOS only lets real pointer input summon the Dock, and which kind of synthesized input it
/// accepts has changed between releases, so several strategies are tried and the outcome of each
/// is *verified* by reading where the Dock actually is. The strategy that worked is remembered and
/// tried first next time. The pointer is always put back where it was.
final class DockMover {
    /// Tried in this order unless another one worked last time.
    enum Strategy: String, CaseIterable {
        /// Relative pointer motion posted through the IOKit HID system. Verified on macOS 15.
        case hidRelativePush = "hid-relative-push"
        /// Mouse-moved events at and beyond the edge, posted at the HID level.
        case syntheticPush = "synthetic-push"
    }

    struct Outcome {
        var success: Bool
        var strategy: Strategy?
        var message: String
    }

    private let pointerGuard: PointerGuard
    /// Returns the display currently hosting the Dock (fresh read).
    private let locateDock: () -> String?

    init(pointerGuard: PointerGuard, locateDock: @escaping () -> String?) {
        self.pointerGuard = pointerGuard
        self.locateDock = locateDock
    }

    @MainActor
    func move(to target: DisplaySnapshot, layout: DisplayLayout, edge: DockEdge,
              preferredStrategy: String?) async -> Outcome {
        if locateDock() == target.uuid {
            return Outcome(success: true, strategy: nil, message: "already there")
        }
        guard let edgePoint = Self.pushPoint(on: target, edge: edge, layout: layout) else {
            return Outcome(success: false, strategy: nil,
                           message: L("Another display covers this display's Dock edge, so the Dock cannot be placed there."))
        }

        var order = Strategy.allCases
        if let preferredStrategy, let preferred = Strategy(rawValue: preferredStrategy) {
            order.removeAll { $0 == preferred }
            order.insert(preferred, at: 0)
        }

        let origin = SystemDisplays.pointerLocation()
        let source = CGEventSource(stateID: .hidSystemState)
        source?.localEventsSuppressionInterval = 0
        source?.userData = PointerGuard.syntheticMarker

        var winner: Strategy?
        for strategy in order {
            let moved: Bool
            switch strategy {
            case .syntheticPush:
                moved = await syntheticPush(target: target, edgePoint: edgePoint, edge: edge, source: source)
            case .hidRelativePush:
                moved = await hidRelativePush(target: target, edgePoint: edgePoint, edge: edge)
            }
            if moved {
                winner = strategy
                break
            }
        }
        restorePointer(to: origin, source: source)

        if let winner {
            return Outcome(success: true, strategy: winner, message: "moved")
        }
        // The Dock animates for a moment; give a late success a chance.
        if await waitForDock(on: target.uuid, timeout: 1.0) {
            return Outcome(success: true, strategy: order.last, message: "moved")
        }
        return Outcome(success: false, strategy: nil,
                       message: L("macOS did not accept the automatic move."))
    }

    // MARK: - Strategies

    @MainActor
    private func syntheticPush(target: DisplaySnapshot, edgePoint: CGPoint, edge: DockEdge,
                               source: CGEventSource?) async -> Bool {
        pointerGuard.beginGesture(.swallowUserMotion, duration: 4.5)
        defer { pointerGuard.endGesture() }

        let outward = Self.outwardVector(edge)
        let approach = CGPoint(x: edgePoint.x - outward.dx * 80, y: edgePoint.y - outward.dy * 80)
        CGWarpMouseCursorPosition(approach)
        post(source, at: approach, dx: 0, dy: 0)
        await pause(0.03)

        // Glide to the edge like a hand would.
        for step in 1...8 {
            let t = CGFloat(step) / 8
            let point = CGPoint(x: approach.x + (edgePoint.x - approach.x) * t,
                                y: approach.y + (edgePoint.y - approach.y) * t)
            post(source, at: point, dx: Int64(outward.dx * 10), dy: Int64(outward.dy * 10))
            await pause(0.012)
        }

        // Keep pushing against (and past) the edge.
        let start = ProcessInfo.processInfo.systemUptime
        var tick = 0
        while ProcessInfo.processInfo.systemUptime - start < 1.5 {
            let overshoot = CGFloat(2 + (tick % 3) * 3)
            let beyond = CGPoint(x: edgePoint.x + outward.dx * overshoot, y: edgePoint.y + outward.dy * overshoot)
            post(source, at: tick.isMultiple(of: 2) ? beyond : edgePoint,
                 dx: Int64(outward.dx * 4), dy: Int64(outward.dy * 4))
            tick += 1
            await pause(0.016)
            if tick.isMultiple(of: 8), locateDock() == target.uuid { return true }
        }
        // Hold still at the edge while the Dock animates across.
        return await waitForDock(on: target.uuid, timeout: 1.2)
    }

    @MainActor
    private func hidRelativePush(target: DisplaySnapshot, edgePoint: CGPoint, edge: DockEdge) async -> Bool {
        guard let poster = HIDEventPoster.shared else { return false }
        pointerGuard.beginGesture(.passAll, duration: 4.5)
        defer { pointerGuard.endGesture() }

        let outward = Self.outwardVector(edge)
        let approach = CGPoint(x: edgePoint.x - outward.dx * 60, y: edgePoint.y - outward.dy * 60)
        CGWarpMouseCursorPosition(approach)
        await pause(0.05)

        let start = ProcessInfo.processInfo.systemUptime
        var tick = 0
        while ProcessInfo.processInfo.systemUptime - start < 1.6 {
            guard poster.postRelativeMove(dx: Int32(outward.dx * 6), dy: Int32(outward.dy * 6)) else { return false }
            tick += 1
            await pause(0.012)
            if tick.isMultiple(of: 10), locateDock() == target.uuid { return true }
        }
        return await waitForDock(on: target.uuid, timeout: 1.2)
    }

    // MARK: - Helpers

    @MainActor
    func waitForDock(on uuid: String, timeout: TimeInterval) async -> Bool {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while ProcessInfo.processInfo.systemUptime < deadline {
            if locateDock() == uuid { return true }
            await pause(0.12)
        }
        return locateDock() == uuid
    }

    private func restorePointer(to origin: CGPoint, source: CGEventSource?) {
        CGWarpMouseCursorPosition(origin)
        // A real move event makes the Dock drop its hover / magnification state.
        post(source, at: origin, dx: 0, dy: 0)
    }

    private func post(_ source: CGEventSource?, at point: CGPoint, dx: Int64, dy: Int64) {
        guard let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                                  mouseCursorPosition: point, mouseButton: .left) else { return }
        event.setIntegerValueField(.mouseEventDeltaX, value: dx)
        event.setIntegerValueField(.mouseEventDeltaY, value: dy)
        event.setIntegerValueField(.eventSourceUserData, value: PointerGuard.syntheticMarker)
        event.post(tap: .cghidEventTap)
    }

    private func pause(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// Unit vector pointing out of the display through its Dock edge (CG coordinates, y down).
    static func outwardVector(_ edge: DockEdge) -> CGVector {
        switch edge {
        case .bottom: return CGVector(dx: 0, dy: 1)
        case .left: return CGVector(dx: -1, dy: 0)
        case .right: return CGVector(dx: 1, dy: 0)
        }
    }

    /// The last pixel of the Dock edge, on a stretch with no other display beyond it,
    /// as close to the middle of the display as possible.
    static func pushPoint(on display: DisplaySnapshot, edge: DockEdge, layout: DisplayLayout) -> CGPoint? {
        let spans = EdgeGuardPlanner.freeSpans(of: display, edge: edge, in: layout)
        let f = display.frame
        let middle = edge == .bottom ? f.midX : f.midY
        guard let span = spans.first(where: { $0.low <= middle && middle < $0.high })
                ?? spans.max(by: { ($0.high - $0.low) < ($1.high - $1.low) }) else { return nil }
        let inset = min(40, (span.high - span.low) / 3)
        let along = min(max(middle, span.low + inset), span.high - inset)
        switch edge {
        case .bottom: return CGPoint(x: along, y: f.maxY - 1)
        case .left: return CGPoint(x: f.minX, y: along)
        case .right: return CGPoint(x: f.maxX - 1, y: along)
        }
    }
}
