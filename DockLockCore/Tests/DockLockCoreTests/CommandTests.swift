import Foundation
import XCTest
@testable import DockLockCore

final class URLCommandTests: XCTestCase {
    private func parse(_ text: String) -> Result<DockCommand, CommandParseError> {
        URLCommandParser.parse(URL(string: text)!)
    }

    func testDockLockPlusCompatibleCommands() {
        XCTAssertEqual(try parse("DockLockPlus://enableDockLock").get(), .setEnabled(true))
        XCTAssertEqual(try parse("docklockplus://disableDockLock").get(), .setEnabled(false))
        XCTAssertEqual(try parse("DockLockPlus://enableDockFollowsMouse").get(), .setFollowMode(.followsMouse, true))
        XCTAssertEqual(try parse("DockLockPlus://disableDockFollowsMouse").get(), .setFollowMode(.followsMouse, false))
        XCTAssertEqual(try parse("DockLockPlus://quit").get(), .quit)
        XCTAssertEqual(try parse("DockLockPlus://moveDockUp").get(), .move(.direction(.up)))
        XCTAssertEqual(try parse("DockLockPlus://moveDockDown").get(), .move(.direction(.down)))
        XCTAssertEqual(try parse("DockLockPlus://moveDockLeft").get(), .move(.direction(.left)))
        XCTAssertEqual(try parse("DockLockPlus://moveDockRight").get(), .move(.direction(.right)))
        XCTAssertEqual(try parse("DockLockPlus://moveToDisplay?name=Studio").get(), .move(.name("Studio")))
        XCTAssertEqual(try parse("DockLockPlus://moveToDisplay?x=1920&y=200").get(), .move(.point(x: 1920, y: 200)))
        XCTAssertEqual(try parse("DockLockPlus://enableDockLockOnDisplay?name=Studio").get(), .setAllowed(.name("Studio"), true))
        XCTAssertEqual(try parse("DockLockPlus://disableDockLockOnDisplay?x=0&y=0").get(), .setAllowed(.point(x: 0, y: 0), false))
    }

    func testDockLockExtras() {
        XCTAssertEqual(try parse("docklock://enableDockFollowsActiveWindow").get(), .setFollowMode(.followsWindow, true))
        XCTAssertEqual(try parse("docklock://enableDockFollowsApps").get(), .setFollowMode(.followsApps, true))
        XCTAssertEqual(try parse("docklock://setMode?mode=follows-window").get(), .setMode(.followsWindow))
        XCTAssertEqual(try parse("docklock://setMode?mode=disabled").get(), .setEnabled(false))
        XCTAssertEqual(try parse("docklock://hideDock").get(), .setHideDock(true))
        XCTAssertEqual(try parse("docklock://showDock").get(), .setHideDock(false))
        XCTAssertEqual(try parse("docklock://toggleHideDock").get(), .setHideDock(nil))
        XCTAssertEqual(try parse("docklock://toggleHideDock?on=1").get(), .setHideDock(true))
        XCTAssertEqual(try parse("docklock://pause?minutes=15").get(), .pause(minutes: 15))
        XCTAssertEqual(try parse("docklock://pause").get(), .pause(minutes: nil))
        XCTAssertEqual(try parse("docklock://resume").get(), .resume)
        XCTAssertEqual(try parse("docklock://moveDockHome").get(), .relocateHome)
        XCTAssertEqual(try parse("docklock://moveDockToPointer").get(), .move(.pointer))
        XCTAssertEqual(try parse("docklock://moveToDisplay?name=Built-in%20Retina%20Display").get(),
                       .move(.name("Built-in Retina Display")))
        XCTAssertEqual(try parse("docklock:///toggleDockLock").get(), .toggleEnabled, "path form")
    }

    func testErrors() {
        XCTAssertEqual(parse("docklock://frobnicate"), .failure(.unknownCommand("frobnicate")))
        XCTAssertEqual(parse("docklock://moveToDisplay"), .failure(.missingArgument("name or x & y")))
        XCTAssertEqual(parse("docklock://moveToDisplay?x=a&y=2"), .failure(.invalidArgument("x/y")))
        XCTAssertEqual(parse("https://enableDockLock"), .failure(.unsupportedScheme("https")))
        XCTAssertEqual(parse("docklock://setMode?mode=sideways"), .failure(.invalidArgument("sideways")))
    }
}

