import Foundation
import XCTest
@testable import TranslateBar

final class TranslationServiceTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.handler = nil
        super.tearDown()
    }

    func testGlobalRequestContainsExpectedQueryAndHeaders() throws {
        let service = TranslationService()
        let request = try service.makeRequest(
            text: "hello & 你好",
            source: .automatic,
            target: Language(code: "ja", name: "Japanese"),
            useChinaEndpoint: false
        )
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: try XCTUnwrap(components.queryItems).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "translate.googleapis.com")
        XCTAssertEqual(components.path, "/translate_a/single")
        XCTAssertEqual(query["client"], "gtx")
        XCTAssertEqual(query["sl"], "auto")
        XCTAssertEqual(query["tl"], "ja")
        XCTAssertEqual(query["dt"], "t")
        XCTAssertEqual(query["q"], "hello & 你好")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "TranslateBar/0.1.0")
        XCTAssertEqual(request.timeoutInterval, 15)
    }

    func testChinaRequestUsesChinaHost() throws {
        let service = TranslationService()
        let request = try service.makeRequest(
            text: "hello",
            source: Language(code: "en", name: "English"),
            target: Language(code: "zh-CN", name: "Chinese"),
            useChinaEndpoint: true
        )

        XCTAssertEqual(request.url?.host, "translate.google.cn")
    }

    func testParserJoinsMultipleSegments() throws {
        let data = Data(#"[[["早上", "Good", null, null, 10], ["好", " morning", null, null, 10]], null, "en"]"#.utf8)

        XCTAssertEqual(try TranslationService.parseTranslation(from: data), "早上好")
    }

    func testParserRejectsMalformedJSON() {
        XCTAssertThrowsError(try TranslationService.parseTranslation(from: Data("not-json".utf8))) { error in
            guard case TranslationError.invalidResponse = error else {
                return XCTFail("Expected invalidResponse, got \(error)")
            }
        }
    }

    func testParserRejectsUnexpectedShape() {
        XCTAssertThrowsError(try TranslationService.parseTranslation(from: Data(#"{"value":"hello"}"#.utf8))) { error in
            guard case TranslationError.invalidResponse = error else {
                return XCTFail("Expected invalidResponse, got \(error)")
            }
        }
    }

    func testParserRejectsEmptyTranslation() {
        let data = Data(#"[[[null, "hello", null]], null, "en"]"#.utf8)

        XCTAssertThrowsError(try TranslationService.parseTranslation(from: data)) { error in
            guard case TranslationError.noTranslation = error else {
                return XCTFail("Expected noTranslation, got \(error)")
            }
        }
    }

    func testTranslateReturnsParsedValue() async throws {
        URLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"[[["bonjour", "hello", null]], null, "en"]"#.utf8))
        }
        let service = TranslationService(session: makeStubbedSession())

        let value = try await service.translate(
            text: "hello",
            source: .automatic,
            target: Language(code: "fr", name: "French"),
            useChinaEndpoint: false
        )

        XCTAssertEqual(value, "bonjour")
    }

    func testTranslateReportsHTTPStatus() async throws {
        URLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        let service = TranslationService(session: makeStubbedSession())

        do {
            _ = try await service.translate(
                text: "hello",
                source: .automatic,
                target: Language(code: "fr", name: "French"),
                useChinaEndpoint: false
            )
            XCTFail("Expected HTTP status error")
        } catch let error as TranslationError {
            guard case .httpStatus(429) = error else {
                return XCTFail("Expected HTTP 429, got \(error)")
            }
            XCTAssertEqual(error.errorDescription, "The translation service returned HTTP status 429.")
        }
    }

    private func makeStubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }
}

private final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
