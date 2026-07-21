import AppKit
import XCTest
@testable import TranslateBar

@MainActor
final class ClipboardMonitorTests: XCTestCase {
    func testPollEmitsNewNonemptyTextOnlyOnce() {
        let pasteboard = makePasteboard()
        let monitor = ClipboardMonitor(pasteboard: pasteboard)
        var received: [String] = []
        monitor.onText = { received.append($0) }

        pasteboard.clearContents()
        pasteboard.setString("hello", forType: .string)
        monitor.poll()
        monitor.poll()

        XCTAssertEqual(received, ["hello"])
    }

    func testPollIgnoresWhitespaceOnlyText() {
        let pasteboard = makePasteboard()
        let monitor = ClipboardMonitor(pasteboard: pasteboard)
        var received: [String] = []
        monitor.onText = { received.append($0) }

        pasteboard.clearContents()
        pasteboard.setString("  \n", forType: .string)
        monitor.poll()

        XCTAssertTrue(received.isEmpty)
    }

    func testIgnoreCurrentChangePreventsSelfCopyFeedback() {
        let pasteboard = makePasteboard()
        let monitor = ClipboardMonitor(pasteboard: pasteboard)
        var received: [String] = []
        monitor.onText = { received.append($0) }

        pasteboard.clearContents()
        pasteboard.setString("translated result", forType: .string)
        monitor.ignoreCurrentChange()
        monitor.poll()

        XCTAssertTrue(received.isEmpty)
    }

    func testStartCanBeCalledTwiceAndStopIsIdempotent() {
        let monitor = ClipboardMonitor(pasteboard: makePasteboard(), pollingInterval: 60)

        monitor.start()
        monitor.start()
        monitor.stop()
        monitor.stop()
    }

    private func makePasteboard() -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("TranslateBarTests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        return pasteboard
    }
}

@MainActor
final class ServiceProviderTests: XCTestCase {
    func testServiceRejectsMissingText() {
        let pasteboard = makePasteboard()
        let provider = ServiceProvider()
        var error: NSString?

        provider.performTranslateService(pasteboard, userData: nil, error: &error)

        XCTAssertEqual(error as String?, "Could not find text to translate.")
    }

    func testServiceRejectsWhitespaceOnlyText() {
        let pasteboard = makePasteboard()
        pasteboard.setString(" \n ", forType: .string)
        let provider = ServiceProvider()
        var error: NSString?

        provider.performTranslateService(pasteboard, userData: nil, error: &error)

        XCTAssertEqual(error as String?, "Could not find text to translate.")
    }

    func testServiceTrimsAndDeliversTextOnMainActor() async {
        let pasteboard = makePasteboard()
        pasteboard.setString("  hello world\n", forType: .string)
        let expectation = expectation(description: "delegate called")
        let delegate = ServiceDelegateSpy(expectation: expectation)
        let provider = ServiceProvider()
        provider.delegate = delegate
        var error: NSString?

        provider.performTranslateService(pasteboard, userData: nil, error: &error)
        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertNil(error)
        XCTAssertEqual(delegate.receivedText, "hello world")
    }

    private func makePasteboard() -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("TranslateBarServiceTests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        return pasteboard
    }
}

@MainActor
private final class ServiceDelegateSpy: ServiceProviderDelegate {
    private let expectation: XCTestExpectation
    private(set) var receivedText: String?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func translateSelectedText(_ text: String) {
        receivedText = text
        expectation.fulfill()
    }
}
