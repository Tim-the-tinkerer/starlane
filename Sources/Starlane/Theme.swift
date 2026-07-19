import AppKit

/// Deep-space palette for Starlane — neon HUD over black void.
enum Theme {
    static let void = NSColor(calibratedRed: 0.02, green: 0.03, blue: 0.07, alpha: 1)
    static let deepSpace = NSColor(calibratedRed: 0.04, green: 0.06, blue: 0.12, alpha: 1)
    static let nebula = NSColor(calibratedRed: 0.18, green: 0.08, blue: 0.28, alpha: 0.35)
    static let accent = NSColor(calibratedRed: 0.30, green: 0.85, blue: 1.0, alpha: 1)
    static let accentDim = NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.70, alpha: 1)
    static let gold = NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.30, alpha: 1)
    static let warning = NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.20, alpha: 1)
    static let danger = NSColor(calibratedRed: 1.0, green: 0.28, blue: 0.32, alpha: 1)
    static let shield = NSColor(calibratedRed: 0.35, green: 0.70, blue: 1.0, alpha: 1)
    static let energy = NSColor(calibratedRed: 0.95, green: 0.85, blue: 0.25, alpha: 1)
    static let plasma = NSColor(calibratedRed: 0.75, green: 0.40, blue: 1.0, alpha: 1)
    static let missile = NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.2, alpha: 1)
    static let hull = NSColor(calibratedRed: 0.40, green: 0.90, blue: 0.55, alpha: 1)
    static let fuel = NSColor(calibratedRed: 0.95, green: 0.75, blue: 0.25, alpha: 1)
    static let player = NSColor(calibratedRed: 0.40, green: 0.90, blue: 1.0, alpha: 1)
    static let pirate = NSColor(calibratedRed: 0.95, green: 0.30, blue: 0.35, alpha: 1)
    static let trader = NSColor(calibratedRed: 0.55, green: 0.85, blue: 0.45, alpha: 1)
    static let police = NSColor(calibratedRed: 0.45, green: 0.55, blue: 1.0, alpha: 1)
    static let alien = NSColor(calibratedRed: 0.35, green: 0.95, blue: 0.70, alpha: 1)
    static let station = NSColor(calibratedRed: 0.85, green: 0.75, blue: 0.45, alpha: 1)
    static let gate = NSColor(calibratedRed: 0.70, green: 0.40, blue: 1.0, alpha: 1)
    static let wormhole = NSColor(calibratedRed: 0.55, green: 0.25, blue: 1.0, alpha: 1)
    static let asteroid = NSColor(calibratedRed: 0.45, green: 0.42, blue: 0.40, alpha: 1)
    static let laser = NSColor(calibratedRed: 0.40, green: 1.0, blue: 0.85, alpha: 1)
    static let enemyLaser = NSColor(calibratedRed: 1.0, green: 0.35, blue: 0.30, alpha: 1)
    static let panelBg = NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.14, alpha: 0.92)
    static let panelBorder = NSColor(calibratedRed: 0.25, green: 0.55, blue: 0.70, alpha: 0.85)
    static let textPrimary = NSColor.white.withAlphaComponent(0.94)
    static let textSecondary = NSColor.white.withAlphaComponent(0.60)
    static let textMuted = NSColor.white.withAlphaComponent(0.38)

    static func systemTint(_ name: String) -> NSColor {
        switch name {
        case "Solara": return NSColor(calibratedRed: 0.35, green: 0.65, blue: 1.0, alpha: 1)
        case "Vesper": return NSColor(calibratedRed: 0.85, green: 0.45, blue: 0.95, alpha: 1)
        case "Ironreach": return NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.30, alpha: 1)
        case "Cinder": return NSColor(calibratedRed: 1.0, green: 0.30, blue: 0.25, alpha: 1)
        case "Azurel": return NSColor(calibratedRed: 0.30, green: 0.90, blue: 0.75, alpha: 1)
        case "Nyx": return NSColor(calibratedRed: 0.35, green: 0.30, blue: 0.85, alpha: 1)
        case "Helion": return NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.30, alpha: 1)
        case "Drift": return NSColor(calibratedRed: 0.70, green: 0.62, blue: 0.48, alpha: 1)
        case "Kestrel": return NSColor(calibratedRed: 0.40, green: 0.55, blue: 0.95, alpha: 1)
        case "Umbra": return NSColor(calibratedRed: 0.65, green: 0.25, blue: 0.80, alpha: 1)
        case "Voidreach": return NSColor(calibratedRed: 0.30, green: 0.95, blue: 0.70, alpha: 1)
        default: return accent
        }
    }
}
