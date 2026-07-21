import Foundation
import Combine

@MainActor
final class TranslatorStore: ObservableObject {
    @Published var sourceText = ""
    @Published var resultText = ""
    @Published var sourceLanguage = Language.automatic
    @Published var targetLanguage = Language(code: "en", name: "English")
    @Published var isTranslating = false
    @Published var errorMessage: String?

    private let service: any TranslationServing
    private let defaults: UserDefaults
    private let debounceDuration: Duration
    private var pendingTask: Task<Void, Never>?
    private var translationTask: Task<Void, Never>?
    private var activeRequestID: UInt64 = 0

    init(
        service: any TranslationServing = TranslationService(),
        defaults: UserDefaults = .standard,
        debounceDuration: Duration = .milliseconds(420)
    ) {
        self.service = service
        self.defaults = defaults
        self.debounceDuration = debounceDuration
    }

    func scheduleTranslation() {
        pendingTask?.cancel()
        pendingTask = nil
        cancelActiveTranslation()
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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
            resultText = ""
            errorMessage = nil
            return
        }
        let source = sourceLanguage
        let target = targetLanguage
        let useChinaEndpoint = defaults.bool(forKey: PreferencesKey.useChinaEndpoint)
        activeRequestID &+= 1
        let requestID = activeRequestID
        isTranslating = true
        errorMessage = nil
        translationTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.activeRequestID == requestID {
                    self.translationTask = nil
                    self.isTranslating = false
                }
            }
            do {
                let value = try await self.service.translate(text: text, source: source, target: target, useChinaEndpoint: useChinaEndpoint)
                guard !Task.isCancelled,
                      self.activeRequestID == requestID,
                      self.sourceText.trimmingCharacters(in: .whitespacesAndNewlines) == text else { return }
                self.resultText = value
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled,
                      self.activeRequestID == requestID,
                      self.sourceText.trimmingCharacters(in: .whitespacesAndNewlines) == text else { return }
                self.errorMessage = error.localizedDescription
            }
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
        sourceText = ""
        resultText = ""
        errorMessage = nil
    }

    private func cancelActiveTranslation() {
        activeRequestID &+= 1
        translationTask?.cancel()
        translationTask = nil
        isTranslating = false
    }
}
