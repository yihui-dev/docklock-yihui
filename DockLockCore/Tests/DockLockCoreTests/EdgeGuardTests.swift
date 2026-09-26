import Foundation
import XCTest
@testable import DockLockCore

/// Test fixtures, all in CG global coordinates (top-left origin, y down).
enum Fixtures {
    static let laptop = DisplaySnapshot(id: 1, uuid: "AAAA", name: "Built-in Retina Display",
                                        frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
                                        isMain: true, isBuiltin: true)
    /// Side by side, to the right of the laptop.
    static let studio = DisplaySnapshot(id: 2, uuid: "BBBB", name: "Studio Display",
                                        frame: CGRect(x: 1728, y: -323, width: 2560, height: 1440))
    /// Further right.
    static let dell = DisplaySnapshot(id: 3, uuid: "CCCC", name: "DELL U2720Q",
                                      frame: CGRect(x: 4288, y: -323, width: 2560, height: 1440))
    /// Stacked above the laptop, wider than it on both sides.
    static let above = DisplaySnapshot(id: 4, uuid: "DDDD", name: "LG UltraFine",
                                       frame: CGRect(x: -1056, y: -2160, width: 3840, height: 2160))

    static let sideBySide = DisplayLayout([laptop, studio])
    static let three = DisplayLayout([laptop, studio, dell])
    static let stacked = DisplayLayout([laptop, above])
}

final class EdgeGuardTests: XCTestCase {
    func testFreeBottomEdgeSideBySide() {
        let spans = EdgeGuardPlanner.freeSpans(of: Fixtures.studio, edge: .bottom, in: Fixtures.sideBySide)
        XCTAssertEqual(spans.count, 1)
        XCTAssertEqual(spans[0].low, 1728)
        XCTAssertEqual(spans[0].high, 1728 + 2560)
    }

