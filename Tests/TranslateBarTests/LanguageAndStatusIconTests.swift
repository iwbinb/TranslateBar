import AppKit
import XCTest
@testable import TranslateBar

final class LanguageTests: XCTestCase {
    func testAutomaticLanguageIsFirstAndUnique() {
        XCTAssertEqual(Language.all.first, .automatic)
        XCTAssertEqual(Language.all.filter { $0.code == "auto" }.count, 1)
    }

    func testLanguageCodesAreUniqueAndNonempty() {
        let codes = Language.all.map(\.code)

        XCTAssertFalse(codes.contains(where: \.isEmpty))
        XCTAssertEqual(Set(codes).count, codes.count)
    }

    func testLanguageNamesAreNonempty() {
        XCTAssertFalse(Language.all.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    func testRequiredCoreLanguagesExist() {
        let codes = Set(Language.all.map(\.code))

        XCTAssertTrue(["auto", "en", "zh-CN", "zh-TW", "ja", "ko"].allSatisfy(codes.contains))
    }
}

@MainActor
final class StatusBarIconTests: XCTestCase {
    func testStatusBarIconHasExpectedMetadata() {
        let image = StatusBarIcon.make()

        XCTAssertEqual(image.size, NSSize(width: 24, height: 18))
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.accessibilityDescription, "TranslateBar")
    }

    func testStatusBarIconRendersVisibleAndTransparentPixels() throws {
        let image = StatusBarIcon.make()
        let data = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
        var visiblePixels = 0
        var transparentPixels = 0

        for x in 0..<bitmap.pixelsWide {
            for y in 0..<bitmap.pixelsHigh {
                let alpha = bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0
                if alpha > 0.1 {
                    visiblePixels += 1
                } else {
                    transparentPixels += 1
                }
            }
        }

        XCTAssertGreaterThan(visiblePixels, 0)
        XCTAssertGreaterThan(transparentPixels, 0)
    }
}
