import AppKit
import CoreGraphics

/// Reads the current display arrangement from Core Graphics / AppKit.
enum SystemDisplays {
    static func currentLayout() -> DisplayLayout {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return .empty }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return .empty }

        let names = screenNames()
        var snapshots: [DisplaySnapshot] = []
        for id in ids.prefix(Int(count)) {
            // Members of a mirror set other than the primary one share its pixels: skip them.
            if CGDisplayMirrorsDisplay(id) != kCGNullDirectDisplay { continue }
            let builtin = CGDisplayIsBuiltin(id) != 0
            let fallbackName = builtin
                ? NSLocalizedString("Built-in Display", comment: "Fallback name for the internal display")
                : String(format: NSLocalizedString("Display %u", comment: "Fallback display name"), id)
            snapshots.append(DisplaySnapshot(id: id,
                                             uuid: uuid(for: id),
                                             name: names[id] ?? fallbackName,
                                             frame: CGDisplayBounds(id),
                                             isMain: CGDisplayIsMain(id) != 0,
                                             isBuiltin: builtin))
        }
        return DisplayLayout(snapshots)
    }

    /// A stable identifier that survives reboots and re-plugging (unlike the display ID).
    static func uuid(for id: CGDirectDisplayID) -> String {
        if let unmanaged = CGDisplayCreateUUIDFromDisplayID(id) {
            let uuid = unmanaged.takeRetainedValue()
            if let text = CFUUIDCreateString(nil, uuid) {
                return (text as String).uppercased()
            }
        }
        // Fall back to vendor/model/serial, which is stable for most monitors.
        return String(format: "DISPLAY-%08X-%08X-%08X-%08X", CGDisplayVendorNumber(id), CGDisplayModelNumber(id),
                      CGDisplaySerialNumber(id), CGDisplayUnitNumber(id))
    }

    private static func screenNames() -> [CGDirectDisplayID: String] {
        var result: [CGDirectDisplayID: String] = [:]
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        for screen in NSScreen.screens {
            if let number = screen.deviceDescription[key] as? NSNumber {
                result[CGDirectDisplayID(number.uint32Value)] = screen.localizedName
            }
        }
        return result
    }

    /// Current pointer location in CG global coordinates.
    static func pointerLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    /// Converts a CG global rect (top-left origin) into Cocoa screen coordinates (bottom-left origin).
    static func cocoaRect(fromCG rect: CGRect) -> CGRect {
        let primaryHeight = CGDisplayBounds(CGMainDisplayID()).height
        return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func screen(for display: DisplaySnapshot) -> NSScreen? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return NSScreen.screens.first { ($0.deviceDescription[key] as? NSNumber)?.uint32Value == display.id }
    }
}
