import AppKit
import Combine

/// Result of a command, shared by the menu, CLI, URL scheme and Shortcuts.
struct CommandResult {
    var ok: Bool
    var message: String
    var json: String?
    /// Job to wait for when the command continues in the background (moving the Dock).
    var job: String?

    static func success(_ message: String = "", json: String? = nil) -> CommandResult {
        CommandResult(ok: true, message: message, json: json, job: nil)
    }

    static func failure(_ message: String) -> CommandResult {
        CommandResult(ok: false, message: message, json: nil, job: nil)
    }
}

struct RelocationRecord {
    var date: Date
    var displayName: String
    var success: Bool
    var detail: String
}

/// The brain of the app. Owns the settings, watches displays and the Dock, drives the pointer
/// guard and the Dock mover, and executes every command. Used from the main thread only.
final class AppController: ObservableObject {
    static let shared = AppController()

    // MARK: Published state

    @Published private(set) var settings: DockLockSettings
    @Published private(set) var layout: DisplayLayout = .empty
    @Published private(set) var dockDisplayUUID: String?
    @Published private(set) var dockEdge: DockEdge = .bottom
    @Published private(set) var dockAutoHide = false
    @Published private(set) var separateSpaces = true
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var guardActive = false
    @Published private(set) var guardedDisplayCount = 0
    @Published private(set) var runtime = RuntimeState()
    @Published private(set) var pausedUntil: Date?
    @Published private(set) var manualHide = false
    @Published private(set) var autoHideReason: String?
    @Published private(set) var isRelocating = false
    @Published private(set) var lastRelocation: RelocationRecord?
    @Published private(set) var launchAtLogin = LoginItem.isEnabled
    @Published private(set) var failedHotKeys: [HotKeyAction] = []

    // MARK: Collaborators

    let pointerGuard = PointerGuard()
    private lazy var mover = DockMover(pointerGuard: pointerGuard) { [weak self] in self?.readDockDisplayUUID() }
    private let hotKeys = HotKeyCenter()
    private let controlServer = ControlServer()
    private let meetingMonitor = MeetingMonitor()
    private let guide = GuideOverlay()
    private var statusMenu: StatusMenuController?
    private var settingsWindow: SettingsWindowController?

    // MARK: Internal state

    private struct PendingRelocation {
        var target: String
        var automatic: Bool
        var rateLimited: Bool
        var idleRequirement: TimeInterval
        var attempts = 0
        var notBefore: TimeInterval = 0
        var requestedAt = Date()
        var jobs: [String] = []
    }

    private enum JobState {
        case running
        case finished(Bool, String)
    }

    private var started = false
    private var queuedURLs: [URL] = []
    private var dockTimer: Timer?
    private var followTimer: Timer?
    private var relocationTimer: Timer?
    private var permissionTimer: Timer?
    private var pauseTimer: Timer?
    private var displayRefreshWork: DispatchWorkItem?
    private var pending: PendingRelocation?
    private var automaticRelocations: [Date] = []
    private var jobs: [String: JobState] = [:]
    private var nextJob = 1
    private var observers: [NSObjectProtocol] = []
    private var ticks = 0
    private var followCandidate: (uuid: String, since: TimeInterval)?

    private init() {
        settings = SettingsStore.load()
    }

    // MARK: - Lifecycle

    func start() {
        guard !started else { return }
        started = true
        let firstRun = settings.arrangements.isEmpty

        applyActivationPolicy()
        statusMenu = StatusMenuController(controller: self)
        statusMenu?.setVisible(settings.showMenuBarIcon)

        accessibilityGranted = Permissions.isAccessibilityTrusted
        if !accessibilityGranted {
            Permissions.requestAccessibility()
        }
        restoreAutoHideAfterCrash()
        refreshDisplays()
        refreshDockState(checkSpaces: true)
        observeSystem()
        startTimers()

        hotKeys.onAction = { [weak self] action in self?.perform(hotKey: action) }
        failedHotKeys = hotKeys.register(settings.hotKeys)

        meetingMonitor.onChange = { [weak self] reason in self?.meetingReasonChanged(reason) }
        meetingMonitor.configure(screenSharing: settings.hideDockWhileScreenSharing, bundleIDs: settings.meetingAppBundleIDs)

        controlServer.start { [weak self] data in
            self?.handleControlRequest(data) ?? ControlCodec.encode(ControlResponse(ok: false, message: "unavailable"))
        }

        reconfigure()
        scheduleHomeCheck(after: 1.0)

        let urls = queuedURLs
        queuedURLs.removeAll()
        urls.forEach(handle(url:))

        if !accessibilityGranted || firstRun {
            showSettings()
        }
    }

    func shutdown() {
        pointerGuard.stop()
        controlServer.stop()
        hotKeys.unregisterAll()
        if SettingsStore.autoHideEnabledByDockLock {
            DockInspector.setAutoHideEnabled(false)
            SettingsStore.autoHideEnabledByDockLock = false
        }
    }

