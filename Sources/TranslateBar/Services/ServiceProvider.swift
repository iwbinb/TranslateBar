import AppKit

@MainActor
protocol ServiceProviderDelegate: AnyObject {
    func translateSelectedText(_ text: String)
}

@MainActor
final class ServiceProvider: NSObject {
    weak var delegate: ServiceProviderDelegate?

    @objc func performTranslateService(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let rawText = pasteboard.string(forType: .string) else {
            error.pointee = "Could not find text to translate." as NSString
            return
        }
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            error.pointee = "Could not find text to translate." as NSString
            return
        }
        delegate?.translateSelectedText(text)
    }
}
