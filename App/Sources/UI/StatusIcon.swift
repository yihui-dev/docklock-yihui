import AppKit

/// Draws the menu bar icon: a screen with the Dock at its bottom and a small lock.
enum StatusIcon {
    enum State {
        case locked
        case following
        case disabled
        case hidden
        case paused
        case attention
    }

    static func image(for state: State) -> NSImage {
        let size = NSSize(width: 20, height: 16)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let alpha: CGFloat = (state == .disabled || state == .paused) ? 0.45 : 1

            // Screen outline.
            let screen = NSBezierPath(roundedRect: NSRect(x: 1, y: 2.5, width: 14.5, height: 11), xRadius: 2, yRadius: 2)
            screen.lineWidth = 1.4
            NSColor.black.withAlphaComponent(alpha).setStroke()
            screen.stroke()

            // The Dock.
            if state != .hidden {
                NSColor.black.withAlphaComponent(alpha).setFill()
                NSBezierPath(roundedRect: NSRect(x: 4, y: 4.3, width: 8.5, height: 2.3), xRadius: 1, yRadius: 1).fill()
            } else {
                let slash = NSBezierPath()
                slash.move(to: NSPoint(x: 3, y: 4))
                slash.line(to: NSPoint(x: 13.5, y: 12))
                slash.lineWidth = 1.4
                slash.stroke()
            }

            // Badge on the right: lock, arrows, pause or exclamation.
            let badge = NSRect(x: 13, y: 0.5, width: 7, height: 7)
            NSGraphicsContext.current?.cgContext.setBlendMode(.clear)
            NSBezierPath(ovalIn: badge.insetBy(dx: -1.2, dy: -1.2)).fill()
            NSGraphicsContext.current?.cgContext.setBlendMode(.normal)
            NSColor.black.withAlphaComponent(alpha).setFill()
            NSColor.black.withAlphaComponent(alpha).setStroke()
            switch state {
            case .locked, .disabled:
                let body = NSBezierPath(roundedRect: NSRect(x: 14, y: 0.8, width: 5.2, height: 3.8), xRadius: 0.8, yRadius: 0.8)
                body.fill()
                let shackle = NSBezierPath()
                shackle.appendArc(withCenter: NSPoint(x: 16.6, y: 4.6), radius: 1.6, startAngle: 0, endAngle: 180)
                shackle.lineWidth = 1.1
                shackle.stroke()
            case .following:
                let arrow = NSBezierPath()
                arrow.move(to: NSPoint(x: 14, y: 3.5))
                arrow.line(to: NSPoint(x: 19.5, y: 3.5))
                arrow.move(to: NSPoint(x: 17.3, y: 5.8))
                arrow.line(to: NSPoint(x: 19.6, y: 3.5))
                arrow.line(to: NSPoint(x: 17.3, y: 1.2))
                arrow.lineWidth = 1.2
                arrow.stroke()
            case .paused:
                NSBezierPath(rect: NSRect(x: 14.5, y: 0.8, width: 1.6, height: 5.4)).fill()
                NSBezierPath(rect: NSRect(x: 17.4, y: 0.8, width: 1.6, height: 5.4)).fill()
            case .attention:
                NSBezierPath(rect: NSRect(x: 15.9, y: 2.6, width: 1.5, height: 4.4)).fill()
                NSBezierPath(ovalIn: NSRect(x: 15.9, y: 0.4, width: 1.5, height: 1.5)).fill()
            case .hidden:
                break
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "DockLock"
        return image
    }
}
