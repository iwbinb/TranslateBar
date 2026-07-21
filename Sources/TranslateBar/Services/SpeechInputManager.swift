import AVFoundation
import Speech

@MainActor
final class SpeechInputManager: NSObject, ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var errorMessage: String?
    var onText: ((String) -> Void)?

    private let recognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var isTapInstalled = false

    func start() {
        errorMessage = nil
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                Task { @MainActor [weak self] in
                    self?.errorMessage = "Speech recognition permission is required."
                }
                return
            }
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard granted else {
                        self.errorMessage = "Microphone permission is required."
                        return
                    }
                    self.beginRecognition()
                }
            }
        }
    }

    func stop() {
        isListening = false
        if audioEngine.isRunning { audioEngine.stop() }
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
    }

    private func beginRecognition() {
        stop()
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition is currently unavailable."
            return
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            self.request = nil
            errorMessage = "No usable microphone input is available."
            return
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        isTapInstalled = true
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in self.onText?(result.bestTranscription.formattedString) }
                if result.isFinal { Task { @MainActor in self.stop() } }
            }
            if let error {
                Task { @MainActor in
                    if self.isListening { self.errorMessage = error.localizedDescription }
                    self.stop()
                }
            }
        }
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
        } catch {
            stop()
            errorMessage = error.localizedDescription
        }
    }
}
