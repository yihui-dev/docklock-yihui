import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var controller: AppController
    @EnvironmentObject var navigation: SettingsNavigation

    var body: some View {
        TabView(selection: $navigation.tab) {
            GeneralSettingsView()
                .tabItem { Label(L("General"), systemImage: "gearshape") }
                .tag(SettingsTab.general)
            DisplaysSettingsView()
                .tabItem { Label(L("Displays"), systemImage: "display.2") }
                .tag(SettingsTab.displays)
            AutomationSettingsView()
                .tabItem { Label(L("Automation"), systemImage: "bolt.horizontal") }
                .tag(SettingsTab.automation)
            HideDockSettingsView()
                .tabItem { Label(L("Hide Dock"), systemImage: "eye.slash") }
                .tag(SettingsTab.hideDock)
            AdvancedSettingsView()
                .tabItem { Label(L("Advanced"), systemImage: "slider.horizontal.3") }
                .tag(SettingsTab.advanced)
            AboutView()
                .tabItem { Label(L("About"), systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .padding(12)
        .frame(minWidth: 640, minHeight: 480)
    }
}

// MARK: - Shared pieces

/// A binding into one settings field that writes through `AppController.updateSettings`.
extension AppController {
    func binding<Value: Equatable>(_ keyPath: WritableKeyPath<DockLockSettings, Value>) -> Binding<Value> {
        Binding(get: { self.settings[keyPath: keyPath] },
                set: { newValue in self.updateSettings { $0[keyPath: keyPath] = newValue } })
    }
}

struct WarningBanner: View {
    let text: String
    var systemImage = "exclamationmark.triangle.fill"
    var tint = Color.orange
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .font(.title3)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.12)))
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

// MARK: - General

struct GeneralSettingsView: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        Form {
            if !controller.accessibilityGranted {
                Section {
                    WarningBanner(text: L("DockLock needs Accessibility access to keep the pointer off the Dock edge of other displays. Open System Settings › Privacy & Security › Accessibility and switch DockLock on (use + to add it if it is missing)."),
                                  actionTitle: L("Open Settings")) {
                        Permissions.requestAccessibility()
                        Permissions.openAccessibilitySettings()
                    }
                }
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
                Toggle(L("Enable Dock locking"), isOn: controller.binding(\.isEnabled))
                LabeledContent(L("Status")) {
                    Text(controller.statusSummary).foregroundStyle(.secondary)
                }
            }

            Section(L("Mode")) {
                Picker(L("Mode"), selection: controller.binding(\.mode)) {
                    ForEach(DockMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(StatusMenuController.title(for: mode))
                            Text(Self.explanation(for: mode)).font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                FootnoteText(L("Every mode only puts the Dock on displays that are checked under Displays. Deliberate moves (menu, hot keys, Shortcuts, URL, CLI) hold the Dock on the chosen display until the display arrangement changes."))
            }

            Section(L("Moving the Dock by hand")) {
                Picker(L("Allow Dock jumping while holding"), selection: controller.binding(\.bypassModifiers)) {
                    ForEach(ModifierSet.bypassChoices, id: \.rawValue) { choice in
                        Text(Self.name(for: choice)).tag(choice)
                    }
                }
                FootnoteText(L("While these keys are held, the Dock moves like it normally does when you push the pointer against the bottom of any display. Shift alone can move the Dock by accident while typing with the pointer near the bottom edge."))
            }

            Section(L("App")) {
                Toggle(L("Launch DockLock at login"), isOn: Binding(get: { controller.launchAtLogin },
                                                                     set: { controller.setLaunchAtLogin($0) }))
                Toggle(L("Show icon in the menu bar"), isOn: controller.binding(\.showMenuBarIcon))
                if !controller.settings.showMenuBarIcon {
                    FootnoteText(L("Open DockLock again (Finder, Spotlight or Launchpad) to get back to these settings."))
                }
                Toggle(L("Show icon in the Dock"), isOn: controller.binding(\.showDockIcon))
            }
        }
        .formStyle(.grouped)
        .onAppear { controller.refreshLoginItemState() }
    }

