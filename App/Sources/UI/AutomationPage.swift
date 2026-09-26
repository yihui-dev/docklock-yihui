import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Automation

struct AutomationPage: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        SettingsPage(title: L("Automation"),
                     subtitle: L("Hot keys, per-app rules, Shortcuts, URLs and the command line.")) {
            Section(L("Hot Keys")) {
                ForEach(Array(controller.settings.hotKeys.enumerated()), id: \.element.action) { item in
                    HotKeyRow(index: item.offset, binding: item.element)
                }
                if !controller.failedHotKeys.isEmpty {
                    WarningBanner(text: L("Some hot keys could not be registered because another app already uses them."))
                }
            }

            AppRulesSection()

            Section(L("Shortcuts, URL Scheme & Command Line")) {
                SettingLabel(title: L("Apple Shortcuts & Siri"), symbol: "square.stack.3d.up.fill", color: .pink)
                FootnoteText(L("Apple Shortcuts: search for \u{201C}DockLock\u{201D} in the Shortcuts app to move the Dock, allow displays, switch modes and more — also from Siri, hot keys and automations."))
                LabeledContent(L("URL scheme")) {
                    Text(verbatim: "docklock://moveToDisplay?name=Studio")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                FootnoteText(L("DockLock Plus URLs (DockLockPlus://…) are understood as well. See the README for the full list."))
                LabeledContent(L("Command line")) {
                    Text(verbatim: "docklock move \"Studio Display\"")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                HStack {
                    Button(L("Copy Install Command")) {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(Self.installCommand, forType: .string)
                    }
                    FootnoteText(L("Paste it into Terminal to create the “docklock” command."))
                }
            }
        }
    }

    static var installCommand: String {
        let executable = Bundle.main.executablePath ?? "/Applications/DockLock.app/Contents/MacOS/DockLock"
        return "sudo mkdir -p /usr/local/bin && sudo ln -sf '\(executable)' /usr/local/bin/docklock"
    }
}

private struct HotKeyRow: View {
    @EnvironmentObject var controller: AppController
    let index: Int
    let binding: HotKeyBinding

    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { binding.enabled },
                set: { value in controller.updateSettings { $0.hotKeys[index].enabled = value } })) {
                SettingLabel(title: Self.title(for: binding.action), symbol: Self.symbol(for: binding.action), color: .orange)
            }
            Spacer()
            ShortcutRecorder(binding: binding) { keyCode, modifiers in
                controller.updateSettings {
                    $0.hotKeys[index].keyCode = keyCode
                    $0.hotKeys[index].modifiers = modifiers
                    $0.hotKeys[index].enabled = true
                }
            }
        }
    }

    static func symbol(for action: HotKeyAction) -> String {
        switch action {
        case .toggleLock: return "lock.fill"
        case .moveLeft: return "arrow.left"
        case .moveRight: return "arrow.right"
        case .moveUp: return "arrow.up"
        case .moveDown: return "arrow.down"
        case .moveToPointerDisplay: return "cursorarrow"
        case .moveHome: return "house.fill"
        case .toggleHideDock: return "eye.slash.fill"
        case .cycleMode: return "arrow.triangle.2.circlepath"
        }
    }

    static func title(for action: HotKeyAction) -> String {
        switch action {
        case .toggleLock: return L("Turn Dock locking on / off")
        case .moveLeft: return L("Move Dock to the display on the left")
        case .moveRight: return L("Move Dock to the display on the right")
        case .moveUp: return L("Move Dock to the display above")
        case .moveDown: return L("Move Dock to the display below")
        case .moveToPointerDisplay: return L("Move Dock to the display with the pointer")
        case .moveHome: return L("Move Dock back to its home display")
        case .toggleHideDock: return L("Hide / show the Dock on all displays")
        case .cycleMode: return L("Switch to the next mode")
        }
    }
}

