import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("usage: swift scripts/generate-icon.swift <output-icns-path>\n", stderr)
    Foundation.exit(1)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let iconsetURL = outputURL.deletingPathExtension().appendingPathExtension("iconset")
let fileManager = FileManager.default

try? fileManager.removeItem(at: iconsetURL)
try? fileManager.removeItem(at: outputURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let requiredSizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, filename) in requiredSizes {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    drawLogo(in: rect)
    NSGraphicsContext.restoreGraphicsState()

    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: iconsetURL.appendingPathComponent(filename))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "FindKeyIcon", code: Int(process.terminationStatus))
}

func drawLogo(in rect: NSRect) {
    let background = NSColor(calibratedRed: 32 / 255, green: 29 / 255, blue: 29 / 255, alpha: 1)
    let border = NSColor(calibratedRed: 100 / 255, green: 98 / 255, blue: 98 / 255, alpha: 0.7)
    let primary = NSColor(calibratedRed: 253 / 255, green: 252 / 255, blue: 252 / 255, alpha: 1)
    let accent = NSColor(calibratedRed: 0, green: 122 / 255, blue: 1, alpha: 1)

    let tileInset = rect.width * 0.03
    let tileRect = rect.insetBy(dx: tileInset, dy: tileInset)
    let tileRadius = rect.width * 0.21

    let tile = NSBezierPath(roundedRect: tileRect, xRadius: tileRadius, yRadius: tileRadius)
    background.setFill()
    tile.fill()
    border.setStroke()
    tile.lineWidth = max(2, rect.width * 0.018)
    tile.stroke()

    let repoRect = NSRect(
        x: rect.minX + rect.width * 0.18,
        y: rect.minY + rect.height * 0.26,
        width: rect.width * 0.64,
        height: rect.height * 0.48
    )

    let tabWidth = repoRect.width * 0.24
    let tabHeight = repoRect.height * 0.18
    let corner = rect.width * 0.03
    let repoPath = NSBezierPath()
    repoPath.lineWidth = max(8, rect.width * 0.042)
    repoPath.lineJoinStyle = .round
    repoPath.lineCapStyle = .square
    repoPath.move(to: NSPoint(x: repoRect.minX, y: repoRect.minY + tabHeight))
    repoPath.line(to: NSPoint(x: repoRect.minX, y: repoRect.maxY - corner))
    repoPath.curve(to: NSPoint(x: repoRect.minX + corner, y: repoRect.maxY), controlPoint1: NSPoint(x: repoRect.minX, y: repoRect.maxY - corner * 0.33), controlPoint2: NSPoint(x: repoRect.minX + corner * 0.33, y: repoRect.maxY))
    repoPath.line(to: NSPoint(x: repoRect.minX + tabWidth - corner, y: repoRect.maxY))
    repoPath.line(to: NSPoint(x: repoRect.minX + tabWidth + corner, y: repoRect.maxY - tabHeight))
    repoPath.line(to: NSPoint(x: repoRect.maxX - corner, y: repoRect.maxY - tabHeight))
    repoPath.curve(to: NSPoint(x: repoRect.maxX, y: repoRect.maxY - tabHeight - corner), controlPoint1: NSPoint(x: repoRect.maxX - corner * 0.33, y: repoRect.maxY - tabHeight), controlPoint2: NSPoint(x: repoRect.maxX, y: repoRect.maxY - tabHeight - corner * 0.33))
    repoPath.line(to: NSPoint(x: repoRect.maxX, y: repoRect.minY + corner))
    repoPath.curve(to: NSPoint(x: repoRect.maxX - corner, y: repoRect.minY), controlPoint1: NSPoint(x: repoRect.maxX, y: repoRect.minY + corner * 0.33), controlPoint2: NSPoint(x: repoRect.maxX - corner * 0.33, y: repoRect.minY))
    repoPath.line(to: NSPoint(x: repoRect.minX + corner, y: repoRect.minY))
    repoPath.curve(to: NSPoint(x: repoRect.minX, y: repoRect.minY + corner), controlPoint1: NSPoint(x: repoRect.minX + corner * 0.33, y: repoRect.minY), controlPoint2: NSPoint(x: repoRect.minX, y: repoRect.minY + corner * 0.33))
    repoPath.close()
    primary.setStroke()
    repoPath.stroke()

    let keyholeCircleSize = rect.width * 0.1
    let keyholeStemWidth = rect.width * 0.05
    let keyholeStemHeight = rect.height * 0.14
    let keyholeCenter = NSPoint(x: rect.midX, y: rect.midY + rect.height * 0.01)
    let keyholeCircle = NSBezierPath(ovalIn: NSRect(x: keyholeCenter.x - keyholeCircleSize / 2, y: keyholeCenter.y - keyholeCircleSize * 0.85, width: keyholeCircleSize, height: keyholeCircleSize))
    accent.setFill()
    keyholeCircle.fill()
    let keyholeStem = NSBezierPath(roundedRect: NSRect(x: keyholeCenter.x - keyholeStemWidth / 2, y: keyholeCenter.y - keyholeCircleSize * 0.05, width: keyholeStemWidth, height: keyholeStemHeight), xRadius: keyholeStemWidth / 2, yRadius: keyholeStemWidth / 2)
    keyholeStem.fill()

    let bracketInset = rect.width * 0.11
    let bracketHeight = rect.height * 0.16
    let bracketArm = rect.width * 0.03
    let leftBracket = NSBezierPath()
    leftBracket.lineWidth = max(6, rect.width * 0.026)
    leftBracket.lineCapStyle = .square
    leftBracket.move(to: NSPoint(x: keyholeCenter.x - bracketInset, y: keyholeCenter.y - bracketHeight / 2))
    leftBracket.line(to: NSPoint(x: keyholeCenter.x - bracketInset - bracketArm, y: keyholeCenter.y - bracketHeight / 2))
    leftBracket.line(to: NSPoint(x: keyholeCenter.x - bracketInset - bracketArm, y: keyholeCenter.y + bracketHeight / 2))
    leftBracket.line(to: NSPoint(x: keyholeCenter.x - bracketInset, y: keyholeCenter.y + bracketHeight / 2))
    accent.setStroke()
    leftBracket.stroke()

    let rightBracket = NSBezierPath()
    rightBracket.lineWidth = max(6, rect.width * 0.026)
    rightBracket.lineCapStyle = .square
    rightBracket.move(to: NSPoint(x: keyholeCenter.x + bracketInset, y: keyholeCenter.y - bracketHeight / 2))
    rightBracket.line(to: NSPoint(x: keyholeCenter.x + bracketInset + bracketArm, y: keyholeCenter.y - bracketHeight / 2))
    rightBracket.line(to: NSPoint(x: keyholeCenter.x + bracketInset + bracketArm, y: keyholeCenter.y + bracketHeight / 2))
    rightBracket.line(to: NSPoint(x: keyholeCenter.x + bracketInset, y: keyholeCenter.y + bracketHeight / 2))
    rightBracket.stroke()
}
