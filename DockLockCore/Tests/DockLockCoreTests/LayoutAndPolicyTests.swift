import Foundation
import XCTest
@testable import DockLockCore

final class DisplayLayoutTests: XCTestCase {
    func testOrderingAndArrangementKey() {
        let layout = DisplayLayout([Fixtures.dell, Fixtures.laptop, Fixtures.studio])
        XCTAssertEqual(layout.displays.map(\.uuid), ["AAAA", "BBBB", "CCCC"])
        XCTAssertEqual(layout.arrangementKey, "AAAA+BBBB+CCCC")
        XCTAssertEqual(DisplayLayout([Fixtures.studio, Fixtures.laptop]).arrangementKey,
                       DisplayLayout([Fixtures.laptop, Fixtures.studio]).arrangementKey)
        XCTAssertEqual(layout.main?.uuid, "AAAA")
    }

    func testNameResolution() {
        let layout = Fixtures.three
        XCTAssertEqual(layout.display(named: "Studio Display")?.uuid, "BBBB")
        XCTAssertEqual(layout.display(named: "studio display")?.uuid, "BBBB")
        XCTAssertEqual(layout.display(named: "dell")?.uuid, "CCCC", "unique partial match")
        XCTAssertEqual(layout.display(named: "main")?.uuid, "AAAA")
        XCTAssertEqual(layout.display(named: "builtin")?.uuid, "AAAA")
        XCTAssertEqual(layout.display(named: "#3")?.uuid, "CCCC")
        XCTAssertEqual(layout.display(named: "cccc")?.uuid, "CCCC")
        XCTAssertEqual(layout.display(named: "2")?.uuid, "BBBB", "numeric display ID")
        XCTAssertNil(layout.display(named: "Projector"))
        XCTAssertNil(layout.display(named: "d"), "ambiguous partial match")
    }

    func testIdenticalMonitorsGetDistinctNames() {
        var twin = Fixtures.dell
        twin.uuid = "EEEE"
        twin.id = 5
        twin.frame = CGRect(x: 6848, y: -323, width: 2560, height: 1440)
        let layout = DisplayLayout([Fixtures.laptop, Fixtures.dell, twin])
        XCTAssertEqual(layout.displayName(for: Fixtures.dell), "DELL U2720Q (1)")
        XCTAssertEqual(layout.displayName(for: twin), "DELL U2720Q (2)")
        XCTAssertEqual(layout.display(named: "DELL U2720Q (2)")?.uuid, "EEEE")
    }

    func testContainmentAndNearest() {
        let layout = Fixtures.sideBySide
        XCTAssertEqual(layout.display(containing: CGPoint(x: 1, y: 1))?.uuid, "AAAA")
        XCTAssertEqual(layout.display(containing: CGPoint(x: 1728, y: 10))?.uuid, "BBBB", "seam belongs to the right display")
        XCTAssertNil(layout.display(containing: CGPoint(x: 100, y: -100)))
        XCTAssertEqual(layout.nearestDisplay(to: CGPoint(x: 100, y: -100))?.uuid, "AAAA")
        XCTAssertEqual(layout.display(bestMatching: CGRect(x: 1600, y: 100, width: 400, height: 300))?.uuid, "BBBB")
    }

    func testAdjacency() {
        let layout = Fixtures.three
        XCTAssertEqual(layout.adjacent(to: Fixtures.laptop, direction: .right)?.uuid, "BBBB")
        XCTAssertEqual(layout.adjacent(to: Fixtures.studio, direction: .right)?.uuid, "CCCC")
        XCTAssertEqual(layout.adjacent(to: Fixtures.studio, direction: .left)?.uuid, "AAAA")
        XCTAssertNil(layout.adjacent(to: Fixtures.laptop, direction: .left))
        XCTAssertNil(layout.adjacent(to: Fixtures.laptop, direction: .down))

        let stacked = Fixtures.stacked
        XCTAssertEqual(stacked.adjacent(to: Fixtures.laptop, direction: .up)?.uuid, "DDDD")
        XCTAssertEqual(stacked.adjacent(to: Fixtures.above, direction: .down)?.uuid, "AAAA")
        XCTAssertNil(stacked.adjacent(to: Fixtures.laptop, direction: .right))
    }
}

final class DockLocatorTests: XCTestCase {
    func testVisibleBottomDock() {
        let frame = CGRect(x: 326, y: 1039, width: 1075, height: 78) // measured on a 1728×1117 laptop
        XCTAssertEqual(DockLocator.display(forDockFrame: frame, edge: .bottom, in: Fixtures.sideBySide)?.uuid, "AAAA")
        let onStudio = CGRect(x: 2500, y: 1117 - 70, width: 900, height: 70)
        XCTAssertEqual(DockLocator.display(forDockFrame: onStudio, edge: .bottom, in: Fixtures.sideBySide)?.uuid, "BBBB")
    }

