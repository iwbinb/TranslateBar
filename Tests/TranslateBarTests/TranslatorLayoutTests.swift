import AppKit
import SwiftUI
import XCTest
@testable import TranslateBar

@MainActor
final class TranslatorLayoutTests: XCTestCase {
    func testTextAreasGrowIndependentlyStopAtLimitAndShrinkAfterClear() async throws {
        let store = TranslatorStore(debounceDuration: .seconds(3_600))
        let controller = NSHostingController(
            rootView: TranslatorView(store: store, speechInput: SpeechInputManager())
        )
        controller.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: controller)
        defer { window.close() }

        func height() async throws -> CGFloat {
            // Allow SwiftUI's text measurement and hosting-size updates to settle.
            for _ in 0..<5 {
                controller.view.layoutSubtreeIfNeeded()
                try await Task.sleep(for: .milliseconds(30))
            }
            return controller.preferredContentSize.height
        }

        let compact = try await height()
        XCTAssertGreaterThan(compact, 400)

        store.sourceText = String(repeating: "A line of original text.\n", count: 9)
        let growingInput = try await height()
        XCTAssertGreaterThan(growingInput, compact + 10)

        store.sourceText = String(repeating: "A line of original text.\n", count: 80)
        let cappedInput = try await height()
        XCTAssertGreaterThanOrEqual(cappedInput, growingInput)

        store.resultText = String(repeating: "这是一行译文。\n", count: 80)
        let bothCapped = try await height()
        XCTAssertGreaterThan(bothCapped, cappedInput + 10)
        XCTAssertLessThan(bothCapped, 820)

        store.sourceText += String(repeating: "More original text.\n", count: 80)
        store.resultText += String(repeating: "更多译文。\n", count: 80)
        let stillCapped = try await height()
        XCTAssertEqual(stillCapped, bothCapped, accuracy: 1)

        store.clear()
        let cleared = try await height()
        XCTAssertEqual(cleared, compact, accuracy: 1)
    }
}
