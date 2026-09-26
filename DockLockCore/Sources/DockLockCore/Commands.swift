import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// How a command refers to a display.
public enum DisplayTarget: Codable, Equatable, Sendable {
    /// Display name, UUID, numeric ID, "#n", "main" or "builtin".
    case name(String)
    /// The display containing this point (CG global coordinates: 0,0 = top-left of the main display).
    case point(x: Double, y: Double)
    /// The neighbour of the Dock's current display.
    case direction(Direction)
    /// The display under the mouse pointer.
    case pointer
    /// The home display of the current arrangement.
    case home
}

/// Every action DockLock can perform. The menu, hot keys, URL scheme, CLI and Shortcuts
/// all end up here, so they behave identically.
public enum DockCommand: Codable, Equatable, Sendable {
    case setEnabled(Bool)
    case toggleEnabled
    case setMode(DockMode)
    /// Turn a follow mode on, or off (back to plain locking if it was the active mode).
    case setFollowMode(DockMode, Bool)
    case move(DisplayTarget)
    case setAllowed(DisplayTarget, Bool)
    /// Hide the Dock everywhere (meeting / screen sharing). nil toggles.
    case setHideDock(Bool?)
    /// nil pauses until resumed.
    case pause(minutes: Double?)
    case resume
    case relocateHome
    case status
    case displays
    case currentDisplay
    case queryMode
    case queryEnabled
    case queryFollowMode(DockMode)
    case showSettings
    case restartDock
    case quit
}

// MARK: - URL scheme

public enum CommandParseError: Error, Equatable, CustomStringConvertible {
    case unknownCommand(String)
    case missingArgument(String)
    case invalidArgument(String)
    case unsupportedScheme(String)

    public var description: String {
        switch self {
        case .unknownCommand(let c): return "Unknown command: \(c)"
        case .missingArgument(let a): return "Missing argument: \(a)"
        case .invalidArgument(let a): return "Invalid argument: \(a)"
        case .unsupportedScheme(let s): return "Unsupported URL scheme: \(s)"
        }
    }
}

/// Parses `docklock://<command>?<params>` (and the DockLock Plus spelling `DockLockPlus://…`).
///
/// Supported commands (case-insensitive), compatible with DockLock Plus:
/// enableDockLock, disableDockLock, toggleDockLock, enableDockFollowsMouse, disableDockFollowsMouse,
/// enableDockFollowsActiveWindow, disableDockFollowsActiveWindow, enableDockFollowsApps,
/// disableDockFollowsApps, moveDockUp/Down/Left/Right, moveToDisplay?name=…|x=…&y=…,
/// enableDockLockOnDisplay?name=…|x=…&y=…, disableDockLockOnDisplay?…, quit,
/// plus DockLock extras: setMode?mode=…, hideDock / showDock / toggleHideDock,
/// pause?minutes=…, resume, moveDockHome, moveDockToPointer, settings, restartDock.
public enum URLCommandParser {
    public static func parse(_ url: URL) -> Result<DockCommand, CommandParseError> {
        let scheme = (url.scheme ?? "").lowercased()
        guard DockLockInfo.urlSchemes.contains(scheme) else { return .failure(.unsupportedScheme(scheme)) }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var params: [String: String] = [:]
        for item in components?.queryItems ?? [] {
            params[item.name.lowercased()] = item.value ?? ""
        }
        var name = url.host ?? ""
        if name.isEmpty {
            name = url.pathComponents.first(where: { $0 != "/" }) ?? ""
        }
        return parse(command: name, params: params)
    }

