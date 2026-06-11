import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("Usage: create_dmg_background.swift <output.png>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let width = 660
let height = 400
let size = NSSize(width: width, height: height)

guard
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )
else {
    fputs("Failed to create bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

let rect = NSRect(origin: .zero, size: size)
NSGradient(colors: [
    NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.11, alpha: 1),
    NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.19, alpha: 1)
])?.draw(in: rect, angle: 90)

let accent = NSColor(calibratedRed: 0.30, green: 0.72, blue: 1.0, alpha: 1)
let mint = NSColor(calibratedRed: 0.39, green: 0.86, blue: 0.72, alpha: 1)

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 28, weight: .bold),
    .foregroundColor: NSColor.white
]
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .medium),
    .foregroundColor: NSColor.white.withAlphaComponent(0.70)
]
let footerAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
    .foregroundColor: NSColor.white.withAlphaComponent(0.46)
]

"Install BlinkBar".draw(at: NSPoint(x: 38, y: 332), withAttributes: titleAttributes)
"Drag BlinkBar into Applications".draw(at: NSPoint(x: 40, y: 306), withAttributes: subtitleAttributes)

let glow = NSBezierPath(ovalIn: NSRect(x: 246, y: 115, width: 168, height: 100))
mint.withAlphaComponent(0.06).setFill()
glow.fill()

let arrowPath = NSBezierPath()
arrowPath.lineWidth = 7
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.move(to: NSPoint(x: 260, y: 198))
arrowPath.curve(to: NSPoint(x: 402, y: 198), controlPoint1: NSPoint(x: 306, y: 232), controlPoint2: NSPoint(x: 356, y: 232))
accent.setStroke()
arrowPath.stroke()

let arrowHead = NSBezierPath()
arrowHead.lineWidth = 7
arrowHead.lineCapStyle = .round
arrowHead.lineJoinStyle = .round
arrowHead.move(to: NSPoint(x: 402, y: 198))
arrowHead.line(to: NSPoint(x: 381, y: 215))
arrowHead.move(to: NSPoint(x: 402, y: 198))
arrowHead.line(to: NSPoint(x: 381, y: 181))
accent.setStroke()
arrowHead.stroke()

"If macOS blocks first launch: System Settings > Privacy & Security > Open Anyway."
    .draw(at: NSPoint(x: 40, y: 28), withAttributes: footerAttributes)

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Failed to render PNG background\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL)
