import AppKit
import SwiftUI

extension AppController {
    /// Displays whose Dock edge is currently guarded.
    var guardedDisplayUUIDs: Set<String> {
        DockPolicy.guardedDisplays(settings: settings, layout: layout, preferences: currentPreferences, runtime: runtime)
    }
}

struct DisplaysPage: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        SettingsPage(title: L("Displays"),
                     subtitle: L("Choose where the Dock may appear. Click a display to allow or block it.")) {
            Section {
                ArrangementMapView()
                    .frame(height: 230)
                MapLegend()
            }

            Section {
                ForEach(controller.layout.displays, id: \.uuid) { display in
                    DisplayRow(display: display)
                }
                if controller.currentPreferences.allowed.filter({ controller.layout.display(uuid: $0) != nil }).isEmpty {
                    WarningBanner(text: L("No display is allowed: the Dock is kept hidden on every display (works best with Dock auto-hide on)."),
                                  systemImage: "eye.slash.fill", tint: .blue)
                }
                ForEach(controller.fullyBlockedDisplays, id: \.uuid) { display in
                    FootnoteText(LF("%@ has another display directly below its Dock edge, so the Dock cannot be summoned there.",
                                    controller.displayName(display)))
                }
            } header: {
                Text(L("Allow Dock on Display"))
            } footer: {
                FootnoteText(L("These choices are remembered separately for every combination of connected displays."))
            }

            RememberedArrangementsSection()
        }
    }
}

private struct DisplayRow: View {
    @EnvironmentObject var controller: AppController
    let display: DisplaySnapshot

