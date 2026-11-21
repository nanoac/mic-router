import Cocoa

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: gen-icon.swift <output.iconset>\n", stderr)
    exit(1)
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func renderIcon(pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let inset = size * 0.08
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = rect.width * 0.225
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // Smooth dark teal -> indigo gradient
    let grad = NSGradient(
        starting: NSColor(calibratedRed: 0.07, green: 0.56, blue: 0.58, alpha: 1.0),
        ending: NSColor(calibratedRed: 0.14, green: 0.25, blue: 0.54, alpha: 1.0)
    )!
    grad.draw(in: path, angle: -55)

    // Subtle inner highlight border
    NSColor.white.withAlphaComponent(0.18).setStroke()
    path.lineWidth = max(1, size * 0.012)
    path.stroke()

    // Crisp white SF Symbol microphone
    let symConfig = NSImage.SymbolConfiguration(pointSize: size * 0.44, weight: .semibold)
    if let sym = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(symConfig) {
        let tinted = NSImage(size: sym.size, flipped: false) { r in
            sym.draw(in: r)
            NSColor.white.set()
            r.fill(using: .sourceAtop)
            return true
        }
        let targetW = sym.size.width
        let targetH = sym.size.height
        let drawRect = NSRect(
            x: (size - targetW) / 2,
            y: (size - targetH) / 2,
            width: targetW,
            height: targetH
        )
        tinted.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let entries: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, px) in entries {
    let data = renderIcon(pixels: px)
    try data.write(to: iconsetURL.appendingPathComponent(name))
}
