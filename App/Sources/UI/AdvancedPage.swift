import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Advanced

struct AdvancedPage: View {
    @EnvironmentObject var controller: AppController
    @State private var copied = false
    @State private var confirmReset = false

    var body: some View {
        SettingsPage(title: L("Advanced"),
                     subtitle: L("Fine-tune how the Dock is guarded and moved, and troubleshoot.")) {
            Section(L("Moving the Dock Back")) {
                Toggle(isOn: controller.binding(\.autoRelocate)) {
                    SettingLabel(title: L("Move the Dock back automatically (after sleep, display changes, …)"),
                                 symbol: "arrow.uturn.backward", color: .blue)
                }
                SliderRow(title: L("Wait until the pointer rests for"), value: controller.binding(\.relocationIdleDelay),
                          range: 0.5...10, step: 0.5, unit: L("s"))
                SliderRow(title: L("Follow modes: wait for"), value: controller.binding(\.followDelay),
                          range: 0.3...5, step: 0.1, unit: L("s"))
                Toggle(isOn: controller.binding(\.showRelocationGuide)) {
                    SettingLabel(title: L("Show an on-screen hint when the Dock cannot be moved automatically"),
                                 symbol: "text.bubble.fill", color: .teal)
                }
                Toggle(isOn: controller.binding(\.notifyOnRelocationFailure)) {
                    SettingLabel(title: L("Send a notification when the Dock cannot be moved automatically"),
                                 symbol: "bell.fill", color: .red)
                }
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
                Toggle(isOn: controller.binding(\.keepHotCorners)) {
                    SettingLabel(title: L("Keep hot corners working on guarded displays"),
                                 symbol: "arrow.down.right.square.fill", color: .purple)
                }
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
                    Button { controller.execute(.restartDock) } label: {
                        Label(L("Restart Dock"), systemImage: "arrow.clockwise")
                    }
                    Button { Permissions.openAccessibilitySettings() } label: {
                        Label(L("Open Accessibility Settings"), systemImage: "hand.raised")
                    }
                    Button { Permissions.openDisplaysSettings() } label: {
                        Label(L("Open Displays Settings"), systemImage: "display")
                    }
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
        .confirmationDialog(L("Reset all DockLock settings?"), isPresented: $confirmReset) {
            Button(L("Reset"), role: .destructive) { controller.resetAllSettings() }
        }
    }
}
