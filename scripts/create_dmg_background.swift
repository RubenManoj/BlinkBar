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
    NSColor(calibratedRed: 0.96, green: 0.98, blue: 1.0, alpha: 1),
    NSColor(calibratedRed: 0.88, green: 0.93, blue: 0.98, alpha: 1)
])?.draw(in: rect, angle: 90)

let accent = NSColor(calibratedRed: 0.10, green: 0.48, blue: 0.92, alpha: 1)
let graphite = NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.19, alpha: 1)
let secondary = NSColor(calibratedRed: 0.38, green: 0.44, blue: 0.52, alpha: 1)

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 30, weight: .bold),
    .foregroundColor: graphite
]
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .medium),
    .foregroundColor: secondary
]
let footerAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
    .foregroundColor: secondary.withAlphaComponent(0.82)
]

"Install BlinkBar".draw(at: NSPoint(x: 40, y: 328), withAttributes: titleAttributes)
"Drag BlinkBar.app into Applications".draw(at: NSPoint(x: 42, y: 300), withAttributes: subtitleAttributes)

let panel = NSBezierPath(roundedRect: NSRect(x: 42, y: 68, width: 576, height: 188), xRadius: 24, yRadius: 24)
NSColor.white.withAlphaComponent(0.46).setFill()
panel.fill()

let arrowPath = NSBezierPath()
arrowPath.lineWidth = 6
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.move(to: NSPoint(x: 268, y: 170))
arrowPath.curve(to: NSPoint(x: 392, y: 170), controlPoint1: NSPoint(x: 306, y: 196), controlPoint2: NSPoint(x: 354, y: 196))
accent.setStroke()
arrowPath.stroke()

let arrowHead = NSBezierPath()
arrowHead.lineWidth = 6
arrowHead.lineCapStyle = .round
arrowHead.lineJoinStyle = .round
arrowHead.move(to: NSPoint(x: 392, y: 170))
arrowHead.line(to: NSPoint(x: 374, y: 185))
arrowHead.move(to: NSPoint(x: 392, y: 170))
arrowHead.line(to: NSPoint(x: 374, y: 155))
accent.setStroke()
arrowHead.stroke()

"If macOS blocks first launch: System Settings > Privacy & Security > Open Anyway."
    .draw(at: NSPoint(x: 42, y: 30), withAttributes: footerAttributes)

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Failed to render PNG background\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL)