    func testAutoHiddenDockBelowTheEdge() {
        let hidden = CGRect(x: 2500, y: 1117, width: 900, height: 70)
        XCTAssertEqual(DockLocator.display(forDockFrame: hidden, edge: .bottom, in: Fixtures.sideBySide)?.uuid, "BBBB")
    }

    func testVerticalDock() {
        let left = CGRect(x: 0, y: 200, width: 70, height: 700)
        XCTAssertEqual(DockLocator.display(forDockFrame: left, edge: .left, in: Fixtures.sideBySide)?.uuid, "AAAA")
        let right = CGRect(x: 4288 - 70, y: 0, width: 70, height: 700)
        XCTAssertEqual(DockLocator.display(forDockFrame: right, edge: .right, in: Fixtures.sideBySide)?.uuid, "BBBB")
    }

    func testRejectsEmptyFrames() {
        XCTAssertNil(DockLocator.display(forDockFrame: .zero, edge: .bottom, in: Fixtures.sideBySide))
        XCTAssertNil(DockLocator.display(forDockFrame: CGRect(x: 90000, y: 90000, width: 500, height: 60),
                                         edge: .bottom, in: Fixtures.sideBySide))
    }
}

final class PolicyTests: XCTestCase {
    let settings = DockLockSettings()

    func testDefaultPreferencesKeepDockWhereItIs() {
        let prefs = DockPolicy.defaultPreferences(for: Fixtures.three, dockDisplayUUID: "BBBB")
        XCTAssertEqual(prefs.allowed, ["BBBB"])
        XCTAssertEqual(prefs.home, "BBBB")
        let fallback = DockPolicy.defaultPreferences(for: Fixtures.three, dockDisplayUUID: nil)
        XCTAssertEqual(fallback.allowed, ["AAAA"])
        XCTAssertEqual(fallback.names["CCCC"], "DELL U2720Q")
    }

    func testGuardedDisplays() {
        let prefs = ArrangementPreferences(allowed: ["AAAA"], home: "AAAA")
        var runtime = RuntimeState()
        XCTAssertEqual(DockPolicy.guardedDisplays(settings: settings, layout: Fixtures.three, preferences: prefs, runtime: runtime),
                       ["BBBB", "CCCC"])
        runtime.temporarilyAllowed = ["CCCC"]
        XCTAssertEqual(DockPolicy.guardedDisplays(settings: settings, layout: Fixtures.three, preferences: prefs, runtime: runtime),
                       ["BBBB"])
        runtime.exclusiveTarget = "BBBB"
        XCTAssertEqual(DockPolicy.guardedDisplays(settings: settings, layout: Fixtures.three, preferences: prefs, runtime: runtime),
                       ["AAAA", "CCCC"], "a manual placement holds the Dock on that display only")
        runtime.exclusiveTarget = "GONE"
        XCTAssertEqual(DockPolicy.guardedDisplays(settings: settings, layout: Fixtures.three, preferences: prefs, runtime: runtime),
                       ["BBBB"], "a disconnected exclusive target is ignored")
        runtime.exclusiveTarget = nil
        runtime.hideDock = true
        XCTAssertEqual(DockPolicy.guardedDisplays(settings: settings, layout: Fixtures.three, preferences: prefs, runtime: runtime),
                       ["AAAA", "BBBB", "CCCC"])
        runtime.paused = true
        XCTAssertTrue(DockPolicy.guardedDisplays(settings: settings, layout: Fixtures.three, preferences: prefs, runtime: runtime).isEmpty)

        var disabled = settings
        disabled.isEnabled = false
        XCTAssertTrue(DockPolicy.guardedDisplays(settings: disabled, layout: Fixtures.three, preferences: prefs,
                                                 runtime: RuntimeState()).isEmpty)
    }

    func testSingleDisplayOnlyGuardedWhenHiding() {
        let single = DisplayLayout([Fixtures.laptop])
        let prefs = ArrangementPreferences(allowed: ["AAAA"])
        XCTAssertTrue(DockPolicy.guardedDisplays(settings: settings, layout: single, preferences: prefs,
                                                 runtime: RuntimeState()).isEmpty)
        XCTAssertEqual(DockPolicy.guardedDisplays(settings: settings, layout: single, preferences: prefs,
                                                  runtime: RuntimeState(hideDock: true)), ["AAAA"])
    }

