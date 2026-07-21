import AppKit

enum StatusBarIcon {
    private static let size = NSSize(width: 24, height: 18)

    static func make() -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current else { return false }

            context.shouldAntialias = true
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let rearBubble = bubblePath(
                frame: NSRect(x: 0.75, y: 5.0, width: 14.25, height: 11.25),
                tailStartX: 9.25,
                tailTipX: 11.0,
                tailEndX: 12.25,
                tailTipY: 2.5,
                radius: 2.4
            )
            rearBubble.lineWidth = 1.35
            rearBubble.stroke()

            draw(
                "A",
                font: .systemFont(ofSize: 7.6, weight: .semibold),
                centeredIn: NSRect(x: 2.0, y: 7.0, width: 9.2, height: 7.8)
            )

            let frontBubble = bubblePath(
                frame: NSRect(x: 9.25, y: 2.25, width: 14.0, height: 11.0),
                tailStartX: 15.75,
                tailTipX: 17.2,
                tailEndX: 18.75,
                tailTipY: 0.25,
                radius: 2.4
            )
            frontBubble.fill()

            context.saveGraphicsState()
            context.compositingOperation = .clear
            draw(
                "文",
                font: .systemFont(ofSize: 7.2, weight: .bold),
                centeredIn: NSRect(x: 12.0, y: 4.0, width: 8.7, height: 7.8)
            )
            context.restoreGraphicsState()

            return true
        }

        image.isTemplate = true
        image.accessibilityDescription = "TranslateBar"
        return image
    }

    private static func bubblePath(
        frame: NSRect,
        tailStartX: CGFloat,
        tailTipX: CGFloat,
        tailEndX: CGFloat,
        tailTipY: CGFloat,
        radius: CGFloat
    ) -> NSBezierPath {
        let minX = frame.minX
        let maxX = frame.maxX
        let minY = frame.minY
        let maxY = frame.maxY
        let path = NSBezierPath()

        path.move(to: NSPoint(x: minX + radius, y: minY))
        path.line(to: NSPoint(x: tailStartX, y: minY))
        path.line(to: NSPoint(x: tailTipX, y: tailTipY))
        path.line(to: NSPoint(x: tailEndX, y: minY))
        path.line(to: NSPoint(x: maxX - radius, y: minY))
        path.curve(
            to: NSPoint(x: maxX, y: minY + radius),
            controlPoint1: NSPoint(x: maxX - radius * 0.45, y: minY),
            controlPoint2: NSPoint(x: maxX, y: minY + radius * 0.45)
        )
        path.line(to: NSPoint(x: maxX, y: maxY - radius))
        path.curve(
            to: NSPoint(x: maxX - radius, y: maxY),
            controlPoint1: NSPoint(x: maxX, y: maxY - radius * 0.45),
            controlPoint2: NSPoint(x: maxX - radius * 0.45, y: maxY)
        )
        path.line(to: NSPoint(x: minX + radius, y: maxY))
        path.curve(
            to: NSPoint(x: minX, y: maxY - radius),
            controlPoint1: NSPoint(x: minX + radius * 0.45, y: maxY),
            controlPoint2: NSPoint(x: minX, y: maxY - radius * 0.45)
        )
        path.line(to: NSPoint(x: minX, y: minY + radius))
        path.curve(
            to: NSPoint(x: minX + radius, y: minY),
            controlPoint1: NSPoint(x: minX, y: minY + radius * 0.45),
            controlPoint2: NSPoint(x: minX + radius * 0.45, y: minY)
        )
        path.close()
        return path
    }

    private static func draw(_ text: String, font: NSFont, centeredIn rect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        let origin = NSPoint(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2
        )
        attributed.draw(at: origin)
    }
}
