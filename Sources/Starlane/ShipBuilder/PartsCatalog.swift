import Foundation
import AppKit

// MARK: - Slots

enum PartSlot: String, CaseIterable, Identifiable, Codable {
    case hull, wings, engine, weapon, secondary, shield, utility, paint

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hull: return "Hull"
        case .wings: return "Wings / Fins"
        case .engine: return "Engines"
        case .weapon: return "Primary Weapon"
        case .secondary: return "Secondary Weapon"
        case .shield: return "Shields"
        case .utility: return "Utility"
        case .paint: return "Livery"
        }
    }

    /// Compact label for hangar slot chips (always fits without clipping).
    var shortLabel: String {
        switch self {
        case .hull: return "Hull"
        case .wings: return "Wings"
        case .engine: return "Engines"
        case .weapon: return "Primary"
        case .secondary: return "Secondary"
        case .shield: return "Shields"
        case .utility: return "Utility"
        case .paint: return "Livery"
        }
    }

    var symbol: String {
        switch self {
        case .hull: return "cube.fill"
        case .wings: return "airplane"
        case .engine: return "flame.fill"
        case .weapon: return "scope"
        case .secondary: return "burst.fill"
        case .shield: return "shield.fill"
        case .utility: return "gearshape.2.fill"
        case .paint: return "paintpalette.fill"
        }
    }

    var isRequired: Bool {
        switch self {
        case .hull, .engine, .paint: return true
        default: return false
        }
    }
}

enum PartRarity: String, Codable {
    case common, uncommon, rare, legendary

    var color: NSColor {
        switch self {
        case .common: return NSColor(srgbRed: 0.67, green: 0.69, blue: 0.75, alpha: 1)
        case .uncommon: return NSColor(srgbRed: 0.33, green: 0.87, blue: 0.53, alpha: 1)
        case .rare: return NSColor(srgbRed: 0.33, green: 0.60, blue: 1.0, alpha: 1)
        case .legendary: return NSColor(srgbRed: 1.0, green: 0.67, blue: 0.20, alpha: 1)
        }
    }
}

enum WeaponKind: String, Codable {
    case none, laser, cannon, plasma, rail, beam, missile, spread, torpedo, mine
}

enum HullShape: String, Codable {
    case scout, interceptor, gunship, frigate, needle
}

enum WingShape: String, Codable {
    case none, delta, swept, canard, variable, blade
}

enum EngineShape: String, Codable {
    case ion, chem, fusion, pulse, warp
}

// MARK: - Part

struct ShipPart: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let slot: PartSlot
    let desc: String
    var mass: Double = 0
    var thrust: Double = 0
    var turn: Double = 0
    var armor: Double = 0
    var shield: Double = 0
    var energy: Double = 0
    var energyDrain: Double = 0
    var damage: Double = 0
    var fireRate: Double = 0
    var projectileSpeed: Double = 0
    var spread: Double = 0
    var projectileCount: Int = 1
    var range: Double = 0
    var weaponType: WeaponKind = .none
    var colorHex: String? = nil
    var accentHex: String? = nil
    var hullShape: HullShape? = nil
    var wingShape: WingShape? = nil
    var engineShape: EngineShape? = nil
    var rarity: PartRarity = .common
    var tags: [String] = []

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ShipPart, rhs: ShipPart) -> Bool { lhs.id == rhs.id }
}

// MARK: - Catalog

