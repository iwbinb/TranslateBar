import Foundation

enum TranslationError: LocalizedError, Sendable {
    case invalidResponse
    case httpStatus(Int)
    case noTranslation

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The translation service returned an invalid response."
        case .httpStatus(let status): return "The translation service returned HTTP status \(status)."
        case .noTranslation: return "No translation was returned."
        }
    }
}

protocol TranslationServing: Sendable {
    func translate(text: String, source: Language, target: Language, useChinaEndpoint: Bool) async throws -> String
}

struct TranslationService: TranslationServing {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translate(text: String, source: Language, target: Language, useChinaEndpoint: Bool) async throws -> String {
        let request = try makeRequest(text: text, source: source, target: target, useChinaEndpoint: useChinaEndpoint)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw TranslationError.httpStatus(http.statusCode)
        }
        return try Self.parseTranslation(from: data)
    }

    func makeRequest(text: String, source: Language, target: Language, useChinaEndpoint: Bool) throws -> URLRequest {
        guard var components = URLComponents(string: useChinaEndpoint
            ? "https://translate.google.cn/translate_a/single"
            : "https://translate.googleapis.com/translate_a/single") else {
            throw TranslationError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"), URLQueryItem(name: "sl", value: source.code),
            URLQueryItem(name: "tl", value: target.code), URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]
        guard let url = components.url else { throw TranslationError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("TranslateBar/0.1.0", forHTTPHeaderField: "User-Agent")
        return request
    }

    static func parseTranslation(from data: Data) throws -> String {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw TranslationError.invalidResponse
        }

        guard let root = object as? [Any],
              let segments = root.first as? [Any] else {
            throw TranslationError.invalidResponse
        }
        let translation = segments.compactMap { segment in
            (segment as? [Any])?.first as? String
        }.joined()
        guard !translation.isEmpty else { throw TranslationError.noTranslation }
        return translation
    }
}
