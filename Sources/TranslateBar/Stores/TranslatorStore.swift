import Foundation
import Combine
@preconcurrency import Translation

@MainActor
final class TranslatorStore: ObservableObject {
    @Published var sourceText = ""
    @Published var resultText = ""
    @Published var sourceLanguage = Language.automatic
    @Published var targetLanguage = Language(code: "en", name: "English")
    @Published var isTranslating = false
    @Published var errorMessage: String?
    @Published private(set) var translationConfiguration: TranslationSession.Configuration?

    private let service: (any TranslationServing)?
    private let debounceDuration: Duration
    private var pendingTask: Task<Void, Never>?
    private var translationTask: Task<Void, Never>?
    private var activeRequestID: UInt64 = 0
    private var activeRequest: TranslationRequest?

    init(
        service: (any TranslationServing)? = nil,
        debounceDuration: Duration = .milliseconds(420)
    ) {
        self.service = service
        self.debounceDuration = debounceDuration
    }

    func scheduleTranslation() {
        pendingTask?.cancel()
        pendingTask = nil
        cancelActiveTranslation()
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            translationConfiguration = nil
            resultText = ""
            errorMessage = nil
            return
        }
        pendingTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: self.debounceDuration)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self.pendingTask = nil
            self.translate()
        }
    }

    func translate() {
        pendingTask?.cancel()
        pendingTask = nil
        cancelActiveTranslation()
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            translationConfiguration = nil
            resultText = ""
            errorMessage = nil
            return
        }
        let source = sourceLanguage
        let target = targetLanguage
        activeRequestID &+= 1
        let requestID = activeRequestID
        let request = TranslationRequest(id: requestID, text: text, source: source, target: target)
        activeRequest = request
        isTranslating = true
        errorMessage = nil

        guard let service else {
            activateAppleTranslation(for: request)
            return
        }

        translationTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.activeRequestID == requestID {
                    self.translationTask = nil
                    self.isTranslating = false
                }
            }
            do {
                let value = try await service.translate(text: text, source: source, target: target)
                self.finish(requestID: requestID, text: text, result: .success(value))
            } catch is CancellationError {
                return
            } catch {
                self.finish(requestID: requestID, text: text, result: .failure(error))
            }
        }
    }

    func translatePendingRequest(using session: TranslationSession) async {
        guard let request = activeRequest else { return }
        do {
            let response = try await session.translate(request.text)
            finish(requestID: request.id, text: request.text, result: .success(response.targetText))
        } catch is CancellationError {
            return
        } catch {
            finish(requestID: request.id, text: request.text, result: .failure(error))
        }
    }

    func swapLanguages() {
        guard sourceLanguage.code != "auto" else { return }
        (sourceLanguage, targetLanguage) = (targetLanguage, sourceLanguage)
        translate()
    }

    func clear() {
        pendingTask?.cancel()
        pendingTask = nil
        cancelActiveTranslation()
        translationConfiguration = nil
        sourceText = ""
        resultText = ""
        errorMessage = nil
    }

    private func cancelActiveTranslation() {
        activeRequestID &+= 1
        translationTask?.cancel()
        translationTask = nil
        activeRequest = nil
        isTranslating = false
    }

    private func activateAppleTranslation(for request: TranslationRequest) {
        let source = request.source.localeLanguage
        let target = request.target.localeLanguage
        if var configuration = translationConfiguration,
           configuration.source == source,
           configuration.target == target {
            configuration.invalidate()
            translationConfiguration = configuration
        } else {
            translationConfiguration = TranslationSession.Configuration(source: source, target: target)
        }
    }

    private func finish(requestID: UInt64, text: String, result: Result<String, Error>) {
        guard !Task.isCancelled,
              activeRequestID == requestID,
              sourceText.trimmingCharacters(in: .whitespacesAndNewlines) == text else { return }
        switch result {
        case .success(let value):
            resultText = value
            errorMessage = nil
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
        activeRequest = nil
        translationTask = nil
        isTranslating = false
    }
}

private struct TranslationRequest {
    let id: UInt64
    let text: String
    let source: Language
    let target: Language
}