    static func explanation(for mode: DockMode) -> String {
        switch mode {
        case .lock: return L("The Dock stays on the allowed displays and never jumps to the others.")
        case .followsMouse: return L("The Dock moves to the display where the pointer comes to rest.")
        case .followsWindow: return L("The Dock moves to the display of the window you are working in.")
        case .followsApps: return L("When you switch apps, the Dock moves to that app's display (or the display set in Automation).")
        }
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

// MARK: - Displays

struct DisplaysSettingsView: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        Form {
            Section {
                ArrangementMapView()
                    .frame(height: 220)
                FootnoteText(L("Click a display to allow or disallow the Dock there. Right-click for more. The bar marks the display that has the Dock right now."))
            }

            Section(L("Allow Dock on Display")) {
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
                FootnoteText(L("These choices are remembered separately for every combination of connected displays."))
            }

            RememberedArrangementsSection()
        }
        .formStyle(.grouped)
    }
}

private struct DisplayRow: View {
    @EnvironmentObject var controller: AppController
    let display: DisplaySnapshot

    var body: some View {
        HStack {
            Toggle(isOn: Binding(get: { controller.isAllowed(display) },
                                 set: { controller.setAllowed(display, $0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.displayName(display))
                    HStack(spacing: 6) {
                        if display.uuid == controller.dockDisplayUUID { Badge(text: L("Dock"), color: .accentColor) }
                        if controller.currentPreferences.home == display.uuid { Badge(text: L("Home"), color: .green) }
                        if display.isMain { Badge(text: L("Main"), color: .gray) }
                        if display.isBuiltin { Badge(text: L("Built-in"), color: .gray) }
                        if controller.runtime.exclusiveTarget == display.uuid { Badge(text: L("Held"), color: .orange) }
                        Text(verbatim: "\(Int(display.frame.width))×\(Int(display.frame.height)) @ \(Int(display.frame.minX)),\(Int(display.frame.minY))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button(L("Move Dock Here")) {
                controller.execute(.move(.name(display.uuid)))
            }
            .disabled(display.uuid == controller.dockDisplayUUID || controller.layout.count < 2)
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
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
            Section(L("Other Remembered Arrangements")) {
                ForEach(others, id: \.key) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(describe(entry.key, entry.value))
                            Text(LF("Allowed: %@", allowedNames(entry.value)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(L("Forget")) { controller.forgetArrangement(entry.key) }
                    }
                }
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

/// A scaled picture of the display arrangement.
struct ArrangementMapView: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        GeometryReader { geometry in
            let displays = controller.layout.displays
            let bounds = displays.reduce(CGRect.null) { $0.union($1.frame) }
            if displays.isEmpty || bounds.isNull || bounds.width <= 0 || bounds.height <= 0 {
                Text(L("No displays found")).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let scale = min((geometry.size.width - 16) / bounds.width, (geometry.size.height - 16) / bounds.height)
                let offsetX = (geometry.size.width - bounds.width * scale) / 2
                let offsetY = (geometry.size.height - bounds.height * scale) / 2
                ZStack(alignment: .topLeading) {
                    ForEach(displays, id: \.uuid) { display in
                        DisplayTile(display: display)
                            .frame(width: max(display.frame.width * scale - 4, 10),
                                   height: max(display.frame.height * scale - 4, 10))
                            .offset(x: offsetX + (display.frame.minX - bounds.minX) * scale + 2,
                                    y: offsetY + (display.frame.minY - bounds.minY) * scale + 2)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            }
        }
    }
}

private struct DisplayTile: View {
    @EnvironmentObject var controller: AppController
    let display: DisplaySnapshot

    var body: some View {
        let allowed = controller.effectiveAllowed.contains(display.uuid)
        let hasDock = display.uuid == controller.dockDisplayUUID
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(allowed ? Color.accentColor.opacity(0.22) : Color.gray.opacity(0.15))
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(allowed ? Color.accentColor : Color.gray.opacity(0.6), lineWidth: allowed ? 2 : 1)
            VStack(spacing: 3) {
                Image(systemName: allowed ? "lock.open.fill" : "lock.fill")
                    .foregroundStyle(allowed ? Color.accentColor : Color.secondary)
                Text(controller.displayName(display))
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
            .padding(4)
            VStack {
                if display.isMain {
                    Rectangle().fill(Color.primary.opacity(0.35)).frame(height: 3)
                }
                Spacer()
                if hasDock {
                    Capsule()
                        .fill(Color.primary.opacity(0.75))
                        .frame(width: 40, height: 6)
                        .padding(.bottom, 4)
                }
            }
            .padding(.horizontal, 3)
            .padding(.top, 2)
        }
        .contentShape(Rectangle())
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
}