    func testStackedDisplayKeepsSharedStripOpen() {
        // The display above overhangs the laptop on both sides; only the overhangs are free.
        let spans = EdgeGuardPlanner.freeSpans(of: Fixtures.above, edge: .bottom, in: Fixtures.stacked)
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].low, -1056)
        XCTAssertEqual(spans[0].high, 0)
        XCTAssertEqual(spans[1].low, 1728)
        XCTAssertEqual(spans[1].high, 2784)
        // The laptop's bottom edge is completely free.
        XCTAssertEqual(EdgeGuardPlanner.freeSpans(of: Fixtures.laptop, edge: .bottom, in: Fixtures.stacked).count, 1)
    }

    func testFullyCoveredEdgeIsNeverGuarded() {
        let top = DisplaySnapshot(id: 9, uuid: "TOP", name: "Top", frame: CGRect(x: 0, y: -1117, width: 1728, height: 1117))
        let layout = DisplayLayout([Fixtures.laptop, top])
        XCTAssertTrue(EdgeGuardPlanner.freeSpans(of: top, edge: .bottom, in: layout).isEmpty)
        XCTAssertEqual(EdgeGuardPlanner.fullyBlockedDisplays(edge: .bottom, in: layout).map(\.uuid), ["TOP"])
        XCTAssertTrue(EdgeGuardPlanner.zones(for: ["TOP"], edge: .bottom, in: layout, band: 3).isEmpty)
    }

    func testLeftAndRightEdges() {
        // Laptop's left edge is free; its right edge touches the studio display along the overlap.
        let left = EdgeGuardPlanner.freeSpans(of: Fixtures.laptop, edge: .left, in: Fixtures.sideBySide)
        XCTAssertEqual(left.count, 1)
        XCTAssertEqual(left[0].low, 0)
        XCTAssertEqual(left[0].high, 1117)
        let right = EdgeGuardPlanner.freeSpans(of: Fixtures.laptop, edge: .right, in: Fixtures.sideBySide)
        XCTAssertTrue(right.isEmpty, "the laptop's right edge is covered by the studio display")
        let studioLeft = EdgeGuardPlanner.freeSpans(of: Fixtures.studio, edge: .left, in: Fixtures.sideBySide)
        // Studio spans y -323…1117 against the laptop's 0…1117: only the top 323 points are free.
        XCTAssertEqual(studioLeft.count, 1)
        XCTAssertEqual(studioLeft[0].low, -323)
        XCTAssertEqual(studioLeft[0].high, 0)
    }

    func testBottomZoneClampsOnlyTheLastRows() {
        let zones = EdgeGuardPlanner.zones(for: ["BBBB"], edge: .bottom, in: Fixtures.sideBySide, band: 3)
        XCTAssertEqual(zones.count, 1)
        let zone = zones[0]
        let bottom = Fixtures.studio.frame.maxY // 1117
        XCTAssertEqual(zone.limit, bottom - 3)
        XCTAssertTrue(zone.contains(CGPoint(x: 2000, y: bottom - 1)))
        XCTAssertTrue(zone.contains(CGPoint(x: 2000, y: bottom - 2)))
        XCTAssertFalse(zone.contains(CGPoint(x: 2000, y: bottom - 3)))
        XCTAssertFalse(zone.contains(CGPoint(x: 2000, y: 500)))
        XCTAssertFalse(zone.contains(CGPoint(x: 1000, y: bottom - 1)), "laptop is not guarded")
        XCTAssertEqual(zone.clamp(CGPoint(x: 2000, y: bottom - 1)), CGPoint(x: 2000, y: bottom - 3))
    }

    func testLeftZoneClamp() {
        let zones = EdgeGuardPlanner.zones(for: ["AAAA"], edge: .left, in: Fixtures.sideBySide, band: 3)
        XCTAssertEqual(zones.count, 1)
        let zone = zones[0]
        XCTAssertEqual(zone.limit, 2)
        XCTAssertTrue(zone.contains(CGPoint(x: 0, y: 500)))
        XCTAssertTrue(zone.contains(CGPoint(x: 1, y: 500)))
        XCTAssertFalse(zone.contains(CGPoint(x: 2, y: 500)))
        XCTAssertEqual(zone.clamp(CGPoint(x: 0, y: 500)), CGPoint(x: 2, y: 500))
    }

    func testEngineClampsAndBypasses() {
        var engine = PointerClampEngine(configuration: GuardConfiguration(
            zones: EdgeGuardPlanner.zones(for: ["BBBB"], edge: .bottom, in: Fixtures.sideBySide, band: 3),
            bypassModifiers: [.command], keepHotCorners: false))
        let edge = CGPoint(x: 3000, y: 1116)
        XCTAssertEqual(engine.process(point: edge, modifiers: [], now: 0), .clamp(CGPoint(x: 3000, y: 1114)))
        XCTAssertEqual(engine.process(point: edge, modifiers: [.command, .shift], now: 0), .bypassed(displayUUID: "BBBB"))
        XCTAssertEqual(engine.process(point: edge, modifiers: [.shift], now: 0), .clamp(CGPoint(x: 3000, y: 1114)))
        XCTAssertEqual(engine.process(point: CGPoint(x: 100, y: 1116), modifiers: [], now: 0), .pass)
    }

    func testHotCornerGrace() {
        var engine = PointerClampEngine(configuration: GuardConfiguration(
            zones: EdgeGuardPlanner.zones(for: ["BBBB"], edge: .bottom, in: Fixtures.sideBySide, band: 3),
            keepHotCorners: true, cornerSize: 6, cornerGrace: 0.3))
        let corner = CGPoint(x: Fixtures.studio.frame.maxX - 1, y: 1116)
        XCTAssertEqual(engine.process(point: corner, modifiers: [], now: 10.0), .pass)
        XCTAssertEqual(engine.process(point: corner, modifiers: [], now: 10.2), .pass)
        XCTAssertEqual(engine.process(point: corner, modifiers: [], now: 10.5), .clamp(CGPoint(x: corner.x, y: 1114)))
        // Leaving the band resets the grace period.
        XCTAssertEqual(engine.process(point: CGPoint(x: corner.x, y: 900), modifiers: [], now: 11), .pass)
        XCTAssertEqual(engine.process(point: corner, modifiers: [], now: 11.1), .pass)
        // Away from the corners the edge is always held.
        XCTAssertEqual(engine.process(point: CGPoint(x: 3000, y: 1116), modifiers: [], now: 11.2),
                       .clamp(CGPoint(x: 3000, y: 1114)))
    }

    func testZonesNeverCoverSharedSpan() {
        // Invariant: no clamp zone may contain a point directly above another display.
        let layouts = [Fixtures.sideBySide, Fixtures.three, Fixtures.stacked]
        for layout in layouts {
            let zones = EdgeGuardPlanner.zones(for: Set(layout.uuids), edge: .bottom, in: layout, band: 3)
            for zone in zones {
                for x in stride(from: zone.spanLow, to: zone.spanHigh, by: 16) {
                    let below = CGPoint(x: x, y: zone.displayFrame.maxY + 0.5)
                    XCTAssertNil(layout.display(containing: below),
                                 "zone on \(zone.displayUUID) covers a crossing at x=\(x)")
                }
            }
        }
    }
}
