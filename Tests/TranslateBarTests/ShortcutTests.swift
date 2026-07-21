import AppKit
import Carbon.HIToolbox
import Foundation
import XCTest
@testable import TranslateBar

final class ShortcutTests: XCTestCase {
    func testFallbackIsOptionShiftT() {
        XCTAssertEqual(Shortcut.fallback.keyCode, UInt32(kVK_ANSI_T))
        XCTAssertEqual(Shortcut.fallback.modifiers, UInt32(optionKey | shiftKey))
        XCTAssertEqual(Shortcut.fallback.displayText, "⌥⇧T")
    }

    func testDisplayTextUsesStableModifierOrder() {
        let shortcut = Shortcut(
            keyCode: UInt32(kVK_ANSI_K),
            modifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey)
        )

        XCTAssertEqual(shortcut.displayText, "⌘⌥⌃⇧K")
    }

    func testUnknownKeyIncludesNumericCode() {
        XCTAssertEqual(Shortcut.keyName(999), "Key 999")
    }

    func testEventRequiresAtLeastOneModifier() throws {
        let event = try makeKeyEvent(keyCode: UInt16(kVK_ANSI_K), modifiers: [])

        XCTAssertNil(Shortcut.from(event: event))
    }

    func testEventConvertsKeyAndModifiers() throws {
        let event = try makeKeyEvent(keyCode: UInt16(kVK_ANSI_K), modifiers: [.command, .shift])

        let shortcut = try XCTUnwrap(Shortcut.from(event: event))
        XCTAssertEqual(shortcut.keyCode, UInt32(kVK_ANSI_K))
        XCTAssertEqual(shortcut.modifiers, UInt32(cmdKey | shiftKey))
        XCTAssertEqual(shortcut.displayText, "⌘⇧K")
    }

    func testStoredShortcutFallsBackWhenKeysAreMissing() {
        let defaults = makeDefaults()

        XCTAssertEqual(Shortcut.stored(in: defaults), .fallback)
    }

    func testShortcutRoundTripsThroughUserDefaults() {
        let defaults = makeDefaults()
        let expected = Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | optionKey))

        expected.save(in: defaults)

        XCTAssertEqual(Shortcut.stored(in: defaults), expected)
    }

    func testRegistrationErrorsAreActionable() {
        XCTAssertEqual(
            ShortcutRegistrationError.eventHandler(-1).errorDescription,
            "Couldn’t install the keyboard shortcut handler (error -1)."
        )
        XCTAssertEqual(
            ShortcutRegistrationError.hotKey(-987).errorDescription,
            "That keyboard shortcut could not be registered (error -987). It may already be in use."
        )
    }

    private func makeKeyEvent(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "k",
            charactersIgnoringModifiers: "k",
            isARepeat: false,
            keyCode: keyCode
        ))
    }

    private func makeDefaults() -> UserDefaults {
        let name = "TranslateBarShortcutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
