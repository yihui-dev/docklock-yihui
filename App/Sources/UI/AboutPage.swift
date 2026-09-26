import AppKit
import SwiftUI

struct AboutPage: View {
    @EnvironmentObject var controller: AppController

    private let repository = URL(string: "https://github.com/yihui-dev/docklock-yihui")!

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 112, height: 112)
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                VStack(spacing: 4) {
                    Text("DockLock").font(.system(size: 30, weight: .bold))
                    Text(LF("Version %@", DockLockInfo.version))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text(L("Keeps the macOS Dock on the displays you choose. Stops the Dock from jumping between monitors, hides it during meetings, and moves it on command — from the menu bar, hot keys, Shortcuts, URLs or the command line."))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 480)

                HStack(spacing: 10) {
                    Link(destination: repository) {
                        Label(L("Source Code"), systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Link(destination: repository.appendingPathComponent("issues/new/choose")) {
                        Label(L("Report an Issue"), systemImage: "exclamationmark.bubble")
                    }
                    Link(destination: repository.appendingPathComponent("releases")) {
                        Label(L("Releases"), systemImage: "arrow.down.circle")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                VStack(alignment: .leading, spacing: 10) {
                    fact("checkmark.shield.fill", .green,
                         L("No system files are modified and SIP stays on."))
                    fact("hand.raised.fill", .orange,
                         L("The Accessibility permission is only used to keep the pointer off the Dock edge and to move the Dock."))
                    fact("wifi.slash", .blue,
                         L("No network access. Nothing is collected."))
                    fact("heart.fill", .pink,
                         L("Free and open source under the MIT License."))
                }
                .padding(16)
                .frame(maxWidth: 480, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.04)))
            }
            .padding(.top, 48)
            .padding(.bottom, 24)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
    }

    private func fact(_ symbol: String, _ color: Color, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            IconTile(symbol: symbol, color: color, size: 22)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