    // MARK: - Derived values

    var currentPreferences: ArrangementPreferences {
        settings.arrangements[layout.arrangementKey]
            ?? DockPolicy.defaultPreferences(for: layout, dockDisplayUUID: dockDisplayUUID)
    }

    var effectiveAllowed: Set<String> {
        DockPolicy.effectiveAllowed(layout: layout, preferences: currentPreferences, runtime: runtime)
    }

    var dockDisplay: DisplaySnapshot? { dockDisplayUUID.flatMap { layout.display(uuid: $0) } }

    var isPaused: Bool { runtime.paused }
    var isDockHidden: Bool { runtime.hideDock }

    func displayName(_ display: DisplaySnapshot) -> String { layout.displayName(for: display) }

    func isAllowed(_ display: DisplaySnapshot) -> Bool { currentPreferences.allowedSet.contains(display.uuid) }

    var fullyBlockedDisplays: [DisplaySnapshot] {
        layout.count > 1 ? EdgeGuardPlanner.fullyBlockedDisplays(edge: dockEdge, in: layout) : []
    }

    var warnings: [String] {
        var list: [String] = []
        if !accessibilityGranted {
            list.append(L("Accessibility access is off, so the Dock is not locked."))
        }
        if !separateSpaces {
            list.append(L("\u{201C}Displays have separate Spaces\u{201D} is off. macOS then keeps the Dock on the main display."))
        }
        if layout.count < 2 {
            list.append(L("Only one display is connected; the Dock cannot jump anywhere."))
        }
        for display in fullyBlockedDisplays {
            list.append(LF("%@ has another display directly below its Dock edge, so the Dock cannot be summoned there.",
                           displayName(display)))
        }
        if settings.mode.isFollowMode && settings.isEnabled && effectiveAllowed.count < 2 && layout.count > 1 {
            list.append(L("Follow modes only move the Dock between allowed displays. Allow at least two displays."))
        }
        return list
    }

    var statusSummary: String {
        if !settings.isEnabled { return L("Dock locking is off") }
        if let until = pausedUntil, runtime.paused {
            return until == .distantFuture ? L("Paused") : LF("Paused until %@", Self.timeFormatter.string(from: until))
        }
        if runtime.hideDock {
            if let reason = autoHideReason, !manualHide { return LF("Dock hidden (%@)", reason) }
            return L("Dock hidden on all displays")
        }
        if isRelocating { return L("Moving the Dock…") }
        let dockName = dockDisplay.map(displayName) ?? L("unknown display")
        if !accessibilityGranted { return L("Waiting for Accessibility access") }
        if let exclusive = runtime.exclusiveTarget, let display = layout.display(uuid: exclusive) {
            return LF("Dock held on %@", displayName(display))
        }
        switch settings.mode {
        case .lock: return LF("Dock locked · on %@", dockName)
        case .followsMouse: return LF("Dock follows the pointer · on %@", dockName)
        case .followsWindow: return LF("Dock follows the active window · on %@", dockName)
        case .followsApps: return LF("Dock follows apps · on %@", dockName)
        }
    }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    // MARK: - Settings mutation

    func updateSettings(_ change: (inout DockLockSettings) -> Void) {
        var copy = settings
        change(&copy)
        guard copy != settings else { return }
        let old = settings
        settings = copy
        SettingsStore.save(copy)
        settingsDidChange(from: old)
    }

    private func updatePreferences(_ change: (inout ArrangementPreferences) -> Void) {
        guard !layout.isEmpty else { return }
        let key = layout.arrangementKey
        updateSettings { settings in
            var prefs = settings.arrangements[key] ?? DockPolicy.defaultPreferences(for: layout, dockDisplayUUID: dockDisplayUUID)
            change(&prefs)
            settings.arrangements[key] = prefs
        }
    }

    private func settingsDidChange(from old: DockLockSettings) {
        if old.showDockIcon != settings.showDockIcon { applyActivationPolicy() }
        if old.showMenuBarIcon != settings.showMenuBarIcon { statusMenu?.setVisible(settings.showMenuBarIcon) }
        if old.hotKeys != settings.hotKeys { failedHotKeys = hotKeys.register(settings.hotKeys) }
        if old.hideDockWhileScreenSharing != settings.hideDockWhileScreenSharing
            || old.meetingAppBundleIDs != settings.meetingAppBundleIDs {
            meetingMonitor.configure(screenSharing: settings.hideDockWhileScreenSharing, bundleIDs: settings.meetingAppBundleIDs)
        }
        if old.mode != settings.mode || old.isEnabled != settings.isEnabled {
            runtime.exclusiveTarget = nil
            runtime.temporarilyAllowed = []
            followCandidate = nil
            if let p = pending, p.automatic { cancelPending(message: "mode changed") }
        }
        if old.autoHideWhileHidden != settings.autoHideWhileHidden { applyAutoHide() }
        reconfigure()
        if old.isEnabled != settings.isEnabled || old.mode != settings.mode
            || old.arrangements[layout.arrangementKey] != settings.arrangements[layout.arrangementKey] {
            scheduleHomeCheck(after: 0.3)
        }
    }

