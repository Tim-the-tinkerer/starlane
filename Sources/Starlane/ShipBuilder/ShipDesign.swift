import Foundation
import AppKit

// MARK: - Aggregated stats

struct WeaponConfig: Equatable {
    var type: WeaponKind
    var name: String
    var damage: Double
    var fireRate: Double
    var speed: Double
    var energy: Double
    var range: Double
    var count: Int
    var spread: Double
    var color: NSColor
}

/// Aggregated visual / hangar stats from modular parts (not Starlane Mk `ShipStats`).
struct ModularShipStats: Equatable {
    var mass: Double
    var thrust: Double
    var accel: Double
    var maxSpeed: Double
    var turnRate: Double
    var armor: Double
    var maxShield: Double
    var energy: Double
    var energyRegen: Double
    var dps: Double
    var primary: WeaponConfig?
    var secondary: WeaponConfig?
    var hullColor: NSColor
    var accentColor: NSColor
    var engineColor: NSColor
    var hullShape: HullShape
    var wingShape: WingShape
    var engineShape: EngineShape
    var hasBoost: Bool
    var hasRepair: Bool
}

struct RatingBars: Equatable {
    var speed: Double
    var agility: Double
    var armor: Double
    var shield: Double
    var firepower: Double
    var power: Double
}

// MARK: - Design

struct ShipDesign: Codable, Equatable {
    var name: String
    var loadout: [PartSlot: String]

    /// Shared hangar design (standalone Spacecraft Builder + Starlane).
    static let storageKey = "spacecraft-builder.design.v1"
    static let starlanePlayerKey = "starlane.player.shipDesign.v1"

    static var `default`: ShipDesign {
        ShipDesign(name: "Unnamed Vessel", loadout: PartsCatalog.defaults)
    }

    func part(for slot: PartSlot) -> ShipPart? {
        guard let id = loadout[slot] else { return nil }
        return PartsCatalog.part(id: id)
    }

    mutating func setPart(_ part: ShipPart) {
        guard part.slot == part.slot else { return }
        loadout[part.slot] = part.id
    }

    mutating func setPart(id: String, slot: PartSlot) {
        guard let p = PartsCatalog.part(id: id), p.slot == slot else { return }
        loadout[slot] = id
    }

    func equipped() -> [ShipPart] {
        PartSlot.allCases.compactMap { part(for: $0) }
    }

    func computeStats() -> ModularShipStats {
        let parts = equipped()
        var mass = 0.0
        var thrust = 0.0
        var armor = 0.0
        var shield = 0.0
        var energy = 0.0
        var energyDrainIdle = 0.0
        var hullColor = NSColor(hex: "#3A6EA5")!
        var accentColor = NSColor(hex: "#5EC8FF")!
        var engineColor = NSColor(hex: "#FFAA44")!
        var hullShape: HullShape = .interceptor
        var wingShape: WingShape = .none
        var engineShape: EngineShape = .chem
        var hasBoost = false
        var hasRepair = false
        var weaponRangeBonus = 0.0

        for p in parts {
            mass += p.mass
            thrust += p.thrust
            armor += p.armor
            shield += p.shield
            energy += p.energy
            if p.weaponType == .none && p.energyDrain > 0 {
                energyDrainIdle += p.energyDrain * 0.15
            }
            if let hs = p.hullShape { hullShape = hs }
            if let ws = p.wingShape { wingShape = ws }
            if let es = p.engineShape { engineShape = es }
            if p.slot == .engine, let hex = p.colorHex, let c = NSColor(hex: hex) {
                engineColor = c
            }
            if p.slot == .paint {
                if let hex = p.colorHex, let c = NSColor(hex: hex) { hullColor = c }
                if let hex = p.accentHex, let c = NSColor(hex: hex) { accentColor = c }
            }
            if p.tags.contains("boost") { hasBoost = true }
            if p.tags.contains("repair") { hasRepair = true }
            if p.slot == .utility { weaponRangeBonus += p.range }
        }

        let hull = part(for: .hull)
        let baseTurn = hull?.turn ?? 1
        var bonusTurn = 0.0
        for p in parts where p.slot != .hull {
            bonusTurn += p.turn
        }
        // Cap so glass builds stay pilotable (rad/s). Soft ships stay snappy; never spin-wild.
        let rawTurn = baseTurn * (1 + bonusTurn) * (2.2 + 28 / (mass + 20))
        let turnRate = min(2.6, max(0.9, rawTurn))
        let maxSpeed = min(420, (thrust / max(mass, 1)) * 95 + 80)
        let accel = thrust / max(mass, 1) * 180

        let primary = weaponConfig(part(for: .weapon), rangeBonus: weaponRangeBonus)
        let secondary = weaponConfig(part(for: .secondary), rangeBonus: weaponRangeBonus)
        let dps =
            (primary.map { $0.damage * $0.fireRate * Double($0.count) } ?? 0) +
            (secondary.map { $0.damage * $0.fireRate * Double($0.count) } ?? 0)
        let energyRegen = max(2, 12 + energy * 0.04 - energyDrainIdle)

        return ModularShipStats(
            mass: mass,
            thrust: thrust,
            accel: accel,
            maxSpeed: maxSpeed,
            turnRate: turnRate,
            armor: max(1, armor),
            maxShield: shield,
            energy: max(40, energy),
            energyRegen: energyRegen,
            dps: dps,
            primary: primary,
            secondary: secondary,
            hullColor: hullColor,
            accentColor: accentColor,
            engineColor: engineColor,
            hullShape: hullShape,
            wingShape: wingShape,
            engineShape: engineShape,
            hasBoost: hasBoost,
            hasRepair: hasRepair
        )
    }

