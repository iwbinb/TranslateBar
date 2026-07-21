import Foundation
import Translation
import XCTest
@testable import TranslateBar

@MainActor
final class AppleTranslationTests: XCTestCase {
    func testLanguageMapsToFoundationLocaleLanguage() {
        XCTAssertNil(Language.automatic.localeLanguage)
        XCTAssertEqual(
            Language(code: "ja", name: "Japanese").localeLanguage,
            Locale.Language(identifier: "ja")
        )
    }

    func testAutomaticSourceCreatesOnDeviceTranslationConfiguration() throws {
        let store = TranslatorStore()
        store.sourceText = "hello"
        store.targetLanguage = Language(code: "fr", name: "French")

        store.translate()

        let configuration = try XCTUnwrap(store.translationConfiguration)
        XCTAssertNil(configuration.source)
        XCTAssertEqual(configuration.target, Locale.Language(identifier: "fr"))
        XCTAssertTrue(store.isTranslating)
    }

    func testRepeatedLanguagePairInvalidatesConfiguration() throws {
        let store = TranslatorStore()
        store.sourceText = "first"
        store.translate()
        let firstVersion = try XCTUnwrap(store.translationConfiguration).version

        store.sourceText = "second"
        store.translate()
        let secondVersion = try XCTUnwrap(store.translationConfiguration).version

        XCTAssertGreaterThan(secondVersion, firstVersion)
    }

    func testClearRemovesPendingOnDeviceTranslation() {
        let store = TranslatorStore()
        store.sourceText = "hello"
        store.translate()

        store.clear()

        XCTAssertNil(store.translationConfiguration)
        XCTAssertFalse(store.isTranslating)
    }
}
