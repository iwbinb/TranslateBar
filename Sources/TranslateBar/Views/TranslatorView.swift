import AppKit
import SwiftUI
@preconcurrency import Translation

struct TranslatorView: View {
    @ObservedObject var store: TranslatorStore
    @ObservedObject var speechInput: SpeechInputManager
    @State private var maximumTextHeight: CGFloat = 260

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                languagePicker(selection: $store.sourceLanguage, allowsAutomatic: true)
                Button(action: store.swapLanguages) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(store.sourceLanguage.code == "auto")
                .help("Swap languages")
                languagePicker(selection: $store.targetLanguage, allowsAutomatic: false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            textPanel(title: "Original", text: $store.sourceText, editable: true)

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Translation")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if store.isTranslating { ProgressView().controlSize(.small) }
                    Button(action: { AppDelegate.shared?.copyResultToClipboard() }) {
                        Image(systemName: "doc.on.doc")
                    }
                        .buttonStyle(.plain).help("Copy translation")
                    Button(action: { AppDelegate.shared?.speakResult() }) { Image(systemName: "speaker.wave.2") }
                        .buttonStyle(.plain).help("Speak translation")
                }
                ZStack(alignment: .topLeading) {
                    if store.resultText.isEmpty && !store.isTranslating {
                        Text(store.errorMessage ?? "Translation will appear here")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 7)
                            .padding(.leading, 5)
                    }
                    ScrollView(.vertical) {
                        Text(store.resultText)
                            .font(.system(size: 15))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 7)
                    }
                    .modifier(GrowingTextHeight(text: store.resultText, maximumHeight: maximumTextHeight))
                    .accessibilityLabel("Translation result")
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 9))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()
            HStack {
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.link)
                Button("Preferences…") { AppDelegate.shared?.openPreferences() }
                    .buttonStyle(.link)
                Spacer()
                Button("Clear", action: store.clear)
                    .keyboardShortcut(.delete, modifiers: [.command])
                Button("Translate", action: store.translate)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 438)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: updateMaximumTextHeight)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            updateMaximumTextHeight()
        }
        .onChange(of: store.sourceText) { _, _ in store.scheduleTranslation() }
        .onChange(of: store.sourceLanguage) { _, _ in store.scheduleTranslation() }
        .onChange(of: store.targetLanguage) { _, _ in store.scheduleTranslation() }
        .translationTask(store.translationConfiguration) { session in
            await store.translatePendingRequest(using: session)
        }
    }

    private func languagePicker(selection: Binding<Language>, allowsAutomatic: Bool) -> some View {
        Picker("", selection: selection) {
            ForEach(Language.all.filter { allowsAutomatic || $0.code != "auto" }) { language in
                Text(language.name).tag(language)
            }
        }
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }

    private func textPanel(title: String, text: Binding<String>, editable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if title == "Original" {
                    Button(action: toggleDictation) {
                        Image(systemName: speechInput.isListening ? "mic.fill" : "mic")
                    }
                    .buttonStyle(.plain)
                    .help("Dictate text")
                }
            }
            TextEditor(text: text)
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .modifier(GrowingTextHeight(text: text.wrappedValue, maximumHeight: maximumTextHeight))
            if let error = speechInput.errorMessage, title == "Original" {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 9))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func toggleDictation() {
        if speechInput.isListening {
            speechInput.stop()
        } else {
            speechInput.start()
        }
    }

    private func updateMaximumTextHeight() {
        let screen = AppDelegate.shared?.popoverScreen ?? NSScreen.main
        // Reserve room for the controls, panel headings, and popover margins.
        maximumTextHeight = min(260, max(120, ((screen?.visibleFrame.height ?? 820) - 300) / 2))
    }
}

private struct GrowingTextHeight: ViewModifier {
    let text: String
    let maximumHeight: CGFloat
    @State private var measuredHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .frame(height: min(maximumHeight, max(120, measuredHeight)))
            .background(alignment: .topLeading) {
                // Match the text area's font and insets. The final character also
                // measures an empty last line while the user types a newline.
                Text(verbatim: text + "\u{200B}")
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 7)
                    .onGeometryChange(for: CGFloat.self) { geometry in
                        ceil(geometry.size.height)
                    } action: { height in
                        measuredHeight = height
                    }
                    .hidden()
                    .accessibilityHidden(true)
            }
    }
}