    func setAllowed(_ display: DisplaySnapshot, _ allowed: Bool) {
        runtime.exclusiveTarget = nil
        updatePreferences { prefs in
            var list = prefs.allowed
            list.removeAll { $0 == display.uuid }
            if allowed { list.append(display.uuid) }
            prefs.allowed = list
            let homeStillAllowed = prefs.home.map { list.contains($0) } ?? false
            if allowed && !homeStillAllowed { prefs.home = display.uuid }
        }
    }

    func setHome(_ display: DisplaySnapshot) {
        updatePreferences { prefs in
            prefs.home = display.uuid
            if !prefs.allowed.contains(display.uuid) { prefs.allowed.append(display.uuid) }
        }
    }

    func forgetArrangement(_ key: String) {
        updateSettings { $0.arrangements.removeValue(forKey: key) }
        refreshDisplays()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        _ = LoginItem.set(enabled)
        launchAtLogin = LoginItem.isEnabled
    }

    func refreshLoginItemState() {
        launchAtLogin = LoginItem.isEnabled
    }

    func resetAllSettings() {
        let old = settings
        settings = DockLockSettings()
        SettingsStore.save(settings)
        runtime = RuntimeState()
        settingsDidChange(from: old)
        refreshDisplays()
    }

    // MARK: - Observation