enum PartsCatalog {
    static let all: [ShipPart] = [
        // Hulls
        ShipPart(id: "hull_scout", name: "Scout Frame", slot: .hull,
                 desc: "Light composite frame. Nimble, fragile, low mass.",
                 mass: 12, turn: 1.15, armor: 80, energy: 100,
                 hullShape: .scout, rarity: .common, tags: ["light", "agile"]),
        ShipPart(id: "hull_interceptor", name: "Interceptor Chassis", slot: .hull,
                 desc: "Balanced combat frame with reinforced spars.",
                 mass: 18, turn: 1.0, armor: 120, energy: 120,
                 hullShape: .interceptor, rarity: .common, tags: ["balanced"]),
        ShipPart(id: "hull_gunship", name: "Gunship Hull", slot: .hull,
                 desc: "Heavy armor plating. Slow turns, hard to kill.",
                 mass: 28, turn: 0.75, armor: 200, energy: 140,
                 hullShape: .gunship, rarity: .uncommon, tags: ["heavy", "tank"]),
        ShipPart(id: "hull_frigate", name: "Frigate Core", slot: .hull,
                 desc: "Capital-class midframe. Huge energy reserves.",
                 mass: 40, turn: 0.55, armor: 260, energy: 220,
                 hullShape: .frigate, rarity: .rare, tags: ["capital", "power"]),
        ShipPart(id: "hull_needle", name: "Needle Striker", slot: .hull,
                 desc: "Ultra-thin stealth frame. Paper armor, extreme agility.",
                 mass: 8, turn: 1.4, armor: 50, energy: 90,
                 hullShape: .needle, rarity: .rare, tags: ["stealth", "glass"]),

        // Wings
        ShipPart(id: "wings_none", name: "No Wings", slot: .wings,
                 desc: "Bare hull. Minimal profile, no wing bonuses.",
                 wingShape: WingShape.none),
        ShipPart(id: "wings_delta", name: "Delta Fins", slot: .wings,
                 desc: "Classic delta planform. Improves turn rate.",
                 mass: 3, turn: 0.2, armor: 10, wingShape: .delta),
        ShipPart(id: "wings_swept", name: "Swept Wings", slot: .wings,
                 desc: "Aggressive sweep for high-speed stability.",
                 mass: 4, thrust: 4, turn: 0.1, wingShape: .swept),
        ShipPart(id: "wings_canard", name: "Canard Array", slot: .wings,
                 desc: "Forward canards for snap turns.",
                 mass: 2, turn: 0.35, wingShape: .canard, rarity: .uncommon),
        ShipPart(id: "wings_variable", name: "Variable Geometry", slot: .wings,
                 desc: "Adaptive foil. Balanced thrust and agility.",
                 mass: 5, thrust: 6, turn: 0.25, armor: 15,
                 wingShape: .variable, rarity: .rare),
        ShipPart(id: "wings_blade", name: "Blade Vanes", slot: .wings,
                 desc: "Razor energy-conducting vanes.",
                 mass: 2, turn: 0.3, energy: 20, wingShape: .blade, rarity: .rare),

        // Engines
        ShipPart(id: "eng_ion", name: "Ion Drift Drive", slot: .engine,
                 desc: "Efficient low-thrust ion engines. Sips energy.",
                 mass: 4, thrust: 22, energyDrain: 2,
                 colorHex: "#6EC8FF", engineShape: .ion),
        ShipPart(id: "eng_chem", name: "Chemical Rockets", slot: .engine,
                 desc: "Classic bipropellant. Strong burst, hungry.",
                 mass: 6, thrust: 38, energyDrain: 6,
                 colorHex: "#FFAA44", engineShape: .chem),
        ShipPart(id: "eng_fusion", name: "Fusion Torch", slot: .engine,
                 desc: "Compact fusion plume. Serious acceleration.",
                 mass: 10, thrust: 55, energyDrain: 10,
                 colorHex: "#88FFCC", engineShape: .fusion, rarity: .uncommon),
        ShipPart(id: "eng_pulse", name: "Pulse Detonation", slot: .engine,
                 desc: "Stuttering plasma detonations. Raw power.",
                 mass: 12, thrust: 70, energyDrain: 14,
                 colorHex: "#FF6688", engineShape: .pulse, rarity: .rare),
        ShipPart(id: "eng_warp", name: "Warp Coil Array", slot: .engine,
                 desc: "Experimental subspace push. Extreme thrust.",
                 mass: 14, thrust: 90, energy: 30, energyDrain: 18,
                 colorHex: "#C088FF", engineShape: .warp, rarity: .legendary),

        // Primary weapons
        ShipPart(id: "wpn_none", name: "Unarmed", slot: .weapon,
                 desc: "No primary hardpoint mounted.", weaponType: .none),
        ShipPart(id: "wpn_laser", name: "Pulse Laser", slot: .weapon,
                 desc: "Fast, accurate energy bolts. Low damage each.",
                 mass: 3, energyDrain: 3, damage: 8, fireRate: 8,
                 projectileSpeed: 900, range: 700, weaponType: .laser,
                 colorHex: "#55FFAA"),
        ShipPart(id: "wpn_cannon", name: "Mass Driver", slot: .weapon,
                 desc: "Kinetic slugs. Hard-hitting, moderate rate.",
                 mass: 5, energyDrain: 4, damage: 22, fireRate: 3,
                 projectileSpeed: 700, range: 650, weaponType: .cannon,
                 colorHex: "#FFCC66"),
        ShipPart(id: "wpn_plasma", name: "Plasma Repeater", slot: .weapon,
                 desc: "Superheated plasma orbs with splash.",
                 mass: 6, energyDrain: 7, damage: 16, fireRate: 4.5,
                 projectileSpeed: 520, range: 550, weaponType: .plasma,
                 colorHex: "#FF66CC", rarity: .uncommon),
        ShipPart(id: "wpn_rail", name: "Rail Lance", slot: .weapon,
                 desc: "Hypersonic railgun. Devastating single shots.",
                 mass: 9, energyDrain: 12, damage: 55, fireRate: 1.2,
                 projectileSpeed: 1400, range: 900, weaponType: .rail,
                 colorHex: "#88DDFF", rarity: .rare),
        ShipPart(id: "wpn_beam", name: "Focus Beam", slot: .weapon,
                 desc: "Rapid cutting beam pulses. Energy hungry.",
                 mass: 7, energyDrain: 16, damage: 18, fireRate: 12,
                 projectileSpeed: 2000, range: 500, weaponType: .beam,
                 colorHex: "#FF4444", rarity: .rare),

        // Secondary
        ShipPart(id: "sec_none", name: "Empty Bay", slot: .secondary,
                 desc: "No secondary system installed.", weaponType: .none),
        ShipPart(id: "sec_missiles", name: "Seeker Pods", slot: .secondary,
                 desc: "Homing missiles. Fire in salvos.",
                 mass: 5, energyDrain: 10, damage: 28, fireRate: 0.7,
                 projectileSpeed: 380, projectileCount: 2, range: 800,
                 weaponType: .missile, colorHex: "#FFAA33", rarity: .uncommon),
        ShipPart(id: "sec_spread", name: "Scatter Battery", slot: .secondary,
                 desc: "Wide-angle flak. Great vs swarms.",
                 mass: 4, energyDrain: 5, damage: 6, fireRate: 5,
                 projectileSpeed: 600, spread: 0.45, projectileCount: 5, range: 400,
                 weaponType: .spread, colorHex: "#AADDFF"),
        ShipPart(id: "sec_torpedo", name: "Photon Torpedo", slot: .secondary,
                 desc: "Slow, massive warheads. Asteroid crackers.",
                 mass: 8, energyDrain: 18, damage: 90, fireRate: 0.4,
                 projectileSpeed: 280, range: 750, weaponType: .torpedo,
                 colorHex: "#FF55FF", rarity: .rare),
        ShipPart(id: "sec_mines", name: "Proximity Mines", slot: .secondary,
                 desc: "Drop sticky mines that arm after a delay.",
                 mass: 4, energyDrain: 8, damage: 45, fireRate: 1.5,
                 projectileSpeed: 40, range: 200, weaponType: .mine,
                 colorHex: "#FFEE55", rarity: .uncommon),

        // Shields
        ShipPart(id: "shd_none", name: "No Shields", slot: .shield,
                 desc: "Rely on hull armor alone."),
        ShipPart(id: "shd_light", name: "Light Barrier", slot: .shield,
                 desc: "Basic deflector. Quick recharge.",
                 mass: 2, shield: 50, energy: 10, energyDrain: 1),
        ShipPart(id: "shd_standard", name: "Standard Deflector", slot: .shield,
                 desc: "Reliable mid-tier shield bubble.",
                 mass: 4, shield: 100, energy: 15, energyDrain: 2),
        ShipPart(id: "shd_heavy", name: "Heavy Aegis", slot: .shield,
                 desc: "Thick multi-layer field. Slow regen.",
                 mass: 8, shield: 180, energy: 20, energyDrain: 4, rarity: .uncommon),
        ShipPart(id: "shd_phase", name: "Phase Lattice", slot: .shield,
                 desc: "Exotic phase-shifted barrier.",
                 mass: 6, turn: 0.05, shield: 140, energy: 40, energyDrain: 3, rarity: .rare),

        // Utility
        ShipPart(id: "util_none", name: "Empty Slot", slot: .utility,
                 desc: "No utility module."),
        ShipPart(id: "util_reactor", name: "Aux Reactor", slot: .utility,
                 desc: "Extra power plant. Higher energy cap & regen.",
                 mass: 5, energy: 80, rarity: .uncommon, tags: ["power"]),
        ShipPart(id: "util_afterburner", name: "Afterburner", slot: .utility,
                 desc: "Boost thrust when holding Shift. Costs energy.",
                 mass: 3, thrust: 8, rarity: .uncommon, tags: ["boost"]),
        ShipPart(id: "util_armor", name: "Ablative Plating", slot: .utility,
                 desc: "Extra armor panels welded on.",
                 mass: 6, turn: -0.08, armor: 60, tags: ["defense"]),
        ShipPart(id: "util_scanner", name: "Target Scanner", slot: .utility,
                 desc: "Highlights threats and extends weapon range.",
                 mass: 2, energy: 15, range: 120, rarity: .uncommon, tags: ["sensor"]),
        ShipPart(id: "util_drone", name: "Repair Nanites", slot: .utility,
                 desc: "Slow hull regeneration in combat.",
                 mass: 3, armor: 10, energyDrain: 1, rarity: .rare, tags: ["repair"]),

        // Paint
        ShipPart(id: "paint_cobalt", name: "Cobalt Fleet", slot: .paint,
                 desc: "Standard navy cobalt with cyan trim.",
                 colorHex: "#3A6EA5", accentHex: "#5EC8FF"),
        ShipPart(id: "paint_crimson", name: "Crimson Raider", slot: .paint,
                 desc: "Deep red hull with gold accents.",
                 colorHex: "#8B2A2A", accentHex: "#FFCC44"),
        ShipPart(id: "paint_void", name: "Void Black", slot: .paint,
                 desc: "Near-black stealth coating with violet edge light.",
                 colorHex: "#1A1A28", accentHex: "#A855F7", rarity: .uncommon),
        ShipPart(id: "paint_emerald", name: "Emerald Corsair", slot: .paint,
                 desc: "Forest green with lime highlights.",
                 colorHex: "#1A5C3A", accentHex: "#6DFF9A"),
        ShipPart(id: "paint_solar", name: "Solar Gold", slot: .paint,
                 desc: "Burnished gold hull, white-hot trim.",
                 colorHex: "#8A6A20", accentHex: "#FFE566", rarity: .rare),
        ShipPart(id: "paint_ice", name: "Ice Ghost", slot: .paint,
                 desc: "Pale ice-white with electric blue.",
                 colorHex: "#C8D8E8", accentHex: "#40E0FF", rarity: .uncommon),
        ShipPart(id: "paint_nebula", name: "Nebula Drift", slot: .paint,
                 desc: "Iridescent magenta-to-cyan livery.",
                 colorHex: "#6B2D8B", accentHex: "#00FFD5", rarity: .legendary),
    ]