    func testNoAllowedDisplayHidesDockEverywhere() {
        let prefs = ArrangementPreferences(allowed: [])
        XCTAssertEqual(DockPolicy.guardedDisplays(settings: settings, layout: Fixtures.sideBySide, preferences: prefs,
                                                  runtime: RuntimeState()), ["AAAA", "BBBB"])
        XCTAssertNil(DockPolicy.homeTarget(dockDisplayUUID: "BBBB", settings: settings, layout: Fixtures.sideBySide,
                                           preferences: prefs, runtime: RuntimeState()))
    }

    func testHomeTarget() {
        let prefs = ArrangementPreferences(allowed: ["AAAA", "CCCC"], home: "CCCC")
        let rt = RuntimeState()
        XCTAssertNil(DockPolicy.homeTarget(dockDisplayUUID: "AAAA", settings: settings, layout: Fixtures.three,
                                           preferences: prefs, runtime: rt), "already on an allowed display")
        XCTAssertEqual(DockPolicy.homeTarget(dockDisplayUUID: "BBBB", settings: settings, layout: Fixtures.three,
                                             preferences: prefs, runtime: rt)?.uuid, "CCCC")
        let noHome = ArrangementPreferences(allowed: ["CCCC", "AAAA"], home: "ZZZZ")
        XCTAssertEqual(DockPolicy.homeTarget(dockDisplayUUID: "BBBB", settings: settings, layout: Fixtures.three,
                                             preferences: noHome, runtime: rt)?.uuid, "AAAA", "main display first")
        XCTAssertNil(DockPolicy.homeTarget(dockDisplayUUID: "BBBB", settings: settings, layout: Fixtures.three,
                                           preferences: prefs, runtime: RuntimeState(hideDock: true)))
        XCTAssertEqual(DockPolicy.homeTarget(dockDisplayUUID: "AAAA", settings: settings, layout: Fixtures.three,
                                             preferences: prefs, runtime: RuntimeState(exclusiveTarget: "BBBB"))?.uuid, "BBBB")
    }

    func testFollowTarget() {
        var s = settings
        s.mode = .followsMouse
        let prefs = ArrangementPreferences(allowed: ["AAAA", "BBBB"])
        XCTAssertEqual(DockPolicy.followTarget(candidate: Fixtures.studio, dockDisplayUUID: "AAAA", settings: s,
                                               layout: Fixtures.three, preferences: prefs, runtime: RuntimeState())?.uuid, "BBBB")
        XCTAssertNil(DockPolicy.followTarget(candidate: Fixtures.dell, dockDisplayUUID: "AAAA", settings: s,
                                             layout: Fixtures.three, preferences: prefs, runtime: RuntimeState()),
                     "not allowed")
        XCTAssertNil(DockPolicy.followTarget(candidate: Fixtures.laptop, dockDisplayUUID: "AAAA", settings: s,
                                             layout: Fixtures.three, preferences: prefs, runtime: RuntimeState()),
                     "already there")
        s.mode = .lock
        XCTAssertNil(DockPolicy.followTarget(candidate: Fixtures.studio, dockDisplayUUID: "AAAA", settings: s,
                                             layout: Fixtures.three, preferences: prefs, runtime: RuntimeState()))
    }

    func testGuardConfigurationDropsBypassWhileHiding() {
        var s = settings
        s.bypassModifiers = [.option]
        let prefs = ArrangementPreferences(allowed: ["AAAA"])
        let normal = DockPolicy.guardConfiguration(settings: s, layout: Fixtures.sideBySide, preferences: prefs,
                                                   runtime: RuntimeState(), dockEdge: .bottom)
        XCTAssertEqual(normal.bypassModifiers, [.option])
        XCTAssertEqual(normal.zones.map(\.displayUUID), ["BBBB"])
        let hiding = DockPolicy.guardConfiguration(settings: s, layout: Fixtures.sideBySide, preferences: prefs,
                                                   runtime: RuntimeState(hideDock: true), dockEdge: .bottom)
        XCTAssertEqual(hiding.bypassModifiers, [])
        XCTAssertEqual(Set(hiding.zones.map(\.displayUUID)), ["AAAA", "BBBB"])
    }

    func testRelocationRateLimit() {
        let now = Date()
        let recent = (0..<6).map { now.addingTimeInterval(-Double($0) * 10) }
        XCTAssertFalse(DockPolicy.allowsAutomaticRelocation(history: recent, now: now))
        let old = (0..<6).map { now.addingTimeInterval(-400 - Double($0)) }
        XCTAssertTrue(DockPolicy.allowsAutomaticRelocation(history: old, now: now))
    }
}