    private func weaponConfig(_ part: ShipPart?, rangeBonus: Double) -> WeaponConfig? {
        guard let part, part.weaponType != .none, part.damage > 0 else { return nil }
        let color = part.colorHex.flatMap { NSColor(hex: $0) } ?? .white
        return WeaponConfig(
            type: part.weaponType,
            name: part.name,
            damage: part.damage,
            fireRate: max(0.1, part.fireRate),
            speed: part.projectileSpeed > 0 ? part.projectileSpeed : 600,
            energy: part.energyDrain > 0 ? part.energyDrain : 4,
            range: (part.range > 0 ? part.range : 500) + rangeBonus,
            count: max(1, part.projectileCount),
            spread: part.spread,
            color: color
        )
    }

    func ratingBars() -> RatingBars {
        let st = computeStats()
        func clamp(_ v: Double) -> Double { min(100, max(0, v)) }
        return RatingBars(
            speed: clamp((st.maxSpeed - 80) / 3.4),
            agility: clamp((st.turnRate - 1.5) * 25),
            armor: clamp(st.armor / 3.2),
            shield: clamp(st.maxShield / 2),
            firepower: clamp(st.dps / 1.8),
            power: clamp(st.energy / 3)
        )
    }

    // MARK: Persistence

    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {}
    }

    static func load() -> ShipDesign {
        // Prefer Starlane player key, then shared builder hangar design
        if let data = UserDefaults.standard.data(forKey: starlanePlayerKey),
           let design = try? JSONDecoder().decode(ShipDesign.self, from: data) {
            return design
        }
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let design = try? JSONDecoder().decode(ShipDesign.self, from: data)
        else { return .default }
        return design
    }

    func saveForStarlane() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: Self.starlanePlayerKey)
            // Also mirror to shared builder key so Spacecraft Builder app sees it
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {}
    }

    /// Defaults tuned to Starlane hull class.
    /// Primary gun is always free **Pulse Laser** — other hangar weapons must be bought.
    static func preset(for shipClass: PlayerShipClass, paint: ShipPaint) -> ShipDesign {
        var d = ShipDesign.default
        switch shipClass {
        case .hybrid:
            d.loadout[.hull] = "hull_interceptor"
            d.loadout[.wings] = "wings_delta"
            d.loadout[.engine] = "eng_chem"
        case .freighter:
            d.loadout[.hull] = "hull_frigate"
            d.loadout[.wings] = "wings_swept"
            d.loadout[.engine] = "eng_fusion"
            d.loadout[.shield] = "shd_heavy"
        case .interceptor:
            d.loadout[.hull] = "hull_needle"
            d.loadout[.wings] = "wings_canard"
            d.loadout[.engine] = "eng_pulse"
            d.loadout[.shield] = "shd_light"
        }
        d.loadout[.weapon] = "wpn_laser"
        d.loadout[.secondary] = "sec_none"
        d.loadout[.paint] = paint.builderPaintID
        d.name = shipClass.displayName
        return d
    }

    /// Free starter kit — only default laser among primary weapons.
    static var freeStarterPartIDs: Set<String> {
        [
            "wings_none", "wpn_none", "wpn_laser", "sec_none", "shd_none", "util_none",
            "eng_ion", "eng_chem",
            "hull_scout", "hull_interceptor",
            "wings_delta", "wings_swept",
            "shd_light", "shd_standard",
            "paint_cobalt", "paint_ice", "paint_crimson", "paint_emerald",
            "paint_void", "paint_solar", "paint_nebula",
        ]
    }

    /// Primary weapons that must be purchased (not free).
    static var purchasablePrimaryWeaponIDs: Set<String> {
        ["wpn_cannon", "wpn_plasma", "wpn_rail", "wpn_beam"]
    }

    mutating func randomize() {
        for slot in PartSlot.allCases {
            let options = PartsCatalog.parts(for: slot)
            if let pick = options.randomElement() {
                loadout[slot] = pick.id
            }
        }
        if Double.random(in: 0...1) > 0.2 {
            let weapons = PartsCatalog.parts(for: .weapon).filter { $0.weaponType != .none }
            if let w = weapons.randomElement() {
                loadout[.weapon] = w.id
            }
        }
    }
}

// Codable for PartSlot as dictionary key
extension ShipDesign {
    enum CodingKeys: String, CodingKey { case name, loadout }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        let raw = try c.decode([String: String].self, forKey: .loadout)
        var map = PartsCatalog.defaults
        for (k, v) in raw {
            if let slot = PartSlot(rawValue: k) { map[slot] = v }
        }
        loadout = map
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        var raw: [String: String] = [:]
        for (k, v) in loadout { raw[k.rawValue] = v }
        try c.encode(raw, forKey: .loadout)
    }
}