    var body: some View {
        let allowed = controller.isAllowed(display)
        HStack(spacing: 10) {
            IconTile(symbol: display.isBuiltin ? "laptopcomputer" : "display",
                     color: allowed ? .blue : .gray, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(controller.displayName(display)).font(.body.weight(.medium))
                HStack(spacing: 5) {
                    if display.uuid == controller.dockDisplayUUID { Badge(text: L("Dock"), color: .accentColor) }
                    if controller.currentPreferences.home == display.uuid { Badge(text: L("Home"), color: .green) }
                    if display.isMain { Badge(text: L("Main"), color: .secondary) }
                    if controller.runtime.exclusiveTarget == display.uuid { Badge(text: L("Held"), color: .orange) }
                    Text(verbatim: "\(Int(display.frame.width)) × \(Int(display.frame.height))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                controller.execute(.move(.name(display.uuid)))
            } label: {
                Label(L("Move Dock Here"), systemImage: "arrow.down.to.line")
            }
            .controlSize(.small)
            .disabled(display.uuid == controller.dockDisplayUUID || controller.layout.count < 2)
            Toggle("", isOn: Binding(get: { controller.isAllowed(display) },
                                     set: { controller.setAllowed(display, $0) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .help(allowed ? L("Disallow Dock Here") : L("Allow Dock Here"))
        }
        .padding(.vertical, 2)
    }
}

private struct RememberedArrangementsSection: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        let current = controller.layout.arrangementKey
        let others = controller.settings.arrangements
            .filter { $0.key != current }
            .sorted { ($0.value.lastUsed ?? .distantPast) > ($1.value.lastUsed ?? .distantPast) }
        if !others.isEmpty {
            Section {
                ForEach(others, id: \.key) { entry in
                    HStack(spacing: 10) {
                        IconTile(symbol: "rectangle.3.group", color: .gray, size: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(describe(entry.key, entry.value))
                            Text(LF("Allowed: %@", allowedNames(entry.value)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(L("Forget")) { controller.forgetArrangement(entry.key) }
                            .controlSize(.small)
                    }
                }
            } header: {
                Text(L("Other Remembered Arrangements"))
            }
        }
    }

    private func describe(_ key: String, _ prefs: ArrangementPreferences) -> String {
        ArrangementKey.uuids(in: key).map { prefs.names[$0] ?? String($0.prefix(8)) }.joined(separator: " + ")
    }

    private func allowedNames(_ prefs: ArrangementPreferences) -> String {
        let names = prefs.allowed.map { prefs.names[$0] ?? String($0.prefix(8)) }
        return names.isEmpty ? L("none") : names.joined(separator: ", ")
    }
}

/// A scaled, interactive picture of the display arrangement.
struct ArrangementMapView: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        GeometryReader { geometry in
            let displays = controller.layout.displays
            let bounds = displays.reduce(CGRect.null) { $0.union($1.frame) }
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                if displays.isEmpty || bounds.isNull || bounds.width <= 0 || bounds.height <= 0 {
                    Text(L("No displays found"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let inset: CGFloat = 22
                    let scale = min((geometry.size.width - inset * 2) / bounds.width,
                                    (geometry.size.height - inset * 2) / bounds.height)
                    let offsetX = (geometry.size.width - bounds.width * scale) / 2
                    let offsetY = (geometry.size.height - bounds.height * scale) / 2
                    ForEach(displays, id: \.uuid) { display in
                        DisplayTile(display: display, scale: scale)
                            .frame(width: max(display.frame.width * scale - 6, 12),
                                   height: max(display.frame.height * scale - 6, 12))
                            .offset(x: offsetX + (display.frame.minX - bounds.minX) * scale + 3,
                                    y: offsetY + (display.frame.minY - bounds.minY) * scale + 3)
                    }
                }
            }
        }
    }
}

private struct DisplayTile: View {
    @EnvironmentObject var controller: AppController
    let display: DisplaySnapshot
    let scale: CGFloat
    @State private var hovering = false

    var body: some View {
        let allowed = controller.effectiveAllowed.contains(display.uuid)
        let hasDock = display.uuid == controller.dockDisplayUUID
        let guarded = controller.guardActive && controller.guardedDisplayUUIDs.contains(display.uuid)
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(allowed
                          ? LinearGradient(colors: [Color(red: 0.25, green: 0.52, blue: 0.98), Color(red: 0.36, green: 0.30, blue: 0.86)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [Color.gray.opacity(0.45), Color.gray.opacity(0.30)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(hovering ? Color.accentColor : Color.black.opacity(0.25), lineWidth: hovering ? 2 : 1)

                VStack(spacing: 0) {
                    if display.isMain {
                        Rectangle().fill(Color.white.opacity(0.35)).frame(height: max(3, geo.size.height * 0.04))
                    }
                    Spacer(minLength: 0)
                    if hasDock {
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill([Color.red, .orange, .yellow, .green, .blue][i])
                                    .frame(width: dotSize(geo), height: dotSize(geo))
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.8)))
                        .padding(.bottom, 5)
                    }
                    if guarded {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(height: 3)
                            .padding(.horizontal, 6)
                            .padding(.bottom, 2)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(spacing: 4) {
                    Image(systemName: allowed ? "checkmark.circle.fill" : "nosign")
                        .font(.system(size: min(22, geo.size.height * 0.2), weight: .semibold))
                    Text(controller.displayName(display))
                        .font(.caption.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                .padding(6)
            }
        }
        .scaleEffect(hovering ? 1.02 : 1)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { controller.setAllowed(display, !controller.isAllowed(display)) }
        .contextMenu {
            Button(L("Move Dock Here")) { controller.execute(.move(.name(display.uuid))) }
            Button(L("Set as Home Display")) { controller.setHome(display) }
            Button(controller.isAllowed(display) ? L("Disallow Dock Here") : L("Allow Dock Here")) {
                controller.setAllowed(display, !controller.isAllowed(display))
            }
        }
        .help(controller.displayName(display))
    }

    private func dotSize(_ geo: GeometryProxy) -> CGFloat {
        min(9, max(4, geo.size.width * 0.045))
    }
}

private struct MapLegend: View {
    var body: some View {
        HStack(spacing: 18) {
            item(L("Dock allowed")) {
                RoundedRectangle(cornerRadius: 3).fill(Color(red: 0.3, green: 0.45, blue: 0.95)).frame(width: 16, height: 11)
            }
            item(L("Dock blocked")) {
                RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.45)).frame(width: 16, height: 11)
            }
            item(L("Guarded edge")) {
                Rectangle().fill(Color.orange).frame(width: 16, height: 3)
            }
            item(L("The Dock is here")) {
                Capsule().fill(Color.primary.opacity(0.6)).frame(width: 16, height: 5)
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func item<Swatch: View>(_ title: String, @ViewBuilder swatch: () -> Swatch) -> some View {
        HStack(spacing: 5) {
            swatch()
            Text(title)
        }
    }
}
