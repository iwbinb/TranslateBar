protocol TranslationServing: Sendable {
    func translate(text: String, source: Language, target: Language) async throws -> String
}
