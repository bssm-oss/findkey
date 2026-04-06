import AppKit

@MainActor
final class LogoMarkView: NSView {
    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 40, height: 40)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = self.bounds.insetBy(dx: 1, dy: 1)
        let tile = NSBezierPath(roundedRect: bounds, xRadius: 9, yRadius: 9)
        Theme.background.setFill()
        tile.fill()

        Theme.border.withAlphaComponent(0.7).setStroke()
        tile.lineWidth = 1
        tile.stroke()

        drawRepositoryGlyph(in: bounds)
    }

    private func drawRepositoryGlyph(in rect: NSRect) {
        let repoRect = NSRect(
            x: rect.minX + rect.width * 0.18,
            y: rect.minY + rect.height * 0.24,
            width: rect.width * 0.64,
            height: rect.height * 0.48
        )

        let repoPath = NSBezierPath()
        repoPath.lineWidth = 2.4
        repoPath.lineJoinStyle = .round
        repoPath.lineCapStyle = .square

        let tabWidth = repoRect.width * 0.24
        let tabHeight = repoRect.height * 0.18
        repoPath.move(to: NSPoint(x: repoRect.minX, y: repoRect.minY + tabHeight))
        repoPath.line(to: NSPoint(x: repoRect.minX, y: repoRect.maxY - 3))
        repoPath.curve(to: NSPoint(x: repoRect.minX + 3, y: repoRect.maxY), controlPoint1: NSPoint(x: repoRect.minX, y: repoRect.maxY - 1), controlPoint2: NSPoint(x: repoRect.minX + 1, y: repoRect.maxY))
        repoPath.line(to: NSPoint(x: repoRect.minX + tabWidth - 2, y: repoRect.maxY))
        repoPath.line(to: NSPoint(x: repoRect.minX + tabWidth + 2, y: repoRect.maxY - tabHeight))
        repoPath.line(to: NSPoint(x: repoRect.maxX - 3, y: repoRect.maxY - tabHeight))
        repoPath.curve(to: NSPoint(x: repoRect.maxX, y: repoRect.maxY - tabHeight - 3), controlPoint1: NSPoint(x: repoRect.maxX - 1, y: repoRect.maxY - tabHeight), controlPoint2: NSPoint(x: repoRect.maxX, y: repoRect.maxY - tabHeight - 1))
        repoPath.line(to: NSPoint(x: repoRect.maxX, y: repoRect.minY + 3))
        repoPath.curve(to: NSPoint(x: repoRect.maxX - 3, y: repoRect.minY), controlPoint1: NSPoint(x: repoRect.maxX, y: repoRect.minY + 1), controlPoint2: NSPoint(x: repoRect.maxX - 1, y: repoRect.minY))
        repoPath.line(to: NSPoint(x: repoRect.minX + 3, y: repoRect.minY))
        repoPath.curve(to: NSPoint(x: repoRect.minX, y: repoRect.minY + 3), controlPoint1: NSPoint(x: repoRect.minX + 1, y: repoRect.minY), controlPoint2: NSPoint(x: repoRect.minX, y: repoRect.minY + 1))
        repoPath.close()

        Theme.textPrimary.setStroke()
        repoPath.stroke()

        let accent = Theme.accent
        let keyholeCenter = NSPoint(x: rect.midX, y: rect.midY + 1)
        let keyholeCircle = NSBezierPath(ovalIn: NSRect(x: keyholeCenter.x - 4.5, y: keyholeCenter.y - 9, width: 9, height: 9))
        accent.setFill()
        keyholeCircle.fill()

        let keyholeStem = NSBezierPath(roundedRect: NSRect(x: keyholeCenter.x - 2.1, y: keyholeCenter.y - 1, width: 4.2, height: 9), xRadius: 2, yRadius: 2)
        keyholeStem.fill()

        let leftBracket = NSBezierPath()
        leftBracket.lineWidth = 1.8
        leftBracket.lineCapStyle = .square
        leftBracket.move(to: NSPoint(x: keyholeCenter.x - 11, y: keyholeCenter.y - 8))
        leftBracket.line(to: NSPoint(x: keyholeCenter.x - 14, y: keyholeCenter.y - 8))
        leftBracket.line(to: NSPoint(x: keyholeCenter.x - 14, y: keyholeCenter.y + 8))
        leftBracket.line(to: NSPoint(x: keyholeCenter.x - 11, y: keyholeCenter.y + 8))

        let rightBracket = NSBezierPath()
        rightBracket.lineWidth = 1.8
        rightBracket.lineCapStyle = .square
        rightBracket.move(to: NSPoint(x: keyholeCenter.x + 11, y: keyholeCenter.y - 8))
        rightBracket.line(to: NSPoint(x: keyholeCenter.x + 14, y: keyholeCenter.y - 8))
        rightBracket.line(to: NSPoint(x: keyholeCenter.x + 14, y: keyholeCenter.y + 8))
        rightBracket.line(to: NSPoint(x: keyholeCenter.x + 11, y: keyholeCenter.y + 8))

        accent.setStroke()
        leftBracket.stroke()
        rightBracket.stroke()
    }
}
