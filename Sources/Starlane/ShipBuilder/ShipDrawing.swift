import AppKit
import CoreGraphics

/// Procedural modular ship art.
/// Local space: nose points **+Y** (up). Starlane world drawing uses nose **+X** —
/// call with `rotateToPlusX: true` (default) so it matches existing ship orientation.
enum ShipDrawing {
    struct Options {
        var scale: CGFloat = 1
        var thrustGlow: CGFloat = 0.2
        var shieldPulse: CGFloat = 0
        var damaged: CGFloat = 0
        /// When true, rotate −90° so nose faces +X (Starlane convention).
        var rotateToPlusX: Bool = true
    }

    static func draw(ctx: CGContext, stats: ModularShipStats, options: Options = Options()) {
        ctx.saveGState()
        if options.rotateToPlusX {
            // +Y nose → +X nose
            ctx.rotate(by: -.pi / 2)
        }
        ctx.scaleBy(x: options.scale, y: options.scale)

        if stats.maxShield > 0, options.shieldPulse > 0 {
            drawShield(ctx: ctx, pulse: options.shieldPulse)
        }

        drawEngine(ctx: ctx, shape: stats.engineShape, color: stats.engineColor, glow: options.thrustGlow)
        drawWings(ctx: ctx, shape: stats.wingShape, color: stats.hullColor, accent: stats.accentColor)
        drawHull(ctx: ctx, shape: stats.hullShape, color: stats.hullColor, accent: stats.accentColor, damaged: options.damaged)

        // Cockpit glass + specular
        ctx.setFillColor(NSColor(srgbRed: 0.55, green: 0.85, blue: 1, alpha: 0.62).cgColor)
        let glass: CGRect
        switch stats.hullShape {
        case .needle: glass = CGRect(x: -2.5, y: 5, width: 5, height: 10)
        case .frigate: glass = CGRect(x: -5, y: -1, width: 10, height: 14)
        default: glass = CGRect(x: -3.5, y: 2, width: 7, height: 12)
        }
        ctx.fillEllipse(in: glass)
        ctx.setStrokeColor(stats.accentColor.withAlphaComponent(0.75).cgColor)
        ctx.setLineWidth(0.9)
        ctx.strokeEllipse(in: glass)
        // Specular highlight
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.35).cgColor)
        let hl = CGRect(x: glass.midX - 1.2, y: glass.maxY - 4.5, width: 2.4, height: 3.2)
        ctx.fillEllipse(in: hl)

        // Accent stripe
        ctx.setStrokeColor(stats.accentColor.cgColor)
        ctx.setLineWidth(1.5)
        ctx.move(to: CGPoint(x: 0, y: -10))
        ctx.addLine(to: CGPoint(x: 0, y: 14))
        ctx.strokePath()
        // Secondary pinstripe
        ctx.setStrokeColor(stats.accentColor.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(0.7)
        ctx.move(to: CGPoint(x: 2.2, y: -8))
        ctx.addLine(to: CGPoint(x: 2.2, y: 10))
        ctx.strokePath()

        ctx.restoreGState()
    }

    private static func drawShield(ctx: CGContext, pulse: CGFloat) {
        let r: CGFloat = 28 + pulse * 6
        let colors = [
            NSColor(srgbRed: 0.4, green: 0.8, blue: 1, alpha: 0.08 * pulse).cgColor,
            NSColor(srgbRed: 0.3, green: 0.7, blue: 1, alpha: 0.18 * pulse).cgColor,
            NSColor(srgbRed: 0.3, green: 0.7, blue: 1, alpha: 0).cgColor,
        ] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.7, 1]) {
            ctx.drawRadialGradient(g, startCenter: .zero, startRadius: 10, endCenter: .zero, endRadius: r, options: [])
        }
        ctx.setStrokeColor(NSColor(srgbRed: 0.47, green: 0.82, blue: 1, alpha: 0.35 * pulse).cgColor)
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
    }

    private static func drawHull(ctx: CGContext, shape: HullShape, color: NSColor, accent: NSColor, damaged: CGFloat) {
        let dark = color.shaded(by: -0.25)
        let light = color.shaded(by: 0.2)
        let edge = color.shaded(by: 0.35)

        let path = CGMutablePath()
        switch shape {
        case .scout:
            path.move(to: CGPoint(x: 0, y: 20))
            path.addLine(to: CGPoint(x: 8, y: -4))
            path.addLine(to: CGPoint(x: 5, y: -14))
            path.addLine(to: CGPoint(x: 0, y: -10))
            path.addLine(to: CGPoint(x: -5, y: -14))
            path.addLine(to: CGPoint(x: -8, y: -4))
            path.closeSubpath()
        case .gunship:
            path.move(to: CGPoint(x: 0, y: 18))
            path.addLine(to: CGPoint(x: 12, y: 2))
            path.addLine(to: CGPoint(x: 14, y: -12))
            path.addLine(to: CGPoint(x: 6, y: -16))
            path.addLine(to: CGPoint(x: -6, y: -16))
            path.addLine(to: CGPoint(x: -14, y: -12))
            path.addLine(to: CGPoint(x: -12, y: 2))
            path.closeSubpath()
        case .frigate:
            path.move(to: CGPoint(x: 0, y: 22))
            path.addLine(to: CGPoint(x: 10, y: 8))
            path.addLine(to: CGPoint(x: 14, y: -4))
            path.addLine(to: CGPoint(x: 12, y: -16))
            path.addLine(to: CGPoint(x: -12, y: -16))
            path.addLine(to: CGPoint(x: -14, y: -4))
            path.addLine(to: CGPoint(x: -10, y: 8))
            path.closeSubpath()
        case .needle:
            path.move(to: CGPoint(x: 0, y: 26))
            path.addLine(to: CGPoint(x: 5, y: -2))
            path.addLine(to: CGPoint(x: 3, y: -16))
            path.addLine(to: CGPoint(x: 0, y: -12))
            path.addLine(to: CGPoint(x: -3, y: -16))
            path.addLine(to: CGPoint(x: -5, y: -2))
            path.closeSubpath()
        case .interceptor:
            path.move(to: CGPoint(x: 0, y: 22))
            path.addLine(to: CGPoint(x: 10, y: -2))
            path.addLine(to: CGPoint(x: 7, y: -14))
            path.addLine(to: CGPoint(x: 0, y: -11))
            path.addLine(to: CGPoint(x: -7, y: -14))
            path.addLine(to: CGPoint(x: -10, y: -2))
            path.closeSubpath()
        }

        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let colors = [dark.cgColor, light.cgColor, dark.cgColor] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: -12, y: 0), end: CGPoint(x: 12, y: 0), options: [])
        }
        // Soft top highlight band
        let hlColors = [
            edge.withAlphaComponent(0.0).cgColor,
            edge.withAlphaComponent(0.22).cgColor,
            edge.withAlphaComponent(0.0).cgColor,
        ] as CFArray
        if let hg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: hlColors, locations: [0, 0.5, 1]) {
            ctx.drawLinearGradient(hg, start: CGPoint(x: 0, y: -16), end: CGPoint(x: 0, y: 22), options: [])
        }
        ctx.restoreGState()

        // Panel seam lines
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.setStrokeColor(dark.withAlphaComponent(0.55).cgColor)
        ctx.setLineWidth(0.7)
        switch shape {
        case .scout, .interceptor, .needle:
            ctx.move(to: CGPoint(x: -5, y: 8)); ctx.addLine(to: CGPoint(x: -4, y: -8))
            ctx.move(to: CGPoint(x: 5, y: 8)); ctx.addLine(to: CGPoint(x: 4, y: -8))
            ctx.move(to: CGPoint(x: 0, y: 16)); ctx.addLine(to: CGPoint(x: 0, y: -6))
        case .gunship:
            ctx.move(to: CGPoint(x: -8, y: 4)); ctx.addLine(to: CGPoint(x: -7, y: -10))
            ctx.move(to: CGPoint(x: 8, y: 4)); ctx.addLine(to: CGPoint(x: 7, y: -10))
            ctx.move(to: CGPoint(x: -10, y: -2)); ctx.addLine(to: CGPoint(x: 10, y: -2))
        case .frigate:
            ctx.move(to: CGPoint(x: -6, y: 10)); ctx.addLine(to: CGPoint(x: -6, y: -12))
            ctx.move(to: CGPoint(x: 6, y: 10)); ctx.addLine(to: CGPoint(x: 6, y: -12))
            ctx.move(to: CGPoint(x: -10, y: 2)); ctx.addLine(to: CGPoint(x: 10, y: 2))
            ctx.move(to: CGPoint(x: -10, y: -8)); ctx.addLine(to: CGPoint(x: 10, y: -8))
        }
        ctx.strokePath()
        ctx.restoreGState()

        // Edge stroke (accent outer + dark inner)
        ctx.addPath(path)
        ctx.setStrokeColor(accent.cgColor)
        ctx.setLineWidth(1.35)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        ctx.addPath(path)
        ctx.setStrokeColor(edge.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(0.6)
        ctx.strokePath()

        if shape == .gunship {
            ctx.setFillColor(dark.cgColor)
            ctx.fill(CGRect(x: -16, y: -10, width: 5, height: 10))
            ctx.fill(CGRect(x: 11, y: -10, width: 5, height: 10))
            ctx.setStrokeColor(accent.withAlphaComponent(0.6).cgColor)
            ctx.setLineWidth(0.8)
            ctx.stroke(CGRect(x: -16, y: -10, width: 5, height: 10))
            ctx.stroke(CGRect(x: 11, y: -10, width: 5, height: 10))
        }
        if shape == .frigate {
            ctx.setFillColor(accent.withAlphaComponent(0.4).cgColor)
            ctx.fill(CGRect(x: -8, y: -5, width: 16, height: 3))
            ctx.setFillColor(dark.withAlphaComponent(0.5).cgColor)
            ctx.fill(CGRect(x: -7, y: 6, width: 14, height: 2))
        }

        if damaged > 0.3 {
            ctx.setStrokeColor(NSColor(srgbRed: 1, green: 0.3, blue: 0.15, alpha: damaged * 0.65).cgColor)
            ctx.setLineWidth(1.1)
            ctx.move(to: CGPoint(x: -4, y: -2))
            ctx.addLine(to: CGPoint(x: 3, y: 4))
            ctx.move(to: CGPoint(x: 5, y: -6))
            ctx.addLine(to: CGPoint(x: -2, y: -10))
            ctx.strokePath()
            // Scorch blotch
            ctx.setFillColor(NSColor(srgbRed: 0.1, green: 0.05, blue: 0.04, alpha: damaged * 0.45).cgColor)
            ctx.fillEllipse(in: CGRect(x: -3, y: -8, width: 7, height: 5))
        }
    }

    private static func drawWings(ctx: CGContext, shape: WingShape, color: NSColor, accent: NSColor) {
        guard shape != .none else { return }
        let dark = color.shaded(by: -0.15)
        let edge = accent.withAlphaComponent(0.85)

        func wing(_ pts: [CGPoint]) {
            guard let first = pts.first else { return }
            let p = CGMutablePath()
            p.move(to: first)
            for pt in pts.dropFirst() { p.addLine(to: pt) }
            p.closeSubpath()
            ctx.setFillColor(dark.cgColor)
            ctx.setStrokeColor(edge.cgColor)
            ctx.setLineWidth(1)
            ctx.addPath(p)
            ctx.drawPath(using: .fillStroke)
            // Leading-edge accent (first edge of polygon)
            if pts.count >= 2 {
                ctx.setStrokeColor(accent.withAlphaComponent(0.7).cgColor)
                ctx.setLineWidth(1.4)
                ctx.move(to: pts[0])
                ctx.addLine(to: pts[1])
                ctx.strokePath()
            }
        }

        switch shape {
        case .delta:
            wing([CGPoint(x: 4, y: 0), CGPoint(x: 22, y: -10), CGPoint(x: 20, y: -14), CGPoint(x: 6, y: -10)])
            wing([CGPoint(x: -4, y: 0), CGPoint(x: -22, y: -10), CGPoint(x: -20, y: -14), CGPoint(x: -6, y: -10)])
        case .swept:
            wing([CGPoint(x: 5, y: 4), CGPoint(x: 24, y: -4), CGPoint(x: 22, y: -10), CGPoint(x: 6, y: -6)])
            wing([CGPoint(x: -5, y: 4), CGPoint(x: -24, y: -4), CGPoint(x: -22, y: -10), CGPoint(x: -6, y: -6)])
        case .canard:
            wing([CGPoint(x: 3, y: 12), CGPoint(x: 12, y: 14), CGPoint(x: 14, y: 8), CGPoint(x: 4, y: 6)])
            wing([CGPoint(x: -3, y: 12), CGPoint(x: -12, y: 14), CGPoint(x: -14, y: 8), CGPoint(x: -4, y: 6)])
            wing([CGPoint(x: 5, y: -2), CGPoint(x: 18, y: -8), CGPoint(x: 16, y: -12), CGPoint(x: 6, y: -8)])
            wing([CGPoint(x: -5, y: -2), CGPoint(x: -18, y: -8), CGPoint(x: -16, y: -12), CGPoint(x: -6, y: -8)])
        case .variable:
            wing([CGPoint(x: 4, y: 2), CGPoint(x: 20, y: 0), CGPoint(x: 26, y: -8), CGPoint(x: 18, y: -12), CGPoint(x: 6, y: -8)])
            wing([CGPoint(x: -4, y: 2), CGPoint(x: -20, y: 0), CGPoint(x: -26, y: -8), CGPoint(x: -18, y: -12), CGPoint(x: -6, y: -8)])
        case .blade:
            ctx.setStrokeColor(accent.cgColor)
            ctx.setLineWidth(2.2)
            ctx.move(to: CGPoint(x: 4, y: 6))
            ctx.addLine(to: CGPoint(x: 20, y: -2))
            ctx.addLine(to: CGPoint(x: 6, y: -8))
            ctx.strokePath()
            ctx.move(to: CGPoint(x: -4, y: 6))
            ctx.addLine(to: CGPoint(x: -20, y: -2))
            ctx.addLine(to: CGPoint(x: -6, y: -8))
            ctx.strokePath()
            // Glow along blades when accent is bright
            ctx.setStrokeColor(accent.withAlphaComponent(0.3).cgColor)
            ctx.setLineWidth(4)
            ctx.move(to: CGPoint(x: 4, y: 6))
            ctx.addLine(to: CGPoint(x: 20, y: -2))
            ctx.strokePath()
            ctx.move(to: CGPoint(x: -4, y: 6))
            ctx.addLine(to: CGPoint(x: -20, y: -2))
            ctx.strokePath()
        case .none:
            break
        }
    }

    private static func drawEngine(ctx: CGContext, shape: EngineShape, color: NSColor, glow: CGFloat) {
        let g = max(0.12, glow)
        let len: CGFloat = 10 + g * 32
        let w: CGFloat = (shape == .warp) ? 10 : (shape == .pulse ? 8 : 6)

        // Additive-ish soft plume base
        ctx.saveGState()
        ctx.setBlendMode(.plusLighter)
        let softColors = [
            color.withAlphaComponent(0.45 * g).cgColor,
            color.withAlphaComponent(0).cgColor,
        ] as CFArray
        if let sg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: softColors, locations: [0, 1]) {
            ctx.drawRadialGradient(sg,
                                   startCenter: CGPoint(x: 0, y: -14), startRadius: 0,
                                   endCenter: CGPoint(x: 0, y: -14 - len * 0.35), endRadius: w * 1.8 + g * 6,
                                   options: [])
        }
        ctx.restoreGState()

        let colors = [
            color.cgColor,
            color.withAlphaComponent(0.65).cgColor,
            color.withAlphaComponent(0).cgColor,
        ] as CFArray
        if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.4, 1]) {
            ctx.saveGState()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -w * 0.5, y: -14))
            path.addLine(to: CGPoint(x: w * 0.5, y: -14))
            path.addLine(to: CGPoint(x: w * (0.2 + g * 0.35), y: -14 - len))
            path.addLine(to: CGPoint(x: -w * (0.2 + g * 0.35), y: -14 - len))
            path.closeSubpath()
            ctx.addPath(path)
            ctx.clip()
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: -14), end: CGPoint(x: 0, y: -14 - len), options: [])
            ctx.restoreGState()
        }

        // Hot core streak when thrusting hard
        if g > 0.4 {
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.35 * g).cgColor)
            ctx.setLineWidth(1.2)
            ctx.move(to: CGPoint(x: 0, y: -14))
            ctx.addLine(to: CGPoint(x: 0, y: -14 - len * 0.7))
            ctx.strokePath()
        }

        if shape == .fusion || shape == .warp || shape == .pulse {
            ctx.setFillColor(color.withAlphaComponent(0.7).cgColor)
            let twin: [(CGFloat, CGFloat)] = [(-10, -6), (6, 10)]
            for (x0, x1) in twin {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x0, y: -12))
                p.addLine(to: CGPoint(x: x1, y: -12))
                p.addLine(to: CGPoint(x: x1 - 1, y: -12 - len * 0.7))
                p.addLine(to: CGPoint(x: x0 + 1, y: -12 - len * 0.7))
                p.closeSubpath()
                ctx.addPath(p)
                ctx.fillPath()
            }
        }

        // Thruster bell rings
        ctx.setFillColor(NSColor(srgbRed: 0.12, green: 0.12, blue: 0.16, alpha: 1).cgColor)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(1.1)
        let nozzle = CGRect(x: -5.5, y: -17, width: 11, height: 5.5)
        ctx.addPath(CGPath(roundedRect: nozzle, cornerWidth: 1.2, cornerHeight: 1.2, transform: nil))
        ctx.drawPath(using: .fillStroke)
        // Inner glow ring
        ctx.setStrokeColor(color.withAlphaComponent(0.55 + 0.35 * g).cgColor)
        ctx.setLineWidth(1)
        ctx.strokeEllipse(in: CGRect(x: -3.5, y: -16.2, width: 7, height: 3.2))
        // Bell lip
        ctx.setStrokeColor(color.shaded(by: 0.2).cgColor)
        ctx.setLineWidth(1.4)
        ctx.move(to: CGPoint(x: -6, y: -12.5))
        ctx.addLine(to: CGPoint(x: 6, y: -12.5))
        ctx.strokePath()
    }
}
