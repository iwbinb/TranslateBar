import AppKit
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: Shortcut

    func makeNSView(context: Context) -> ShortcutCaptureView {
        let view = ShortcutCaptureView()
        view.shortcut = shortcut
        view.onShortcut = { value in DispatchQueue.main.async { shortcut = value } }
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureView, context: Context) {
        nsView.shortcut = shortcut
    }
}

final class ShortcutCaptureView: NSView {
    var shortcut = Shortcut.fallback { didSet { needsDisplay = true } }
    var onShortcut: ((Shortcut) -> Void)?
    private var isRecording = false { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording, let shortcut = Shortcut.from(event: event) else { return }
        self.shortcut = shortcut
        isRecording = false
        onShortcut?(shortcut)
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        NSColor.controlBackgroundColor.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
        NSColor.separatorColor.setStroke()
        NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).stroke()
        let label = isRecording ? "Press shortcut…" : shortcut.displayText
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.labelColor]
        let size = (label as NSString).size(withAttributes: attributes)
        (label as NSString).draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2), withAttributes: attributes)
    }
}
