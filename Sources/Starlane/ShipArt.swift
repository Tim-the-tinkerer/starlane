import AppKit
import CoreGraphics

/// Detailed vector starships — drawn in local space with nose pointing +X.
enum ShipArt {
    enum Style {
        case player
        case pirateRaider
        case pirateGunship
        case freighter
        case bulkHauler
        case tanker
        case containerShip
        case oreBarge
        case courier
        case patrol
        case interceptor
        case militiaCutter
        case alienSkimmer
        case alienWarden

        static func from(hullType: HullType) -> Style {
            switch hullType {
            case .pirateRaider: return .pirateRaider
            case .pirateGunship: return .pirateGunship
            case .freighter: return .freighter
            case .bulkHauler: return .bulkHauler
            case .tanker: return .tanker
            case .containerShip: return .containerShip
            case .oreBarge: return .oreBarge
            case .courier: return .courier
            case .patrol: return .patrol
            case .interceptor: return .interceptor
            case .militiaCutter: return .militiaCutter
            case .alienSkimmer: return .alienSkimmer
            case .alienWarden: return .alienWarden
            }
        }

        static func from(faction: Faction) -> Style {
            switch faction {
            case .pirate: return .pirateRaider
            case .trader: return .freighter
            case .police: return .patrol
            case .militia: return .militiaCutter
            case .alien: return .alienSkimmer
            }
        }
    }

    /// Draw a full ship at the current CTM origin, oriented along +X, scaled so hull ≈ `scale` units long.
    static func draw(
        ctx: CGContext, style: Style, scale: CGFloat, accent: NSColor,
        time: Float = 0, paint: ShipPaint = .arctic
    ) {
        ctx.saveGState()
        // Normalize designs are ~28 units long nose-to-tail; scale to requested size.
        let s = scale / 14
        ctx.scaleBy(x: s, y: s)

        switch style {
        case .player: drawPlayer(ctx: ctx, accent: paint.accent, time: time, paint: paint)
        case .pirateRaider: drawPirate(ctx: ctx, accent: accent, time: time)
        case .pirateGunship: drawPirateGunship(ctx: ctx, accent: accent, time: time)
        case .freighter: drawTrader(ctx: ctx, accent: accent, time: time)
        case .bulkHauler: drawBulkHauler(ctx: ctx, accent: accent, time: time)
        case .tanker: drawTanker(ctx: ctx, accent: accent, time: time)
        case .containerShip: drawContainerShip(ctx: ctx, accent: accent, time: time)
        case .oreBarge: drawOreBarge(ctx: ctx, accent: accent, time: time)
        case .courier: drawCourier(ctx: ctx, accent: accent, time: time)
        case .patrol: drawPolice(ctx: ctx, accent: accent, time: time)
        case .interceptor: drawInterceptor(ctx: ctx, accent: accent, time: time)
        case .militiaCutter: drawMilitia(ctx: ctx, accent: accent, time: time)
        case .alienSkimmer: drawAlienSkimmer(ctx: ctx, accent: accent, time: time)
        case .alienWarden: drawAlienWarden(ctx: ctx, accent: accent, time: time)
        }

        ctx.restoreGState()
    }

    // MARK: - Player: industrial heavy fighter (paint-job recolorable)

