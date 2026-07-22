import SwiftUI

struct PreferencesView: View {
    @AppStorage(PreferencesKey.launchAtLogin) private var launchAtLogin = false
    @AppStorage(PreferencesKey.showInDock) private var showInDock = false
    @AppStorage(PreferencesKey.translateClipboard) private var translateClipboard = false
    @State private var shortcut = PreferencesView.storedShortcut
    @State private var settingsIssue: SettingsIssue?
    @State private var isRevertingLoginItem = false
    @State private var isRevertingShortcut = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch TranslateBar at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        guard !isRevertingLoginItem else {
                            isRevertingLoginItem = false
                            return
                        }
                        if let error = LoginItemManager.setEnabled(enabled) {
                            settingsIssue = SettingsIssue(
                                title: "Couldn’t update the login item",
                                message: error.localizedDescription
                            )
                            isRevertingLoginItem = true
                            launchAtLogin = !enabled
                        }
                    }
                Toggle("Show TranslateBar in the Dock", isOn: $showInDock)
                    .onChange(of: showInDock) { _, _ in AppDelegate.shared?.refreshActivationPolicy() }
                Toggle("Translate copied text automatically", isOn: $translateClipboard)
            }
            Section("Translation") {
                Label("On-device translation", systemImage: "checkmark.shield")
                Text("Translation is handled by macOS. Text is not sent to TranslateBar or third-party translation services. macOS may download language packs when needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Keyboard shortcut") {
                HStack {
                    Text("Show TranslateBar")
                    Spacer()
                    ShortcutRecorder(shortcut: $shortcut)
                        .frame(width: 140, height: 28)
                }
            }
            Section("About") {
                Link("Privacy Policy", destination: URL(string: "https://translatebar.arenovo.com/privacy/")!)
                Link("Support", destination: URL(string: "https://translatebar.arenovo.com/support/")!)
                Text("TranslateBar 0.2.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(18)
        .onChange(of: shortcut) { oldValue, newValue in
            guard !isRevertingShortcut else {
                isRevertingShortcut = false
                return
            }
            if let error = AppDelegate.shared?.shortcutManager.register(newValue) {
                settingsIssue = SettingsIssue(
                    title: "Couldn’t register that shortcut",
                    message: error.localizedDescription
                )
                oldValue.save()
                isRevertingShortcut = true
                shortcut = oldValue
            } else {
                newValue.save()
            }
        }
        .alert(item: $settingsIssue) { issue in
            Alert(
                title: Text(issue.title),
                message: Text(issue.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private static var storedShortcut: Shortcut {
        Shortcut.stored()
    }
}

private struct SettingsIssue: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
