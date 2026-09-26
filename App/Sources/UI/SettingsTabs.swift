import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Automation

struct AutomationSettingsView: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        Form {
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
        .formStyle(.grouped)
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
            Toggle(Self.title(for: binding.action), isOn: Binding(
                get: { binding.enabled },
                set: { value in controller.updateSettings { $0.hotKeys[index].enabled = value } }))
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
                .font(.system(.body, design: .rounded))
                .frame(minWidth: 90)
        }
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
            Button(L("Add App…"), action: addApp)
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
                            .frame(width: 20, height: 20)
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
                Image(systemName: "minus.circle")
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

// MARK: - Hide Dock

struct HideDockSettingsView: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        Form {
            Section {
                Toggle(L("Hide the Dock on all displays now"), isOn: Binding(get: { controller.manualHide },
                                                                             set: { controller.setManualHide($0) }))
                if let reason = controller.autoHideReason {
                    LabeledContent(L("Hidden automatically because of")) { Text(reason).foregroundStyle(.secondary) }
                }
                FootnoteText(L("While hidden, the pointer is kept off the Dock edge of every display, so the Dock cannot pop up during presentations, meetings or screen sharing."))
                Toggle(L("Turn on Dock auto-hide while hidden (restored afterwards)"), isOn: controller.binding(\.autoHideWhileHidden))
            }

            Section(L("Hide Automatically")) {
                Toggle(L("While the screen is being shared or recorded"), isOn: controller.binding(\.hideDockWhileScreenSharing))
                if !ScreenCaptureDetector.isAvailable {
                    FootnoteText(L("Screen-sharing detection is not available on this version of macOS."))
                }
                FootnoteText(L("While any of these apps is running:"))
                ForEach(MeetingAppPresets.all, id: \.bundleID) { preset in
                    Toggle(preset.name, isOn: Binding(
                        get: { controller.settings.meetingAppBundleIDs.contains(preset.bundleID) },
                        set: { on in
                            controller.updateSettings { settings in
                                settings.meetingAppBundleIDs.removeAll { $0 == preset.bundleID }
                                if on { settings.meetingAppBundleIDs.append(preset.bundleID) }
                            }
                        }))
                }
                ForEach(customMeetingApps, id: \.self) { bundleID in
                    HStack {
                        Text(bundleID)
                        Spacer()
                        Button {
                            controller.updateSettings { $0.meetingAppBundleIDs.removeAll { $0 == bundleID } }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button(L("Add Other App…"), action: addApp)
            }
        }
        .formStyle(.grouped)
    }

    private var customMeetingApps: [String] {
        let presets = Set(MeetingAppPresets.all.map(\.bundleID))
        return controller.settings.meetingAppBundleIDs.filter { !presets.contains($0) }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }
        let ids = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
        controller.updateSettings { settings in
            for id in ids where !settings.meetingAppBundleIDs.contains(id) {
                settings.meetingAppBundleIDs.append(id)
            }
        }
    }
}

// MARK: - Advanced

struct AdvancedSettingsView: View {
    @EnvironmentObject var controller: AppController
    @State private var copied = false
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section(L("Moving the Dock Back")) {
                Toggle(L("Move the Dock back automatically (after sleep, display changes, …)"), isOn: controller.binding(\.autoRelocate))
                SliderRow(title: L("Wait until the pointer rests for"), value: controller.binding(\.relocationIdleDelay),
                          range: 0.5...10, step: 0.5, unit: L("s"))
                SliderRow(title: L("Follow modes: wait for"), value: controller.binding(\.followDelay),
                          range: 0.3...5, step: 0.1, unit: L("s"))
                Toggle(L("Show an on-screen hint when the Dock cannot be moved automatically"), isOn: controller.binding(\.showRelocationGuide))
                Toggle(L("Send a notification when the Dock cannot be moved automatically"), isOn: controller.binding(\.notifyOnRelocationFailure))
                FootnoteText(L("DockLock moves the Dock only while you are not using the mouse, and never while a menu is open. It briefly moves the pointer to the Dock edge of the target display and puts it back."))
                LabeledContent(L("Working method on this Mac")) {
                    Text(controller.settings.preferredMoveStrategy ?? L("not determined yet")).foregroundStyle(.secondary)
                }
                if let last = controller.lastRelocation {
                    LabeledContent(L("Last move")) {
                        Text(verbatim: "\(last.success ? "✓" : "✗") \(last.displayName) · \(AppController.timeFormatter.string(from: last.date))")
                            .foregroundStyle(last.success ? Color.secondary : Color.red)
                    }
                }
            }

            Section(L("Edge Guard")) {
                SliderRow(title: L("Keep the pointer away from the edge by"), value: controller.binding(\.guardBand),
                          range: 2...10, step: 1, unit: L("pt"))
                Toggle(L("Keep hot corners working on guarded displays"), isOn: controller.binding(\.keepHotCorners))
                if controller.settings.keepHotCorners {
                    SliderRow(title: L("Corner grace period"), value: controller.binding(\.hotCornerGrace),
                              range: 0.1...1.0, step: 0.05, unit: L("s"))
                }
                LabeledContent(L("Guard")) {
                    Text(controller.guardActive ? LF("Active on %ld display(s)", controller.guardedDisplayCount) : L("Idle"))
                        .foregroundStyle(.secondary)
                }
            }

            Section(L("Troubleshooting")) {
                HStack {
                    Button(L("Restart Dock")) { controller.execute(.restartDock) }
                    Button(L("Open Accessibility Settings")) { Permissions.openAccessibilitySettings() }
                    Button(L("Open Displays Settings")) { Permissions.openDisplaysSettings() }
                }
                HStack {
                    Button(copied ? L("Copied") : L("Copy Diagnostics")) {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(controller.diagnosticsText(), forType: .string)
                        copied = true
                    }
                    Button(L("Forget Learned Method")) {
                        controller.updateSettings { $0.preferredMoveStrategy = nil }
                    }
                    Button(L("Reset All Settings…"), role: .destructive) { confirmReset = true }
                }
                FootnoteText(L("After updating or rebuilding DockLock, macOS may keep an old Accessibility entry. If locking stops working, remove DockLock from the Accessibility list and add it again."))
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(L("Reset all DockLock settings?"), isPresented: $confirmReset) {
            Button(L("Reset"), role: .destructive) { controller.resetAllSettings() }
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
            Text(String(format: step < 1 ? "%.2g %@" : "%.0f %@", value, unit))
                .monospacedDigit()
                .frame(width: 56, alignment: .trailing)
        }
    }
}

// MARK: - About

struct AboutView: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("DockLock").font(.largeTitle.weight(.semibold))
            Text(LF("Version %@", DockLockInfo.version)).foregroundStyle(.secondary)
            Text(L("Keeps the macOS Dock on the displays you choose. Stops the Dock from jumping between monitors, hides it during meetings, and moves it on command — from the menu bar, hot keys, Shortcuts, URLs or the command line."))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            Text(L("No system files are modified and SIP stays on. DockLock only uses the Accessibility permission to keep the pointer off the Dock edge and to move the Dock. It has no network access and collects nothing."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            Link(L("Source code on GitHub"), destination: URL(string: "https://github.com/yihui-dev/docklock-yihui")!)
            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
