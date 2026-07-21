import Foundation

struct Language: Identifiable, Hashable, Codable, Sendable {
    let code: String
    let name: String
    var id: String { code }

    static let automatic = Language(code: "auto", name: "Detect language")

    var localeLanguage: Locale.Language? {
        code == Self.automatic.code ? nil : Locale.Language(identifier: code)
    }

    static let all: [Language] = [
        automatic,
        Language(code: "en", name: "English"), Language(code: "zh-CN", name: "Chinese (Simplified)"),
        Language(code: "zh-TW", name: "Chinese (Traditional)"), Language(code: "ja", name: "Japanese"),
        Language(code: "ko", name: "Korean"), Language(code: "es", name: "Spanish"),
        Language(code: "fr", name: "French"), Language(code: "de", name: "German"),
        Language(code: "it", name: "Italian"), Language(code: "pt", name: "Portuguese"),
        Language(code: "ru", name: "Russian"), Language(code: "ar", name: "Arabic"),
        Language(code: "hi", name: "Hindi"), Language(code: "th", name: "Thai"),
        Language(code: "vi", name: "Vietnamese"), Language(code: "id", name: "Indonesian"),
        Language(code: "nl", name: "Dutch"), Language(code: "pl", name: "Polish"),
        Language(code: "tr", name: "Turkish"), Language(code: "uk", name: "Ukrainian")
    ]
}

enum PreferencesKey {
    static let launchAtLogin = "launchAtLogin"
    static let showInDock = "showInDock"
    static let translateClipboard = "translateClipboard"
    static let shortcutKeyCode = "shortcutKeyCode"
    static let shortcutModifiers = "shortcutModifiers"
}
