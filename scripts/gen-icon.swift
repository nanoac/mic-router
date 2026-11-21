import Cocoa

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: gen-icon.swift <output.iconset>\n", stderr)
    exit(1)
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let cs = CGColorSpaceCreateDeviceRGB()

func renderIcon(pixels: Int) -> Data {
    let s = CGFloat(pixels)
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
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    let nsCtx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = nsCtx
    let ctx = nsCtx.cgContext
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // macOS HIG squircle base (8.5% outer margin, 22.5% corner radius)
    let inset = s * 0.085
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = rect.width * 0.225
    let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Subtle outer shadow
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -s * 0.014),
        blur: s * 0.028,
        color: CGColor(colorSpace: cs, components: [0, 0, 0, 0.28])!
    )
    ctx.addPath(squircle)
    ctx.setFillColor(CGColor(colorSpace: cs, components: [0.095, 0.10, 0.115, 1.0])!)
    ctx.fillPath()
    ctx.restoreGState()

    // Subtle matte hardware rim
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.setLineWidth(max(1.0, s * 0.008))
    ctx.setStrokeColor(CGColor(colorSpace: cs, components: [1.0, 1.0, 1.0, 0.09])!)
    ctx.strokePath()
    ctx.restoreGState()

    // 7x7 Retro LED dot-matrix audio waveform
    let cols = 7
    let rows = 7
    let gridSpan = s * 0.60
    let step = gridSpan / CGFloat(cols - 1)
    let startX = (s - gridSpan) / 2
    let startY = (s - gridSpan) / 2
    let dotR = s * 0.036

    let activeCounts = [1, 3, 5, 7, 5, 3, 1]

    for c in 0..<cols {
        let count = activeCounts[c]
        let minR = (rows - count) / 2
        let maxR = minR + count - 1
        for r in 0..<rows {
            let x = startX + CGFloat(c) * step
            let y = startY + CGFloat(r) * step
            let isLit = (r >= minR && r <= maxR)
            let color: [CGFloat]
            if isLit {
                // Signal orange center column + warm ivory flanking waveform
                color = (c == 3) ? [1.0, 0.35, 0.15, 1.0] : [0.95, 0.95, 0.92, 1.0]
            } else {
                color = [1.0, 1.0, 1.0, 0.10]
            }
            ctx.setFillColor(CGColor(colorSpace: cs, components: color)!)
            ctx.fillEllipse(in: CGRect(x: x - dotR, y: y - dotR, width: dotR * 2, height: dotR * 2))
        }
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