    private static func drawPlayer(ctx: CGContext, accent: NSColor, time: Float, paint: ShipPaint) {
        // Hull palette from paint job; accent for ID stripe / thruster glow
        let white = paint.highlight
        let hull = paint.hull
        let shadow = paint.shadow
        let panel = paint.panel
        let darkMech = NSColor(calibratedRed: 0.18, green: 0.19, blue: 0.22, alpha: 1)
        let mech = paint.panel.blended(withFraction: 0.35, of: .black) ?? panel
        let canopy = NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.16, alpha: 0.95)
        let canopyGlass = accent.withAlphaComponent(0.45)
        let glow = accent.blended(withFraction: 0.25, of: .white) ?? accent
        let engineCore = accent.blended(withFraction: 0.3, of: NSColor(calibratedRed: 1, green: 0.5, blue: 0.15, alpha: 1))
            ?? NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.2, alpha: 1)
        let pulse = 0.55 + 0.45 * sin(time * 12)
        _ = white // used below for highlights

        // --- Main wing planform (broad diamond / cranked delta, top-down) ---
        fillPath(ctx, color: hull, points: [
            CGPoint(x: 6, y: 0),
            CGPoint(x: 2, y: 5.5),
            CGPoint(x: -3, y: 11.5),
            CGPoint(x: -9, y: 13.2),
            CGPoint(x: -13, y: 11.5),
            CGPoint(x: -11, y: 7),
            CGPoint(x: -8, y: 4),
            CGPoint(x: -8, y: -4),
            CGPoint(x: -11, y: -7),
            CGPoint(x: -13, y: -11.5),
            CGPoint(x: -9, y: -13.2),
            CGPoint(x: -3, y: -11.5),
            CGPoint(x: 2, y: -5.5),
        ])
        // Wing surface highlight (top half slightly lighter)
        fillPath(ctx, color: white.withAlphaComponent(0.35), points: [
            CGPoint(x: 5, y: 0.5),
            CGPoint(x: 1, y: 5),
            CGPoint(x: -4, y: 10.5),
            CGPoint(x: -10, y: 12),
            CGPoint(x: -11, y: 8),
            CGPoint(x: -7, y: 3.5),
            CGPoint(x: -6, y: 0.5),
        ])
        // Wing panel lines
        strokePath(ctx, color: shadow.withAlphaComponent(0.45), width: 0.55, points: [
            CGPoint(x: 3, y: 2), CGPoint(x: -6, y: 9), CGPoint(x: -11, y: 11),
        ])
        strokePath(ctx, color: shadow.withAlphaComponent(0.45), width: 0.55, points: [
            CGPoint(x: 3, y: -2), CGPoint(x: -6, y: -9), CGPoint(x: -11, y: -11),
        ])
        strokePath(ctx, color: shadow.withAlphaComponent(0.35), width: 0.5, points: [
            CGPoint(x: -1, y: 6), CGPoint(x: -8, y: 5),
        ])
        strokePath(ctx, color: shadow.withAlphaComponent(0.35), width: 0.5, points: [
            CGPoint(x: -1, y: -6), CGPoint(x: -8, y: -5),
        ])

        // Outer wing tips / control surfaces
        fillPath(ctx, color: panel, points: [
            CGPoint(x: -9, y: 13.2), CGPoint(x: -14.5, y: 12.5), CGPoint(x: -13, y: 10.5), CGPoint(x: -10, y: 11.5),
        ])
        fillPath(ctx, color: panel, points: [
            CGPoint(x: -9, y: -13.2), CGPoint(x: -14.5, y: -12.5), CGPoint(x: -13, y: -10.5), CGPoint(x: -10, y: -11.5),
        ])
        // Wingtip fins (vertical stabilizers seen top-down as thin blades)
        fillPath(ctx, color: white, points: [
            CGPoint(x: -12.5, y: 12), CGPoint(x: -15.5, y: 13.8), CGPoint(x: -14, y: 11.2),
        ])
        fillPath(ctx, color: white, points: [
            CGPoint(x: -12.5, y: -12), CGPoint(x: -15.5, y: -13.8), CGPoint(x: -14, y: -11.2),
        ])

        // --- Long pointed nose / fuselage ---
        fillPath(ctx, color: white, points: [
            CGPoint(x: 18.5, y: 0),
            CGPoint(x: 12, y: 1.6),
            CGPoint(x: 4, y: 2.6),
            CGPoint(x: -6, y: 2.9),
            CGPoint(x: -12, y: 2.2),
            CGPoint(x: -12, y: -2.2),
            CGPoint(x: -6, y: -2.9),
            CGPoint(x: 4, y: -2.6),
            CGPoint(x: 12, y: -1.6),
        ])
        // Nose needle
        fillPath(ctx, color: hull, points: [
            CGPoint(x: 18.5, y: 0),
            CGPoint(x: 14, y: 0.9),
            CGPoint(x: 14, y: -0.9),
        ])
        // Center spine highlight
        fillPath(ctx, color: white.withAlphaComponent(0.7), points: [
            CGPoint(x: 16, y: 0.25),
            CGPoint(x: 6, y: 0.9),
            CGPoint(x: -8, y: 0.7),
            CGPoint(x: -8, y: 0.15),
            CGPoint(x: 6, y: 0.15),
        ])
        // Fuselage panel seams
        strokePath(ctx, color: shadow.withAlphaComponent(0.4), width: 0.5, points: [
            CGPoint(x: 10, y: 1.4), CGPoint(x: 10, y: -1.4),
        ])
        strokePath(ctx, color: shadow.withAlphaComponent(0.4), width: 0.5, points: [
            CGPoint(x: 3, y: 2.4), CGPoint(x: 3, y: -2.4),
        ])
        strokePath(ctx, color: shadow.withAlphaComponent(0.4), width: 0.5, points: [
            CGPoint(x: -4, y: 2.7), CGPoint(x: -4, y: -2.7),
        ])

        // Chin / sensor under-nose (visible as dark wedge)
        fillPath(ctx, color: darkMech, points: [
            CGPoint(x: 11, y: 0), CGPoint(x: 7, y: 1.1), CGPoint(x: 7, y: -1.1),
        ])

        // --- Cockpit canopy (dark bubble, mid-forward) ---
        fillPath(ctx, color: canopy, points: [
            CGPoint(x: 7.5, y: 0),
            CGPoint(x: 4.5, y: 1.7),
            CGPoint(x: 0.5, y: 1.9),
            CGPoint(x: -1.5, y: 1.2),
            CGPoint(x: -1.5, y: -1.2),
            CGPoint(x: 0.5, y: -1.9),
            CGPoint(x: 4.5, y: -1.7),
        ])
        fillPath(ctx, color: canopyGlass, points: [
            CGPoint(x: 6.5, y: 0.2),
            CGPoint(x: 4, y: 1.2),
            CGPoint(x: 1, y: 1.3),
            CGPoint(x: 1, y: 0.3),
            CGPoint(x: 4, y: 0.3),
        ])
        strokePath(ctx, color: .white.withAlphaComponent(0.35), width: 0.55, points: [
            CGPoint(x: 7.5, y: 0), CGPoint(x: 4.5, y: 1.7), CGPoint(x: 0.5, y: 1.9),
        ])

        // --- Shoulder intakes / mechanical wing roots ---
        fillPath(ctx, color: mech, points: [
            CGPoint(x: 1, y: 3.5), CGPoint(x: -5, y: 6.5), CGPoint(x: -7, y: 5), CGPoint(x: -4, y: 2.8),
        ])
        fillPath(ctx, color: mech, points: [
            CGPoint(x: 1, y: -3.5), CGPoint(x: -5, y: -6.5), CGPoint(x: -7, y: -5), CGPoint(x: -4, y: -2.8),
        ])
        // Intake lips
        fillPath(ctx, color: darkMech, points: [
            CGPoint(x: -0.5, y: 4.2), CGPoint(x: -3.5, y: 5.8), CGPoint(x: -4, y: 4.8), CGPoint(x: -1.5, y: 3.6),
        ])
        fillPath(ctx, color: darkMech, points: [
            CGPoint(x: -0.5, y: -4.2), CGPoint(x: -3.5, y: -5.8), CGPoint(x: -4, y: -4.8), CGPoint(x: -1.5, y: -3.6),
        ])
        // Red status lights (like reference)
        ctx.setFillColor(NSColor(calibratedRed: 0.9, green: 0.25, blue: 0.15, alpha: 0.9).cgColor)
        ctx.fillEllipse(in: CGRect(x: -5.2, y: 4.6, width: 1.2, height: 1.2))
        ctx.fillEllipse(in: CGRect(x: -5.2, y: -5.8, width: 1.2, height: 1.2))

        // --- Rear multi-engine cluster (4 nozzles + center bay) ---
        // Engine nacelle housings
        fillPath(ctx, color: panel, points: [
            CGPoint(x: -8, y: 5.5), CGPoint(x: -15.5, y: 6.2), CGPoint(x: -16.5, y: 3.8),
            CGPoint(x: -16.5, y: 1.2), CGPoint(x: -12, y: 1.0), CGPoint(x: -8, y: 2.2),
        ])
        fillPath(ctx, color: panel, points: [
            CGPoint(x: -8, y: -5.5), CGPoint(x: -15.5, y: -6.2), CGPoint(x: -16.5, y: -3.8),
            CGPoint(x: -16.5, y: -1.2), CGPoint(x: -12, y: -1.0), CGPoint(x: -8, y: -2.2),
        ])
        // Center engine block
        fillPath(ctx, color: shadow, points: [
            CGPoint(x: -10, y: 2.4), CGPoint(x: -16.2, y: 2.6), CGPoint(x: -16.2, y: -2.6), CGPoint(x: -10, y: -2.4),
        ])
        fillPath(ctx, color: darkMech, points: [
            CGPoint(x: -12, y: 1.6), CGPoint(x: -15.8, y: 1.7), CGPoint(x: -15.8, y: -1.7), CGPoint(x: -12, y: -1.6),
        ])

        // Four thruster bells (outboard pair + inboard pair)
        let thrusters: [(CGFloat, CGFloat, CGFloat)] = [
            (-16.8, 4.2, 2.4),
            (-16.8, 1.6, 2.1),
            (-16.8, -3.7, 2.1),
            (-16.8, -6.3, 2.4),
        ]
        for (x, y, s) in thrusters {
            ctx.setFillColor(darkMech.cgColor)
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: s, height: s))
            ctx.setFillColor(engineCore.withAlphaComponent(CGFloat(pulse)).cgColor)
            ctx.fillEllipse(in: CGRect(x: x + 0.35, y: y + 0.35, width: s * 0.65, height: s * 0.65))
            ctx.setFillColor(NSColor.white.withAlphaComponent(CGFloat(0.45 * pulse)).cgColor)
            ctx.fillEllipse(in: CGRect(x: x + 0.7, y: y + 0.7, width: s * 0.3, height: s * 0.3))
        }
        // Center exhaust glow
        ctx.setFillColor(glow.withAlphaComponent(CGFloat(0.5 * pulse)).cgColor)
        ctx.fillEllipse(in: CGRect(x: -17.2, y: -1.1, width: 2.4, height: 2.2))

        // Accent ID stripe (player color) along spine
        fillPath(ctx, color: accent.withAlphaComponent(0.55), points: [
            CGPoint(x: 5, y: 0.35), CGPoint(x: -9, y: 0.35), CGPoint(x: -9, y: -0.35), CGPoint(x: 5, y: -0.35),
        ])

        // Outer silhouette stroke
        strokePath(ctx, color: .white.withAlphaComponent(0.5), width: 0.75, closed: true, points: [
            CGPoint(x: 18.5, y: 0),
            CGPoint(x: 12, y: 1.6),
            CGPoint(x: 6, y: 0),
            CGPoint(x: 2, y: 5.5),
            CGPoint(x: -3, y: 11.5),
            CGPoint(x: -9, y: 13.2),
            CGPoint(x: -14.5, y: 12.5),
            CGPoint(x: -15.5, y: 6.2),
            CGPoint(x: -16.5, y: 3.8),
            CGPoint(x: -16.5, y: -3.8),
            CGPoint(x: -15.5, y: -6.2),
            CGPoint(x: -14.5, y: -12.5),
            CGPoint(x: -9, y: -13.2),
            CGPoint(x: -3, y: -11.5),
            CGPoint(x: 2, y: -5.5),
            CGPoint(x: 6, y: 0),
            CGPoint(x: 12, y: -1.6),
        ])
    }

    // MARK: - Pirate: jagged raider

    private static func drawPirate(ctx: CGContext, accent: NSColor, time: Float) {
        let hull = accent
        let dark = accent.blended(withFraction: 0.5, of: .black) ?? accent
        let rust = NSColor(calibratedRed: 0.45, green: 0.22, blue: 0.18, alpha: 1)
        let metal = NSColor(calibratedRed: 0.35, green: 0.32, blue: 0.32, alpha: 1)
        let engine = NSColor(calibratedRed: 1.0, green: 0.2, blue: 0.15, alpha: 1)
        let canopy = NSColor(calibratedRed: 0.9, green: 0.25, blue: 0.2, alpha: 0.7)

        // Asymmetric swept wing (upper larger)
        fillPath(ctx, color: dark, points: [
            CGPoint(x: 2, y: 1),
            CGPoint(x: -4, y: 13),
            CGPoint(x: -12, y: 14),
            CGPoint(x: -9, y: 7),
            CGPoint(x: -6, y: 2),
        ])
        fillPath(ctx, color: dark, points: [
            CGPoint(x: 2, y: -1),
            CGPoint(x: -6, y: -9),
            CGPoint(x: -11, y: -10),
            CGPoint(x: -8, y: -4),
            CGPoint(x: -5, y: -1),
        ])

        // Spikes / blades
        fillPath(ctx, color: metal, points: [
            CGPoint(x: -4, y: 13), CGPoint(x: -2, y: 16), CGPoint(x: -7, y: 13.5),
        ])
        fillPath(ctx, color: metal, points: [
            CGPoint(x: -6, y: -9), CGPoint(x: -5, y: -13), CGPoint(x: -9, y: -10),
        ])
        fillPath(ctx, color: rust, points: [
            CGPoint(x: 8, y: 2.5), CGPoint(x: 12, y: 4), CGPoint(x: 9, y: 1),
        ])

        // Fuselage (blocky, damaged look)
        fillPath(ctx, color: hull, points: [
            CGPoint(x: 14, y: 0),
            CGPoint(x: 8, y: 3.5),
            CGPoint(x: -2, y: 4),
            CGPoint(x: -12, y: 3),
            CGPoint(x: -13, y: 0),
            CGPoint(x: -12, y: -3),
            CGPoint(x: -2, y: -3.5),
            CGPoint(x: 8, y: -3),
        ])
        // Armor plating lines
        strokePath(ctx, color: .black.withAlphaComponent(0.35), width: 0.6, points: [
            CGPoint(x: 6, y: 3), CGPoint(x: 6, y: -2.8),
        ])
        strokePath(ctx, color: .black.withAlphaComponent(0.35), width: 0.6, points: [
            CGPoint(x: 0, y: 3.6), CGPoint(x: 0, y: -3.2),
        ])

        // Cockpit (slit)
        fillPath(ctx, color: canopy, points: [
            CGPoint(x: 7, y: 1.5), CGPoint(x: 3, y: 2.2), CGPoint(x: 3, y: -2), CGPoint(x: 7, y: -1.2),
        ])

        // Single hot engine + offset thruster
        let pulse = 0.6 + 0.4 * sin(time * 16)
        fillPath(ctx, color: metal, points: [
            CGPoint(x: -12, y: 2.5), CGPoint(x: -16, y: 3.5), CGPoint(x: -16, y: -1), CGPoint(x: -12, y: -2),
        ])
        ctx.setFillColor(engine.withAlphaComponent(CGFloat(pulse)).cgColor)
        ctx.fillEllipse(in: CGRect(x: -17.5, y: -0.2, width: 3.5, height: 3.2))
        ctx.setFillColor(NSColor(calibratedRed: 1, green: 0.7, blue: 0.3, alpha: CGFloat(0.5 * pulse)).cgColor)
        ctx.fillEllipse(in: CGRect(x: -16.8, y: 0.5, width: 1.6, height: 1.4))

        // Skull-mark stripe
        strokePath(ctx, color: .black.withAlphaComponent(0.5), width: 1.2, points: [
            CGPoint(x: -4, y: 0), CGPoint(x: 10, y: 0),
        ])
    }

    // MARK: - Trader: bulk freighter

    private static func drawTrader(ctx: CGContext, accent: NSColor, time: Float) {
        let hull = accent
        let dark = accent.blended(withFraction: 0.4, of: .black) ?? accent
        let metal = NSColor(calibratedRed: 0.5, green: 0.55, blue: 0.5, alpha: 1)
        let metalDark = NSColor(calibratedRed: 0.3, green: 0.33, blue: 0.3, alpha: 1)
        let cargo = NSColor(calibratedRed: 0.4, green: 0.45, blue: 0.38, alpha: 1)
        let canopy = NSColor(calibratedRed: 0.5, green: 0.9, blue: 0.7, alpha: 0.8)
        let engine = NSColor(calibratedRed: 0.4, green: 0.85, blue: 1.0, alpha: 1)

        // Cargo containers (port / starboard)
        fillPath(ctx, color: cargo, points: [
            CGPoint(x: 2, y: 4), CGPoint(x: -8, y: 5.5), CGPoint(x: -10, y: 3), CGPoint(x: 0, y: 2),
        ])
        fillPath(ctx, color: cargo, points: [
            CGPoint(x: 2, y: -4), CGPoint(x: -8, y: -5.5), CGPoint(x: -10, y: -3), CGPoint(x: 0, y: -2),
        ])
        // Container seams
        for x: CGFloat in [-2, -5] {
            strokePath(ctx, color: .black.withAlphaComponent(0.3), width: 0.5, points: [
                CGPoint(x: x, y: 4.5), CGPoint(x: x - 1, y: 3.2),
            ])
            strokePath(ctx, color: .black.withAlphaComponent(0.3), width: 0.5, points: [
                CGPoint(x: x, y: -4.5), CGPoint(x: x - 1, y: -3.2),
            ])
        }

        // Wide freighter body
        fillPath(ctx, color: hull, points: [
            CGPoint(x: 12, y: 0),
            CGPoint(x: 8, y: 3.5),
            CGPoint(x: -4, y: 4.5),
            CGPoint(x: -14, y: 3.5),
            CGPoint(x: -14, y: -3.5),
            CGPoint(x: -4, y: -4.5),
            CGPoint(x: 8, y: -3.5),
        ])
        // Bridge superstructure
        fillPath(ctx, color: dark, points: [
            CGPoint(x: 6, y: 2), CGPoint(x: 0, y: 3), CGPoint(x: -2, y: 2),
            CGPoint(x: -2, y: -2), CGPoint(x: 0, y: -3), CGPoint(x: 6, y: -2),
        ])
        fillPath(ctx, color: canopy, points: [
            CGPoint(x: 5, y: 1.2), CGPoint(x: 1, y: 1.8), CGPoint(x: 1, y: -1.8), CGPoint(x: 5, y: -1.2),
        ])

        // Nose
        fillPath(ctx, color: metal, points: [
            CGPoint(x: 12, y: 0), CGPoint(x: 9, y: 2), CGPoint(x: 9, y: -2),
        ])

        // Rear engine block
        fillPath(ctx, color: metalDark, points: [
            CGPoint(x: -12, y: 3), CGPoint(x: -17, y: 3.5), CGPoint(x: -17, y: -3.5), CGPoint(x: -12, y: -3),
        ])
        let pulse = 0.55 + 0.35 * sin(time * 10)
        ctx.setFillColor(engine.withAlphaComponent(CGFloat(pulse)).cgColor)
        ctx.fillEllipse(in: CGRect(x: -18.2, y: 1.2, width: 2.8, height: 2.2))
        ctx.fillEllipse(in: CGRect(x: -18.2, y: -3.4, width: 2.8, height: 2.2))
        ctx.fillEllipse(in: CGRect(x: -18.2, y: -1.1, width: 2.8, height: 2.2))

        // Hull outline
        strokePath(ctx, color: .white.withAlphaComponent(0.3), width: 0.7, closed: true, points: [
            CGPoint(x: 12, y: 0), CGPoint(x: 8, y: 3.5), CGPoint(x: -4, y: 4.5),
            CGPoint(x: -14, y: 3.5), CGPoint(x: -17, y: 3.5), CGPoint(x: -17, y: -3.5),
            CGPoint(x: -14, y: -3.5), CGPoint(x: -4, y: -4.5), CGPoint(x: 8, y: -3.5),
        ])
    }

    // MARK: - Bulk hauler: huge box freighter

    private static func drawBulkHauler(ctx: CGContext, accent: NSColor, time: Float) {
        let hull = accent
        let dark = accent.blended(withFraction: 0.45, of: .black) ?? accent
        let plate = NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.40, alpha: 1)
        let metal = NSColor(calibratedRed: 0.35, green: 0.38, blue: 0.36, alpha: 1)
        let engine = NSColor(calibratedRed: 0.45, green: 0.9, blue: 1.0, alpha: 1)

        // Massive cargo block
        fillPath(ctx, color: plate, points: [
            CGPoint(x: 6, y: 6), CGPoint(x: -12, y: 7), CGPoint(x: -14, y: 5),
            CGPoint(x: -14, y: -5), CGPoint(x: -12, y: -7), CGPoint(x: 6, y: -6),
        ])
        // Grid of cargo bays
        for row: CGFloat in [-4, -1.2, 1.6] {
            for col: CGFloat in [-10, -6, -2, 2] {
                ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.35).cgColor)
                ctx.setLineWidth(0.6)
                ctx.stroke(CGRect(x: col, y: row, width: 3.2, height: 2.2))
            }
        }
        // Bridge tower (aft-offset)
        fillPath(ctx, color: dark, points: [
            CGPoint(x: -2, y: 3), CGPoint(x: -8, y: 4), CGPoint(x: -9, y: 2),
            CGPoint(x: -9, y: -2), CGPoint(x: -8, y: -4), CGPoint(x: -2, y: -3),
        ])
        fillPath(ctx, color: NSColor(calibratedRed: 0.4, green: 0.85, blue: 0.7, alpha: 0.75), points: [
            CGPoint(x: -3, y: 1.5), CGPoint(x: -7, y: 2), CGPoint(x: -7, y: -2), CGPoint(x: -3, y: -1.5),
        ])
        // Blunt bow
        fillPath(ctx, color: hull, points: [
            CGPoint(x: 14, y: 0), CGPoint(x: 8, y: 4), CGPoint(x: 6, y: 5.5),
            CGPoint(x: 6, y: -5.5), CGPoint(x: 8, y: -4),
        ])
        // Engines
        fillPath(ctx, color: metal, points: [
            CGPoint(x: -12, y: 4.5), CGPoint(x: -18, y: 5), CGPoint(x: -18, y: -5), CGPoint(x: -12, y: -4.5),
        ])
        let pulse = 0.5 + 0.4 * sin(time * 9)
        ctx.setFillColor(engine.withAlphaComponent(CGFloat(pulse)).cgColor)
        for y: CGFloat in [-3.5, -1.1, 1.3, 3.5] {
            ctx.fillEllipse(in: CGRect(x: -19, y: y, width: 2.6, height: 1.8))
        }
    }

    // MARK: - Tanker: long cylindrical tanks

    private static func drawTanker(ctx: CGContext, accent: NSColor, time: Float) {
        let hull = accent.blended(withFraction: 0.15, of: .white) ?? accent
        let dark = accent.blended(withFraction: 0.4, of: .black) ?? accent
        let tank = NSColor(calibratedRed: 0.55, green: 0.58, blue: 0.52, alpha: 1)
        let hazard = NSColor(calibratedRed: 0.95, green: 0.75, blue: 0.15, alpha: 1)
        let engine = NSColor(calibratedRed: 0.35, green: 0.8, blue: 1.0, alpha: 1)

        // Long spine
        fillPath(ctx, color: hull, points: [
            CGPoint(x: 16, y: 0), CGPoint(x: 10, y: 2), CGPoint(x: -12, y: 2.2),
            CGPoint(x: -12, y: -2.2), CGPoint(x: 10, y: -2),
        ])
        // Cylindrical tank lobes
        for (cx, cy) in [(CGFloat(-2), CGFloat(3.8)), (-6, 3.8), (-2, -5.5), (-6, -5.5)] as [(CGFloat, CGFloat)] {
            ctx.setFillColor(tank.cgColor)
            ctx.fillEllipse(in: CGRect(x: cx, y: cy, width: 7, height: 3.8))
            ctx.setStrokeColor(hazard.withAlphaComponent(0.7).cgColor)
            ctx.setLineWidth(0.7)
            ctx.strokeEllipse(in: CGRect(x: cx, y: cy, width: 7, height: 3.8))
        }
        // Bridge
        fillPath(ctx, color: dark, points: [
            CGPoint(x: 8, y: 1.8), CGPoint(x: 3, y: 2.4), CGPoint(x: 3, y: -2.4), CGPoint(x: 8, y: -1.8),
        ])
        fillPath(ctx, color: NSColor(calibratedRed: 0.3, green: 0.7, blue: 0.9, alpha: 0.7), points: [
            CGPoint(x: 7, y: 1), CGPoint(x: 4, y: 1.4), CGPoint(x: 4, y: -1.4), CGPoint(x: 7, y: -1),
        ])
        // Hazard stripe
        fillPath(ctx, color: hazard, points: [
            CGPoint(x: 1, y: 2), CGPoint(x: -1, y: 2), CGPoint(x: -1, y: -2), CGPoint(x: 1, y: -2),
        ])
        // Engines
        fillPath(ctx, color: dark, points: [
            CGPoint(x: -11, y: 2.5), CGPoint(x: -16.5, y: 3), CGPoint(x: -16.5, y: -3), CGPoint(x: -11, y: -2.5),
        ])
        let pulse = 0.55 + 0.35 * sin(time * 11)
        ctx.setFillColor(engine.withAlphaComponent(CGFloat(pulse)).cgColor)
        ctx.fillEllipse(in: CGRect(x: -17.5, y: 0.8, width: 2.4, height: 1.8))
        ctx.fillEllipse(in: CGRect(x: -17.5, y: -2.6, width: 2.4, height: 1.8))
    }

    // MARK: - Container ship: stacked boxes

    private static func drawContainerShip(ctx: CGContext, accent: NSColor, time: Float) {
        let hull = accent
        let dark = accent.blended(withFraction: 0.4, of: .black) ?? accent
        let colors: [NSColor] = [
            NSColor(calibratedRed: 0.85, green: 0.35, blue: 0.2, alpha: 1),
            NSColor(calibratedRed: 0.25, green: 0.45, blue: 0.85, alpha: 1),
            NSColor(calibratedRed: 0.9, green: 0.75, blue: 0.2, alpha: 1),
            NSColor(calibratedRed: 0.3, green: 0.7, blue: 0.4, alpha: 1),
            NSColor(calibratedRed: 0.6, green: 0.35, blue: 0.75, alpha: 1),
        ]
        // Deck
        fillPath(ctx, color: dark, points: [
            CGPoint(x: 12, y: 0), CGPoint(x: 8, y: 3), CGPoint(x: -12, y: 3.5),
            CGPoint(x: -14, y: 2), CGPoint(x: -14, y: -2), CGPoint(x: -12, y: -3.5),
            CGPoint(x: 8, y: -3),
        ])
        // Container stacks
        var ci = 0
        for row: CGFloat in [1.2, -3.0] {
            for col: CGFloat in [-10, -6.5, -3, 0.5, 4] {
                let c = colors[ci % colors.count]
                ci += 1
                ctx.setFillColor(c.cgColor)
                ctx.fill(CGRect(x: col, y: row, width: 3.0, height: 2.0))
                ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.3).cgColor)
                ctx.setLineWidth(0.4)
                ctx.stroke(CGRect(x: col, y: row, width: 3.0, height: 2.0))
            }
        }
        // Bridge house
        fillPath(ctx, color: hull, points: [
            CGPoint(x: -6, y: 3.2), CGPoint(x: -11, y: 4), CGPoint(x: -12, y: 2),
            CGPoint(x: -12, y: -2), CGPoint(x: -11, y: -4), CGPoint(x: -6, y: -3.2),
        ])
        fillPath(ctx, color: NSColor(calibratedRed: 0.5, green: 0.9, blue: 1.0, alpha: 0.7), points: [
            CGPoint(x: -7, y: 1.5), CGPoint(x: -10.5, y: 2), CGPoint(x: -10.5, y: -2), CGPoint(x: -7, y: -1.5),
        ])
        // Bow
        fillPath(ctx, color: hull, points: [
            CGPoint(x: 14, y: 0), CGPoint(x: 10, y: 2.5), CGPoint(x: 8, y: 2.8),
            CGPoint(x: 8, y: -2.8), CGPoint(x: 10, y: -2.5),
        ])
        let pulse = 0.55 + 0.35 * sin(time * 10)
        ctx.setFillColor(NSColor(calibratedRed: 0.4, green: 0.85, blue: 1, alpha: CGFloat(pulse)).cgColor)
        ctx.fillEllipse(in: CGRect(x: -16, y: 0.5, width: 2.5, height: 1.8))
        ctx.fillEllipse(in: CGRect(x: -16, y: -2.3, width: 2.5, height: 1.8))
        fillPath(ctx, color: dark, points: [
            CGPoint(x: -12, y: 2.5), CGPoint(x: -15.5, y: 3), CGPoint(x: -15.5, y: -3), CGPoint(x: -12, y: -2.5),
        ])
    }

    // MARK: - Ore barge: industrial tug + hopper

    private static func drawOreBarge(ctx: CGContext, accent: NSColor, time: Float) {
        let rust = NSColor(calibratedRed: 0.55, green: 0.38, blue: 0.28, alpha: 1)
        let dark = NSColor(calibratedRed: 0.3, green: 0.28, blue: 0.26, alpha: 1)
        let ore = NSColor(calibratedRed: 0.45, green: 0.4, blue: 0.35, alpha: 1)
        let engine = NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.2, alpha: 1)

        // Hopper body
        fillPath(ctx, color: rust, points: [
            CGPoint(x: 4, y: 5), CGPoint(x: -10, y: 6.5), CGPoint(x: -12, y: 4),
            CGPoint(x: -12, y: -4), CGPoint(x: -10, y: -6.5), CGPoint(x: 4, y: -5),
        ])
        // Ore pile
        fillPath(ctx, color: ore, points: [
            CGPoint(x: 0, y: 3), CGPoint(x: -8, y: 4), CGPoint(x: -9, y: 0),
            CGPoint(x: -8, y: -4), CGPoint(x: 0, y: -3), CGPoint(x: 1, y: 0),
        ])
        // Tug / drive section
        fillPath(ctx, color: dark, points: [
            CGPoint(x: 12, y: 0), CGPoint(x: 6, y: 3), CGPoint(x: 4, y: 4),
            CGPoint(x: 4, y: -4), CGPoint(x: 6, y: -3),
        ])
        fillPath(ctx, color: accent.withAlphaComponent(0.6), points: [
            CGPoint(x: 9, y: 1.2), CGPoint(x: 6, y: 1.6), CGPoint(x: 6, y: -1.6), CGPoint(x: 9, y: -1.2),
        ])
        // Cranes
        strokePath(ctx, color: dark, width: 1.2, points: [
            CGPoint(x: -2, y: 5), CGPoint(x: -2, y: 9), CGPoint(x: 2, y: 8),
        ])
        strokePath(ctx, color: dark, width: 1.2, points: [
            CGPoint(x: -5, y: -5), CGPoint(x: -5, y: -9), CGPoint(x: -1, y: -8),
        ])
        fillPath(ctx, color: dark, points: [
            CGPoint(x: -10, y: 3), CGPoint(x: -16, y: 3.5), CGPoint(x: -16, y: -3.5), CGPoint(x: -10, y: -3),
        ])
        let pulse = 0.5 + 0.4 * sin(time * 8)
        ctx.setFillColor(engine.withAlphaComponent(CGFloat(pulse)).cgColor)
        ctx.fillEllipse(in: CGRect(x: -17.2, y: 0.6, width: 2.6, height: 2))
        ctx.fillEllipse(in: CGRect(x: -17.2, y: -2.6, width: 2.6, height: 2))
    }

    // MARK: - Courier: small fast mail runner

    private static func drawCourier(ctx: CGContext, accent: NSColor, time: Float) {
        let hull = accent.blended(withFraction: 0.2, of: .white) ?? accent
        let dark = accent.blended(withFraction: 0.4, of: .black) ?? accent
        let stripe = Theme.gold
        let canopy = NSColor(calibratedRed: 0.4, green: 0.9, blue: 1.0, alpha: 0.85)
        let engine = NSColor(calibratedRed: 0.5, green: 0.95, blue: 1.0, alpha: 1)

        // Slim wings
        fillPath(ctx, color: dark, points: [
            CGPoint(x: 2, y: 1), CGPoint(x: -4, y: 7), CGPoint(x: -10, y: 6), CGPoint(x: -6, y: 1.5),
        ])
        fillPath(ctx, color: dark, points: [
            CGPoint(x: 2, y: -1), CGPoint(x: -4, y: -7), CGPoint(x: -10, y: -6), CGPoint(x: -6, y: -1.5),
        ])
        // Fast hull
        fillPath(ctx, color: hull, points: [
            CGPoint(x: 16, y: 0), CGPoint(x: 10, y: 1.8), CGPoint(x: -4, y: 2),
            CGPoint(x: -12, y: 1.4), CGPoint(x: -12, y: -1.4), CGPoint(x: -4, y: -2), CGPoint(x: 10, y: -1.8),
        ])
        fillPath(ctx, color: stripe, points: [
            CGPoint(x: 8, y: 0.4), CGPoint(x: -8, y: 0.4), CGPoint(x: -8, y: -0.4), CGPoint(x: 8, y: -0.4),
        ])
        fillPath(ctx, color: canopy, points: [
            CGPoint(x: 8, y: 0), CGPoint(x: 4, y: 1.2), CGPoint(x: 1, y: 1), CGPoint(x: 1, y: -1), CGPoint(x: 4, y: -1.2),
        ])
        fillPath(ctx, color: dark, points: [
            CGPoint(x: -10, y: 1.5), CGPoint(x: -15, y: 2), CGPoint(x: -15, y: -2), CGPoint(x: -10, y: -1.5),
        ])
        let pulse = 0.6 + 0.4 * sin(time * 16)
        ctx.setFillColor(engine.withAlphaComponent(CGFloat(pulse)).cgColor)
        ctx.fillEllipse(in: CGRect(x: -16.2, y: -1.2, width: 2.8, height: 2.4))
    }

    // MARK: - Pirate gunship: heavier raider

    private static func drawPirateGunship(ctx: CGContext, accent: NSColor, time: Float) {
        let hull = accent
        let dark = accent.blended(withFraction: 0.5, of: .black) ?? accent
        let metal = NSColor(calibratedRed: 0.3, green: 0.28, blue: 0.28, alpha: 1)
        let engine = NSColor(calibratedRed: 1.0, green: 0.25, blue: 0.1, alpha: 1)

        fillPath(ctx, color: dark, points: [
            CGPoint(x: 2, y: 2), CGPoint(x: -4, y: 12), CGPoint(x: -12, y: 13),
            CGPoint(x: -10, y: 6), CGPoint(x: -6, y: 3),
        ])
        fillPath(ctx, color: dark, points: [
            CGPoint(x: 2, y: -2), CGPoint(x: -4, y: -12), CGPoint(x: -12, y: -13),
            CGPoint(x: -10, y: -6), CGPoint(x: -6, y: -3),
        ])
        fillPath(ctx, color: hull, points: [
            CGPoint(x: 15, y: 0), CGPoint(x: 8, y: 4), CGPoint(x: -4, y: 4.5),
            CGPoint(x: -13, y: 3), CGPoint(x: -14, y: 0), CGPoint(x: -13, y: -3),
            CGPoint(x: -4, y: -4.5), CGPoint(x: 8, y: -4),
        ])
        // Twin guns
        fillPath(ctx, color: metal, points: [
            CGPoint(x: 10, y: 2.5), CGPoint(x: 16, y: 3), CGPoint(x: 16, y: 2), CGPoint(x: 10, y: 1.5),
        ])
        fillPath(ctx, color: metal, points: [
            CGPoint(x: 10, y: -2.5), CGPoint(x: 16, y: -3), CGPoint(x: 16, y: -2), CGPoint(x: 10, y: -1.5),
        ])
        fillPath(ctx, color: metal, points: [
            CGPoint(x: -11, y: 3), CGPoint(x: -17, y: 4), CGPoint(x: -17, y: -4), CGPoint(x: -11, y: -3),
        ])
        let pulse = 0.55 + 0.45 * sin(time * 14)
        ctx.setFillColor(engine.withAlphaComponent(CGFloat(pulse)).cgColor)
        ctx.fillEllipse(in: CGRect(x: -18.5, y: 1, width: 3, height: 2.5))
        ctx.fillEllipse(in: CGRect(x: -18.5, y: -3.5, width: 3, height: 2.5))
    }

    // MARK: - Police interceptor: faster needle

    private static func drawInterceptor(ctx: CGContext, accent: NSColor, time: Float) {
        let hull = accent
        let dark = accent.blended(withFraction: 0.35, of: .black) ?? accent
        let white = NSColor.white.withAlphaComponent(0.9)
        let canopy = NSColor(calibratedRed: 0.5, green: 0.8, blue: 1.0, alpha: 0.9)
        let engine = NSColor(calibratedRed: 0.6, green: 0.85, blue: 1.0, alpha: 1)

        fillPath(ctx, color: dark, points: [
            CGPoint(x: 0, y: 0.8), CGPoint(x: -8, y: 8), CGPoint(x: -13, y: 6.5), CGPoint(x: -6, y: 1),
        ])
        fillPath(ctx, color: dark, points: [
            CGPoint(x: 0, y: -0.8), CGPoint(x: -8, y: -8), CGPoint(x: -13, y: -6.5), CGPoint(x: -6, y: -1),
        ])
        fillPath(ctx, color: hull, points: [
            CGPoint(x: 18, y: 0), CGPoint(x: 10, y: 1.6), CGPoint(x: -8, y: 1.8),
            CGPoint(x: -14, y: 1.2), CGPoint(x: -14, y: -1.2), CGPoint(x: -8, y: -1.8), CGPoint(x: 10, y: -1.6),
        ])
        fillPath(ctx, color: white, points: [
            CGPoint(x: 12, y: 0.35), CGPoint(x: -10, y: 0.35), CGPoint(x: -10, y: -0.35), CGPoint(x: 12, y: -0.35),
        ])
        fillPath(ctx, color: canopy, points: [
            CGPoint(x: 9, y: 0), CGPoint(x: 5, y: 1.1), CGPoint(x: 2, y: 0.9), CGPoint(x: 2, y: -0.9), CGPoint(x: 5, y: -1.1),
        ])
        let pulse = 0.6 + 0.4 * sin(time * 18)
        ctx.setFillColor(engine.withAlphaComponent(CGFloat(pulse)).cgColor)
        ctx.fillEllipse(in: CGRect(x: -16, y: -1.1, width: 2.6, height: 2.2))
        fillPath(ctx, color: dark, points: [
            CGPoint(x: -12, y: 1.4), CGPoint(x: -15.5, y: 1.8), CGPoint(x: -15.5, y: -1.8), CGPoint(x: -12, y: -1.4),
        ])
    }

    // MARK: - Police: clean interceptor

    private static func drawPolice(ctx: CGContext, accent: NSColor, time: Float) {
        let hull = accent
        let dark = accent.blended(withFraction: 0.4, of: .black) ?? accent
        let white = NSColor(calibratedWhite: 0.92, alpha: 1)
        let canopy = NSColor(calibratedRed: 0.4, green: 0.7, blue: 1.0, alpha: 0.9)
        let engine = NSColor(calibratedRed: 0.5, green: 0.75, blue: 1.0, alpha: 1)
        let stripe = NSColor(calibratedRed: 1.0, green: 0.9, blue: 0.2, alpha: 1)

        // Slim wings
        fillPath(ctx, color: dark, points: [
            CGPoint(x: 0, y: 1),
            CGPoint(x: -6, y: 9),
            CGPoint(x: -12, y: 8),
            CGPoint(x: -7, y: 2),
        ])
        fillPath(ctx, color: dark, points: [
            CGPoint(x: 0, y: -1),
            CGPoint(x: -6, y: -9),
            CGPoint(x: -12, y: -8),
            CGPoint(x: -7, y: -2),
        ])
        // White wing tips (patrol markings)
        fillPath(ctx, color: white, points: [
            CGPoint(x: -9, y: 8.2), CGPoint(x: -12, y: 8), CGPoint(x: -10, y: 6),
        ])
        fillPath(ctx, color: white, points: [
            CGPoint(x: -9, y: -8.2), CGPoint(x: -12, y: -8), CGPoint(x: -10, y: -6),
        ])

        // Needle fuselage
        fillPath(ctx, color: hull, points: [
            CGPoint(x: 17, y: 0),
            CGPoint(x: 10, y: 2.2),
            CGPoint(x: -6, y: 2.5),
            CGPoint(x: -13, y: 1.8),
            CGPoint(x: -13, y: -1.8),
            CGPoint(x: -6, y: -2.5),
            CGPoint(x: 10, y: -2.2),
        ])
        // Center white stripe
        fillPath(ctx, color: white.withAlphaComponent(0.85), points: [
            CGPoint(x: 14, y: 0.5), CGPoint(x: -10, y: 0.5), CGPoint(x: -10, y: -0.5), CGPoint(x: 14, y: -0.5),
        ])
        // Yellow ID band
        fillPath(ctx, color: stripe, points: [
            CGPoint(x: 2, y: 2.2), CGPoint(x: -1, y: 2.3), CGPoint(x: -1, y: -2.3), CGPoint(x: 2, y: -2.2),
        ])

        // Canopy
        fillPath(ctx, color: canopy, points: [
            CGPoint(x: 9, y: 0), CGPoint(x: 5, y: 1.5), CGPoint(x: 1, y: 1.3),
            CGPoint(x: 1, y: -1.3), CGPoint(x: 5, y: -1.5),
        ])

        // Twin rear engines
        fillPath(ctx, color: dark, points: [
            CGPoint(x: -11, y: 2), CGPoint(x: -15.5, y: 2.8), CGPoint(x: -15.5, y: 0.5), CGPoint(x: -11, y: 0.3),
        ])
        fillPath(ctx, color: dark, points: [
            CGPoint(x: -11, y: -2), CGPoint(x: -15.5, y: -2.8), CGPoint(x: -15.5, y: -0.5), CGPoint(x: -11, y: -0.3),
        ])
        let pulse = 0.6 + 0.35 * sin(time * 15)
        ctx.setFillColor(engine.withAlphaComponent(CGFloat(pulse)).cgColor)
        ctx.fillEllipse(in: CGRect(x: -16.8, y: 0.8, width: 2.6, height: 1.8))
        ctx.fillEllipse(in: CGRect(x: -16.8, y: -2.6, width: 2.6, height: 1.8))
    }

    // MARK: - Militia: utilitarian patrol boat

    private static func drawMilitia(ctx: CGContext, accent: NSColor, time: Float) {
        let hull = accent
        let dark = accent.blended(withFraction: 0.45, of: .black) ?? accent
        let metal = NSColor(calibratedRed: 0.45, green: 0.48, blue: 0.52, alpha: 1)
        let canopy = NSColor(calibratedRed: 0.6, green: 0.8, blue: 0.95, alpha: 0.75)
        let engine = NSColor(calibratedRed: 0.9, green: 0.6, blue: 0.25, alpha: 1)

        // Angular wings
        fillPath(ctx, color: dark, points: [
            CGPoint(x: 1, y: 2),
            CGPoint(x: -3, y: 10),
            CGPoint(x: -11, y: 9),
            CGPoint(x: -8, y: 3),
        ])
        fillPath(ctx, color: dark, points: [
            CGPoint(x: 1, y: -2),
            CGPoint(x: -3, y: -10),
            CGPoint(x: -11, y: -9),
            CGPoint(x: -8, y: -3),
        ])

        // Boxy body
        fillPath(ctx, color: hull, points: [
            CGPoint(x: 13, y: 0),
            CGPoint(x: 8, y: 3.2),
            CGPoint(x: -5, y: 3.5),
            CGPoint(x: -12, y: 2.5),
            CGPoint(x: -12, y: -2.5),
            CGPoint(x: -5, y: -3.5),
            CGPoint(x: 8, y: -3.2),
        ])
        // Panel lines
        strokePath(ctx, color: .black.withAlphaComponent(0.3), width: 0.5, points: [
            CGPoint(x: 4, y: 3), CGPoint(x: 4, y: -3),
        ])
        strokePath(ctx, color: .black.withAlphaComponent(0.3), width: 0.5, points: [
            CGPoint(x: -2, y: 3.3), CGPoint(x: -2, y: -3.3),
        ])

        // Turret blister
        ctx.setFillColor(metal.cgColor)
        ctx.fillEllipse(in: CGRect(x: -1, y: -2.2, width: 4.4, height: 4.4))
        ctx.setFillColor(canopy.cgColor)
        ctx.fillEllipse(in: CGRect(x: 0.2, y: -1, width: 2, height: 2))

        // Cockpit
        fillPath(ctx, color: canopy, points: [
            CGPoint(x: 8, y: 1.5), CGPoint(x: 4, y: 2), CGPoint(x: 4, y: -2), CGPoint(x: 8, y: -1.5),
        ])

        // Single rear engine
        fillPath(ctx, color: metal, points: [
            CGPoint(x: -11, y: 2), CGPoint(x: -15.5, y: 2.5), CGPoint(x: -15.5, y: -2.5), CGPoint(x: -11, y: -2),
        ])
        let pulse = 0.55 + 0.35 * sin(time * 12)
        ctx.setFillColor(engine.withAlphaComponent(CGFloat(pulse)).cgColor)
        ctx.fillEllipse(in: CGRect(x: -17, y: -1.5, width: 3, height: 3))
    }

    // MARK: - Vael alien craft (crystalline / organic)

    private static func drawAlienSkimmer(ctx: CGContext, accent: NSColor, time: Float) {
        let teal = accent
        let dark = NSColor(calibratedRed: 0.08, green: 0.22, blue: 0.2, alpha: 1)
        let glow = NSColor(calibratedRed: 0.4, green: 1.0, blue: 0.75, alpha: 1)
        let pulse = 0.5 + 0.4 * sin(time * 7)

        fillPath(ctx, color: dark, points: [
            CGPoint(x: 12, y: 0),
            CGPoint(x: 4, y: 5),
            CGPoint(x: -8, y: 7),
            CGPoint(x: -14, y: 2),
            CGPoint(x: -10, y: 0),
            CGPoint(x: -14, y: -2),
            CGPoint(x: -8, y: -7),
            CGPoint(x: 4, y: -5),
        ])
        fillPath(ctx, color: teal, points: [
            CGPoint(x: 10, y: 0),
            CGPoint(x: 2, y: 3.2),
            CGPoint(x: -6, y: 4),
            CGPoint(x: -9, y: 0),
            CGPoint(x: -6, y: -4),
            CGPoint(x: 2, y: -3.2),
        ])
        ctx.setFillColor(glow.withAlphaComponent(CGFloat(pulse)).cgColor)
        ctx.fillEllipse(in: CGRect(x: 1, y: -2, width: 4, height: 4))
        strokePath(ctx, color: glow.withAlphaComponent(0.7), width: 1.2, points: [
            CGPoint(x: -4, y: 4), CGPoint(x: -12, y: 9),
        ])
        strokePath(ctx, color: glow.withAlphaComponent(0.7), width: 1.2, points: [
            CGPoint(x: -4, y: -4), CGPoint(x: -12, y: -9),
        ])
        ctx.setFillColor(glow.withAlphaComponent(CGFloat(0.4 + pulse * 0.4)).cgColor)
        ctx.fillEllipse(in: CGRect(x: -16, y: -2, width: 4, height: 4))
    }

    private static func drawAlienWarden(ctx: CGContext, accent: NSColor, time: Float) {
        let teal = accent
        let dark = NSColor(calibratedRed: 0.06, green: 0.18, blue: 0.16, alpha: 1)
        let crystal = NSColor(calibratedRed: 0.55, green: 1.0, blue: 0.85, alpha: 1)
        let pulse = 0.5 + 0.35 * sin(time * 5)

        fillPath(ctx, color: dark, points: [
            CGPoint(x: 14, y: 0),
            CGPoint(x: 6, y: 7),
            CGPoint(x: -4, y: 10),
            CGPoint(x: -14, y: 6),
            CGPoint(x: -16, y: 0),
            CGPoint(x: -14, y: -6),
            CGPoint(x: -4, y: -10),
            CGPoint(x: 6, y: -7),
        ])
        fillPath(ctx, color: teal, points: [
            CGPoint(x: 11, y: 0),
            CGPoint(x: 4, y: 4.5),
            CGPoint(x: -5, y: 6),
            CGPoint(x: -12, y: 3),
            CGPoint(x: -12, y: -3),
            CGPoint(x: -5, y: -6),
            CGPoint(x: 4, y: -4.5),
        ])
        for side: CGFloat in [1, -1] {
            fillPath(ctx, color: crystal.withAlphaComponent(0.85), points: [
                CGPoint(x: -2, y: 2 * side),
                CGPoint(x: -8, y: 11 * side),
                CGPoint(x: -10, y: 5 * side),
            ])
        }
        ctx.setStrokeColor(crystal.withAlphaComponent(CGFloat(pulse)).cgColor)
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: -2, y: -3.5, width: 7, height: 7))
        ctx.setFillColor(crystal.withAlphaComponent(CGFloat(0.5 + pulse * 0.4)).cgColor)
        ctx.fillEllipse(in: CGRect(x: 0, y: -1.5, width: 3, height: 3))
        ctx.setFillColor(crystal.withAlphaComponent(CGFloat(pulse)).cgColor)
        ctx.fillEllipse(in: CGRect(x: -18, y: 2, width: 4, height: 3))
        ctx.fillEllipse(in: CGRect(x: -18, y: -5, width: 4, height: 3))
    }

    // MARK: - Space station (orbital structure)

    static func drawStation(
        ctx: CGContext, at p: CGPoint, radius: CGFloat, time: Float,
        name: String, faction: String,
        turretAim: Float = 0,
        defenseRange: Float = 0,
        showDefenseRing: Bool = false
    ) {
        ctx.saveGState()
        ctx.translateBy(x: p.x, y: p.y)

        let r = radius
        let metal = NSColor(calibratedRed: 0.55, green: 0.58, blue: 0.62, alpha: 1)
        let metalDark = NSColor(calibratedRed: 0.28, green: 0.30, blue: 0.35, alpha: 1)
        let gold = Theme.station
        let light = Theme.accent
        let window = NSColor(calibratedRed: 0.4, green: 0.85, blue: 1.0, alpha: 0.9)

        // Soft outer glow / docking envelope
        ctx.setStrokeColor(gold.withAlphaComponent(0.15).cgColor)
        ctx.setLineWidth(1)
        ctx.strokeEllipse(in: CGRect(x: -r - 8, y: -r - 8, width: (r + 8) * 2, height: (r + 8) * 2))

        // Defense perimeter when engaging hostiles
        if showDefenseRing, defenseRange > 0 {
            let dr = CGFloat(defenseRange)
            let pulse = 0.12 + 0.08 * sin(time * 3)
            ctx.setStrokeColor(Theme.danger.withAlphaComponent(CGFloat(pulse)).cgColor)
            ctx.setLineWidth(1)
            ctx.setLineDash(phase: CGFloat(time * 20), lengths: [8, 10])
            ctx.strokeEllipse(in: CGRect(x: -dr, y: -dr, width: dr * 2, height: dr * 2))
            ctx.setLineDash(phase: 0, lengths: [])
        }

        // Rotating habitat ring
        ctx.saveGState()
        ctx.rotate(by: CGFloat(time * 0.25))
        ctx.setStrokeColor(metal.cgColor)
        ctx.setLineWidth(7)
        ctx.strokeEllipse(in: CGRect(x: -r * 0.85, y: -r * 0.85, width: r * 1.7, height: r * 1.7))
        ctx.setStrokeColor(metalDark.cgColor)
        ctx.setLineWidth(3)
        ctx.strokeEllipse(in: CGRect(x: -r * 0.85, y: -r * 0.85, width: r * 1.7, height: r * 1.7))

        // Ring modules (boxes along ring)
        for i in 0..<8 {
            let a = CGFloat(i) * .pi / 4
            let rr = r * 0.85
            let mx = cos(a) * rr
            let my = sin(a) * rr
            ctx.saveGState()
            ctx.translateBy(x: mx, y: my)
            ctx.rotate(by: a + .pi / 2)
            ctx.setFillColor(metal.cgColor)
            ctx.fill(CGRect(x: -7, y: -5, width: 14, height: 10))
            ctx.setFillColor(window.cgColor)
            ctx.fill(CGRect(x: -4, y: -2, width: 3, height: 2.5))
            ctx.fill(CGRect(x: 1, y: -2, width: 3, height: 2.5))
            ctx.restoreGState()
        }
        ctx.restoreGState()

        // Spokes to core (slow opposite rotation)
        ctx.saveGState()
        ctx.rotate(by: CGFloat(-time * 0.12))
        ctx.setStrokeColor(metalDark.cgColor)
        ctx.setLineWidth(3)
        for i in 0..<4 {
            let a = CGFloat(i) * .pi / 2
            ctx.move(to: CGPoint(x: cos(a) * r * 0.22, y: sin(a) * r * 0.22))
            ctx.addLine(to: CGPoint(x: cos(a) * r * 0.78, y: sin(a) * r * 0.78))
        }
        ctx.strokePath()
        ctx.restoreGState()

        // Central hub
        ctx.setFillColor(metalDark.cgColor)
        ctx.fillEllipse(in: CGRect(x: -r * 0.28, y: -r * 0.28, width: r * 0.56, height: r * 0.56))
        ctx.setFillColor(gold.withAlphaComponent(0.9).cgColor)
        ctx.fillEllipse(in: CGRect(x: -r * 0.18, y: -r * 0.18, width: r * 0.36, height: r * 0.36))
        ctx.setStrokeColor(light.cgColor)
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: -r * 0.18, y: -r * 0.18, width: r * 0.36, height: r * 0.36))

        // Docking bay portals
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.55).cgColor)
        ctx.fillEllipse(in: CGRect(x: -8, y: -8, width: 16, height: 16))
        ctx.setStrokeColor(light.withAlphaComponent(0.7).cgColor)
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: -8, y: -8, width: 16, height: 16))

        // Antenna mast
        ctx.setStrokeColor(metal.cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: 0, y: r * 0.18))
        ctx.addLine(to: CGPoint(x: 0, y: r * 0.55))
        ctx.strokePath()
        ctx.setFillColor(Theme.danger.cgColor)
        ctx.fillEllipse(in: CGRect(x: -3, y: r * 0.52, width: 6, height: 6))

        // Solar panel arms
        ctx.setFillColor(NSColor(calibratedRed: 0.15, green: 0.25, blue: 0.45, alpha: 0.9).cgColor)
        ctx.fill(CGRect(x: -r * 1.05, y: -6, width: r * 0.22, height: 12))
        ctx.fill(CGRect(x: r * 0.83, y: -6, width: r * 0.22, height: 12))
        ctx.setStrokeColor(light.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(0.8)
        for i in 0..<3 {
            let yy = -4 + CGFloat(i) * 4
            ctx.move(to: CGPoint(x: -r * 1.05, y: yy))
            ctx.addLine(to: CGPoint(x: -r * 0.83, y: yy))
            ctx.move(to: CGPoint(x: r * 0.83, y: yy))
            ctx.addLine(to: CGPoint(x: r * 1.05, y: yy))
        }
        ctx.strokePath()

        // Defense turrets (4 hardpoints on the ring, one tracks hostiles)
        for i in 0..<4 {
            let baseAngle = CGFloat(i) * (.pi / 2) + CGFloat(time * 0.25)
            let tr = r * 0.85
            let tx = cos(baseAngle) * tr
            let ty = sin(baseAngle) * tr
            ctx.saveGState()
            ctx.translateBy(x: tx, y: ty)
            // Track aim on the "front" turret closest to aim direction
            let aimDiff = abs(atan2(sin(CGFloat(turretAim) - baseAngle), cos(CGFloat(turretAim) - baseAngle)))
            let facing = showDefenseRing && aimDiff < .pi / 4 ? CGFloat(turretAim) : baseAngle + .pi / 2
            ctx.rotate(by: facing)
            // Turret base
            ctx.setFillColor(metalDark.cgColor)
            ctx.fillEllipse(in: CGRect(x: -6, y: -6, width: 12, height: 12))
            ctx.setFillColor(metal.cgColor)
            ctx.fillEllipse(in: CGRect(x: -4, y: -4, width: 8, height: 8))
            // Twin barrels
            ctx.setFillColor(NSColor(calibratedRed: 0.2, green: 0.22, blue: 0.26, alpha: 1).cgColor)
            ctx.fill(CGRect(x: 2, y: -3.5, width: 14, height: 2.5))
            ctx.fill(CGRect(x: 2, y: 1, width: 14, height: 2.5))
            if showDefenseRing {
                ctx.setFillColor(Theme.gold.withAlphaComponent(0.85).cgColor)
                ctx.fillEllipse(in: CGRect(x: 14, y: -2, width: 4, height: 4))
            }
            ctx.restoreGState()
        }

        ctx.restoreGState()

        drawLabel(name, at: CGPoint(x: p.x, y: p.y - r - 16), size: 11, weight: .semibold, color: gold)
        let defLabel = showDefenseRing ? "\(faction)  ·  DEFENSES ACTIVE" : faction
        drawLabel(defLabel, at: CGPoint(x: p.x, y: p.y - r - 30), size: 9, weight: .regular,
                  color: showDefenseRing ? Theme.danger : Theme.textSecondary)
    }

    // MARK: - Path helpers

    private static func fillPath(_ ctx: CGContext, color: NSColor, points: [CGPoint]) {
        guard let first = points.first else { return }
        let path = CGMutablePath()
        path.move(to: first)
        for pt in points.dropFirst() { path.addLine(to: pt) }
        path.closeSubpath()
        ctx.setFillColor(color.cgColor)
        ctx.addPath(path)
        ctx.fillPath()
    }

    private static func strokePath(
        _ ctx: CGContext, color: NSColor, width: CGFloat,
        closed: Bool = false, points: [CGPoint]
    ) {
        guard let first = points.first else { return }
        let path = CGMutablePath()
        path.move(to: first)
        for pt in points.dropFirst() { path.addLine(to: pt) }
        if closed { path.closeSubpath() }
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.addPath(path)
        ctx.strokePath()
    }

    private static func drawLabel(_ text: String, at p: CGPoint, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
        let attr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
        ]
        let ns = text as NSString
        let s = ns.size(withAttributes: attr)
        ns.draw(at: CGPoint(x: p.x - s.width / 2, y: p.y), withAttributes: attr)
    }
}