final class CLITests: XCTestCase {
    private func command(_ args: [String]) -> DockCommand? {
        guard case .success(let invocation) = CLIParser.parse(args), case .command(let c) = invocation.action else { return nil }
        return c
    }

    func testDockLockPlusCompatibleSyntax() {
        XCTAssertEqual(command(["mode"]), .queryMode)
        XCTAssertEqual(command(["mode", "lock-selected"]), .setMode(.lock))
        XCTAssertEqual(command(["mode", "follows-mouse"]), .setMode(.followsMouse))
        XCTAssertEqual(command(["mode", "follows-apps"]), .setMode(.followsApps))
        XCTAssertEqual(command(["mode", "follows-window"]), .setMode(.followsWindow))
        XCTAssertEqual(command(["mode", "disabled"]), .setEnabled(false))
        XCTAssertEqual(command(["move", "left"]), .move(.direction(.left)))
        XCTAssertEqual(command(["move", "1920", "200"]), .move(.point(x: 1920, y: 200)))
        XCTAssertEqual(command(["move", "Studio Display"]), .move(.name("Studio Display")))
        XCTAssertEqual(command(["move", "Studio", "Display"]), .move(.name("Studio Display")))
        XCTAssertEqual(command(["allow", "--display", "Studio Display", "on"]), .setAllowed(.name("Studio Display"), true))
        XCTAssertEqual(command(["allow", "--display", "Studio Display", "off"]), .setAllowed(.name("Studio Display"), false))
        XCTAssertEqual(command(["allow", "--xy", "1", "1", "on"]), .setAllowed(.point(x: 1, y: 1), true))
        XCTAssertEqual(command(["disallow", "--display", "Studio"]), .setAllowed(.name("Studio"), false))
        XCTAssertEqual(command(["displays"]), .displays)
        XCTAssertEqual(command(["display"]), .currentDisplay)
        XCTAssertEqual(command(["status"]), .status)
        XCTAssertEqual(command(["quit"]), .quit)
    }

    func testExtras() {
        XCTAssertEqual(command(["hide"]), .setHideDock(true))
        XCTAssertEqual(command(["hide", "off"]), .setHideDock(false))
        XCTAssertEqual(command(["hide", "toggle"]), .setHideDock(nil))
        XCTAssertEqual(command(["pause", "15"]), .pause(minutes: 15))
        XCTAssertEqual(command(["move", "--pointer"]), .move(.pointer))
        XCTAssertEqual(command(["url", "docklock://moveDockUp"]), .move(.direction(.up)))
    }

    func testFlagsAndSpecialActions() throws {
        let status = try CLIParser.parse(["status", "--json"]).get()
        XCTAssertTrue(status.json)
        let move = try CLIParser.parse(["move", "right", "--no-wait"]).get()
        XCTAssertFalse(move.wait)
        XCTAssertEqual(move.action, .command(.move(.direction(.right))))
        XCTAssertEqual(try CLIParser.parse(["launch"]).get().action, .launch)
        XCTAssertEqual(try CLIParser.parse(["--help"]).get().action, .help)
        XCTAssertEqual(try CLIParser.parse([]).get().action, .help)
        XCTAssertEqual(try CLIParser.parse(["--version"]).get().action, .version)
    }

    func testErrors() {
        XCTAssertEqual(CLIParser.parse(["mode", "sideways"]), .failure(.invalidArgument("sideways")))
        XCTAssertEqual(CLIParser.parse(["jump"]), .failure(.unknownCommand("jump")))
        if case .success = CLIParser.parse(["allow", "--xy", "1", "on"]) { XCTFail("--xy needs two numbers") }
        if case .success = CLIParser.parse(["move"]) { XCTFail("move needs a target") }
    }

    func testGUILaunchArgumentsAreNotCLI() {
        XCTAssertFalse(CLIParser.looksLikeCLI([]))
        XCTAssertFalse(CLIParser.looksLikeCLI(["-psn_0_1234567"]))
        XCTAssertFalse(CLIParser.looksLikeCLI(["-NSDocumentRevisionsDebugMode", "YES"]))
        XCTAssertTrue(CLIParser.looksLikeCLI(["status"]))
        XCTAssertTrue(CLIParser.looksLikeCLI(["-NSDocumentRevisionsDebugMode", "YES", "status"]))
        XCTAssertTrue(CLIParser.looksLikeCLI(["--help"]))
    }
}