/// Click, then press a key combination (with ⌘, ⌥ or ⌃). Esc cancels.
struct ShortcutRecorder: View {
    let binding: HotKeyBinding
    let onRecord: (UInt32, ModifierSet) -> Void
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggle) {
            Text(recording ? L("Type shortcut…") : binding.displayString)
                .font(.system(.body, design: .rounded).weight(.medium))
                .frame(minWidth: 96)
        }
        .buttonStyle(.bordered)
        .tint(recording ? .accentColor : nil)
        .onDisappear(perform: stop)
    }

    private func toggle() {
        recording ? stop() : start()
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc
                stop()
                return nil
            }
            let flags = event.modifierFlags
            var modifiers: ModifierSet = []
            if flags.contains(.command) { modifiers.insert(.command) }
            if flags.contains(.option) { modifiers.insert(.option) }
            if flags.contains(.control) { modifiers.insert(.control) }
            if flags.contains(.shift) { modifiers.insert(.shift) }
            guard !modifiers.intersection([.command, .option, .control]).isEmpty else {
                NSSound.beep()
                return nil
            }
            onRecord(UInt32(event.keyCode), modifiers)
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

private struct AppRulesSection: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        Section(L("Apps (Follows Apps / Follows Active Window)")) {
            if controller.settings.appRules.isEmpty {
                FootnoteText(L("Without rules the Dock goes to the display showing the active app's window. Add an app to always send the Dock to a particular display when that app is active, or to make DockLock ignore it."))
            }
            ForEach(controller.settings.appRules) { rule in
                AppRuleRow(rule: rule)
            }
            Button(action: addApp) {
                Label(L("Add App…"), systemImage: "plus")
            }
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = L("Add")
        guard panel.runModal() == .OK else { return }
        let rules = panel.urls.compactMap { url -> AppRule? in
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return nil }
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            var target = AppRuleTarget.appWindow
            if let display = controller.dockDisplay {
                target = .display(uuid: display.uuid, name: controller.displayName(display))
            }
            return AppRule(bundleID: id, appName: name, target: target)
        }
        controller.updateSettings { settings in
            for rule in rules where !settings.appRules.contains(where: { $0.bundleID == rule.bundleID }) {
                settings.appRules.append(rule)
            }
        }
    }
}

private struct AppRuleRow: View {
    @EnvironmentObject var controller: AppController
    let rule: AppRule

    var body: some View {
        HStack {
            Toggle(isOn: Binding(get: { rule.enabled }, set: { value in update { $0.enabled = value } })) {
                HStack(spacing: 8) {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleID) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .frame(width: 26, height: 26)
                    }
                    Text(rule.appName)
                }
            }
            Spacer()
            Picker("", selection: Binding(get: { rule.target }, set: { value in update { $0.target = value } })) {
                Text(L("Its window's display")).tag(AppRuleTarget.appWindow)
                Text(L("Ignore this app")).tag(AppRuleTarget.ignore)
                Divider()
                ForEach(targetDisplays, id: \.self) { target in
                    Text(label(for: target)).tag(target)
                }
            }
            .labelsHidden()
            .frame(width: 220)
            Button {
                controller.updateSettings { $0.appRules.removeAll { $0.id == rule.id } }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
    }

    /// Current displays, plus the rule's display if it is not connected right now.
    private var targetDisplays: [AppRuleTarget] {
        var targets = controller.layout.displays.map {
            AppRuleTarget.display(uuid: $0.uuid, name: controller.displayName($0))
        }
        if case .display(let uuid, _) = rule.target, controller.layout.display(uuid: uuid) == nil {
            targets.append(rule.target)
        }
        return targets
    }

    private func label(for target: AppRuleTarget) -> String {
        guard case .display(let uuid, let name) = target else { return "" }
        return controller.layout.display(uuid: uuid) == nil ? LF("%@ (not connected)", name) : LF("Display: %@", name)
    }

    private func update(_ change: @escaping (inout AppRule) -> Void) {
        controller.updateSettings { settings in
            guard let index = settings.appRules.firstIndex(where: { $0.id == rule.id }) else { return }
            change(&settings.appRules[index])
        }
    }
}