    private func observeSystem() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            self?.scheduleDisplayRefresh()
        })

        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.systemDidWake()
            })
        }
        observers.append(workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.cancelPending(message: "system sleep")
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                               object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.applicationActivated(app)
        })
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.systemDidWake()
        })
    }

    private func startTimers() {
        let dock = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.dockTick() }
        dock.tolerance = 0.25
        RunLoop.main.add(dock, forMode: .common)
        dockTimer = dock

        let permission = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in self?.checkPermission() }
        permission.tolerance = 0.5
        RunLoop.main.add(permission, forMode: .common)
        permissionTimer = permission
    }

    private func checkPermission() {
        let trusted = Permissions.isAccessibilityTrusted
        guard trusted != accessibilityGranted else { return }
        accessibilityGranted = trusted
        if !trusted { pointerGuard.stop() }
        reconfigure()
        if trusted { scheduleHomeCheck(after: 0.5) }
    }

    private func dockTick() {
        ticks += 1
        refreshDockState(checkSpaces: ticks % 10 == 0)
        pointerGuard.ensureEnabled()
        if let until = pausedUntil, until != .distantFuture, until <= Date() {
            resume()
        }
        // Periodic safety net for escapes that happened without a display notification.
        if ticks % 3 == 0 { evaluateHome() }
    }

    private func systemDidWake() {
        displayRefreshWork?.cancel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.refreshDisplays()
            self?.scheduleHomeCheck(after: 0.5)
        }
    }

    private func scheduleDisplayRefresh() {
        displayRefreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refreshDisplays() }
        displayRefreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func refreshDisplays() {
        let newLayout = SystemDisplays.currentLayout()
        let arrangementChanged = newLayout.arrangementKey != layout.arrangementKey
        if newLayout != layout { layout = newLayout }
        if arrangementChanged {
            runtime.exclusiveTarget = nil
            runtime.temporarilyAllowed = []
            followCandidate = nil
        }
        refreshDockState(checkSpaces: arrangementChanged)
        ensurePreferences(touch: arrangementChanged)
        reconfigure()
        if arrangementChanged { scheduleHomeCheck(after: 1.0) }
        if let pending, layout.display(uuid: pending.target) == nil {
            cancelPending(message: L("The display was disconnected."))
        }
    }

    private func ensurePreferences(touch: Bool) {
        guard !layout.isEmpty else { return }
        let key = layout.arrangementKey
        var prefs = settings.arrangements[key] ?? DockPolicy.defaultPreferences(for: layout, dockDisplayUUID: dockDisplayUUID)
        var names = prefs.names
        for display in layout.displays { names[display.uuid] = layout.displayName(for: display) }
        prefs.names = names
        if touch { prefs.lastUsed = Date() }
        if settings.arrangements[key] != prefs {
            settings.arrangements[key] = prefs
            SettingsStore.save(settings)
        }
    }

    func readDockDisplayUUID() -> String? {
        guard let frame = DockInspector.dockFrame() else { return nil }
        return DockLocator.display(forDockFrame: frame, edge: DockInspector.edge(), in: layout)?.uuid
    }

    private func refreshDockState(checkSpaces: Bool) {
        let edge = DockInspector.edge()
        var needsReconfigure = false
        if edge != dockEdge {
            dockEdge = edge
            needsReconfigure = true
        }
        let autoHide = DockInspector.isAutoHideEnabled()
        if autoHide != dockAutoHide { dockAutoHide = autoHide }
        if checkSpaces {
            let spaces = DockInspector.displaysHaveSeparateSpaces()
            if spaces != separateSpaces { separateSpaces = spaces }
        }
        let current = readDockDisplayUUID()
        if current != dockDisplayUUID {
            let previous = dockDisplayUUID
            dockDisplayUUID = current
            dockMoved(from: previous, to: current)
        }
        if needsReconfigure { reconfigure() }
    }

    private func dockMoved(from previous: String?, to current: String?) {
        guard let current else { return }
        guide.dockArrived(on: current)
        statusMenu?.refreshIcon()
        guard settings.isEnabled, !runtime.paused, previous != nil else { return }

        if effectiveAllowed.contains(current) {
            if currentPreferences.allowedSet.contains(current) && currentPreferences.home != current {
                updatePreferences { $0.home = current }
            }
            return
        }
        if !isRelocating, let bypass = pointerGuard.recentBypass(within: 8), bypass == current {
            // The user held the modifier key and moved the Dock on purpose: keep it there.
            if settings.mode == .lock {
                runtime.exclusiveTarget = current
            } else {
                runtime.temporarilyAllowed.insert(current)
            }
            reconfigure()
            return
        }
        if !isRelocating { scheduleHomeCheck(after: 0.3) }
    }

    // MARK: - Guard configuration

    /// Recomputes what the event tap must guard and starts / stops it.
    func reconfigure() {
        guard started else { return }
        var newRuntime = runtime
        newRuntime.paused = pausedUntil.map { $0 > Date() } ?? false
        newRuntime.hideDock = manualHide || autoHideReason != nil
        if newRuntime != runtime { runtime = newRuntime }

        let configuration = DockPolicy.guardConfiguration(settings: settings, layout: layout, preferences: currentPreferences,
                                                          runtime: runtime, dockEdge: dockEdge)
        pointerGuard.update(configuration)
        if configuration.isActive && accessibilityGranted {
            pointerGuard.start()
        } else if !isRelocating {
            pointerGuard.stop()
        }
        let active = pointerGuard.isRunning && configuration.isActive
        if active != guardActive { guardActive = active }
        let count = Set(configuration.zones.map(\.displayUUID)).count
        if count != guardedDisplayCount { guardedDisplayCount = count }
        updateFollowTimer()
        statusMenu?.refreshIcon()
    }

    // MARK: - Relocation

    /// Moves the Dock back home when it is somewhere it may not be.
    private func evaluateHome() {
        guard started, !isRelocating, pending == nil else { return }
        guard let target = DockPolicy.homeTarget(dockDisplayUUID: dockDisplayUUID, settings: settings, layout: layout,
                                                 preferences: currentPreferences, runtime: runtime) else { return }
        guard settings.autoRelocate else { return }
        requestRelocation(to: target, automatic: true, rateLimited: true)
    }

    private func scheduleHomeCheck(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.refreshDockState(checkSpaces: false)
            self?.evaluateHome()
        }
    }

    private func requestRelocation(to display: DisplaySnapshot, automatic: Bool, rateLimited: Bool, job: String? = nil) {
        if rateLimited {
            guard DockPolicy.allowsAutomaticRelocation(history: automaticRelocations, now: Date()) else { return }
        }
        var request = PendingRelocation(target: display.uuid, automatic: automatic, rateLimited: rateLimited,
                                        idleRequirement: automatic ? idleRequirement() : 0.3)
        request.notBefore = ProcessInfo.processInfo.systemUptime + (automatic ? 0.3 : 0)
        if let existing = pending {
            if existing.target == display.uuid {
                if let job { pending?.jobs.append(job) }
                return
            }
            finishJobs(existing.jobs, ok: false, message: L("Superseded by another move."))
        }
        if let job { request.jobs.append(job) }
        pending = request
        startRelocationTimer()
    }

    private func idleRequirement() -> TimeInterval {
        settings.mode.isFollowMode ? max(0.3, settings.followDelay) : max(0.3, settings.relocationIdleDelay)
    }

    private func startRelocationTimer() {
        guard relocationTimer == nil else { return }
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in self?.relocationTick() }
        RunLoop.main.add(timer, forMode: .common)
        relocationTimer = timer
    }

    private func stopRelocationTimer() {
        relocationTimer?.invalidate()
        relocationTimer = nil
    }

    private func cancelPending(message: String) {
        guard let current = pending else { return }
        finishJobs(current.jobs, ok: false, message: message)
        pending = nil
        stopRelocationTimer()
    }

    private func relocationTick() {
        guard let request = pending else {
            stopRelocationTimer()
            return
        }
        guard !isRelocating else { return }
        guard let target = layout.display(uuid: request.target) else {
            cancelPending(message: L("The display was disconnected."))
            return
        }
        if readDockDisplayUUID() == request.target {
            finishJobs(request.jobs, ok: true, message: LF("The Dock is on %@.", displayName(target)))
            pending = nil
            stopRelocationTimer()
            refreshDockState(checkSpaces: false)
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        guard now >= request.notBefore else { return }
        let patience: TimeInterval = request.automatic ? 180 : 30
        if Date().timeIntervalSince(request.requestedAt) > patience {
            pending = nil
            stopRelocationTimer()
            relocationFailed(target: target, jobs: request.jobs,
                             detail: L("The pointer never rested long enough to move the Dock."))
            return
        }
        guard accessibilityGranted else {
            pending = nil
            stopRelocationTimer()
            relocationFailed(target: target, jobs: request.jobs, detail: L("Accessibility access is required."))
            return
        }
        guard UserActivity.secondsSincePointerActivity() >= request.idleRequirement,
              !UserActivity.anyMouseButtonDown,
              !UserActivity.isMenuOpen(),
              !UserActivity.isScreenLocked() else { return }
        perform(request, target: target)
    }

    private func perform(_ request: PendingRelocation, target: DisplaySnapshot) {
        isRelocating = true
        if request.rateLimited { automaticRelocations.append(Date()) }
        automaticRelocations = automaticRelocations.filter { Date().timeIntervalSince($0) < 600 }
        // The target must not be guarded while the pointer pushes on its edge.
        if !effectiveAllowed.contains(target.uuid) {
            runtime.temporarilyAllowed.insert(target.uuid)
        }
        reconfigure()
        pointerGuard.start()
        let layoutSnapshot = layout
        let edge = dockEdge
        let preferred = settings.preferredMoveStrategy
        Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await self.mover.move(to: target, layout: layoutSnapshot, edge: edge, preferredStrategy: preferred)
            self.relocationFinished(request, target: target, outcome: outcome)
        }
    }

    private func relocationFinished(_ request: PendingRelocation, target: DisplaySnapshot, outcome: DockMover.Outcome) {
        isRelocating = false
        refreshDockState(checkSpaces: false)
        if outcome.success {
            if let strategy = outcome.strategy, strategy.rawValue != settings.preferredMoveStrategy {
                settings.preferredMoveStrategy = strategy.rawValue
                SettingsStore.save(settings)
            }
            lastRelocation = RelocationRecord(date: Date(), displayName: displayName(target), success: true,
                                              detail: outcome.strategy?.rawValue ?? "")
            finishJobs(pending?.jobs ?? request.jobs, ok: true, message: LF("The Dock is on %@.", displayName(target)))
            pending = nil
            stopRelocationTimer()
        } else if var retry = pending, retry.target == target.uuid, retry.attempts + 1 < 2 {
            retry.attempts += 1
            retry.notBefore = ProcessInfo.processInfo.systemUptime + 2.0
            pending = retry
        } else {
            let jobs = pending?.jobs ?? request.jobs
            pending = nil
            stopRelocationTimer()
            relocationFailed(target: target, jobs: jobs, detail: outcome.message)
        }
        reconfigure()
    }

    private func relocationFailed(target: DisplaySnapshot, jobs: [String], detail: String) {
        lastRelocation = RelocationRecord(date: Date(), displayName: displayName(target), success: false, detail: detail)
        finishJobs(jobs, ok: false, message: LF("Could not move the Dock to %@: %@", displayName(target), detail))
        if settings.showRelocationGuide {
            let format: String
            switch dockEdge {
            case .bottom: format = "Push the pointer against the bottom of this screen to bring the Dock to %@."
            case .left: format = "Push the pointer against the left edge of this screen to bring the Dock to %@."
            case .right: format = "Push the pointer against the right edge of this screen to bring the Dock to %@."
            }
            guide.show(on: target, edge: dockEdge, message: LF(format, displayName(target)))
        }
        if settings.notifyOnRelocationFailure {
            Notifier.post(title: L("DockLock could not move the Dock"),
                          body: LF("Move the pointer to the Dock edge of %@ once — the Dock can only go there now.",
                                   displayName(target)))
        }
    }

    // MARK: - Jobs (CLI / Shortcuts waiting for a move)

    private func makeJob() -> String {
        let id = String(nextJob)
        nextJob += 1
        jobs[id] = .running
        return id
    }

    private func finishJobs(_ ids: [String], ok: Bool, message: String) {
        for id in ids { jobs[id] = .finished(ok, message) }
    }

    /// Waits (asynchronously) for a job to finish.
    @MainActor
    func waitForJob(_ id: String, timeout: TimeInterval = 30) async -> (Bool, String) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if case .finished(let ok, let message)? = jobs[id] {
                jobs.removeValue(forKey: id)
                return (ok, message)
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        return (false, L("Timed out."))
    }

    // MARK: - Follow modes

    private func updateFollowTimer() {
        let needsTimer = settings.isEnabled && (settings.mode == .followsMouse || settings.mode == .followsWindow)
            && !runtime.paused && !runtime.hideDock && accessibilityGranted
        if needsTimer && followTimer == nil {
            let interval = settings.mode == .followsMouse ? 0.3 : 0.5
            let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.followTick() }
            timer.tolerance = 0.1
            RunLoop.main.add(timer, forMode: .common)
            followTimer = timer
        } else if !needsTimer, let timer = followTimer {
            timer.invalidate()
            followTimer = nil
        }
    }

    private func followTick() {
        guard !isRelocating else { return }
        let candidate: DisplaySnapshot?
        switch settings.mode {
        case .followsMouse:
            candidate = layout.nearestDisplay(to: SystemDisplays.pointerLocation())
        case .followsWindow:
            candidate = displayForFrontmostApp(NSWorkspace.shared.frontmostApplication, useWindow: true)
        case .lock, .followsApps:
            return
        }
        followTowards(candidate)
    }

    private func applicationActivated(_ app: NSRunningApplication?) {
        guard settings.isEnabled, settings.mode == .followsApps, !runtime.paused, !runtime.hideDock else { return }
        // Give the app a moment to bring its window forward.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            self.followTowards(self.displayForFrontmostApp(app, useWindow: true))
        }
    }

    private func displayForFrontmostApp(_ app: NSRunningApplication?, useWindow: Bool) -> DisplaySnapshot? {
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              app.bundleIdentifier != "com.apple.dock" else { return nil }
        if let bundleID = app.bundleIdentifier, let rule = settings.rule(forBundleID: bundleID) {
            switch rule.target {
            case .ignore: return nil
            case .display(let uuid, let name): return layout.display(uuid: uuid) ?? layout.display(named: name)
            case .appWindow: break
            }
        }
        guard useWindow, let frame = AX.focusedWindowFrame(pid: app.processIdentifier) else { return nil }
        return layout.display(bestMatching: frame)
    }

    private func followTowards(_ candidate: DisplaySnapshot?) {
        guard let target = DockPolicy.followTarget(candidate: candidate, dockDisplayUUID: dockDisplayUUID, settings: settings,
                                                   layout: layout, preferences: currentPreferences, runtime: runtime) else {
            followCandidate = nil
            if let p = pending, p.automatic, !p.rateLimited { cancelPending(message: "follow target changed") }
            return
        }
        if pending?.target == target.uuid { return }
        requestRelocation(to: target, automatic: true, rateLimited: false)
    }

    // MARK: - Hiding the Dock (meetings)

    private func meetingReasonChanged(_ reason: String?) {
        autoHideReason = reason
        reconfigure()
        applyAutoHide()
    }

    func setManualHide(_ hide: Bool) {
        manualHide = hide
        reconfigure()
        applyAutoHide()
    }

    /// While hidden, a Dock that is always visible would stay on screen, so auto-hide is
    /// switched on (and switched back off afterwards) when the user allows it.
    private func applyAutoHide() {
        let hiding = runtime.hideDock && settings.isEnabled
        if hiding && settings.autoHideWhileHidden {
            if !DockInspector.isAutoHideEnabled() {
                DockInspector.setAutoHideEnabled(true)
                SettingsStore.autoHideEnabledByDockLock = true
            }
        } else if SettingsStore.autoHideEnabledByDockLock {
            DockInspector.setAutoHideEnabled(false)
            SettingsStore.autoHideEnabledByDockLock = false
        }
        dockAutoHide = DockInspector.isAutoHideEnabled()
    }

    private func restoreAutoHideAfterCrash() {
        if SettingsStore.autoHideEnabledByDockLock {
            DockInspector.setAutoHideEnabled(false)
            SettingsStore.autoHideEnabledByDockLock = false
        }
    }

    // MARK: - Pause

    func pause(minutes: Double?) {
        pausedUntil = minutes.map { Date().addingTimeInterval($0 * 60) } ?? .distantFuture
        cancelPending(message: L("Paused."))
        reconfigure()
    }

    func resume() {
        pausedUntil = nil
        reconfigure()
        scheduleHomeCheck(after: 0.5)
    }

    // MARK: - UI

    func showSettings(tab: SettingsTab? = nil) {
        if settingsWindow == nil { settingsWindow = SettingsWindowController(controller: self) }
        settingsWindow?.show(tab: tab)
    }

    func applyActivationPolicy() {
        NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
    }

    func handle(url: URL) {
        guard started else {
            queuedURLs.append(url)
            return
        }
        switch URLCommandParser.parse(url) {
        case .success(let command):
            _ = execute(command)
        case .failure(let error):
            NSLog("DockLock: ignored URL \(url.absoluteString): \(error.description)")
        }
    }

    private func perform(hotKey action: HotKeyAction) {
        switch action {
        case .toggleLock: _ = execute(.toggleEnabled)
        case .moveLeft: _ = execute(.move(.direction(.left)))
        case .moveRight: _ = execute(.move(.direction(.right)))
        case .moveUp: _ = execute(.move(.direction(.up)))
        case .moveDown: _ = execute(.move(.direction(.down)))
        case .moveToPointerDisplay: _ = execute(.move(.pointer))
        case .moveHome: _ = execute(.relocateHome)
        case .toggleHideDock: _ = execute(.setHideDock(nil))
        case .cycleMode:
            let modes = DockMode.allCases
            let index = modes.firstIndex(of: settings.mode) ?? 0
            _ = execute(.setMode(modes[(index + 1) % modes.count]))
        }
    }

    // MARK: - Commands

    func resolve(_ target: DisplayTarget) -> DisplaySnapshot? {
        switch target {
        case .name(let name):
            return layout.display(named: name)
        case .point(let x, let y):
            return layout.display(containing: CGPoint(x: x, y: y))
        case .direction(let direction):
            let origin = dockDisplay ?? layout.nearestDisplay(to: SystemDisplays.pointerLocation())
            return origin.flatMap { layout.adjacent(to: $0, direction: direction) }
        case .pointer:
            return layout.nearestDisplay(to: SystemDisplays.pointerLocation())
        case .home:
            let allowed = DockPolicy.effectiveAllowed(layout: layout, preferences: currentPreferences, runtime: RuntimeState())
            return DockPolicy.preferredAllowedDisplay(layout: layout, preferences: currentPreferences, allowed: allowed)
        }
    }

    /// Executes a command. Moves continue in the background; their job id is returned.
    @discardableResult
    func execute(_ command: DockCommand) -> CommandResult {
        switch command {
        case .setEnabled(let enabled):
            updateSettings { $0.isEnabled = enabled }
            return .success(enabled ? L("Dock locking is on.") : L("Dock locking is off."))
        case .toggleEnabled:
            return execute(.setEnabled(!settings.isEnabled))
        case .setMode(let mode):
            updateSettings {
                $0.mode = mode
                $0.isEnabled = true
            }
            return .success(LF("Mode: %@", mode.rawValue))
        case .setFollowMode(let mode, let on):
            if on {
                return execute(.setMode(mode))
            }
            if settings.mode == mode { updateSettings { $0.mode = .lock } }
            return .success(LF("Mode: %@", settings.mode.rawValue))
        case .move(let target):
            guard let display = resolve(target) else {
                return .failure(L("No matching display."))
            }
            return moveDock(to: display)
        case .relocateHome:
            runtime.exclusiveTarget = nil
            runtime.temporarilyAllowed = []
            reconfigure()
            guard let display = resolve(.home) else { return .failure(L("No display is allowed for the Dock.")) }
            return moveDock(to: display, deliberate: false)
        case .setAllowed(let target, let allowed):
            guard let display = resolve(target) else { return .failure(L("No matching display.")) }
            setAllowed(display, allowed)
            return .success(LF(allowed ? "Dock allowed on %@." : "Dock not allowed on %@.", displayName(display)))
        case .setHideDock(let flag):
            let hide = flag ?? !manualHide
            setManualHide(hide)
            return .success(hide ? L("The Dock is hidden.") : L("The Dock is no longer hidden."))
        case .pause(let minutes):
            pause(minutes: minutes)
            return .success(L("Dock locking paused."))
        case .resume:
            resume()
            return .success(L("Dock locking resumed."))
        case .status:
            let report = statusReport()
            return .success(StatusFormatter.text(report), json: ControlCodec.jsonString(report, pretty: true))
        case .displays:
            let report = statusReport()
            return .success(StatusFormatter.displayList(report.displays),
                            json: ControlCodec.jsonString(report.displays, pretty: true))
        case .currentDisplay:
            refreshDockState(checkSpaces: false)
            guard let display = dockDisplay else { return .failure(L("The Dock's display is unknown.")) }
            return .success(displayName(display), json: ControlCodec.jsonString(["display": displayName(display)]))
        case .queryMode:
            let token = settings.isEnabled ? settings.mode.rawValue : "disabled"
            return .success(token, json: ControlCodec.jsonString(["mode": token]))
        case .queryEnabled:
            return .success(settings.isEnabled ? "true" : "false")
        case .queryFollowMode(let mode):
            let on = settings.isEnabled && settings.mode == mode
            return .success(on ? "true" : "false")
        case .showSettings:
            showSettings()
            return .success()
        case .restartDock:
            DockInspector.restartDock()
            scheduleHomeCheck(after: 3)
            return .success(L("The Dock is restarting."))
        case .quit:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { NSApp.terminate(nil) }
            return .success(L("DockLock is quitting."))
        }
    }

    /// A deliberate move: in lock mode the target is held exclusively until the arrangement changes.
    private func moveDock(to display: DisplaySnapshot, deliberate: Bool = true) -> CommandResult {
        guard layout.count > 1 else { return .failure(L("Only one display is connected.")) }
        if deliberate {
            if settings.mode == .lock {
                runtime.exclusiveTarget = display.uuid
            } else if !effectiveAllowed.contains(display.uuid) {
                runtime.temporarilyAllowed.insert(display.uuid)
            }
            if isAllowed(display) && currentPreferences.home != display.uuid {
                updatePreferences { $0.home = display.uuid }
            }
        }
        reconfigure()
        if readDockDisplayUUID() == display.uuid {
            return .success(LF("The Dock is on %@.", displayName(display)))
        }
        guard accessibilityGranted else { return .failure(L("Accessibility access is required.")) }
        let job = makeJob()
        requestRelocation(to: display, automatic: false, rateLimited: false, job: job)
        return CommandResult(ok: true, message: LF("Moving the Dock to %@…", displayName(display)), json: nil, job: job)
    }

    /// Runs a command and, for moves, waits until the Dock arrived. Used by Shortcuts.
    @MainActor
    func executeAndWait(_ command: DockCommand) async -> CommandResult {
        let result = execute(command)
        guard let job = result.job else { return result }
        let (ok, message) = await waitForJob(job)
        return CommandResult(ok: ok, message: message, json: nil, job: nil)
    }

    /// Clears a manual placement ("Dock held on …").
    func releaseManualPlacement() {
        runtime.exclusiveTarget = nil
        runtime.temporarilyAllowed = []
        reconfigure()
        scheduleHomeCheck(after: 0.3)
    }

    // MARK: - CLI

    private func handleControlRequest(_ data: Data) -> Data {
        guard let request = ControlCodec.decode(ControlRequest.self, from: data) else {
            return ControlCodec.encode(ControlResponse(ok: false, message: "malformed request"))
        }
        switch request {
        case .command(let command, _):
            let result = execute(command)
            return ControlCodec.encode(ControlResponse(ok: result.ok, message: result.message, json: result.json,
                                                       pendingJob: result.job))
        case .job(let id):
            switch jobs[id] {
            case .running?:
                return ControlCodec.encode(ControlResponse(ok: true, message: "", pendingJob: id))
            case .finished(let ok, let message)?:
                jobs.removeValue(forKey: id)
                return ControlCodec.encode(ControlResponse(ok: ok, message: message))
            case nil:
                return ControlCodec.encode(ControlResponse(ok: false, message: "unknown job"))
            }
        }
    }

    // MARK: - Status

    func statusReport() -> StatusReport {
        let prefs = currentPreferences
        let displays = layout.displays.map { d in
            DisplayReport(name: layout.displayName(for: d), uuid: d.uuid, id: d.id,
                          x: Double(d.frame.minX), y: Double(d.frame.minY),
                          width: Double(d.frame.width), height: Double(d.frame.height),
                          isMain: d.isMain, isBuiltin: d.isBuiltin,
                          allowed: prefs.allowedSet.contains(d.uuid),
                          temporarilyAllowed: runtime.temporarilyAllowed.contains(d.uuid) || runtime.exclusiveTarget == d.uuid,
                          hasDock: d.uuid == dockDisplayUUID, isHome: prefs.home == d.uuid)
        }
        let last = lastRelocation.map { record in
            "\(record.success ? "moved to" : "failed to move to") \(record.displayName) at \(Self.timeFormatter.string(from: record.date))"
                + (record.detail.isEmpty ? "" : " (\(record.detail))")
        }
        return StatusReport(version: DockLockInfo.version, enabled: settings.isEnabled, mode: settings.mode.rawValue,
                            paused: runtime.paused, pausedUntil: pausedUntil == .distantFuture ? nil : pausedUntil,
                            dockHidden: runtime.hideDock, accessibilityGranted: accessibilityGranted,
                            guardActive: guardActive, guardedDisplays: guardedDisplayCount,
                            separateSpaces: separateSpaces, dockEdge: dockEdge.rawValue, dockAutoHide: dockAutoHide,
                            dockDisplay: dockDisplay.map(displayName), arrangement: layout.arrangementKey,
                            displays: displays, lastRelocation: last, warnings: warnings)
    }

    func diagnosticsText() -> String {
        var text = StatusFormatter.text(statusReport())
        text += "\n\nmacOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
        text += "\nClamp events: \(pointerGuard.clampCount)"
        text += "\nPreferred move strategy: \(settings.preferredMoveStrategy ?? "none yet")"
        text += "\nScreen-capture detection: \(ScreenCaptureDetector.isAvailable ? "available" : "unavailable")"
        text += "\nDock frame: \(DockInspector.dockFrame().map { NSStringFromRect($0) } ?? "unknown")"
        return text
    }
}
