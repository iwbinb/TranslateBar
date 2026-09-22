import AppKit
import AVFoundation
import SwiftUI

@main
struct TranslateBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    let store = TranslatorStore()
    let clipboardMonitor = ClipboardMonitor()
    let shortcutManager = ShortcutManager()
    let speechInput = SpeechInputManager()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let serviceProvider = ServiceProvider()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var preferencesWindow: NSWindow?

    var popoverScreen: NSScreen? { statusItem?.button?.window?.screen }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSApp.setActivationPolicy(UserDefaults.standard.bool(forKey: PreferencesKey.showInDock) ? .regular : .accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: 28)
        if let button = statusItem.button {
            button.image = StatusBarIcon.make()
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        let hostingController = NSHostingController(
            rootView: TranslatorView(store: store, speechInput: speechInput)
        )
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController

        serviceProvider.delegate = self
        NSApp.servicesProvider = serviceProvider
        shortcutManager.onShortcut = { [weak self] in self?.showPopover() }
        if let error = shortcutManager.registerStoredShortcut() {
            NSLog("TranslateBar shortcut registration failed: %@", error.localizedDescription)
        }
        speechInput.onText = { [weak self] text in self?.store.sourceText = text }

        clipboardMonitor.onText = { [weak self] text in
            guard let self, UserDefaults.standard.bool(forKey: PreferencesKey.translateClipboard) else { return }
            self.store.sourceText = text
            self.showPopover()
            self.store.translate()
        }
        clipboardMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stop()
        shortcutManager.stop()
        speechInput.stop()
    }

    @objc func togglePopover(_ sender: Any? = nil) {
        if popover.isShown { popover.performClose(sender) } else { showPopover() }
    }

    func showPopover() {
        guard !popover.isShown, let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openPreferences() {
        NSApp.activate(ignoringOtherApps: true)
        if preferencesWindow == nil {
            let content = NSHostingController(rootView: PreferencesView().frame(width: 480, height: 450))
            let window = NSWindow(contentViewController: content)
            window.title = "TranslateBar Preferences"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            preferencesWindow = window
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
    }

    func speakResult() {
        guard !store.resultText.isEmpty else { return }
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(AVSpeechUtterance(string: store.resultText))
    }

    func copyResultToClipboard() {
        guard !store.resultText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(store.resultText, forType: .string)
        clipboardMonitor.ignoreCurrentChange()
    }

    func refreshActivationPolicy() {
        NSApp.setActivationPolicy(UserDefaults.standard.bool(forKey: PreferencesKey.showInDock) ? .regular : .accessory)
    }
}

extension AppDelegate: ServiceProviderDelegate {
    func translateSelectedText(_ text: String) {
        store.sourceText = text
        showPopover()
        store.translate()
    }
}
