import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Hide Dock

struct HideDockPage: View {
    @EnvironmentObject var controller: AppController

    var body: some View {
        SettingsPage(title: L("Hide Dock"),
                     subtitle: L("Keep the Dock from popping up during presentations, meetings and screen sharing.")) {
            Section {
                Toggle(isOn: Binding(get: { controller.manualHide }, set: { controller.setManualHide($0) })) {
                    SettingLabel(title: L("Hide the Dock on all displays now"), symbol: "eye.slash.fill", color: .indigo)
                }
                if let reason = controller.autoHideReason {
                    LabeledContent(L("Hidden automatically because of")) { Text(reason).foregroundStyle(.secondary) }
                }
                FootnoteText(L("While hidden, the pointer is kept off the Dock edge of every display, so the Dock cannot pop up during presentations, meetings or screen sharing."))
                Toggle(isOn: controller.binding(\.autoHideWhileHidden)) {
                    SettingLabel(title: L("Turn on Dock auto-hide while hidden (restored afterwards)"),
                                 symbol: "dock.arrow.down.rectangle", color: .blue)
                }
            }

            Section(L("Hide Automatically")) {
                Toggle(isOn: controller.binding(\.hideDockWhileScreenSharing)) {
                    SettingLabel(title: L("While the screen is being shared or recorded"), symbol: "rectangle.on.rectangle", color: .red)
                }
                if !ScreenCaptureDetector.isAvailable {
                    FootnoteText(L("Screen-sharing detection is not available on this version of macOS."))
                }
                FootnoteText(L("While any of these apps is running:"))
                ForEach(MeetingAppPresets.all, id: \.bundleID) { preset in
                    Toggle(isOn: Binding(
                        get: { controller.settings.meetingAppBundleIDs.contains(preset.bundleID) },
                        set: { on in
                            controller.updateSettings { settings in
                                settings.meetingAppBundleIDs.removeAll { $0 == preset.bundleID }
                                if on { settings.meetingAppBundleIDs.append(preset.bundleID) }
                            }
                        })) {
                        AppNameLabel(bundleID: preset.bundleID, name: preset.name)
                    }
                }
                ForEach(customMeetingApps, id: \.self) { bundleID in
                    HStack {
                        AppNameLabel(bundleID: bundleID, name: bundleID)
                        Spacer()
                        Button {
                            controller.updateSettings { $0.meetingAppBundleIDs.removeAll { $0 == bundleID } }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button(action: addApp) {
                    Label(L("Add Other App…"), systemImage: "plus")
                }
            }
        }
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

/// App icon (when installed) and name.
struct AppNameLabel: View {
    let bundleID: String
    let name: String

    var body: some View {
        HStack(spacing: 10) {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                IconTile(symbol: "app.dashed", color: .gray, size: 24)
            }
            Text(name)
        }
    }
}
