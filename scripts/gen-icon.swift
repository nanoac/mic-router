import Cocoa

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: gen-icon.swift <output.iconset> [preview.png]\n", stderr)
    exit(1)
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

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

    let cs = CGColorSpaceCreateDeviceRGB()

    // 1. macOS squircle container (8.5% outer margin to match Apple HIG icon grid)
    let inset = s * 0.085
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let cornerR = rect.width * 0.225
    let squircle = CGPath(roundedRect: rect, cornerWidth: cornerR, cornerHeight: cornerR, transform: nil)

    // Subtle outer shadow
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -s * 0.015),
        blur: s * 0.03,
        color: CGColor(colorSpace: cs, components: [0, 0, 0, 0.35])!
    )
    ctx.addPath(squircle)
    ctx.setFillColor(CGColor(colorSpace: cs, components: [0.06, 0.09, 0.16, 1.0])!)
    ctx.fillPath()
    ctx.restoreGState()

    // Clip to squircle for internal layers
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    // 2. Deep midnight-indigo base gradient
    let bgGrad = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(colorSpace: cs, components: [0.11, 0.15, 0.26, 1.0])!, // top-left slate indigo
            CGColor(colorSpace: cs, components: [0.05, 0.07, 0.14, 1.0])!, // bottom-right deep obsidian
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        bgGrad,
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY),
        options: []
    )

    // 3. Soft dual-tone ambient glow (cyan-teal top-left + electric violet bottom-right)
    let glow1 = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(colorSpace: cs, components: [0.10, 0.82, 0.85, 0.36])!,
            CGColor(colorSpace: cs, components: [0.10, 0.82, 0.85, 0.0])!,
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawRadialGradient(
        glow1,
        startCenter: CGPoint(x: s * 0.34, y: s * 0.68),
        startRadius: 0,
        endCenter: CGPoint(x: s * 0.34, y: s * 0.68),
        endRadius: s * 0.45,
        options: []
    )

    let glow2 = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(colorSpace: cs, components: [0.46, 0.36, 0.96, 0.32])!,
            CGColor(colorSpace: cs, components: [0.46, 0.36, 0.96, 0.0])!,
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawRadialGradient(
        glow2,
        startCenter: CGPoint(x: s * 0.68, y: s * 0.32),
        startRadius: 0,
        endCenter: CGPoint(x: s * 0.68, y: s * 0.32),
        endRadius: s * 0.44,
        options: []
    )

    // 4. Dual symmetric signal/routing arcs flanking the microphone
    let cx = s * 0.50
    let cy = s * 0.54
    let arcLineWidth = s * 0.034

    // Left routing arcs (mint-cyan: remote mic)
    ctx.saveGState()
    ctx.setLineCap(.round)
    ctx.setLineWidth(arcLineWidth)
    for (radiusMul, alpha) in [(0.235, 0.92), (0.315, 0.48)] as [(CGFloat, CGFloat)] {
        ctx.setStrokeColor(CGColor(colorSpace: cs, components: [0.22, 0.90, 0.86, alpha])!)
        ctx.addArc(
            center: CGPoint(x: cx, y: cy),
            radius: s * radiusMul,
            startAngle: .pi * 0.78,
            endAngle: .pi * 1.22,
            clockwise: false
        )
        ctx.strokePath()
    }
    ctx.restoreGState()

    // Right routing arcs (soft electric indigo-blue: desktop mic)
    ctx.saveGState()
    ctx.setLineCap(.round)
    ctx.setLineWidth(arcLineWidth)
    for (radiusMul, alpha) in [(0.235, 0.92), (0.315, 0.48)] as [(CGFloat, CGFloat)] {
        ctx.setStrokeColor(CGColor(colorSpace: cs, components: [0.56, 0.64, 1.00, alpha])!)
        ctx.addArc(
            center: CGPoint(x: cx, y: cy),
            radius: s * radiusMul,
            startAngle: -.pi * 0.22,
            endAngle: .pi * 0.22,
            clockwise: false
        )
        ctx.strokePath()
    }
    ctx.restoreGState()

    // 5. Crisp studio microphone glyph (capsule + cradle + stem + base)
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -s * 0.014),
        blur: s * 0.032,
        color: CGColor(colorSpace: cs, components: [0, 0, 0, 0.45])!
    )

    // Capsule pill
    let capW = s * 0.185
    let capH = s * 0.305
    let capRect = CGRect(x: cx - capW / 2, y: cy - capH * 0.44, width: capW, height: capH)
    let capPath = CGPath(roundedRect: capRect, cornerWidth: capW / 2, cornerHeight: capW / 2, transform: nil)

    ctx.saveGState()
    ctx.addPath(capPath)
    ctx.clip()
    let capGrad = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(colorSpace: cs, components: [1.00, 1.00, 1.00, 1.0])!,
            CGColor(colorSpace: cs, components: [0.84, 0.91, 0.98, 1.0])!,
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        capGrad,
        start: CGPoint(x: cx, y: capRect.maxY),
        end: CGPoint(x: cx, y: capRect.minY),
        options: []
    )

    // Subtle acoustic grille slits on capsule
    ctx.setStrokeColor(CGColor(colorSpace: cs, components: [0.12, 0.19, 0.32, 0.22])!)
    ctx.setLineWidth(max(1.0, s * 0.011))
    ctx.setLineCap(.round)
    for offset in [-0.032, 0.0, 0.032] as [CGFloat] {
        let y = capRect.midY + s * offset + s * 0.02
        ctx.move(to: CGPoint(x: cx - capW * 0.24, y: y))
        ctx.addLine(to: CGPoint(x: cx + capW * 0.24, y: y))
        ctx.strokePath()
    }
    ctx.restoreGState()

    // U-shaped cradle + stem + base (grouped in one transparency layer for seamless junctions)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    let strokeW = s * 0.038
    ctx.setStrokeColor(CGColor(colorSpace: cs, components: [0.94, 0.97, 1.0, 0.96])!)
    ctx.setLineWidth(strokeW)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    let cradleR = s * 0.145
    let cradleCenterY = capRect.minY + capW * 0.50
    ctx.addArc(
        center: CGPoint(x: cx, y: cradleCenterY),
        radius: cradleR,
        startAngle: .pi,
        endAngle: 0,
        clockwise: false
    )

    // Vertical stem
    let stemTopY = cradleCenterY - cradleR
    let stemBotY = s * 0.265
    ctx.move(to: CGPoint(x: cx, y: stemTopY))
    ctx.addLine(to: CGPoint(x: cx, y: stemBotY))

    // Horizontal base pill
    let baseHalfW = s * 0.095
    ctx.move(to: CGPoint(x: cx - baseHalfW, y: stemBotY))
    ctx.addLine(to: CGPoint(x: cx + baseHalfW, y: stemBotY))
    ctx.strokePath()
    ctx.endTransparencyLayer()

    ctx.restoreGState()

    // 6. Subtle glass rim highlight around the squircle
    let borderRect = rect.insetBy(dx: max(0.5, s * 0.004), dy: max(0.5, s * 0.004))
    let borderPath = CGPath(roundedRect: borderRect, cornerWidth: cornerR, cornerHeight: cornerR, transform: nil)
    ctx.addPath(borderPath)
    ctx.setLineWidth(max(1.0, s * 0.008))
    ctx.setStrokeColor(CGColor(colorSpace: cs, components: [1.0, 1.0, 1.0, 0.16])!)
    ctx.strokePath()

    ctx.restoreGState()
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

if CommandLine.arguments.count >= 3 {
    let previewURL = URL(fileURLWithPath: CommandLine.arguments[2])
    let data = renderIcon(pixels: 512)
    try data.write(to: previewURL)
}
