import AppIntents
import AppKit

// Apple Shortcuts / Siri actions. They run inside the DockLock app, which macOS launches in the
// background when needed. The set mirrors DockLock Plus's actions, plus a few extras.

enum IntentFailure: Error, CustomLocalizedStringResourceConvertible {
    case failed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .failed(let message): return "\(message)"
        }
    }
}

@MainActor
private func sharedController() async -> AppController {
    let controller = AppController.shared
    // Give a freshly launched app a moment to read its displays.
    if controller.layout.isEmpty {
        controller.start()
        controller.refreshDisplays()
    }
    return controller
}

@MainActor
private func run(_ command: DockCommand) async -> CommandResult {
    await sharedController().executeAndWait(command)
}

struct DisplayNameOptions: DynamicOptionsProvider {
    @MainActor
    func results() async throws -> [String] {
        let controller = await sharedController()
        return controller.layout.displays.map(controller.displayName)
    }
}

enum DockDirection: String, AppEnum {
    case left, right, up, down

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Direction"
    static let caseDisplayRepresentations: [DockDirection: DisplayRepresentation] = [
        .left: "Left",
        .right: "Right",
        .up: "Up",
        .down: "Down",
    ]

    var direction: Direction {
        switch self {
        case .left: return .left
        case .right: return .right
        case .up: return .up
        case .down: return .down
        }
    }
}

// MARK: - On / off

struct EnableDockLockIntent: AppIntent {
    static let title: LocalizedStringResource = "Enable DockLock"
    static let description = IntentDescription("Locks the Dock to the displays it is allowed on.")

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await run(.setEnabled(true))
        return .result()
    }
}

struct DisableDockLockIntent: AppIntent {
    static let title: LocalizedStringResource = "Disable DockLock"
    static let description = IntentDescription("Restores the default Dock behaviour.")

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await run(.setEnabled(false))
        return .result()
    }
}

struct IsDockLockEnabledIntent: AppIntent {
    static let title: LocalizedStringResource = "Is DockLock Enabled?"

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: await sharedController().settings.isEnabled)
    }
}

// MARK: - Follow modes

struct EnableFollowsMouseIntent: AppIntent {
    static let title: LocalizedStringResource = "Enable Dock Follows Mouse"

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await run(.setFollowMode(.followsMouse, true))
        return .result()
    }
}

struct DisableFollowsMouseIntent: AppIntent {
    static let title: LocalizedStringResource = "Disable Dock Follows Mouse"

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await run(.setFollowMode(.followsMouse, false))
        return .result()
    }
}

struct IsFollowsMouseEnabledIntent: AppIntent {
    static let title: LocalizedStringResource = "Is Dock Follows Mouse Enabled?"

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let settings = await sharedController().settings
        return .result(value: settings.isEnabled && settings.mode == .followsMouse)
    }
}

struct EnableFollowsWindowIntent: AppIntent {
    static let title: LocalizedStringResource = "Enable Dock Follows Active Window"

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await run(.setFollowMode(.followsWindow, true))
        return .result()
    }
}

struct DisableFollowsWindowIntent: AppIntent {
    static let title: LocalizedStringResource = "Disable Dock Follows Active Window"

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await run(.setFollowMode(.followsWindow, false))
        return .result()
    }
}

struct IsFollowsWindowEnabledIntent: AppIntent {
    static let title: LocalizedStringResource = "Is Dock Follows Active Window Enabled?"

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let settings = await sharedController().settings
        return .result(value: settings.isEnabled && settings.mode == .followsWindow)
    }
}

struct EnableFollowsAppsIntent: AppIntent {
    static let title: LocalizedStringResource = "Enable Dock Follows Apps When Active"

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await run(.setFollowMode(.followsApps, true))
        return .result()
    }
}

struct DisableFollowsAppsIntent: AppIntent {
    static let title: LocalizedStringResource = "Disable Dock Follows Apps When Active"

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await run(.setFollowMode(.followsApps, false))
        return .result()
    }
}

struct IsFollowsAppsEnabledIntent: AppIntent {
    static let title: LocalizedStringResource = "Is Dock Follows Apps When Active Enabled?"

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let settings = await sharedController().settings
        return .result(value: settings.isEnabled && settings.mode == .followsApps)
    }
}

// MARK: - App

struct LaunchDockLockIntent: AppIntent {
    static let title: LocalizedStringResource = "Launch DockLock"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await sharedController()
        return .result()
    }
}

struct QuitDockLockIntent: AppIntent {
    static let title: LocalizedStringResource = "Quit DockLock"

