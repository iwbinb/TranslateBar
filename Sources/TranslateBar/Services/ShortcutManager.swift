import AppKit
import Carbon.HIToolbox

enum ShortcutRegistrationError: LocalizedError, Sendable {
    case eventHandler(OSStatus)
    case hotKey(OSStatus)

    var errorDescription: String? {
        switch self {
        case .eventHandler(let status):
            return "Couldn’t install the keyboard shortcut handler (error \(status))."
        case .hotKey(let status):
            return "That keyboard shortcut could not be registered (error \(status)). It may already be in use."
        }
    }
}

struct Shortcut: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let fallback = Shortcut(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(optionKey | shiftKey))

    var displayText: String {
        let glyphs = (modifiers & UInt32(cmdKey) != 0 ? "⌘" : "")
            + (modifiers & UInt32(optionKey) != 0 ? "⌥" : "")
            + (modifiers & UInt32(controlKey) != 0 ? "⌃" : "")
            + (modifiers & UInt32(shiftKey) != 0 ? "⇧" : "")
        return glyphs + Shortcut.keyName(keyCode)
    }

    static func stored(in defaults: UserDefaults = .standard) -> Shortcut {
        let code = (defaults.object(forKey: PreferencesKey.shortcutKeyCode) as? NSNumber)?.uint32Value
        let modifiers = (defaults.object(forKey: PreferencesKey.shortcutModifiers) as? NSNumber)?.uint32Value
        return Shortcut(
            keyCode: code ?? fallback.keyCode,
            modifiers: modifiers ?? fallback.modifiers
        )
    }

    func save(in defaults: UserDefaults = .standard) {
        defaults.set(Int(keyCode), forKey: PreferencesKey.shortcutKeyCode)
        defaults.set(Int(modifiers), forKey: PreferencesKey.shortcutModifiers)
    }

    static func from(event: NSEvent) -> Shortcut? {
        var modifiers: UInt32 = 0
        if event.modifierFlags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.option) { modifiers |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { modifiers |= UInt32(controlKey) }
        if event.modifierFlags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        guard modifiers != 0 else { return nil }
        return Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
    }

    static func keyName(_ code: UInt32) -> String {
        let names: [UInt32: String] = [
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C", UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F", UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I", UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L", UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O", UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R", UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U", UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X", UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z", UInt32(kVK_Space): "Space", UInt32(kVK_Return): "↩"
        ]
        return names[code] ?? "Key \(code)"
    }
}

final class ShortcutManager {
    var onShortcut: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    @discardableResult
    func registerStoredShortcut() -> ShortcutRegistrationError? {
        register(Shortcut.stored())
    }

    @discardableResult
    func register(_ shortcut: Shortcut) -> ShortcutRegistrationError? {
        unregister()
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        var installedHandler: EventHandlerRef?
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard GetEventKind(event) == UInt32(kEventHotKeyPressed), let userData else { return noErr }
            let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { manager.onShortcut?() }
            return noErr
        }, 1, &eventType, context, &installedHandler)
        guard handlerStatus == noErr else {
            return .eventHandler(handlerStatus)
        }
        eventHandler = installedHandler

        let hotKeyID = EventHotKeyID(signature: OSType(0x544C4252), id: 1)
        let registrationStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registrationStatus == noErr else {
            unregister()
            return .hotKey(registrationStatus)
        }
        return nil
    }

    private func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef); self.hotKeyRef = nil }
        if let eventHandler { RemoveEventHandler(eventHandler); self.eventHandler = nil }
    }

    deinit { unregister() }
}
