import AppKit

final class ClipboardMonitor {
    var onText: ((String) -> Void)?
    private let pasteboard: NSPasteboard
    private let pollingInterval: TimeInterval
    private var changeCount: Int
    private var timer: Timer?

    init(pasteboard: NSPasteboard = .general, pollingInterval: TimeInterval = 0.6) {
        self.pasteboard = pasteboard
        self.pollingInterval = pollingInterval
        changeCount = pasteboard.changeCount
    }

    func start() {
        stop()
        let timer = Timer(timeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func ignoreCurrentChange() {
        changeCount = pasteboard.changeCount
    }

    func poll() {
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount
        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onText?(text)
    }

    deinit { stop() }
}
