import CoreGraphics
import Foundation

/// The event tap that keeps the pointer off the Dock edge of guarded displays.
///
/// It runs on its own thread with its own run loop, so a busy main thread can never make
/// macOS disable the tap for being slow. Per event it does a handful of comparisons
/// (see `PointerClampEngine`) and, when needed, moves the event's location — which moves the
/// pointer — a couple of points back from the edge.
final class PointerGuard {
    /// Marks events DockLock posts itself, so the tap lets them through untouched.
    static let syntheticMarker: Int64 = 0x444F_434B_4C4B // "DOCKLK"

    enum GestureMode {
        /// Real pointer motion is dropped while DockLock drives the pointer.
        case swallowUserMotion
        /// Nothing is clamped or dropped.
        case passAll
    }

    private let lock = NSLock()
    private var engine = PointerClampEngine()
    private var gestureMode: GestureMode?
    private var gestureDeadline: TimeInterval = 0
    private var lastBypassTime: TimeInterval = 0
    private var lastBypassDisplay: String?
    private var clamps = 0
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    var isRunning: Bool { locked { tap != nil } }
    var clampCount: Int { locked { clamps } }

    /// Starts the tap. Returns false when macOS refuses (no Accessibility permission).
    @discardableResult
    func start() -> Bool {
        if isRunning { return true }
        let types: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
        guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                             place: .headInsertEventTap,
                                             options: .defaultTap,
                                             eventsOfInterest: mask,
                                             callback: pointerGuardCallback,
                                             userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            return false
        }
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [weak self] in
            guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
                ready.signal()
                return
            }
            let loop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(loop, source, .commonModes)
            if let self { self.locked { self.runLoop = loop } }
            CGEvent.tapEnable(tap: newTap, enable: true)
            ready.signal()
            CFRunLoopRun()
            CFRunLoopRemoveSource(loop, source, .commonModes)
        }
        thread.name = "DockLock.PointerGuard"
        thread.qualityOfService = .userInteractive
        locked { tap = newTap }
        thread.start()
        _ = ready.wait(timeout: .now() + 2)
        return true
    }

    func stop() {
        let (oldTap, oldLoop): (CFMachPort?, CFRunLoop?) = locked {
            let pair = (tap, runLoop)
            tap = nil
            runLoop = nil
            gestureMode = nil
            return pair
        }
        if let oldTap {
            CGEvent.tapEnable(tap: oldTap, enable: false)
            CFMachPortInvalidate(oldTap)
        }
        if let oldLoop { CFRunLoopStop(oldLoop) }
    }

    /// Re-enables the tap if macOS switched it off (it does so after a timeout or on secure input).
    func ensureEnabled() {
        guard let current = locked({ tap }) else { return }
        if !CGEvent.tapIsEnabled(tap: current) {
            CGEvent.tapEnable(tap: current, enable: true)
        }
    }

    func update(_ configuration: GuardConfiguration) {
        locked {
            if engine.configuration != configuration { engine.configuration = configuration }
        }
    }

    var configuration: GuardConfiguration { locked { engine.configuration } }

    func beginGesture(_ mode: GestureMode, duration: TimeInterval) {
        locked {
            gestureMode = mode
            gestureDeadline = ProcessInfo.processInfo.systemUptime + duration
        }
    }

    func endGesture() {
        locked { gestureMode = nil }
    }

    /// The display the pointer was let through to with the bypass modifier within the last `seconds`.
    func recentBypass(within seconds: TimeInterval) -> String? {
        locked {
            ProcessInfo.processInfo.systemUptime - lastBypassTime <= seconds ? lastBypassDisplay : nil
        }
    }

    // MARK: - Event handling (tap thread)

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let current = locked({ tap }) { CGEvent.tapEnable(tap: current, enable: true) }
            return pass
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker { return pass }

        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        defer { lock.unlock() }

        if let mode = gestureMode {
            if now < gestureDeadline {
                return mode == .swallowUserMotion ? nil : pass
            }
            gestureMode = nil
        }
        guard !engine.configuration.zones.isEmpty else { return pass }

        switch engine.process(point: event.location, modifiers: ModifierSet(cgFlags: event.flags.rawValue), now: now) {
        case .pass:
            return pass
        case .bypassed(let display):
            lastBypassTime = now
            lastBypassDisplay = display
            return pass
        case .clamp(let point):
            event.location = point
            clamps &+= 1
            return pass
        }
    }
}

private func pointerGuardCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                                  userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let pointerGuard = Unmanaged<PointerGuard>.fromOpaque(userInfo).takeUnretainedValue()
    return pointerGuard.handle(type: type, event: event)
}
