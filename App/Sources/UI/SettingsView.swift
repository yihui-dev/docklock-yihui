import AppKit
import SwiftUI

extension SettingsTab {
    var title: String {
        switch self {
        case .general: return L("General")
        case .displays: return L("Displays")
        case .automation: return L("Automation")
        case .hideDock: return L("Hide Dock")
        case .advanced: return L("Advanced")
        case .about: return L("About")
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .displays: return "display.2"
        case .automation: return "bolt.fill"
        case .hideDock: return "eye.slash.fill"
        case .advanced: return "slider.horizontal.3"
        case .about: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .general: return .gray
        case .displays: return .blue
        case .automation: return .orange
        case .hideDock: return .indigo
        case .advanced: return .teal
        case .about: return .pink
        }
    }
}

/// The settings window: a System Settings–style sidebar and the selected page.
struct SettingsView: View {
    @EnvironmentObject var controller: AppController
    @EnvironmentObject var navigation: SettingsNavigation

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 210)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(VisualEffectBackground(material: .sidebar))
                .ignoresSafeArea(.container, edges: .top)
            Divider().ignoresSafeArea(.container, edges: .top)
            page
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        }
        .frame(minWidth: 760, minHeight: 540)
    }

    @ViewBuilder private var page: some View {
        switch navigation.tab {
        case .general: GeneralPage()
        case .displays: DisplaysPage()
        case .automation: AutomationPage()
        case .hideDock: HideDockPage()
        case .advanced: AdvancedPage()
        case .about: AboutPage()
        }
    }
}

private struct Sidebar: View {
    @EnvironmentObject var controller: AppController
    @EnvironmentObject var navigation: SettingsNavigation

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text("DockLock").font(.headline)
                    StatePill(state: LockState(controller))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 46) // below the traffic lights
            .padding(.bottom, 14)

            ForEach(SettingsTab.allCases) { tab in
                SidebarRow(tab: tab, selected: navigation.tab == tab) {
                    navigation.tab = tab
                }
            }
            Spacer()
            Text(LF("Version %@", DockLockInfo.version))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 8)
    }
}

private struct SidebarRow: View {
    let tab: SettingsTab
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                IconTile(symbol: tab.symbol, color: tab.color, size: 22)
                Text(tab.title)
                    .foregroundStyle(selected ? Color.white : Color.primary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Color.accentColor : (hovering ? Color.primary.opacity(0.07) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
