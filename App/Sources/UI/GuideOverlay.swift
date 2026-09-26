import AppKit
import SwiftUI

/// A small floating hint on the target display, shown when the Dock could not be moved
/// automatically: one push of the pointer against that display's Dock edge finishes the job,
/// and the pointer guard makes sure it cannot land anywhere else.
final class GuideOverlay {
    private var panel: NSPanel?
    private var targetUUID: String?
    private var dismissWork: DispatchWorkItem?

    func show(on display: DisplaySnapshot, edge: DockEdge, message: String) {
        dismiss()
        let size = CGSize(width: 440, height: 74)
        let screen = SystemDisplays.cocoaRect(fromCG: display.frame)
        let origin: CGPoint
        switch edge {
        case .bottom:
            origin = CGPoint(x: screen.midX - size.width / 2, y: screen.minY + 110)
        case .left:
            origin = CGPoint(x: screen.minX + 110, y: screen.midY - size.height / 2)
        case .right:
            origin = CGPoint(x: screen.maxX - 110 - size.width, y: screen.midY - size.height / 2)
        }
        let panel = NSPanel(contentRect: NSRect(origin: origin, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: GuideView(message: message, edge: edge))
        panel.orderFrontRegardless()
        self.panel = panel
        targetUUID = display.uuid

        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: work)
    }

    func dockArrived(on uuid: String?) {
        if let uuid, uuid == targetUUID { dismiss() }
    }

    func dismiss() {
        dismissWork?.cancel()
        dismissWork = nil
        panel?.orderOut(nil)
        panel = nil
        targetUUID = nil
    }
}

private struct GuideView: View {
    let message: String
    let edge: DockEdge

    private var arrow: String {
        switch edge {
        case .bottom: return "arrow.down.circle.fill"
        case .left: return "arrow.left.circle.fill"
        case .right: return "arrow.right.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: arrow)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.78)))
    }
}