final class CodecTests: XCTestCase {
    func testControlRequestRoundTrip() {
        let requests: [ControlRequest] = [
            .command(.move(.point(x: 1, y: 2)), wait: true),
            .command(.setAllowed(.name("Studio"), false), wait: false),
            .command(.pause(minutes: nil), wait: true),
            .command(.setFollowMode(.followsApps, true), wait: true),
            .job("42"),
        ]
        for request in requests {
            let data = ControlCodec.encode(request)
            XCTAssertEqual(ControlCodec.decode(ControlRequest.self, from: data), request)
        }
    }

    func testStatusFormatter() {
        let report = StatusReport(version: "1.0.0", enabled: true, mode: "lock-selected", paused: false, pausedUntil: nil,
                                  dockHidden: false, accessibilityGranted: true, guardActive: true, guardedDisplays: 1,
                                  separateSpaces: true, dockEdge: "bottom", dockAutoHide: false, dockDisplay: "Studio",
                                  arrangement: "A+B",
                                  displays: [DisplayReport(name: "Studio", uuid: "B", id: 2, x: 1728, y: -323, width: 2560,
                                                           height: 1440, isMain: false, isBuiltin: false, allowed: true,
                                                           temporarilyAllowed: false, hasDock: true, isHome: true)],
                                  lastRelocation: nil, warnings: ["test warning"])
        let text = StatusFormatter.text(report)
        XCTAssertTrue(text.contains("Dock display:   Studio"))
        XCTAssertTrue(text.contains("*+h Studio"))
        XCTAssertTrue(text.contains("! test warning"))
    }
}

final class SettingsTests: XCTestCase {
    func testRoundTrip() throws {
        var settings = DockLockSettings()
        settings.mode = .followsApps
        settings.bypassModifiers = [.option, .command]
        settings.arrangements["A+B"] = ArrangementPreferences(allowed: ["A"], home: "A", names: ["A": "Laptop"])
        settings.appRules = [AppRule(bundleID: "us.zoom.xos", appName: "Zoom", target: .display(uuid: "A", name: "Laptop")),
                             AppRule(bundleID: "com.apple.finder", appName: "Finder", target: .ignore)]
        let decoded = try DockLockSettings.decode(settings.encoded())
        XCTAssertEqual(decoded, settings)
    }

    func testMissingAndCorruptKeysFallBackToDefaults() throws {
        let json = #"{"mode":"follows-mouse","guardBand":"wide","hotKeys":[{"action":"moveLeft","keyCode":0,"modifiers":1,"enabled":true}]}"#
        let decoded = try DockLockSettings.decode(Data(json.utf8))
        XCTAssertEqual(decoded.mode, .followsMouse)
        XCTAssertEqual(decoded.guardBand, 3, "corrupt value replaced by default")
        XCTAssertTrue(decoded.isEnabled)
        XCTAssertEqual(decoded.hotKeys.count, HotKeyAction.allCases.count, "missing hot keys are added")
        XCTAssertEqual(decoded.hotKeys.first(where: { $0.action == .moveLeft })?.keyCode, 0)
        XCTAssertEqual(decoded.hotKeys.first(where: { $0.action == .moveLeft })?.enabled, true)
    }

    func testModifierConversions() {
        let flags: UInt64 = ModifierSet.cgCommandMask | ModifierSet.cgOptionMask | 0x100 // plus an unrelated bit
        XCTAssertEqual(ModifierSet(cgFlags: flags), [.command, .option])
        XCTAssertEqual(ModifierSet([.command, .shift]).carbonFlags, (1 << 8) | (1 << 9))
        XCTAssertEqual(ModifierSet([.control, .option, .shift, .command]).symbols, "⌃⌥⇧⌘")
        XCTAssertEqual(HotKeyBinding(action: .moveLeft, keyCode: 123, modifiers: [.control, .option], enabled: true).displayString,
                       "⌃⌥←")
    }

    func testModeTokens() {
        XCTAssertEqual(DockMode(token: "LOCK-SELECTED"), .lock)
        XCTAssertEqual(DockMode(token: "follows-window"), .followsWindow)
        XCTAssertNil(DockMode(token: "disabled"))
        XCTAssertEqual(DockEdge(coreDockOrientation: 2), .bottom)
        XCTAssertNil(DockEdge(coreDockOrientation: 1))
        XCTAssertEqual(DockEdge(defaultsValue: "Left"), .left)
    }
}
