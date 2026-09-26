import AppKit
import SwiftUI

/// A binding into one settings field that writes through `AppController.updateSettings`.
extension AppController {
    func binding<Value: Equatable>(_ keyPath: WritableKeyPath<DockLockSettings, Value>) -> Binding<Value> {
        Binding(get: { self.settings[keyPath: keyPath] },
                set: { newValue in self.updateSettings { $0[keyPath: keyPath] = newValue } })
    }
}

/// The overall state, used for the sidebar pill, the status card and the menu bar icon.
enum LockState {
    case active, following, needsPermission, hidden, paused, off

    init(_ controller: AppController) {
        if !controller.settings.isEnabled {
            self = .off
        } else if !controller.accessibilityGranted {
            self = .needsPermission
        } else if controller.isPaused {
            self = .paused
        } else if controller.isDockHidden {
            self = .hidden
        } else if controller.settings.mode.isFollowMode {
            self = .following
        } else {
            self = .active
        }
    }

    var title: String {
        switch self {
        case .active: return L("Active")
        case .following: return L("Following")
        case .needsPermission: return L("Needs Permission")
        case .hidden: return L("Dock Hidden")
        case .paused: return L("Paused")
        case .off: return L("Off")
        }
    }

    var color: Color {
        switch self {
        case .active, .following: return .green
        case .needsPermission: return .orange
        case .hidden: return .blue
        case .paused, .off: return .gray
        }
    }

    var symbol: String {
        switch self {
        case .active: return "lock.fill"
        case .following: return "arrow.left.and.right"
        case .needsPermission: return "exclamationmark.triangle.fill"
        case .hidden: return "eye.slash.fill"
        case .paused: return "pause.fill"
        case .off: return "lock.open"
        }
    }
}

/// Small coloured capsule showing the lock state.
struct StatePill: View {
    let state: LockState

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(state.color).frame(width: 7, height: 7)
            Text(state.title).font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(state.color.opacity(0.14)))
        .foregroundStyle(.primary)
    }
}

/// A rounded, coloured square holding an SF Symbol — the System Settings look.
struct IconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(LinearGradient(colors: [color.opacity(0.85), color], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.52, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .shadow(color: .black.opacity(0.12), radius: 0.5, y: 0.5)
    }
}

struct WarningBanner: View {
    let text: String
    var systemImage = "exclamationmark.triangle.fill"
    var tint = Color.orange
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 28)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .controlSize(.regular)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(tint.opacity(0.25)))
    }
}

struct FootnoteText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.16)))
            .foregroundStyle(color)
    }
}

/// A row label with an icon tile, a title and an optional explanation underneath.
struct SettingLabel: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var color: Color = .accentColor

    var body: some View {
        HStack(spacing: 10) {
            if let symbol { IconTile(symbol: symbol, color: color, size: 24) }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        HStack {
            Text(title)
            Slider(value: $value, in: range, step: step)
                .frame(minWidth: 140)
            Text(String(format: step < 1 ? "%.2g %@" : "%.0f %@", value, unit))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
        }
    }
}

/// Sidebar-style translucent background.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

/// Page layout: large title and subtitle above a grouped form.
struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 24, weight: .bold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 2)
            Form {
                content()
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }
}