    static let defaults: [PartSlot: String] = [
        .hull: "hull_interceptor",
        .wings: "wings_delta",
        .engine: "eng_chem",
        .weapon: "wpn_laser",
        .secondary: "sec_none",
        .shield: "shd_standard",
        .utility: "util_none",
        .paint: "paint_cobalt",
    ]

    static func part(id: String) -> ShipPart? {
        all.first { $0.id == id }
    }

    static func parts(for slot: PartSlot) -> [ShipPart] {
        all.filter { $0.slot == slot }
    }

    /// Shipyard install price (credits). Empty / none options are cheap; rare gear is expensive.
    static func installCost(for part: ShipPart) -> Int {
        if ShipDesign.freeStarterPartIDs.contains(part.id) { return 0 }

        // Primary weapons (beyond free laser) — explicit hangar prices
        switch part.id {
        case "wpn_cannon": return 1_800
        case "wpn_plasma": return 2_600
        case "wpn_rail": return 4_200
        case "wpn_beam": return 5_500
        case "sec_missiles": return 1_400
        case "sec_spread": return 1_100
        case "sec_torpedo": return 3_500
        case "sec_mines": return 1_200
        default: break
        }

        let rarityBase: Int
        switch part.rarity {
        case .common: rarityBase = 350
        case .uncommon: rarityBase = 900
        case .rare: rarityBase = 2_400
        case .legendary: rarityBase = 6_000
        }

        let slotMult: Double
        switch part.slot {
        case .hull: slotMult = 3.0
        case .engine: slotMult = 2.2
        case .weapon: slotMult = 2.5
        case .secondary: slotMult = 2.0
        case .shield: slotMult = 1.6
        case .wings: slotMult = 1.3
        case .utility: slotMult = 1.5
        case .paint: slotMult = 1.0
        }
        return max(50, Int(Double(rarityBase) * slotMult))
    }

    /// All equippable primary guns (excluding unarmed).
    static var primaryWeapons: [ShipPart] {
        parts(for: .weapon).filter { $0.weaponType != .none }
    }
}

// MARK: - Color helpers

extension NSColor {
    convenience init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt64(h, radix: 16) else { return nil }
        let r = CGFloat((v >> 16) & 0xFF) / 255
        let g = CGFloat((v >> 8) & 0xFF) / 255
        let b = CGFloat(v & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    func shaded(by amount: CGFloat) -> NSColor {
        guard let c = usingColorSpace(.sRGB) else { return self }
        return NSColor(
            srgbRed: min(1, max(0, c.redComponent + amount)),
            green: min(1, max(0, c.greenComponent + amount)),
            blue: min(1, max(0, c.blueComponent + amount)),
            alpha: c.alphaComponent
        )
    }
}