    public static func parse(command rawName: String, params: [String: String]) -> Result<DockCommand, CommandParseError> {
        let name = rawName.lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "_", with: "")
        switch name {
        case "enabledocklock", "enable", "lock", "on":
            return .success(.setEnabled(true))
        case "disabledocklock", "disable", "unlock", "off":
            return .success(.setEnabled(false))
        case "toggledocklock", "toggle":
            return .success(.toggleEnabled)
        case "enabledockfollowsmouse":
            return .success(.setFollowMode(.followsMouse, true))
        case "disabledockfollowsmouse":
            return .success(.setFollowMode(.followsMouse, false))
        case "enabledockfollowsactivewindow", "enabledockfollowswindow":
            return .success(.setFollowMode(.followsWindow, true))
        case "disabledockfollowsactivewindow", "disabledockfollowswindow":
            return .success(.setFollowMode(.followsWindow, false))
        case "enabledockfollowsapps", "enabledockfollowsappswhenactive":
            return .success(.setFollowMode(.followsApps, true))
        case "disabledockfollowsapps", "disabledockfollowsappswhenactive":
            return .success(.setFollowMode(.followsApps, false))
        case "movedockup": return .success(.move(.direction(.up)))
        case "movedockdown": return .success(.move(.direction(.down)))
        case "movedockleft": return .success(.move(.direction(.left)))
        case "movedockright": return .success(.move(.direction(.right)))
        case "movedockhome", "relocate", "home":
            return .success(.relocateHome)
        case "movedocktopointer", "movedocktomouse", "movedocktocursor":
            return .success(.move(.pointer))
        case "movetodisplay", "movedocktodisplay", "move":
            return displayTarget(params).map { .move($0) }
        case "enabledocklockondisplay", "allowdisplay", "allowdockondisplay":
            return displayTarget(params).map { .setAllowed($0, true) }
        case "disabledocklockondisplay", "disallowdisplay", "disallowdockondisplay":
            return displayTarget(params).map { .setAllowed($0, false) }
        case "setmode", "mode":
            guard let token = params["mode"] ?? params["value"] else { return .failure(.missingArgument("mode")) }
            if token.lowercased() == "disabled" { return .success(.setEnabled(false)) }
            guard let mode = DockMode(token: token) else { return .failure(.invalidArgument(token)) }
            return .success(.setMode(mode))
        case "hidedock":
            return .success(.setHideDock(true))
        case "showdock":
            return .success(.setHideDock(false))
        case "togglehidedock", "meetingmode":
            if let on = params["on"] ?? params["enabled"] {
                guard let flag = bool(on) else { return .failure(.invalidArgument(on)) }
                return .success(.setHideDock(flag))
            }
            return .success(.setHideDock(nil))
        case "pause":
            if let minutes = params["minutes"] {
                guard let value = Double(minutes), value > 0 else { return .failure(.invalidArgument(minutes)) }
                return .success(.pause(minutes: value))
            }
            return .success(.pause(minutes: nil))
        case "resume":
            return .success(.resume)
        case "settings", "preferences", "show":
            return .success(.showSettings)
        case "restartdock":
            return .success(.restartDock)
        case "quit", "exit":
            return .success(.quit)
        default:
            return .failure(.unknownCommand(rawName))
        }
    }

    static func displayTarget(_ params: [String: String]) -> Result<DisplayTarget, CommandParseError> {
        if let name = params["name"] ?? params["display"], !name.isEmpty {
            return .success(.name(name))
        }
        if let xs = params["x"], let ys = params["y"] {
            guard let x = Double(xs), let y = Double(ys) else { return .failure(.invalidArgument("x/y")) }
            return .success(.point(x: x, y: y))
        }
        if let dir = params["direction"] {
            guard let d = Direction(token: dir) else { return .failure(.invalidArgument(dir)) }
            return .success(.direction(d))
        }
        return .failure(.missingArgument("name or x & y"))
    }

    static func bool(_ text: String) -> Bool? {
        switch text.lowercased() {
        case "1", "true", "yes", "on": return true
        case "0", "false", "no", "off": return false
        default: return nil
        }
    }
}

// MARK: - Command line

public enum CLIAction: Equatable {
    case help
    case version
    case launch
    case command(DockCommand)
}

public struct CLIInvocation: Equatable {
    public var action: CLIAction
    public var json: Bool
    /// For move commands: wait for the Dock to arrive (default) or return immediately.
    public var wait: Bool

    public init(action: CLIAction, json: Bool = false, wait: Bool = true) {
        self.action = action
        self.json = json
        self.wait = wait
    }
}

/// Parses the command line interface, compatible with DockLock Plus:
///
///     docklock mode [lock-selected|follows-mouse|follows-apps|follows-window|disabled]
///     docklock move left|right|up|down | <x> <y> | "<display name>" | --pointer | --home
///     docklock allow --display "<display name>" on|off
///     docklock allow --xy <x> <y> on|off
///     docklock displays | display | status [--json]
///     docklock enable | disable | toggle | hide [on|off] | pause [minutes] | resume
///     docklock launch | quit | settings | restart-dock | url <docklock://…>
public enum CLIParser {
    public static let subcommands: Set<String> = [
        "mode", "move", "allow", "disallow", "displays", "display", "status", "launch", "quit",
        "enable", "disable", "toggle", "hide", "show", "pause", "resume", "relocate", "home",
        "settings", "restart-dock", "url", "help", "version",
    ]

