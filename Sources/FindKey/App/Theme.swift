import AppKit

enum Theme {
    static let background = NSColor(calibratedRed: 32 / 255, green: 29 / 255, blue: 29 / 255, alpha: 1)
    static let surface = NSColor(calibratedRed: 48 / 255, green: 44 / 255, blue: 44 / 255, alpha: 1)
    static let textPrimary = NSColor(calibratedRed: 253 / 255, green: 252 / 255, blue: 252 / 255, alpha: 1)
    static let textSecondary = NSColor(calibratedRed: 154 / 255, green: 152 / 255, blue: 152 / 255, alpha: 1)
    static let border = NSColor(calibratedRed: 100 / 255, green: 98 / 255, blue: 98 / 255, alpha: 1)
    static let subtleBorder = NSColor(calibratedRed: 15 / 255, green: 0, blue: 0, alpha: 0.12)
    static let accent = NSColor(calibratedRed: 0, green: 122 / 255, blue: 1, alpha: 1)
    static let success = NSColor(calibratedRed: 48 / 255, green: 209 / 255, blue: 88 / 255, alpha: 1)
    static let warning = NSColor(calibratedRed: 1, green: 159 / 255, blue: 10 / 255, alpha: 1)
    static let danger = NSColor(calibratedRed: 1, green: 59 / 255, blue: 48 / 255, alpha: 1)

    static func font(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont(name: "Berkeley Mono", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
    }
}

final class ThemedContainerView: NSView {
    override var isFlipped: Bool { true }

    var fillColor: NSColor = Theme.background {
        didSet { needsDisplay = true }
    }

    var strokeColor: NSColor? {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let path = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
        fillColor.setFill()
        path.fill()

        if let strokeColor {
            strokeColor.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }
}

@MainActor
enum LabelFactory {
    static func section(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = Theme.font(size: 14, weight: .semibold)
        label.textColor = Theme.textPrimary
        return label
    }

    static func body(_ text: String, color: NSColor = Theme.textSecondary) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = Theme.font(size: 12)
        label.textColor = color
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        return label
    }
}
