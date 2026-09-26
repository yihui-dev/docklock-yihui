import AppKit

/// In-app language choice. macOS reads `AppleLanguages` from the app's own defaults at launch,
/// so a change applies after DockLock restarts. (The same choice is available in
/// System Settings › General › Language & Region › Applications.)
enum AppLanguage {
    struct Option: Hashable {
        let code: String
        let name: String
    }

    /// Languages DockLock ships translations for, with their names in that language.
    static let supported: [Option] = [
        Option(code: "en", name: "English"),
        Option(code: "zh-Hans", name: "简体中文"),
        Option(code: "zh-Hant", name: "繁體中文"),
        Option(code: "ja", name: "日本語"),
        Option(code: "ko", name: "한국어"),
        Option(code: "de", name: "Deutsch"),
        Option(code: "fr", name: "Français"),
        Option(code: "es", name: "Español"),
        Option(code: "pt-BR", name: "Português (Brasil)"),
        Option(code: "ru", name: "Русский"),
    ]

    /// The language chosen inside DockLock, or nil to follow the system.
    static var override: String? {
        guard let id = Bundle.main.bundleIdentifier,
              let languages = UserDefaults.standard.persistentDomain(forName: id)?["AppleLanguages"] as? [String] else {
            return nil
        }
        return languages.first
    }

    static func set(_ code: String?) {
        if let code {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }

    /// Starts a fresh copy once this one has quit.
    static func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }
}
