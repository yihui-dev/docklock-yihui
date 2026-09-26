import Foundation

/// Works out which display hosts the Dock from the Dock's frame.
///
/// The frame comes from `CoreDockGetRect` or the Dock's accessibility tree. When the Dock is
/// auto-hidden the frame sits (partly) beyond the display edge, so this scores displays by how
/// close their Dock edge is to the frame rather than requiring containment.
public enum DockLocator {
    public static func display(forDockFrame frame: CGRect, edge: DockEdge,
                               in layout: DisplayLayout) -> DisplaySnapshot? {
        guard !layout.isEmpty, frame.width > 1, frame.height > 1,
              frame.minX.isFinite, frame.minY.isFinite else { return nil }

        var best: (DisplaySnapshot, CGFloat)?
        for display in layout.displays {
            let d = display.frame
            let score: CGFloat
            switch edge {
            case .bottom:
                let alongOff = offset(frame.midX, d.minX, d.maxX)
                let across = min(abs(frame.maxY - d.maxY), abs(frame.minY - d.maxY))
                score = alongOff * 4 + across
            case .left:
                let alongOff = offset(frame.midY, d.minY, d.maxY)
                let across = min(abs(frame.minX - d.minX), abs(frame.maxX - d.minX))
                score = alongOff * 4 + across
            case .right:
                let alongOff = offset(frame.midY, d.minY, d.maxY)
                let across = min(abs(frame.maxX - d.maxX), abs(frame.minX - d.maxX))
                score = alongOff * 4 + across
            }
            if best == nil || score < best!.1 {
                best = (display, score)
            }
        }
        // Reject nonsense (e.g. a frame reported far away from every display).
        guard let result = best, result.1 < 400 else { return nil }
        return result.0
    }

    /// Distance of `value` outside the closed interval [low, high]; 0 inside.
    private static func offset(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
        if value < low { return low - value }
        if value > high { return value - high }
        return 0
    }
}