    /// Whether these process arguments ask for the CLI rather than the app.
    public static func looksLikeCLI(_ arguments: [String]) -> Bool {
        let args = meaningful(arguments)
        guard let first = args.first else { return false }
        return subcommands.contains(first.lowercased()) || ["-h", "--help", "-v", "--version"].contains(first)
    }

    /// Drops arguments macOS / Xcode add to GUI launches (-psn_…, -NSDocumentRevisionsDebugMode YES …).
    public static func meaningful(_ arguments: [String]) -> [String] {
        var result: [String] = []
        var skipNext = false
        for arg in arguments {
            if skipNext { skipNext = false; continue }
            if arg.hasPrefix("-psn_") { continue }
            if arg.hasPrefix("-NS") || arg.hasPrefix("-Apple") || arg.hasPrefix("-com.apple") {
                skipNext = true
                continue
            }
            result.append(arg)
        }
        return result
    }

    public static func parse(_ arguments: [String]) -> Result<CLIInvocation, CommandParseError> {
        var args = meaningful(arguments)
        var json = false
        var wait = true
        args.removeAll { arg in
            switch arg {
            case "--json": json = true; return true
            case "--no-wait": wait = false; return true
            default: return false
            }
        }
        guard let head = args.first else { return .success(CLIInvocation(action: .help)) }
        let rest = Array(args.dropFirst())
        let make: (DockCommand) -> Result<CLIInvocation, CommandParseError> = {
            .success(CLIInvocation(action: .command($0), json: json, wait: wait))
        }

        switch head.lowercased() {
        case "-h", "--help", "help":
            return .success(CLIInvocation(action: .help))
        case "-v", "--version", "version":
            return .success(CLIInvocation(action: .version, json: json))
        case "launch":
            return .success(CLIInvocation(action: .launch))
        case "quit":
            return make(.quit)
        case "status":
            return make(.status)
        case "displays":
            return make(.displays)
        case "display":
            return make(.currentDisplay)
        case "enable":
            return make(.setEnabled(true))
        case "disable":
            return make(.setEnabled(false))
        case "toggle":
            return make(.toggleEnabled)
        case "relocate", "home":
            return make(.relocateHome)
        case "settings":
            return make(.showSettings)
        case "restart-dock":
            return make(.restartDock)
        case "resume":
            return make(.resume)
        case "show":
            return make(.setHideDock(false))
        case "hide":
            guard let value = rest.first else { return make(.setHideDock(true)) }
            if value.lowercased() == "toggle" { return make(.setHideDock(nil)) }
            guard let flag = URLCommandParser.bool(value) else { return .failure(.invalidArgument(value)) }
            return make(.setHideDock(flag))
        case "pause":
            guard let value = rest.first else { return make(.pause(minutes: nil)) }
            guard let minutes = Double(value), minutes > 0 else { return .failure(.invalidArgument(value)) }
            return make(.pause(minutes: minutes))
        case "mode":
            guard let token = rest.first else { return make(.queryMode) }
            if token.lowercased() == "disabled" { return make(.setEnabled(false)) }
            guard let mode = DockMode(token: token) else { return .failure(.invalidArgument(token)) }
            return make(.setMode(mode))
        case "move":
            return parseMoveTarget(rest).flatMap { make(.move($0)) }
        case "allow", "disallow":
            let defaultFlag = head.lowercased() == "allow"
            return parseAllow(rest, defaultFlag: defaultFlag).flatMap { make(.setAllowed($0.0, $0.1)) }
        case "url":
            guard let text = rest.first, let url = URL(string: text) else { return .failure(.missingArgument("url")) }
            return URLCommandParser.parse(url).flatMap { make($0) }
        default:
            return .failure(.unknownCommand(head))
        }
    }

