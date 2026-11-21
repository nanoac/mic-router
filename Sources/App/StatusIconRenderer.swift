import Cocoa

/// Renders crisp, Retina-ready custom menu bar icons optically centered to match
/// macOS menu bar SF Symbols (14pt optical height inside an 18pt tall canvas).
enum StatusIconRenderer {
    enum Mode {
        case idle
        case voiceActive
        case paused
        case needsPermission
    }

    static func image(for mode: Mode) -> NSImage {
        let size = NSSize(width: 22, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setAllowsAntialiasing(true)
            ctx.setShouldAntialias(true)

            let cx = rect.width * 0.50 // 11.0
            // Exact optical bounds: bottom = 2.0, top = 16.0 -> center = 9.0
            let capW: CGFloat = 4.5
            let capH: CGFloat = 7.8
            let capTop: CGFloat = 16.0
            let capRect = CGRect(x: cx - capW / 2, y: capTop - capH, width: capW, height: capH)

            let primaryColor: NSColor
            let arcColor: NSColor

            switch mode {
            case .voiceActive:
                primaryColor = NSColor(calibratedRed: 0.16, green: 0.88, blue: 0.84, alpha: 1.0)
                arcColor = primaryColor
            case .paused:
                primaryColor = NSColor.labelColor.withAlphaComponent(0.75)
                arcColor = primaryColor
            case .idle, .needsPermission:
                primaryColor = NSColor.labelColor
                arcColor = NSColor.labelColor.withAlphaComponent(0.85)
            }

            // 1. Sleek microphone capsule (top = 16.0, bottom = 8.2)
            let capPath = CGPath(roundedRect: capRect, cornerWidth: capW / 2, cornerHeight: capW / 2, transform: nil)
            ctx.addPath(capPath)
            ctx.setFillColor(primaryColor.cgColor)
            ctx.fillPath()

            // 2. Precision U-cradle + short stem + base (bottom edge = 2.0)
            let strokeW: CGFloat = 1.4
            ctx.setStrokeColor(primaryColor.cgColor)
            ctx.setLineWidth(strokeW)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            let cradleR: CGFloat = 4.15
            let cradleCenterY: CGFloat = 10.35 // bottom of arc = 6.2
            ctx.addArc(
                center: CGPoint(x: cx, y: cradleCenterY),
                radius: cradleR,
                startAngle: .pi,
                endAngle: 0,
                clockwise: false
            )

            let stemTopY = cradleCenterY - cradleR // 6.2
            let baseY: CGFloat = 2.7               // bottom edge = 2.7 - 0.7 = 2.0
            ctx.move(to: CGPoint(x: cx, y: stemTopY))
            ctx.addLine(to: CGPoint(x: cx, y: baseY))
            ctx.move(to: CGPoint(x: cx - 2.8, y: baseY))
            ctx.addLine(to: CGPoint(x: cx + 2.8, y: baseY))
            ctx.strokePath()

            // 3. Balanced dual routing wave arcs centered on the capsule
            let waveCenterY: CGFloat = 10.6
            if mode == .idle || mode == .voiceActive {
                let innerR: CGFloat = 6.85
                ctx.setLineWidth(1.35)
                ctx.setLineCap(.round)
                ctx.setStrokeColor(arcColor.cgColor)

                // Left inner arc
                ctx.addArc(center: CGPoint(x: cx, y: waveCenterY), radius: innerR,
                           startAngle: .pi * 0.80, endAngle: .pi * 1.20, clockwise: false)
                ctx.strokePath()

                // Right inner arc
                ctx.addArc(center: CGPoint(x: cx, y: waveCenterY), radius: innerR,
                           startAngle: -.pi * 0.20, endAngle: .pi * 0.20, clockwise: false)
                ctx.strokePath()

                // Outer arcs when actively routing remote voice
                if mode == .voiceActive {
                    let outerR: CGFloat = 9.35
                    ctx.setLineWidth(1.25)
                    ctx.setStrokeColor(arcColor.withAlphaComponent(0.60).cgColor)
                    ctx.addArc(center: CGPoint(x: cx, y: waveCenterY), radius: outerR,
                               startAngle: .pi * 0.78, endAngle: .pi * 1.22, clockwise: false)
                    ctx.strokePath()
                    ctx.addArc(center: CGPoint(x: cx, y: waveCenterY), radius: outerR,
                               startAngle: -.pi * 0.22, endAngle: .pi * 0.22, clockwise: false)
                    ctx.strokePath()
                }
            } else if mode == .paused {
                // Apple SF Symbol-style slash with subtle knockout gap
                ctx.saveGState()
                ctx.setBlendMode(.clear)
                ctx.setLineWidth(3.2)
                ctx.setLineCap(.round)
                ctx.move(to: CGPoint(x: 4.0, y: 15.2))
                ctx.addLine(to: CGPoint(x: 18.0, y: 2.6))
                ctx.strokePath()
                ctx.restoreGState()

                ctx.setStrokeColor(NSColor.labelColor.cgColor)
                ctx.setLineWidth(1.45)
                ctx.setLineCap(.round)
                ctx.move(to: CGPoint(x: 4.0, y: 15.2))
                ctx.addLine(to: CGPoint(x: 18.0, y: 2.6))
                ctx.strokePath()
            } else if mode == .needsPermission {
                ctx.setFillColor(NSColor.systemOrange.cgColor)
                let dotD: CGFloat = 4.0
                ctx.fillEllipse(in: CGRect(x: rect.width - dotD - 2.0,
                                           y: rect.height - dotD - 2.0,
                                           width: dotD,
                                           height: dotD))
            }

            return true
        }

        img.isTemplate = (mode == .idle || mode == .paused)
        return img
    }
}
