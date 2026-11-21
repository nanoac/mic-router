import Cocoa

/// Renders crisp, Retina-ready custom menu bar icons matching MicRouter's visual identity
/// (studio microphone flanked by dual routing wave arcs).
enum StatusIconRenderer {
    enum Mode {
        case idle
        case voiceActive
        case paused
        case needsPermission
    }

    static func image(for mode: Mode) -> NSImage {
        let size = NSSize(width: 20, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setAllowsAntialiasing(true)
            ctx.setShouldAntialias(true)

            let cx = rect.width * 0.50
            let cy = rect.height * 0.54

            let primaryColor: NSColor
            let accentLeft: NSColor
            let accentRight: NSColor

            switch mode {
            case .voiceActive:
                // Vibrant cyan-teal highlight when remote mic is live
                primaryColor = NSColor(calibratedRed: 0.14, green: 0.86, blue: 0.82, alpha: 1.0)
                accentLeft = primaryColor
                accentRight = primaryColor
            case .paused:
                primaryColor = NSColor.labelColor.withAlphaComponent(0.55)
                accentLeft = primaryColor
                accentRight = primaryColor
            case .idle, .needsPermission:
                primaryColor = NSColor.labelColor
                accentLeft = NSColor.labelColor.withAlphaComponent(0.88)
                accentRight = NSColor.labelColor.withAlphaComponent(0.88)
            }

            // 1. Microphone capsule (pill)
            let capW: CGFloat = 4.6
            let capH: CGFloat = 7.4
            let capRect = CGRect(x: cx - capW / 2, y: cy - capH * 0.42, width: capW, height: capH)
            let capPath = CGPath(roundedRect: capRect, cornerWidth: capW / 2, cornerHeight: capW / 2, transform: nil)

            ctx.addPath(capPath)
            ctx.setFillColor(primaryColor.cgColor)
            ctx.fillPath()

            // 2. U-shaped cradle + stem + base
            ctx.setStrokeColor(primaryColor.cgColor)
            ctx.setLineWidth(1.45)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            let cradleR: CGFloat = 3.9
            let cradleCenterY = capRect.minY + capW * 0.50
            ctx.addArc(
                center: CGPoint(x: cx, y: cradleCenterY),
                radius: cradleR,
                startAngle: .pi,
                endAngle: 0,
                clockwise: false
            )
            let stemTopY = cradleCenterY - cradleR
            let stemBotY: CGFloat = 2.4
            ctx.move(to: CGPoint(x: cx, y: stemTopY))
            ctx.addLine(to: CGPoint(x: cx, y: stemBotY))
            ctx.move(to: CGPoint(x: cx - 2.6, y: stemBotY))
            ctx.addLine(to: CGPoint(x: cx + 2.6, y: stemBotY))
            ctx.strokePath()

            // 3. Routing wave arcs flanking the mic
            if mode == .idle || mode == .voiceActive {
                let innerR: CGFloat = 6.2
                let outerR: CGFloat = 8.4

                ctx.setLineWidth(1.35)
                ctx.setLineCap(.round)

                // Left inner arc
                ctx.setStrokeColor(accentLeft.cgColor)
                ctx.addArc(center: CGPoint(x: cx, y: cy), radius: innerR,
                           startAngle: .pi * 0.78, endAngle: .pi * 1.22, clockwise: false)
                ctx.strokePath()

                // Right inner arc
                ctx.setStrokeColor(accentRight.cgColor)
                ctx.addArc(center: CGPoint(x: cx, y: cy), radius: innerR,
                           startAngle: -.pi * 0.22, endAngle: .pi * 0.22, clockwise: false)
                ctx.strokePath()

                // Outer arcs shown when actively routing remote voice
                if mode == .voiceActive {
                    ctx.setLineWidth(1.25)
                    ctx.setStrokeColor(accentLeft.withAlphaComponent(0.65).cgColor)
                    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: outerR,
                               startAngle: .pi * 0.76, endAngle: .pi * 1.24, clockwise: false)
                    ctx.strokePath()

                    ctx.setStrokeColor(accentRight.withAlphaComponent(0.65).cgColor)
                    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: outerR,
                               startAngle: -.pi * 0.24, endAngle: .pi * 0.24, clockwise: false)
                    ctx.strokePath()
                }
            } else if mode == .paused {
                // Clean diagonal slash for paused state
                ctx.setStrokeColor(NSColor.labelColor.cgColor)
                ctx.setLineWidth(1.6)
                ctx.setLineCap(.round)
                ctx.move(to: CGPoint(x: 3.5, y: 14.8))
                ctx.addLine(to: CGPoint(x: 16.5, y: 2.8))
                ctx.strokePath()
            } else if mode == .needsPermission {
                // Small exclamation indicator at top-right
                ctx.setFillColor(NSColor.systemOrange.cgColor)
                let dotR: CGFloat = 2.6
                ctx.fillEllipse(in: CGRect(x: rect.width - dotR * 2 - 1.2,
                                           y: rect.height - dotR * 2 - 1.2,
                                           width: dotR * 2,
                                           height: dotR * 2))
            }

            return true
        }

        // Template mode for monochrome states (auto-adapts to light/dark menu bar);
        // full color for active voice (cyan) and missing permission (orange badge).
        img.isTemplate = (mode == .idle || mode == .paused)
        return img
    }
}