    static func parseMoveTarget(_ rest: [String]) -> Result<DisplayTarget, CommandParseError> {
        guard let first = rest.first else { return .failure(.missingArgument("left|right|up|down, <x> <y> or a display name")) }
        switch first.lowercased() {
        case "--pointer", "--mouse", "--cursor", "pointer": return .success(.pointer)
        case "--home", "home": return .success(.home)
        default: break
        }
        if rest.count == 1, let direction = Direction(token: first) {
            return .success(.direction(direction))
        }
        if rest.count == 2, let x = Double(rest[0]), let y = Double(rest[1]) {
            return .success(.point(x: x, y: y))
        }
        let name = rest.joined(separator: " ")
        return .success(.name(name))
    }

    static func parseAllow(_ rest: [String], defaultFlag: Bool) -> Result<(DisplayTarget, Bool), CommandParseError> {
        var args = rest
        var flag = defaultFlag
        if let last = args.last, let parsed = URLCommandParser.bool(last) {
            flag = defaultFlag ? parsed : !parsed
            args.removeLast()
        }
        guard let option = args.first else { return .failure(.missingArgument("--display <name> or --xy <x> <y>")) }
        switch option {
        case "--display", "-d":
            let name = args.dropFirst().joined(separator: " ")
            guard !name.isEmpty else { return .failure(.missingArgument("display name")) }
            return .success((.name(name), flag))
        case "--xy":
            guard args.count == 3, let x = Double(args[1]), let y = Double(args[2]) else {
                return .failure(.invalidArgument("--xy expects <x> <y>"))
            }
            return .success((.point(x: x, y: y), flag))
        default:
            return .success((.name(args.joined(separator: " ")), flag))
        }
    }

    public static let helpText = """
    DockLock \(DockLockInfo.version) — keep the macOS Dock on the displays you choose.

    USAGE
      docklock <command> [arguments] [--json] [--no-wait]

    COMMANDS
      status                         Show state, displays and where the Dock is
      displays                       List displays (* = Dock, + = allowed, h = home)
      display                        Print the display that currently hosts the Dock
      mode                           Print the current mode
      mode <token>                   lock-selected | follows-mouse | follows-apps | follows-window | disabled
      enable | disable | toggle      Turn Dock locking on / off
      move left|right|up|down        Move the Dock to the neighbouring display
      move <x> <y>                   Move the Dock to the display containing the point (0,0 = top-left of main)
      move "<display name>"          Move the Dock to a display by name (also: UUID, #n, main, builtin)
      move --pointer | --home        Move the Dock to the pointer's display / its home display
      allow --display "<name>" on|off  Allow or disallow the Dock on a display
      allow --xy <x> <y> on|off      Same, choosing the display by a point
      hide [on|off|toggle]           Hide the Dock on every display (meetings, screen sharing)
      show                           Stop hiding the Dock
      pause [minutes] | resume       Pause locking (until resumed, or for some minutes)
      relocate                       Move the Dock back to its home display now
      settings                       Open the settings window
      restart-dock                   Restart the Dock process
      url <docklock://…>             Run a URL-scheme command
      launch | quit                  Start or quit the DockLock app
      version | help

    EXIT CODES
      0 success · 1 invalid usage · 2 command failed · 3 DockLock is not running · 4 communication error
    """
}

// MARK: - IPC between the CLI and the app

public enum ControlRequest: Codable, Equatable, Sendable {
    case command(DockCommand, wait: Bool)
    case job(String)
}

public struct ControlResponse: Codable, Equatable, Sendable {
    public var ok: Bool
    public var message: String
    /// Machine-readable result (status report, display name, booleans …) as JSON text.
    public var json: String?
    /// Set when the command continues in the background (moving the Dock); poll with `.job(id)`.
    public var pendingJob: String?

    public init(ok: Bool, message: String, json: String? = nil, pendingJob: String? = nil) {
        self.ok = ok
        self.message = message
        self.json = json
        self.pendingJob = pendingJob
    }
}

public enum ControlCodec {
    public static func encode<T: Encodable>(_ value: T) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(value)) ?? Data()
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? JSONDecoder().decode(type, from: data)
    }

    public static func jsonString<T: Encodable>(_ value: T, pretty: Bool = false) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.sortedKeys, .prettyPrinted] : [.sortedKeys]
        guard let data = try? encoder.encode(value) else { return "null" }
        return String(decoding: data, as: UTF8.self)
    }
}
