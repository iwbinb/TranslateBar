import Foundation
import XCTest
@testable import TranslateBar

@MainActor
final class TranslatorStoreTests: XCTestCase {
    func testTranslateTrimsInputAndPublishesSuccess() async throws {
        let service = TranslationStub(responses: ["hello": .success("你好", delay: .zero)])
        let store = makeStore(service: service)
        store.sourceText = "  hello\n"
        store.targetLanguage = Language(code: "zh-CN", name: "Chinese")

        store.translate()
        await waitUntil { !store.isTranslating }

        XCTAssertEqual(store.resultText, "你好")
        XCTAssertNil(store.errorMessage)
        let calls = await service.calls
        XCTAssertEqual(calls.map(\.text), ["hello"])
        XCTAssertEqual(calls.first?.source.code, "auto")
        XCTAssertEqual(calls.first?.target.code, "zh-CN")
    }

    func testFailurePublishesReadableError() async throws {
        let service = TranslationStub(responses: ["hello": .failure(TestFailure.expected, delay: .zero)])
        let store = makeStore(service: service)
        store.sourceText = "hello"

        store.translate()
        await waitUntil { !store.isTranslating }

        XCTAssertEqual(store.errorMessage, TestFailure.expected.localizedDescription)
        XCTAssertEqual(store.resultText, "")
    }

    func testLatestRequestWinsWhenOlderRequestIgnoresCancellation() async throws {
        let service = TranslationStub(responses: [
            "first": .success("旧结果", delay: .milliseconds(120), ignoresCancellation: true),
            "second": .success("新结果", delay: .milliseconds(15))
        ])
        let store = makeStore(service: service)
        store.sourceText = "first"
        store.translate()
        try await Task.sleep(for: .milliseconds(5))
        store.sourceText = "second"
        store.translate()

        await waitUntil { store.resultText == "新结果" && !store.isTranslating }
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertEqual(store.resultText, "新结果")
        XCTAssertNil(store.errorMessage)
        XCTAssertFalse(store.isTranslating)
    }

    func testStaleFailureCannotOverwriteNewSuccess() async throws {
        let service = TranslationStub(responses: [
            "first": .failure(TestFailure.expected, delay: .milliseconds(100), ignoresCancellation: true),
            "second": .success("new", delay: .milliseconds(10))
        ])
        let store = makeStore(service: service)
        store.sourceText = "first"
        store.translate()
        try await Task.sleep(for: .milliseconds(5))
        store.sourceText = "second"
        store.translate()

        await waitUntil { store.resultText == "new" && !store.isTranslating }
        try await Task.sleep(for: .milliseconds(120))

        XCTAssertEqual(store.resultText, "new")
        XCTAssertNil(store.errorMessage)
    }

    func testClearCancelsAndInvalidatesInFlightRequest() async throws {
        let service = TranslationStub(responses: [
            "hello": .failure(TestFailure.expected, delay: .milliseconds(80), ignoresCancellation: true)
        ])
        let store = makeStore(service: service)
        store.sourceText = "hello"
        store.translate()
        try await Task.sleep(for: .milliseconds(5))

        store.clear()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(store.sourceText, "")
        XCTAssertEqual(store.resultText, "")
        XCTAssertNil(store.errorMessage)
        XCTAssertFalse(store.isTranslating)
    }

    func testDebounceOnlyTranslatesLatestText() async throws {
        let service = TranslationStub(responses: [
            "first": .success("one", delay: .zero),
            "second": .success("two", delay: .zero)
        ])
        let store = makeStore(service: service, debounce: .milliseconds(25))
        store.sourceText = "first"
        store.scheduleTranslation()
        try await Task.sleep(for: .milliseconds(5))
        store.sourceText = "second"
        store.scheduleTranslation()

        await waitUntil { store.resultText == "two" && !store.isTranslating }

        let calls = await service.calls
        XCTAssertEqual(calls.map(\.text), ["second"])
    }

    func testSchedulingWhitespaceClearsStateWithoutCallingService() async throws {
        let service = TranslationStub(responses: [:])
        let store = makeStore(service: service)
        store.sourceText = "hello"
        store.resultText = "old"
        store.errorMessage = "old error"
        store.sourceText = "  \n"

        store.scheduleTranslation()

        XCTAssertEqual(store.resultText, "")
        XCTAssertNil(store.errorMessage)
        let calls = await service.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testSwapDoesNothingForAutomaticSource() async {
        let service = TranslationStub(responses: [:])
        let store = makeStore(service: service)
        let originalTarget = store.targetLanguage

        store.swapLanguages()

        XCTAssertEqual(store.sourceLanguage, .automatic)
        XCTAssertEqual(store.targetLanguage, originalTarget)
        let calls = await service.calls
        XCTAssertTrue(calls.isEmpty)
    }

    func testSwapExchangesExplicitLanguagesAndTranslates() async {
        let service = TranslationStub(responses: ["hello": .success("hello", delay: .zero)])
        let store = makeStore(service: service)
        store.sourceText = "hello"
        store.sourceLanguage = Language(code: "en", name: "English")
        store.targetLanguage = Language(code: "fr", name: "French")

        store.swapLanguages()
        await waitUntil { !store.isTranslating }

        XCTAssertEqual(store.sourceLanguage.code, "fr")
        XCTAssertEqual(store.targetLanguage.code, "en")
        let calls = await service.calls
        XCTAssertEqual(calls.first?.source.code, "fr")
        XCTAssertEqual(calls.first?.target.code, "en")
    }

    private func makeStore(
        service: TranslationStub,
        debounce: Duration = .milliseconds(5)
    ) -> TranslatorStore {
        TranslatorStore(
            service: service,
            debounceDuration: debounce
        )
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition(), clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertTrue(condition(), "Condition was not met before timeout")
    }
}

private actor TranslationStub: TranslationServing {
    struct Call: Sendable {
        let text: String
        let source: Language
        let target: Language
    }

    enum Response: Sendable {
        case success(String, delay: Duration, ignoresCancellation: Bool = false)
        case failure(TestFailure, delay: Duration, ignoresCancellation: Bool = false)
    }

    private(set) var calls: [Call] = []
    private let responses: [String: Response]

    init(responses: [String: Response]) {
        self.responses = responses
    }

    func translate(text: String, source: Language, target: Language) async throws -> String {
        calls.append(Call(text: text, source: source, target: target))
        guard let response = responses[text] else { throw TestFailure.missingResponse }
        switch response {
        case let .success(value, delay, ignoresCancellation):
            try await pause(for: delay, ignoresCancellation: ignoresCancellation)
            return value
        case let .failure(error, delay, ignoresCancellation):
            try await pause(for: delay, ignoresCancellation: ignoresCancellation)
            throw error
        }
    }

    private func pause(for delay: Duration, ignoresCancellation: Bool) async throws {
        guard delay > .zero else { return }
        do {
            try await Task.sleep(for: delay)
        } catch {
            if !ignoresCancellation { throw error }
            try? await Task.sleep(for: delay)
        }
    }
}

private enum TestFailure: LocalizedError, Sendable {
    case expected
    case missingResponse

    var errorDescription: String? {
        switch self {
        case .expected: "Expected test failure"
        case .missingResponse: "Missing stub response"
        }
    }
}