    @MainActor
    func perform() async throws -> some IntentResult {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
        return .result()
    }
}

// MARK: - Moving the Dock

struct MoveDockToDisplayIntent: AppIntent {
    static let title: LocalizedStringResource = "Move Dock to Display"
    static let description = IntentDescription("Moves the Dock to the display with this name and keeps it there.")

    @Parameter(title: "Display Name", optionsProvider: DisplayNameOptions())
    var displayName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Move Dock to \(\.$displayName)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: await run(.move(.name(displayName))).ok)
    }
}

struct MoveDockToAdjacentDisplayIntent: AppIntent {
    static let title: LocalizedStringResource = "Move Dock to Adjacent Display"

    @Parameter(title: "Direction", default: .right)
    var direction: DockDirection

    static var parameterSummary: some ParameterSummary {
        Summary("Move Dock to the display \(\.$direction)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: await run(.move(.direction(direction.direction))).ok)
    }
}

struct MoveDockToDisplayAtCoordinateIntent: AppIntent {
    static let title: LocalizedStringResource = "Move Dock to Display at Coordinate"
    static let description = IntentDescription("Coordinates start at 0,0 in the top-left corner of the main display. X=1, Y=1 is the main display.")

    @Parameter(title: "X", default: 1)
    var x: Int

    @Parameter(title: "Y", default: 1)
    var y: Int

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: await run(.move(.point(x: Double(x), y: Double(y)))).ok)
    }
}

struct MoveDockToPointerDisplayIntent: AppIntent {
    static let title: LocalizedStringResource = "Move Dock to Display with Pointer"

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: await run(.move(.pointer)).ok)
    }
}

struct GetDockDisplayIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Current Dock Display"

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = await run(.currentDisplay)
        guard result.ok else { throw IntentFailure.failed(result.message) }
        return .result(value: result.message)
    }
}

// MARK: - Allowed displays

struct AllowDockOnDisplayIntent: AppIntent {
    static let title: LocalizedStringResource = "Allow Dock on Display"

    @Parameter(title: "Display Name", optionsProvider: DisplayNameOptions())
    var displayName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Allow Dock on \(\.$displayName)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: await run(.setAllowed(.name(displayName), true)).ok)
    }
}

struct DisallowDockOnDisplayIntent: AppIntent {
    static let title: LocalizedStringResource = "Disallow Dock on Display"

    @Parameter(title: "Display Name", optionsProvider: DisplayNameOptions())
    var displayName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Disallow Dock on \(\.$displayName)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: await run(.setAllowed(.name(displayName), false)).ok)
    }
}

struct AllowDockAtCoordinateIntent: AppIntent {
    static let title: LocalizedStringResource = "Allow Dock on Display at Coordinate"

    @Parameter(title: "X", default: 1)
    var x: Int

    @Parameter(title: "Y", default: 1)
    var y: Int

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: await run(.setAllowed(.point(x: Double(x), y: Double(y)), true)).ok)
    }
}

struct DisallowDockAtCoordinateIntent: AppIntent {
    static let title: LocalizedStringResource = "Disallow Dock on Display at Coordinate"

    @Parameter(title: "X", default: 1)
    var x: Int

    @Parameter(title: "Y", default: 1)
    var y: Int

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: await run(.setAllowed(.point(x: Double(x), y: Double(y)), false)).ok)
    }
}

// MARK: - Extras

struct SetHideDockIntent: AppIntent {
    static let title: LocalizedStringResource = "Hide Dock on All Displays"
    static let description = IntentDescription("Keeps the Dock from appearing anywhere, e.g. during a meeting or presentation.")

    @Parameter(title: "Hide", default: true)
    var hide: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Hide Dock: \(\.$hide)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await run(.setHideDock(hide))
        return .result()
    }
}

struct MoveDockHomeIntent: AppIntent {
    static let title: LocalizedStringResource = "Move Dock to Home Display"

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: await run(.relocateHome).ok)
    }
}

struct DockLockShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: EnableDockLockIntent(), phrases: ["Lock the Dock with \(.applicationName)", "Enable \(.applicationName)"])
        AppShortcut(intent: DisableDockLockIntent(), phrases: ["Unlock the Dock with \(.applicationName)", "Disable \(.applicationName)"])
        AppShortcut(intent: MoveDockToPointerDisplayIntent(), phrases: ["Bring the Dock here with \(.applicationName)"])
        AppShortcut(intent: MoveDockHomeIntent(), phrases: ["Move the Dock home with \(.applicationName)"])
        AppShortcut(intent: SetHideDockIntent(), phrases: ["Hide the Dock with \(.applicationName)"])
    }
}
