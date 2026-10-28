import AppKit
import Carbon

enum Badge {
    private static var cache: [String: NSImage] = [:]
    private static let size = NSSize(width: 22, height: 16)

    static func image(for source: TISInputSource) -> NSImage {
        image(InputSources.iconLabel(source))
    }

    static func image(_ label: String) -> NSImage {
        if let cached = cache[label] {
            return cached
        }
        let lineWidth: CGFloat = 1.3
        var font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        var text = NSAttributedString(string: label, attributes: [.font: font, .foregroundColor: NSColor.black])
        let room = size.width - 6
        if text.size().width > room {
            font = NSFont.systemFont(ofSize: 11 * room / text.size().width, weight: .semibold)
            text = NSAttributedString(string: label, attributes: [.font: font, .foregroundColor: NSColor.black])
        }
        let textSize = text.size()
        let image = NSImage(size: size, flipped: false) { bounds in
            NSColor.black.setStroke()
            let frame = bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            let path = NSBezierPath(roundedRect: frame, xRadius: 4.5, yRadius: 4.5)
            path.lineWidth = lineWidth
            path.stroke()
            let baseline = (bounds.height - font.capHeight) / 2
            text.draw(at: NSPoint(x: (bounds.width - textSize.width) / 2, y: baseline + font.descender))
            return true
        }
        image.isTemplate = true
        cache[label] = image
        return image
    }
}
