import Cocoa

/// Renders ultra-clean, Apple-native menu bar icons based on SF Symbols (`waveform`)
/// so vertical alignment, optical weight, and light/dark adaptation match macOS system icons 100%.
enum StatusIconRenderer {
    enum Mode {
        case idle
        case voiceActive
        case paused
        case needsPermission
    }

    static func image(for mode: Mode) -> NSImage {
        let baseConfig = NSImage.SymbolConfiguration(pointSize: 14.5, weight: mode == .voiceActive ? .bold : .medium)

        switch mode {
        case .idle:
            if let sym = NSImage(systemSymbolName: "waveform", accessibilityDescription: "MicRouter")?
                .withSymbolConfiguration(baseConfig) {
                sym.isTemplate = true
                return sym
            }

        case .paused:
            let name = NSImage(systemSymbolName: "waveform.slash", accessibilityDescription: nil) != nil
                ? "waveform.slash"
                : "mic.slash"
            if let sym = NSImage(systemSymbolName: name, accessibilityDescription: "MicRouter")?
                .withSymbolConfiguration(baseConfig) {
                sym.isTemplate = true
                return sym
            }

        case .voiceActive:
            let cyan = NSColor(calibratedRed: 0.16, green: 0.88, blue: 0.84, alpha: 1.0)
            let palette = NSImage.SymbolConfiguration(hierarchicalColor: cyan)
            if let sym = NSImage(systemSymbolName: "waveform", accessibilityDescription: "MicRouter")?
                .withSymbolConfiguration(baseConfig.applying(palette)) {
                sym.isTemplate = false
                return sym
            }

        case .needsPermission:
            if let base = NSImage(systemSymbolName: "waveform", accessibilityDescription: "MicRouter")?
                .withSymbolConfiguration(baseConfig) {
                let w = max(18, ceil(base.size.width) + 4)
                let h: CGFloat = 18
                let composed = NSImage(size: NSSize(width: w, height: h), flipped: false) { rect in
                    let drawRect = NSRect(
                        x: (rect.width - base.size.width) / 2 - 1,
                        y: (rect.height - base.size.height) / 2,
                        width: base.size.width,
                        height: base.size.height
                    )
                    base.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)

                    NSColor.systemOrange.setFill()
                    let dot: CGFloat = 4.2
                    NSBezierPath(ovalIn: NSRect(
                        x: rect.width - dot - 1.0,
                        y: rect.height - dot - 2.0,
                        width: dot,
                        height: dot
                    )).fill()
                    return true
                }
                composed.isTemplate = false
                return composed
            }
        }

        let fallback = NSImage(systemSymbolName: "waveform", accessibilityDescription: "MicRouter") ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }
}
