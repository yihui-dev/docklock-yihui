import AppKit
import SwiftUI

struct GeneralPage: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        SettingsPage(title: L("General"), subtitle: L("Keep the Dock on the displays you choose.")) {
            Section { StatusCard() }

            if !controller.accessibilityGranted {
                Section { PermissionCard() }
            }
            if !controller.separateSpaces {
                Section {
                    WarningBanner(text: L("\u{201C}Displays have separate Spaces\u{201D} is off. Turn it on in System Settings › Desktop & Dock (then log out) so the Dock can be locked per display."),
                                  actionTitle: L("Open Settings")) {
                        Permissions.openDesktopAndDockSettings()
                    }
                }
            }

            Section {
                ModePicker()
                FootnoteText(L("Every mode only puts the Dock on displays that are checked under Displays. Deliberate moves (menu, hot keys, Shortcuts, URL, CLI) hold the Dock on the chosen display until the display arrangement changes."))
            } header: {
                Text(L("Mode"))
            }

            Section {
                Picker(selection: controller.binding(\.bypassModifiers)) {
                    ForEach(ModifierSet.bypassChoices, id: \.rawValue) { choice in
                        Text(Self.name(for: choice)).tag(choice)
                    }
                } label: {
                    SettingLabel(title: L("Allow Dock jumping while holding"), symbol: "command", color: .purple)
                }
                FootnoteText(L("While these keys are held, the Dock moves like it normally does when you push the pointer against the bottom of any display. Shift alone can move the Dock by accident while typing with the pointer near the bottom edge."))
            } header: {
                Text(L("Moving the Dock by hand"))
            }

            Section {
                Toggle(isOn: Binding(get: { controller.launchAtLogin }, set: { controller.setLaunchAtLogin($0) })) {
                    SettingLabel(title: L("Launch DockLock at login"), symbol: "power", color: .green)
                }
                Toggle(isOn: controller.binding(\.showMenuBarIcon)) {
                    SettingLabel(title: L("Show icon in the menu bar"),
                                 subtitle: controller.settings.showMenuBarIcon ? nil
                                     : L("Open DockLock again (Finder, Spotlight or Launchpad) to get back to these settings."),
                                 symbol: "menubar.rectangle", color: .blue)
                }
                Toggle(isOn: controller.binding(\.showDockIcon)) {
                    SettingLabel(title: L("Show icon in the Dock"), symbol: "dock.rectangle", color: .indigo)
                }
                LanguageRow()
            } header: {
                Text(L("App"))
            }
        }
        .onAppear { controller.refreshLoginItemState() }
    }

    static func name(for modifiers: ModifierSet) -> String {
        if modifiers.isEmpty { return L("Nothing (Dock stays locked)") }
        var names: [String] = []
        if modifiers.contains(.control) { names.append(L("Control")) }
        if modifiers.contains(.option) { names.append(L("Option")) }
        if modifiers.contains(.shift) { names.append(L("Shift")) }
        if modifiers.contains(.command) { names.append(L("Command")) }
        return modifiers.symbols + "  " + names.joined(separator: " + ")
    }
}

/// The big card at the top: what DockLock is doing right now, with the master switch.
private struct StatusCard: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        let state = LockState(controller)
        HStack(spacing: 16) {
            DockGlyph(state: state)
                .frame(width: 76, height: 58)
            VStack(alignment: .leading, spacing: 5) {
                Text(controller.statusSummary)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                StatePill(state: state)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: controller.binding(\.isEnabled))
                .toggleStyle(.switch)
                .controlSize(.large)
                .labelsHidden()
                .help(L("Enable Dock locking"))
        }
        .padding(.vertical, 6)
    }

    private var detail: String {
        if !controller.settings.isEnabled { return L("The Dock behaves like macOS normally does.") }
        if controller.layout.count < 2 { return L("Only one display is connected; the Dock cannot jump anywhere.") }
        if controller.guardActive {
            return LF("Guarding %ld display(s) · %ld display(s) allowed", controller.guardedDisplayCount,
                      controller.effectiveAllowed.count)
        }
        return L("Nothing to guard right now.")
    }
}

/// A little monitor with a Dock, tinted by state.
struct DockGlyph: View {
    let state: LockState

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(LinearGradient(colors: [state.color.opacity(0.55), state.color.opacity(0.9)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: w, height: h * 0.84)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.15))
                    )
                VStack {
                    Spacer()
                    HStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill([Color.red, .yellow, .green, .blue][i])
                                .frame(width: w * 0.09, height: w * 0.09)
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.85)))
                    .opacity(state == .hidden ? 0.25 : 1)
                    .padding(.bottom, h * 0.16 + 4)
                }
                Image(systemName: state.symbol)
                    .font(.system(size: h * 0.22, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, h * 0.12)
            }
            .frame(width: w, height: h)
        }
    }
}

/// Step-by-step help for granting the Accessibility permission.
private struct PermissionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconTile(symbol: "hand.raised.fill", color: .orange, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Allow DockLock to control the pointer")).font(.headline)
                    Text(L("DockLock needs Accessibility access to keep the pointer off the Dock edge of other displays."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                step(1, L("Click \u{201C}Open Accessibility Settings\u{201D} below."))
                step(2, L("Switch on DockLock in the list (use + to add it if it is missing)."))
                step(3, L("Come back — DockLock starts working within a few seconds, no restart needed."))
            }
            Button {
                Permissions.requestAccessibility()
                Permissions.openAccessibilitySettings()
            } label: {
                Label(L("Open Accessibility Settings"), systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.vertical, 6)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: "\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.orange))
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The four modes as selectable cards.
private struct ModePicker: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(DockMode.allCases, id: \.self) { mode in
                ModeCard(mode: mode, selected: controller.settings.mode == mode) {
                    controller.execute(.setMode(mode))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ModeCard: View {
    let mode: DockMode
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                IconTile(symbol: Self.symbol(mode), color: Self.color(mode), size: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(StatusMenuController.title(for: mode))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(Self.explanation(for: mode))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary.opacity(0.5))
                    .font(.title3)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.10) : Color.primary.opacity(hovering ? 0.06 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: selected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    static func symbol(_ mode: DockMode) -> String {
        switch mode {
        case .lock: return "lock.fill"
        case .followsMouse: return "cursorarrow.motionlines"
        case .followsWindow: return "macwindow"
        case .followsApps: return "app.badge"
        }
    }

    static func color(_ mode: DockMode) -> Color {
        switch mode {
        case .lock: return .blue
        case .followsMouse: return .purple
        case .followsWindow: return .teal
        case .followsApps: return .orange
        }
    }

    static func explanation(for mode: DockMode) -> String {
        switch mode {
        case .lock: return L("The Dock stays on the allowed displays and never jumps to the others.")
        case .followsMouse: return L("The Dock moves to the display where the pointer comes to rest.")
        case .followsWindow: return L("The Dock moves to the display of the window you are working in.")
        case .followsApps: return L("When you switch apps, the Dock moves to that app's display (or the display set in Automation).")
        }
    }
}

private struct LanguageRow: View {
    @State private var selection: String = AppLanguage.override ?? ""
    @State private var changed = false

    var body: some View {
        Picker(selection: $selection) {
            Text(L("System Default")).tag("")
            Divider()
            ForEach(AppLanguage.supported, id: \.self) { option in
                Text(option.name).tag(option.code)
            }
        } label: {
            SettingLabel(title: L("Language"),
                         subtitle: changed ? L("Restart DockLock to use the new language.") : nil,
                         symbol: "globe", color: .cyan)
        }
        .onChange(of: selection) { newValue in
            AppLanguage.set(newValue.isEmpty ? nil : newValue)
            changed = true
        }
        if changed {
            HStack {
                Spacer()
                Button(L("Restart Now")) { AppLanguage.relaunch() }
            }
        }
    }
}
