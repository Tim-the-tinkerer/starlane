import Foundation
import CoreGraphics
import AppKit
import simd

// MARK: - Commodities

enum Commodity: String, CaseIterable, Codable {
    case food = "Food"
    case ore = "Ore"
    case fuelCells = "Fuel Cells"
    case electronics = "Electronics"
    case weapons = "Weapons"
    case medical = "Medical"
    case luxury = "Luxury Goods"
    case scrap = "Scrap"

    var basePrice: Int {
        switch self {
        case .food: return 12
        case .ore: return 18
        case .fuelCells: return 22
        case .electronics: return 45
        case .weapons: return 55
        case .medical: return 38
        case .luxury: return 70
        case .scrap: return 8
        }
    }

    var unitMass: Float {
        switch self {
        case .food: return 1
        case .ore: return 2
        case .fuelCells: return 1.5
        case .electronics: return 1
        case .weapons: return 2
        case .medical: return 1
        case .luxury: return 1
        case .scrap: return 1.5
        }
    }
}

// MARK: - Player ship

struct ShipStats: Codable {
    var maxHull: Float = 100
    var maxShield: Float = 80
    var cargoCapacity: Float = 40
    var thrust: Float = 320
    var turnRate: Float = 2.6
    var maxSpeed: Float = 360
    var laserDamage: Float = 12
    var laserCooldown: Float = 0.22
    var shieldRegen: Float = 8
    /// Capacitor for weapons + shield recharge (engines are independent).
    var maxEnergy: Float = 100
    /// Energy restored per second when not fully drained by demand.
    var energyRegen: Float = 20
    /// Energy spent per laser bolt.
    var laserEnergyCost: Float = 8
    /// Plasma cannon (slower, hungrier, harder hit).
    var plasmaDamage: Float = 28
    var plasmaCooldown: Float = 0.55
    var plasmaEnergyCost: Float = 28
    /// Pulse array — rapid low-power bolts.
    var pulseDamage: Float = 6
    var pulseCooldown: Float = 0.09
    var pulseEnergyCost: Float = 3.5
    /// Rail lance — slow, long-range heavy slug.
    var railDamage: Float = 48
    var railCooldown: Float = 0.95
    var railEnergyCost: Float = 42
    /// Energy cost per point of shield restored.
    var shieldEnergyPerPoint: Float = 0.85

    /// Defaults for every field so older saves (missing pulse/rail, etc.) still decode.
    init(
        maxHull: Float = 100, maxShield: Float = 80, cargoCapacity: Float = 40,
        thrust: Float = 320, turnRate: Float = 2.6, maxSpeed: Float = 360,
        laserDamage: Float = 12, laserCooldown: Float = 0.22, shieldRegen: Float = 8,
        maxEnergy: Float = 100, energyRegen: Float = 20, laserEnergyCost: Float = 8,
        plasmaDamage: Float = 28, plasmaCooldown: Float = 0.55, plasmaEnergyCost: Float = 28,
        pulseDamage: Float = 6, pulseCooldown: Float = 0.09, pulseEnergyCost: Float = 3.5,
        railDamage: Float = 48, railCooldown: Float = 0.95, railEnergyCost: Float = 42,
        shieldEnergyPerPoint: Float = 0.85
    ) {
        self.maxHull = maxHull
        self.maxShield = maxShield
        self.cargoCapacity = cargoCapacity
        self.thrust = thrust
        self.turnRate = turnRate
        self.maxSpeed = maxSpeed
        self.laserDamage = laserDamage
        self.laserCooldown = laserCooldown
        self.shieldRegen = shieldRegen
        self.maxEnergy = maxEnergy
        self.energyRegen = energyRegen
        self.laserEnergyCost = laserEnergyCost
        self.plasmaDamage = plasmaDamage
        self.plasmaCooldown = plasmaCooldown
        self.plasmaEnergyCost = plasmaEnergyCost
        self.pulseDamage = pulseDamage
        self.pulseCooldown = pulseCooldown
        self.pulseEnergyCost = pulseEnergyCost
        self.railDamage = railDamage
        self.railCooldown = railCooldown
        self.railEnergyCost = railEnergyCost
        self.shieldEnergyPerPoint = shieldEnergyPerPoint
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ShipStats() // defaults
        maxHull = try c.decodeIfPresent(Float.self, forKey: .maxHull) ?? d.maxHull
        maxShield = try c.decodeIfPresent(Float.self, forKey: .maxShield) ?? d.maxShield
        cargoCapacity = try c.decodeIfPresent(Float.self, forKey: .cargoCapacity) ?? d.cargoCapacity
        thrust = try c.decodeIfPresent(Float.self, forKey: .thrust) ?? d.thrust
        turnRate = try c.decodeIfPresent(Float.self, forKey: .turnRate) ?? d.turnRate
        maxSpeed = try c.decodeIfPresent(Float.self, forKey: .maxSpeed) ?? d.maxSpeed
        laserDamage = try c.decodeIfPresent(Float.self, forKey: .laserDamage) ?? d.laserDamage
        laserCooldown = try c.decodeIfPresent(Float.self, forKey: .laserCooldown) ?? d.laserCooldown
        shieldRegen = try c.decodeIfPresent(Float.self, forKey: .shieldRegen) ?? d.shieldRegen
        maxEnergy = try c.decodeIfPresent(Float.self, forKey: .maxEnergy) ?? d.maxEnergy
        energyRegen = try c.decodeIfPresent(Float.self, forKey: .energyRegen) ?? d.energyRegen
        laserEnergyCost = try c.decodeIfPresent(Float.self, forKey: .laserEnergyCost) ?? d.laserEnergyCost
        plasmaDamage = try c.decodeIfPresent(Float.self, forKey: .plasmaDamage) ?? d.plasmaDamage
        plasmaCooldown = try c.decodeIfPresent(Float.self, forKey: .plasmaCooldown) ?? d.plasmaCooldown
        plasmaEnergyCost = try c.decodeIfPresent(Float.self, forKey: .plasmaEnergyCost) ?? d.plasmaEnergyCost
        pulseDamage = try c.decodeIfPresent(Float.self, forKey: .pulseDamage) ?? d.pulseDamage
        pulseCooldown = try c.decodeIfPresent(Float.self, forKey: .pulseCooldown) ?? d.pulseCooldown
        pulseEnergyCost = try c.decodeIfPresent(Float.self, forKey: .pulseEnergyCost) ?? d.pulseEnergyCost
        railDamage = try c.decodeIfPresent(Float.self, forKey: .railDamage) ?? d.railDamage
        railCooldown = try c.decodeIfPresent(Float.self, forKey: .railCooldown) ?? d.railCooldown
        railEnergyCost = try c.decodeIfPresent(Float.self, forKey: .railEnergyCost) ?? d.railEnergyCost
        shieldEnergyPerPoint = try c.decodeIfPresent(Float.self, forKey: .shieldEnergyPerPoint) ?? d.shieldEnergyPerPoint
    }
}

/// Primary directed-energy mode (Space / Q). Missiles are separate (B).
enum WeaponMode: String, Codable, CaseIterable {
    case laser
    case plasma
    case pulse
    case rail

    var displayName: String {
        switch self {
        case .laser: return "Lasers"
        case .plasma: return "Plasma Cannon"
        case .pulse: return "Pulse Array"
        case .rail: return "Rail Lance"
        }
    }

    var shortName: String {
        switch self {
        case .laser: return "LASER"
        case .plasma: return "PLASMA"
        case .pulse: return "PULSE"
        case .rail: return "RAIL"
        }
    }

    /// Key 1–4 selection order.
    var hotkeyIndex: Int {
        switch self {
        case .laser: return 1
        case .plasma: return 2
        case .pulse: return 3
        case .rail: return 4
        }
    }

    static func fromHotkey(_ n: Int) -> WeaponMode? {
        switch n {
        case 1: return .laser
        case 2: return .plasma
        case 3: return .pulse
        case 4: return .rail
        default: return nil
        }
    }

    /// Unknown future modes fall back to lasers so old clients / bad data still load.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = WeaponMode(rawValue: raw) ?? .laser
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

/// Cosmetic paint jobs for the player fighter (vector recolor).
enum ShipPaint: String, CaseIterable, Codable {
    case arctic
    case voidBlack
    case solarGold
    case nebulaViolet
    case cinderRed
    case laneCyan
    case militiaOlive
    case umbraChrome

    var displayName: String {
        switch self {
        case .arctic: return "Arctic White"
        case .voidBlack: return "Void Black"
        case .solarGold: return "Solar Gold"
        case .nebulaViolet: return "Nebula Violet"
        case .cinderRed: return "Cinder Red"
        case .laneCyan: return "Lane Cyan"
        case .militiaOlive: return "Militia Olive"
        case .umbraChrome: return "Umbra Chrome"
        }
    }

    /// Credits to unlock (arctic free).
    var unlockCost: Int {
        switch self {
        case .arctic: return 0
        case .laneCyan, .militiaOlive: return 400
        case .solarGold, .nebulaViolet: return 600
        case .cinderRed, .voidBlack: return 750
        case .umbraChrome: return 1000
        }
    }

    var hull: NSColor {
        switch self {
        case .arctic: return NSColor(calibratedRed: 0.78, green: 0.80, blue: 0.84, alpha: 1)
        case .voidBlack: return NSColor(calibratedRed: 0.14, green: 0.15, blue: 0.18, alpha: 1)
        case .solarGold: return NSColor(calibratedRed: 0.72, green: 0.62, blue: 0.35, alpha: 1)
        case .nebulaViolet: return NSColor(calibratedRed: 0.45, green: 0.35, blue: 0.62, alpha: 1)
        case .cinderRed: return NSColor(calibratedRed: 0.55, green: 0.28, blue: 0.26, alpha: 1)
        case .laneCyan: return NSColor(calibratedRed: 0.35, green: 0.62, blue: 0.72, alpha: 1)
        case .militiaOlive: return NSColor(calibratedRed: 0.40, green: 0.48, blue: 0.36, alpha: 1)
        case .umbraChrome: return NSColor(calibratedRed: 0.58, green: 0.58, blue: 0.62, alpha: 1)
        }
    }

    var highlight: NSColor {
        switch self {
        case .arctic: return NSColor(calibratedRed: 0.90, green: 0.92, blue: 0.95, alpha: 1)
        case .voidBlack: return NSColor(calibratedRed: 0.28, green: 0.30, blue: 0.34, alpha: 1)
        case .solarGold: return NSColor(calibratedRed: 0.95, green: 0.85, blue: 0.45, alpha: 1)
        case .nebulaViolet: return NSColor(calibratedRed: 0.72, green: 0.55, blue: 0.95, alpha: 1)
        case .cinderRed: return NSColor(calibratedRed: 0.95, green: 0.45, blue: 0.35, alpha: 1)
        case .laneCyan: return NSColor(calibratedRed: 0.55, green: 0.92, blue: 1.0, alpha: 1)
        case .militiaOlive: return NSColor(calibratedRed: 0.60, green: 0.75, blue: 0.50, alpha: 1)
        case .umbraChrome: return NSColor(calibratedRed: 0.85, green: 0.85, blue: 0.90, alpha: 1)
        }
    }

    var accent: NSColor {
        switch self {
        case .arctic: return Theme.player
        case .voidBlack: return NSColor(calibratedRed: 1.0, green: 0.35, blue: 0.4, alpha: 1)
        case .solarGold: return NSColor(calibratedRed: 1.0, green: 0.8, blue: 0.25, alpha: 1)
        case .nebulaViolet: return NSColor(calibratedRed: 0.75, green: 0.4, blue: 1.0, alpha: 1)
        case .cinderRed: return NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.2, alpha: 1)
        case .laneCyan: return Theme.accent
        case .militiaOlive: return NSColor(calibratedRed: 0.5, green: 0.85, blue: 0.45, alpha: 1)
        case .umbraChrome: return NSColor(calibratedRed: 0.7, green: 0.45, blue: 0.95, alpha: 1)
        }
    }

    var panel: NSColor {
        hull.blended(withFraction: 0.25, of: .black) ?? hull
    }

    var shadow: NSColor {
        hull.blended(withFraction: 0.45, of: .black) ?? hull
    }
}

/// Last-known commodity prices at a station (for galaxy map intel).
struct StationPriceIntel: Codable {
    var buyPrices: [Commodity: Int]
    var sellPrices: [Commodity: Int]
    /// Optional rolling averages (sell = what you pay, buy = what they pay you).
    var sellAvg: [Commodity: Int]? = nil
    var buyAvg: [Commodity: Int]? = nil
    var samples: Int? = nil
}

/// Rented cargo bay at Freeport 7 — store goods for arbitrage without a full hold.
struct PlayerWarehouse: Codable, Equatable {
    var rented: Bool = false
    var cargo: [Commodity: Int] = [:]

    static let systemName = "Solara"
    static let stationName = "Freeport 7"
    static let rentCost = 8_000
    /// Mass capacity of the bay (same units as ship cargo).
    static let bayCapacity: Float = 120
    /// Minimum police standing to rent (and must not be wanted).
    static let minPoliceRep = 0

    var usedMass: Float {
        cargo.reduce(0) { $0 + Float($1.value) * $1.key.unitMass }
    }

    var freeMass: Float { max(0, Self.bayCapacity - usedMass) }

    mutating func add(_ c: Commodity, amount: Int) -> Bool {
        guard amount > 0 else { return false }
        let mass = Float(amount) * c.unitMass
        guard usedMass + mass <= Self.bayCapacity + 0.01 else { return false }
        cargo[c, default: 0] += amount
        return true
    }

    mutating func remove(_ c: Commodity, amount: Int) -> Bool {
        let have = cargo[c, default: 0]
        guard have >= amount, amount > 0 else { return false }
        cargo[c] = have - amount
        if cargo[c] == 0 { cargo.removeValue(forKey: c) }
        return true
    }
}

/// Permanent stake at a station — better trade rates + named berth.
struct StationInvestment: Codable, Equatable {
    /// 1...maxLevel
    var level: Int
    /// Display name for your private berth.
    var berthName: String

    static let maxLevel = 3

    /// Credits to go from `level` → `level + 1` (level 0 = uninvested).
    static func upgradeCost(fromLevel level: Int) -> Int {
        switch level {
        case 0: return 5_000
        case 1: return 12_000
        case 2: return 28_000
        default: return 0
        }
    }

    /// Fraction off station sell price (what you pay when buying).
    var buyDiscount: Float {
        switch level {
        case 1: return 0.04
        case 2: return 0.07
        case 3: return 0.10
        default: return 0
        }
    }

    /// Fraction extra on station buy price (what they pay when you sell).
    var sellBonus: Float {
        switch level {
        case 1: return 0.06
        case 2: return 0.10
        case 3: return 0.15
        default: return 0
        }
    }

    /// Multiplier on hull repair cost (1 = full price).
    var repairMult: Float {
        switch level {
        case 1: return 0.90
        case 2: return 0.85
        case 3: return 0.75
        default: return 1
        }
    }

    var tierLabel: String {
        switch level {
        case 1: return "Shareholder"
        case 2: return "Partner"
        case 3: return "Patron"
        default: return "None"
        }
    }

    static func defaultBerthName(station: String) -> String {
        "Private Berth · \(station)"
    }
}

extension Player {
    static func stationKey(system: String, station: String) -> String {
        "\(system)/\(station)"
    }

    /// Non-nil investment map (empty if never invested / old save).
    var investments: [String: StationInvestment] {
        get { stationInvestments ?? [:] }
        set { stationInvestments = newValue }
    }

    func investment(system: String, station: String) -> StationInvestment? {
        investments[Self.stationKey(system: system, station: station)]
    }

    mutating func setInvestment(_ inv: StationInvestment, system: String, station: String) {
        var map = investments
        map[Self.stationKey(system: system, station: station)] = inv
        stationInvestments = map
    }
}

/// Buyable player hull archetype — freighter hold, interceptor guns, or hybrid.
enum PlayerShipClass: String, Codable, CaseIterable {
    case hybrid
    case freighter
    case interceptor

    var displayName: String {
        switch self {
        case .hybrid: return "Hybrid Fighter"
        case .freighter: return "Bulk Freighter"
        case .interceptor: return "Interceptor"
        }
    }

    var shortName: String {
        switch self {
        case .hybrid: return "Hybrid"
        case .freighter: return "Freighter"
        case .interceptor: return "Interceptor"
        }
    }

    var blurb: String {
        switch self {
        case .hybrid: return "Balanced combat freighter — starter hull"
        case .freighter: return "Huge hold, tough plates, slower guns"
        case .interceptor: return "Hard lasers & speed, tiny cargo bay"
        }
    }

    /// Credits to purchase (0 if already owned / starter).
    var purchaseCost: Int {
        switch self {
        case .hybrid: return 0
        case .freighter: return 4500
        case .interceptor: return 5200
        }
    }

    /// HullType used for player vector art.
    var hullType: HullType {
        switch self {
        case .hybrid: return .patrol // uses player art path separately
        case .freighter: return .freighter
        case .interceptor: return .interceptor
        }
    }
}

/// Faction standing & wanted state (optional on save for back-compat).
struct ReputationState: Codable {
    /// 0 clean … 5 maximum heat.
    var wantedLevel: Int = 0
    /// −100…100 standing with each faction group.
    var repPolice: Int = 0
    var repMilitia: Int = 0
    var repPirate: Int = 0
    var civiliansKilled: Int = 0
    var tradersKilled: Int = 0
    var lawKilled: Int = 0
    /// Hulls the pilot has purchased (hybrid always owned).
    var ownedShips: Set<PlayerShipClass> = [.hybrid]
    var shipClass: PlayerShipClass = .hybrid

    var isDirty: Bool { wantedLevel >= 1 || repPirate >= 25 }
    var isWanted: Bool { wantedLevel >= 1 }

    var wantedLabel: String {
        switch wantedLevel {
        case 0: return "Clean"
        case 1: return "Suspected"
        case 2: return "Wanted"
        case 3: return "Fugitive"
        case 4: return "Public Enemy"
        default: return "Most Wanted"
        }
    }

    func fineCost() -> Int {
        max(0, wantedLevel) * 750 + civiliansKilled * 100 + lawKilled * 400
    }

    mutating func clamp() {
        wantedLevel = min(5, max(0, wantedLevel))
        repPolice = min(100, max(-100, repPolice))
        repMilitia = min(100, max(-100, repMilitia))
        repPirate = min(100, max(-100, repPirate))
    }

    mutating func adjust(police: Int = 0, militia: Int = 0, pirate: Int = 0) {
        repPolice += police
        repMilitia += militia
        repPirate += pirate
        clamp()
    }

    mutating func addWanted(_ amount: Int) {
        wantedLevel = min(5, wantedLevel + max(0, amount))
    }

    mutating func clearWanted() {
        wantedLevel = 0
    }
}

/// Lifetime stats + achievement unlocks (saved with pilot).
struct PilotLog: Codable {
    var freelanesRidden: Int = 0
    var freightersSaved: Int = 0
    var stationKillsAssisted: Int = 0
    var lifetimeCreditsEarned: Int = 0
    var cargoPodsLooted: Int = 0
    var capitalsDestroyed: Int = 0
    var piratesDestroyed: Int = 0
    var docks: Int = 0
    var unlocked: Set<String> = []

    mutating func unlock(_ id: String) -> Bool {
        if unlocked.contains(id) { return false }
        unlocked.insert(id)
        return true
    }
}

enum Achievement: String, CaseIterable {
    case firstDock
    case firstFreelane
    case firstBlood
    case systemsFive
    case systemsTen
    case deepPockets
    case wingmanHired
    case capitalSlayer
    case freighterGuardian
    case storyComplete
    case ironmanVictory
    case wreckDiver
    case beyondTheVeil
    case firstContact
    case vaelTech
    case stationInvestor
    case stationPatron
    case warehouseBay
    case scannerAce
    case insuredPilot
    case loanShark
    case wingBoss
    case laneRaider
    case mineLayer
    case anomalyHunter
    case surveyorPro
    case laneWhisper
    case laneRacer
    case laneGhost

    var title: String {
        switch self {
        case .firstDock: return "Safe Harbor"
        case .firstFreelane: return "Lane Rider"
        case .firstBlood: return "First Blood"
        case .systemsFive: return "Surveyor"
        case .systemsTen: return "Cartographer"
        case .deepPockets: return "Deep Pockets"
        case .wingmanHired: return "Wing Leader"
        case .capitalSlayer: return "Capital Breaker"
        case .freighterGuardian: return "Convoy Shield"
        case .storyComplete: return "Frontier Ace"
        case .ironmanVictory: return "Ironman Ace"
        case .wreckDiver: return "Wreck Diver"
        case .beyondTheVeil: return "Beyond the Veil"
        case .firstContact: return "First Contact"
        case .vaelTech: return "Alien Alloy"
        case .stationInvestor: return "Stakeholder"
        case .stationPatron: return "Station Patron"
        case .warehouseBay: return "Bay Lease"
        case .scannerAce: return "Scanner Ace"
        case .insuredPilot: return "Insured Pilot"
        case .loanShark: return "Leveraged"
        case .wingBoss: return "Second Seat"
        case .laneRaider: return "Lane Raider"
        case .mineLayer: return "Mine Layer"
        case .anomalyHunter: return "Anomaly Hunter"
        case .surveyorPro: return "Probe Runner"
        case .laneWhisper: return "Lane Whisper"
        case .laneRacer: return "Lane Racer"
        case .laneGhost: return "Ghost Runner"
        }
    }

    var detail: String {
        switch self {
        case .firstDock: return "Dock at any station"
        case .firstFreelane: return "Ride a freelane"
        case .firstBlood: return "Destroy a pirate"
        case .systemsFive: return "Chart 5 systems"
        case .systemsTen: return "Chart all 10 frontier systems"
        case .deepPockets: return "Hold 25,000+ credits at once"
        case .wingmanHired: return "Hire a wingman"
        case .capitalSlayer: return "Destroy a pirate capital"
        case .freighterGuardian: return "Save 5 freighters from pirates"
        case .storyComplete: return "Finish the story chain"
        case .ironmanVictory: return "Finish the story on Ironman"
        case .wreckDiver: return "Discover 5 wrecks"
        case .beyondTheVeil: return "Enter Voidreach through a hidden wormhole"
        case .firstContact: return "Destroy a Vael alien ship"
        case .vaelTech: return "Purchase alien tech at a Vael base"
        case .stationInvestor: return "Buy a stake in any station"
        case .stationPatron: return "Reach Patron tier at any station"
        case .warehouseBay: return "Rent the Freeport 7 warehouse bay"
        case .scannerAce: return "Identify 10 ships with the scanner"
        case .insuredPilot: return "Buy hull insurance"
        case .loanShark: return "Take a freighter loan"
        case .wingBoss: return "Hire every wingman specialty"
        case .laneRaider: return "Complete a freelane raid contract"
        case .mineLayer: return "Detonate 5 proximity mines"
        case .anomalyHunter: return "Chart 5 anomaly sites"
        case .surveyorPro: return "Complete 3 probe survey missions"
        case .laneWhisper: return "Finish the freelane mystery thread"
        case .laneRacer: return "Set personal bests on 5 freelane time trials"
        case .laneGhost: return "Beat your own ghost on a freelane race"
        }
    }
}

// MARK: - Freelane time trials

/// Sparse path sample for ghost playback (saved with pilot).
struct FreelaneGhostSample: Codable, Equatable {
    var t: Float
    var x: Float
    var y: Float
    var angle: Float

    var position: SIMD2<Float> { SIMD2(x, y) }
}

/// Best end-to-end run on a freelane direction.
struct FreelaneRaceRecord: Codable, Equatable {
    var bestTime: Float
    var ghost: [FreelaneGhostSample]?
    var setAt: Date?
}

/// Hired escort specialty — gunner, scout, or freighter tug.
enum WingmanRole: String, CaseIterable, Codable {
    case gunner
    case scout
    case tug

    var displayName: String {
        switch self {
        case .gunner: return "Gunner"
        case .scout: return "Scout"
        case .tug: return "Freighter Tug"
        }
    }

    var shortName: String {
        switch self {
        case .gunner: return "GUN"
        case .scout: return "SCT"
        case .tug: return "TUG"
        }
    }

    var blurb: String {
        switch self {
        case .gunner: return "Hard guns & missiles — stays on your wing"
        case .scout: return "Fast eyes — long-range ID & harass"
        case .tug: return "Tanky hauler guard — prioritizes freighters"
        }
    }

    var hireCost: Int {
        switch self {
        case .gunner: return 1_400
        case .scout: return 1_200
        case .tug: return 1_100
        }
    }

    var callsign: String {
        switch self {
        case .gunner: return ["Vega Gun", "Ash Lead", "Red Lance", "Bolt"].randomElement()!
        case .scout: return ["Whisper", "Longlook", "Kite", "Picket"].randomElement()!
        case .tug: return ["Anchor", "Bulk Guard", "Tether", "Holdfast"].randomElement()!
        }
    }
}

/// Light story campaign stages.
enum StoryBeat {
    static let count = 4

    static func title(_ stage: Int) -> String {
        switch stage {
        case 0: return "Freelane License"
        case 1: return "First Bounty"
        case 2: return "Shadow Markets"
        case 3: return "Lane War"
        default: return "Campaign Complete"
        }
    }

    static func description(_ stage: Int) -> String {
        switch stage {
        case 0: return "Ride any freelane, then dock at Freeport 7 in Solara."
        case 1: return "Destroy 2 pirate ships, then dock at any station."
        case 2: return "Jump to Umbra and dock at any station there."
        case 3: return "Destroy a pirate capital ship (or finish a station defense)."
        default: return "You own the frontier."
        }
    }

    static func reward(_ stage: Int) -> Int {
        switch stage {
        case 0: return 400
        case 1: return 600
        case 2: return 900
        case 3: return 2000
        default: return 0
        }
    }

    static func target(_ stage: Int) -> Int {
        switch stage {
        case 0: return 1 // freelane used
        case 1: return 2 // pirate kills
        case 2: return 1 // umbra dock
        case 3: return 1 // capital or defense
        default: return 1
        }
    }
}

/// Rare salvage blueprints unlock permanent ship mods.
/// Alien (Vael) tech is only sold at Voidreach bases — not found on wrecks.
enum Blueprint: String, CaseIterable, Codable {
    case overchargedLasers
    case afterburnerCore
    case adaptiveShields
    case expandedHold
    case tractorArray
    case hullPlating
    /// Legendary freelane relic — bypass offline rings; L for temporary lane boost.
    case ancientLaneCore
    // Alien / Vael tech (purchase only in Voidreach)
    case vaelPlasma
    case voidShroud
    case graviticDrive
    case crystalLattice
    case phaseNeedle
    case neuralTractor

    var displayName: String {
        switch self {
        case .overchargedLasers: return "Overcharged Lasers"
        case .afterburnerCore: return "Afterburner Core"
        case .adaptiveShields: return "Adaptive Shields"
        case .expandedHold: return "Expanded Hold"
        case .tractorArray: return "Tractor Array"
        case .hullPlating: return "Reinforced Plating"
        case .ancientLaneCore: return "Ancient Lane Core"
        case .vaelPlasma: return "Vael Plasma Locus"
        case .voidShroud: return "Void Shroud"
        case .graviticDrive: return "Gravitic Drive"
        case .crystalLattice: return "Crystal Lattice Hull"
        case .phaseNeedle: return "Phase Needle Array"
        case .neuralTractor: return "Neural Tractor"
        }
    }

    var blurb: String {
        switch self {
        case .overchargedLasers: return "+25% laser damage"
        case .afterburnerCore: return "+15% thrust & top speed"
        case .adaptiveShields: return "+40% shield regen"
        case .expandedHold: return "+20 cargo capacity"
        case .tractorArray: return "+50% salvage tractor range"
        case .hullPlating: return "+25 max hull"
        case .ancientLaneCore: return "Bypass offline freelane rings · L free lane boost"
        case .vaelPlasma: return "+35% laser damage (alien)"
        case .voidShroud: return "+30 max shield · +20% regen (alien)"
        case .graviticDrive: return "+20% thrust & speed (alien)"
        case .crystalLattice: return "+40 max hull (alien)"
        case .phaseNeedle: return "Faster laser fire rate (alien)"
        case .neuralTractor: return "+80% salvage tractor range (alien)"
        }
    }

    var isAlien: Bool {
        switch self {
        case .vaelPlasma, .voidShroud, .graviticDrive, .crystalLattice, .phaseNeedle, .neuralTractor:
            return true
        default:
            return false
        }
    }

    /// Not found on random wrecks — mystery chain / silent fields only.
    var isLegendaryRelic: Bool {
        self == .ancientLaneCore
    }

    /// Credits to buy at a Vael base (0 if not for sale).
    var alienPurchaseCost: Int {
        switch self {
        case .vaelPlasma: return 8500
        case .voidShroud: return 7800
        case .graviticDrive: return 7200
        case .crystalLattice: return 8000
        case .phaseNeedle: return 9000
        case .neuralTractor: return 5500
        default: return 0
        }
    }

    static var alienTech: [Blueprint] {
        allCases.filter(\.isAlien)
    }

    static var salvageBlueprints: [Blueprint] {
        allCases.filter { !$0.isAlien && !$0.isLegendaryRelic }
    }
}

struct Player: Codable {
    var position: SIMD2<Float> = .zero
    var velocity: SIMD2<Float> = .zero
    var angle: Float = 0 // radians, 0 = right
    var hull: Float = 100
    var shield: Float = 80
    var credits: Int = 2500
    var cargo: [Commodity: Int] = [:]
    var stats: ShipStats = ShipStats()
    var weaponLevel: Int = 1
    var engineLevel: Int = 1
    var shieldLevel: Int = 1
    var cargoLevel: Int = 1
    /// Capacitor / power plant Mk (more energy + faster energy regen). Does not affect engines.
    var energyLevel: Int = 1
    var energy: Float = 100
    /// Primary DE weapon: lasers or plasma cannon.
    var weaponMode: WeaponMode = .laser
    /// Homing missiles (max 10); buy reloads at stations.
    var missiles: Int = 10
    static let maxMissiles = 10
    static let missilePackSize = 5
    static let missilePackCost = 450
    /// Proximity mines (hull class changes rack size).
    /// Optional for save back-compat (pre-1.0.21).
    var mines: Int? = 3
    static let minePackSize = 2
    static let minePackCost = 350
    /// Flare / chaff to break missile locks.
    /// Optional for save back-compat (pre-1.0.21).
    var countermeasures: Int? = 3
    static let cmPackSize = 2
    static let cmPackCost = 280

    /// Safe racks (defaults when loading older saves).
    var mineStock: Int {
        get { mines ?? 3 }
        set { mines = max(0, newValue) }
    }
    var cmStock: Int {
        get { countermeasures ?? 3 }
        set { countermeasures = max(0, newValue) }
    }
    /// Preferred wingman role when hiring (optional for old saves).
    var wingmanRole: WingmanRole? = nil
    var wingmanPaint: ShipPaint? = nil
    var wingmenLost: Int? = nil
    var kills: Int = 0
    var systemsVisited: Set<String> = ["Solara"]
    /// Keys: "SystemName/PlanetName"
    var discoveredPlanets: Set<String> = []
    /// Derelict stable keys: "SystemName/WreckName"
    var discoveredWrecks: Set<String> = []
    /// Wormhole keys: "SystemName/GateName" once the rift is scanned.
    var discoveredWormholes: Set<String> = []
    var unlockedBlueprints: Set<Blueprint> = []
    var aliensDestroyed: Int = 0
    var paintJob: ShipPaint = .arctic
    var ownedPaints: Set<ShipPaint> = [.arctic]
    /// Key: "SystemName/StationName"
    var marketIntel: [String: StationPriceIntel] = [:]
    /// Stake in stations: key "SystemName/StationName" → investment tier.
    /// Optional for save back-compat (pre-1.0.17).
    var stationInvestments: [String: StationInvestment]? = [:]
    /// Freeport 7 private warehouse bay (nil / not rented on old saves).
    var warehouse: PlayerWarehouse? = nil
    /// Concealed hold for smuggling contracts (pre-1.0.20 saves: nil).
    var hiddenCargo: [Commodity: Int]? = nil
    static let hiddenCargoCapacity: Float = 12
    /// Last successful dock (insurance respawn target).
    var lastDockSystem: String? = nil
    var lastDockStation: String? = nil
    /// Hull insurance — non-ironman death respawns at last dock for a fee.
    var hasInsurance: Bool? = nil
    static let insurancePremium = 800
    /// Outstanding freighter loan principal (0 / nil = none).
    var loanPrincipal: Int? = nil
    var loanMissedPayments: Int? = nil
    static let loanPaymentPerDock = 400
    static let freighterLoanAmount = 3500
    static let freighterLoanDownPayment = 1200
    /// Pirates ignore you while remaining flight-seconds > 0 (Umbra protection).
    var pirateProtectionSeconds: Float? = nil
    static let pirateProtectionFee = 1_500
    static let pirateProtectionDuration: Float = 600
    /// Saved trade routes (buy → sell hops).
    var savedRoutes: [TradeRoute]? = nil
    var pinnedRouteID: UUID? = nil
    /// Discovered anomaly keys "System/Name" (optional for old saves).
    var discoveredAnomalies: Set<String>? = nil
    /// Lane mystery thread: 0 = none, 1...3 = steps found, 4 = complete.
    var mysteryLaneStage: Int? = nil
    /// Temporary freelane super-cruise seconds remaining.
    var freelaneBoostSeconds: Float? = nil
    /// Survey missions completed (for achievement).
    var surveysCompleted: Int? = nil
    /// Freelane time-trial PBs: key "System|LaneName|dir" (dir = +1/−1).
    var freelaneRecords: [String: FreelaneRaceRecord]? = nil
    /// Count of distinct lanes with a PB (achievement helper).
    var freelanePBsSet: Int? = nil
    var missionsCompleted: Int = 0
    var discoveryCreditsEarned: Int = 0
    /// Campaign stage 0...3 active, 4 = complete.
    var storyStage: Int = 0
    var storyFreelaneDone: Bool = false
    var storyPirateKills: Int = 0
    var storyVisitedUmbra: Bool = false
    var storyCapitalKill: Bool = false
    /// Optional hardcore: death wipes autosave and blocks further saves this run.
    var ironmanMode: Bool = false
    var ironmanFailed: Bool = false
    /// Lifetime pilot log / achievements
    var log = PilotLog()
    /// Reputation, wanted, owned ship classes (nil on pre-1.0.8 saves).
    var reputation: ReputationState? = ReputationState()

    // MARK: - Reputation accessors (save-safe)

    var rep: ReputationState {
        get { reputation ?? ReputationState() }
        set { reputation = newValue }
    }

    var wantedLevel: Int {
        get { rep.wantedLevel }
        set { var r = rep; r.wantedLevel = min(5, max(0, newValue)); reputation = r }
    }

    var shipClass: PlayerShipClass {
        get { rep.shipClass }
        set { var r = rep; r.shipClass = newValue; reputation = r }
    }

    var isDirty: Bool { rep.isDirty }
    var isWanted: Bool { rep.isWanted }

    var cargoUsed: Float {
        cargo.reduce(0) { $0 + Float($1.value) * $1.key.unitMass }
    }

    var cargoFree: Float { max(0, stats.cargoCapacity - cargoUsed) }

    var tractorRangeBonus: Float {
        var m: Float = 1.0
        if unlockedBlueprints.contains(.tractorArray) { m *= 1.5 }
        if unlockedBlueprints.contains(.neuralTractor) { m *= 1.8 }
        return m
    }

    mutating func applyUpgradeLevels() {
        stats.maxHull = 100 + Float(engineLevel - 1) * 15
        stats.maxShield = 80 + Float(shieldLevel - 1) * 25
        stats.shieldRegen = 8 + Float(shieldLevel - 1) * 3
        stats.cargoCapacity = 40 + Float(cargoLevel - 1) * 20
        stats.thrust = 320 + Float(engineLevel - 1) * 55
        stats.maxSpeed = 360 + Float(engineLevel - 1) * 45
        stats.turnRate = 2.6 + Float(engineLevel - 1) * 0.22
        stats.laserDamage = 12 + Float(weaponLevel - 1) * 6
        stats.laserCooldown = max(0.10, 0.22 - Float(weaponLevel - 1) * 0.03)
        // Energy plant (weapons + shields only — engines independent)
        stats.maxEnergy = 100 + Float(energyLevel - 1) * 35
        stats.energyRegen = 20 + Float(energyLevel - 1) * 7
        stats.laserEnergyCost = 8 + Float(weaponLevel - 1) * 0.5
        stats.plasmaDamage = 26 + Float(weaponLevel - 1) * 10
        stats.plasmaCooldown = max(0.38, 0.58 - Float(weaponLevel - 1) * 0.035)
        stats.plasmaEnergyCost = 26 + Float(weaponLevel - 1) * 2
        stats.pulseDamage = 6 + Float(weaponLevel - 1) * 2.5
        stats.pulseCooldown = max(0.055, 0.09 - Float(weaponLevel - 1) * 0.007)
        stats.pulseEnergyCost = 3.5 + Float(weaponLevel - 1) * 0.25
        stats.railDamage = 42 + Float(weaponLevel - 1) * 14
        stats.railCooldown = max(0.65, 0.95 - Float(weaponLevel - 1) * 0.05)
        stats.railEnergyCost = 40 + Float(weaponLevel - 1) * 3
        stats.shieldEnergyPerPoint = 0.85

        // Ship class base profile (applied before blueprints)
        switch shipClass {
        case .hybrid:
            break
        case .freighter:
            stats.cargoCapacity *= 1.75
            stats.maxHull += 35
            stats.maxShield += 10
            stats.laserDamage *= 0.72
            stats.plasmaDamage *= 0.75
            stats.pulseDamage *= 0.78
            stats.railDamage *= 0.8
            stats.thrust *= 0.88
            stats.maxSpeed *= 0.82
            stats.turnRate *= 0.85
            stats.maxEnergy += 20
        case .interceptor:
            stats.laserDamage *= 1.4
            stats.plasmaDamage *= 1.25
            stats.pulseDamage *= 1.35
            stats.railDamage *= 1.2
            stats.laserCooldown = max(0.08, stats.laserCooldown * 0.85)
            stats.pulseCooldown = max(0.05, stats.pulseCooldown * 0.88)
            stats.thrust *= 1.2
            stats.maxSpeed *= 1.22
            stats.turnRate *= 1.15
            stats.cargoCapacity *= 0.5
            stats.maxHull -= 10
            stats.maxEnergy -= 10
        }

        // Blueprint mods (stack on top of Mk levels)
        if unlockedBlueprints.contains(.hullPlating) { stats.maxHull += 25 }
        if unlockedBlueprints.contains(.adaptiveShields) { stats.shieldRegen *= 1.4 }
        if unlockedBlueprints.contains(.expandedHold) { stats.cargoCapacity += 20 }
        if unlockedBlueprints.contains(.afterburnerCore) {
            stats.thrust *= 1.15
            stats.maxSpeed *= 1.15
        }
        if unlockedBlueprints.contains(.overchargedLasers) {
            stats.laserDamage *= 1.25
            stats.plasmaDamage *= 1.15
            stats.pulseDamage *= 1.2
            stats.railDamage *= 1.1
        }
        // Alien / Vael tech
        if unlockedBlueprints.contains(.vaelPlasma) {
            stats.laserDamage *= 1.35
            stats.plasmaDamage *= 1.3
            stats.pulseDamage *= 1.2
            stats.railDamage *= 1.25
        }
        if unlockedBlueprints.contains(.voidShroud) {
            stats.maxShield += 30
            stats.shieldRegen *= 1.2
        }
        if unlockedBlueprints.contains(.graviticDrive) {
            stats.thrust *= 1.2
            stats.maxSpeed *= 1.2
        }
        if unlockedBlueprints.contains(.crystalLattice) { stats.maxHull += 40 }
        if unlockedBlueprints.contains(.phaseNeedle) {
            stats.laserCooldown = max(0.07, stats.laserCooldown * 0.78)
            stats.plasmaCooldown = max(0.32, stats.plasmaCooldown * 0.9)
            stats.pulseCooldown = max(0.045, stats.pulseCooldown * 0.82)
            stats.railCooldown = max(0.55, stats.railCooldown * 0.92)
        }
        if unlockedBlueprints.contains(.neuralTractor) {
            // Applied via tractorRangeBonus
        }

        hull = min(hull, stats.maxHull)
        shield = min(shield, stats.maxShield)
        energy = min(energy, stats.maxEnergy)
        missiles = min(missiles, Player.maxMissiles)
        mineStock = min(mineStock, maxMinesForClass)
        cmStock = min(cmStock, maxCMForClass)
    }

    /// Fill defaults for optional fields omitted by older save files.
    mutating func normalizeSaveDefaults() {
        if mines == nil { mines = min(3, maxMinesForClass) }
        if countermeasures == nil { countermeasures = min(3, maxCMForClass) }
        if stationInvestments == nil { stationInvestments = [:] }
        if hiddenCargo == nil { hiddenCargo = [:] }
        if discoveredAnomalies == nil { discoveredAnomalies = [] }
        if mysteryLaneStage == nil { mysteryLaneStage = 0 }
        if surveysCompleted == nil { surveysCompleted = 0 }
        if wingmenLost == nil { wingmenLost = 0 }
        if loanMissedPayments == nil, loanPrincipal != nil { loanMissedPayments = 0 }
        mineStock = min(mineStock, maxMinesForClass)
        cmStock = min(cmStock, maxCMForClass)
        missiles = min(missiles, Player.maxMissiles)
    }

    /// Interceptors carry more ordnance; freighters fewer mines but more chaff.
    var maxMinesForClass: Int {
        switch shipClass {
        case .interceptor: return 8
        case .freighter: return 4
        case .hybrid: return 6
        }
    }

    var maxCMForClass: Int {
        switch shipClass {
        case .interceptor: return 6
        case .freighter: return 8
        case .hybrid: return 5
        }
    }

    /// Missile damage mult by hull (interceptors hit harder with racks).
    var missileDamageMult: Float {
        switch shipClass {
        case .interceptor: return 1.25
        case .freighter: return 0.85
        case .hybrid: return 1.0
        }
    }

    mutating func addCargo(_ c: Commodity, amount: Int) -> Bool {
        let mass = Float(amount) * c.unitMass
        guard cargoUsed + mass <= stats.cargoCapacity + 0.01 else { return false }
        cargo[c, default: 0] += amount
        return true
    }

    mutating func removeCargo(_ c: Commodity, amount: Int) -> Bool {
        let have = cargo[c, default: 0]
        guard have >= amount else { return false }
        cargo[c] = have - amount
        if cargo[c] == 0 { cargo.removeValue(forKey: c) }
        return true
    }

    // MARK: - Hidden (smuggler) hold

    var smuggleHold: [Commodity: Int] {
        get { hiddenCargo ?? [:] }
        set { hiddenCargo = newValue.isEmpty ? [:] : newValue }
    }

    var hiddenCargoUsed: Float {
        smuggleHold.reduce(0) { $0 + Float($1.value) * $1.key.unitMass }
    }

    var hiddenCargoFree: Float { max(0, Self.hiddenCargoCapacity - hiddenCargoUsed) }

    mutating func addHiddenCargo(_ c: Commodity, amount: Int) -> Bool {
        let mass = Float(amount) * c.unitMass
        guard hiddenCargoUsed + mass <= Self.hiddenCargoCapacity + 0.01 else { return false }
        var h = smuggleHold
        h[c, default: 0] += amount
        hiddenCargo = h
        return true
    }

    mutating func removeHiddenCargo(_ c: Commodity, amount: Int) -> Bool {
        var h = smuggleHold
        let have = h[c, default: 0]
        guard have >= amount else { return false }
        h[c] = have - amount
        if h[c] == 0 { h.removeValue(forKey: c) }
        hiddenCargo = h
        return true
    }

    var insured: Bool { hasInsurance == true }
    var loanOutstanding: Int { max(0, loanPrincipal ?? 0) }
    var protectionActive: Bool { (pirateProtectionSeconds ?? 0) > 0 }

    var routes: [TradeRoute] {
        get { savedRoutes ?? [] }
        set { savedRoutes = newValue }
    }

    var pinnedRoute: TradeRoute? {
        guard let id = pinnedRouteID else { return nil }
        return routes.first { $0.id == id }
    }

    var anomalyLog: Set<String> {
        get { discoveredAnomalies ?? [] }
        set { discoveredAnomalies = newValue }
    }

    var laneMystery: Int {
        get { mysteryLaneStage ?? 0 }
        set { mysteryLaneStage = newValue }
    }

    var freelaneBoostActive: Bool { (freelaneBoostSeconds ?? 0) > 0 }

    var hasAncientLaneCore: Bool { unlockedBlueprints.contains(.ancientLaneCore) }

    var laneRecords: [String: FreelaneRaceRecord] {
        get { freelaneRecords ?? [:] }
        set { freelaneRecords = newValue }
    }

    static func freelaneRaceKey(system: String, lane: String, direction: Int) -> String {
        "\(system)|\(lane)|\(direction >= 0 ? "+" : "-")"
    }

    func freelanePB(system: String, lane: String, direction: Int) -> FreelaneRaceRecord? {
        laneRecords[Self.freelaneRaceKey(system: system, lane: lane, direction: direction)]
    }

    mutating func setFreelanePB(
        system: String, lane: String, direction: Int,
        time: Float, ghost: [FreelaneGhostSample]
    ) -> Bool {
        let key = Self.freelaneRaceKey(system: system, lane: lane, direction: direction)
        var map = laneRecords
        let isNew: Bool
        if let old = map[key] {
            guard time < old.bestTime else { return false }
            isNew = false
        } else {
            isNew = true
        }
        // Cap ghost length for save size
        let capped = Self.downsampleGhost(ghost, maxSamples: 120)
        map[key] = FreelaneRaceRecord(bestTime: time, ghost: capped, setAt: Date())
        freelaneRecords = map
        if isNew {
            freelanePBsSet = (freelanePBsSet ?? 0) + 1
        }
        return true
    }

    private static func downsampleGhost(_ samples: [FreelaneGhostSample], maxSamples: Int) -> [FreelaneGhostSample] {
        guard samples.count > maxSamples, maxSamples > 2 else { return samples }
        var out: [FreelaneGhostSample] = []
        out.reserveCapacity(maxSamples)
        for i in 0..<maxSamples {
            let t = Float(i) / Float(maxSamples - 1)
            let idx = Int(t * Float(samples.count - 1))
            out.append(samples[idx])
        }
        return out
    }
}

// MARK: - Trade routes (saved buy→sell plans)

struct TradeRoute: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var buySystem: String
    var buyStation: String
    var sellSystem: String
    var sellStation: String
    var commodity: Commodity?

    var shortLabel: String {
        if let c = commodity {
            return "\(c.rawValue): \(buySystem) → \(sellSystem)"
        }
        return "\(buySystem)/\(buyStation) → \(sellSystem)/\(sellStation)"
    }
}

// MARK: - NPC ships

enum Faction: String, Codable {
    case pirate, trader, police, militia, alien

    var displayName: String {
        switch self {
        case .pirate: return "Pirate"
        case .trader: return "Civilian"
        case .police: return "Police"
        case .militia: return "Militia"
        case .alien: return "Vael"
        }
    }
}

/// Visual / role hull archetype (many cargo freighter classes).
enum HullType: String, CaseIterable {
    // Cargo / civilian
    case freighter
    case bulkHauler
    case tanker
    case containerShip
    case oreBarge
    case courier
    // Combat — pirates
    case pirateRaider
    case pirateGunship
    case pirateBomber
    // Combat — law
    case patrol
    case interceptor
    case policeEnforcer
    case militiaCutter
    case militiaFrigate
    // Combat — Vael
    case alienSkimmer
    case alienWarden
    case alienStalker

    var isCargo: Bool {
        switch self {
        case .freighter, .bulkHauler, .tanker, .containerShip, .oreBarge, .courier:
            return true
        default:
            return false
        }
    }

    var classLabel: String {
        switch self {
        case .freighter: return "Freighter"
        case .bulkHauler: return "Bulk Hauler"
        case .tanker: return "Tanker"
        case .containerShip: return "Container Ship"
        case .oreBarge: return "Ore Barge"
        case .courier: return "Courier"
        case .pirateRaider: return "Raider"
        case .pirateGunship: return "Gunship"
        case .pirateBomber: return "Bomber"
        case .patrol: return "Patrol"
        case .interceptor: return "Interceptor"
        case .policeEnforcer: return "Enforcer"
        case .militiaCutter: return "Cutter"
        case .militiaFrigate: return "Frigate"
        case .alienSkimmer: return "Vael Skimmer"
        case .alienWarden: return "Vael Warden"
        case .alienStalker: return "Vael Stalker"
        }
    }

    static var cargoTypes: [HullType] {
        [.freighter, .bulkHauler, .tanker, .containerShip, .oreBarge, .courier]
    }
}

struct NPCShip: Identifiable {
    let id: UUID
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var angle: Float
    var hull: Float
    var maxHull: Float
    var shield: Float
    var maxShield: Float
    var faction: Faction
    var hullType: HullType
    var targetID: UUID?
    var fireCooldown: Float
    var aiTimer: Float
    var dropCredits: Int
    var dropScrap: Int
    var name: String
    var speed: Float
    var damage: Float
    var radius: Float
    /// Homing missile racks (combat ships only).
    var missileAmmo: Int = 0
    var missileCooldown: Float = 0
    /// Player-hired escort.
    var isWingman: Bool = false
    /// Wingman specialty (runtime).
    var wingmanRole: WingmanRole? = nil
    /// Wingman paint job (runtime).
    var wingmanPaint: ShipPaint? = nil
    /// Rare large pirate capital.
    var isCapital: Bool = false
    /// Freighter engines knocked offline — can be boarded for cargo pods.
    var enginesDisabled: Bool = false
    /// Lootable cargo pods remaining after engines disabled.
    var cargoPodsRemaining: Int = 0
    /// NPC freelane cruise state (cargo traffic).
    var onTradeLane: Bool = false
    var tradeLaneID: UUID? = nil
    var tradeLaneRingIndex: Int = 0
    var tradeLaneDirection: Int = 1
    var tradeLaneProgress: Float = 0
    /// Sensor scan (runtime only — not saved).
    var scannedByPlayer: Bool = false
    /// Wanted / bounty flag shown after scan.
    var isWanted: Bool = false
    /// Cargo manifest revealed after scan.
    var manifest: [Commodity: Int] = [:]

    var isHostile: Bool { faction == .pirate || faction == .alien }
    var isCargo: Bool { hullType.isCargo || faction == .trader }
    var isAlien: Bool { faction == .alien }

    /// Cruise speed while locked to a freelane (slower than player for ambush gameplay).
    /// Tuned for expanded systems (~7× world scale).
    var freelaneCruiseSpeed: Float {
        if isCargo {
            switch hullType {
            case .courier: return 1_900
            case .bulkHauler, .oreBarge: return 1_350
            case .tanker: return 1_450
            case .containerShip: return 1_550
            default: return 1_600
            }
        }
        return 1_750
    }
}

// MARK: - Celestial bodies

struct Moon: Identifiable {
    let id: UUID
    var name: String
    var orbitRadius: Float
    var orbitSpeed: Float
    var orbitPhase: Float
    var radius: Float
    var color: (Float, Float, Float)

    func position(around center: SIMD2<Float>, time: Float) -> SIMD2<Float> {
        let a = orbitPhase + time * orbitSpeed
        return center + SIMD2(cos(a), sin(a)) * orbitRadius
    }
}

struct Planet: Identifiable {
    let id: UUID
    var name: String
    var position: SIMD2<Float>
    var radius: Float
    var color: (Float, Float, Float)
    var atmosphere: (Float, Float, Float)?
    var isGasGiant: Bool
    var bandColor: (Float, Float, Float)?
    var moons: [Moon]
}

struct SystemStar: Identifiable {
    let id: UUID
    var position: SIMD2<Float>
    var radius: Float
    var color: (Float, Float, Float)
    var name: String
}

/// Freelancer-style trade lane: ordered rings you cruise through at high speed.
struct TradeLane: Identifiable {
    let id: UUID
    var name: String
    /// Ordered ring centers (enter any ring, travel toward either end).
    var points: [SIMD2<Float>]
    var ringRadius: Float
    /// Ring index → seconds remaining disabled (pirates sabotage).
    var disruptedRings: [Int: Float] = [:]

    func isRingDisrupted(_ index: Int) -> Bool {
        (disruptedRings[index] ?? 0) > 0
    }

    func nearestRingIndex(to pos: SIMD2<Float>) -> Int? {
        guard !points.isEmpty else { return nil }
        var best = 0
        var bestD = distance(pos, points[0])
        for i in 1..<points.count {
            let d = distance(pos, points[i])
            if d < bestD {
                bestD = d
                best = i
            }
        }
        return best
    }
}

// MARK: - Station / gate / asteroid

struct MarketOffer: Codable {
    var buyPrice: Int   // what station pays you
    var sellPrice: Int  // what you pay station
    var stock: Int
}

struct Station: Identifiable {
    let id: UUID
    var name: String
    var position: SIMD2<Float>
    var radius: Float
    var market: [Commodity: MarketOffer]
    var repairCostPerHull: Int
    var faction: String
    var description: String
    /// Combat: how far turrets will engage hostiles.
    var defenseRange: Float
    var turretDamage: Float
    var turretCooldownMax: Float
    /// Runtime fire timer (seconds remaining).
    var turretCooldown: Float
    /// Angle of active turret aim (for VFX).
    var turretAim: Float
    /// Pirate dens / hostile strongholds — turrets fire on law (and on you if not allied).
    var isEnemyBase: Bool = false

    var dockRadius: Float { radius + 55 }
    var hasDefenses: Bool { defenseRange > 0 && turretDamage > 0 }
    /// Pirate Clan dens and similar outlaw strongholds.
    var isPirateBase: Bool {
        isEnemyBase || faction == "Pirate Clan" || faction == "Corsairs"
    }
    /// Black-market / outlaw docks that welcome dirty pilots.
    var isOutlawDock: Bool {
        isPirateBase
            || faction == "Unaligned"
            || name.localizedCaseInsensitiveContains("Black Market")
            || name.localizedCaseInsensitiveContains("Quiet Hold")
            || name.localizedCaseInsensitiveContains("Night Market")
    }
}

struct JumpGate: Identifiable {
    let id: UUID
    var position: SIMD2<Float>
    var radius: Float
    var destinationSystem: String
    var destinationSpawn: SIMD2<Float>
    var name: String
    /// Unstable rift — dim until scanned; not a standard freelane gate.
    var isWormhole: Bool = false
    /// How close the pilot must fly to mark it discovered (world units).
    var discoveryRadius: Float { isWormhole ? radius + 320 : 0 }

    var wormholeKey: String { "\(destinationSystem)|\(name)" }
}

struct Asteroid: Identifiable {
    let id: UUID
    var position: SIMD2<Float>
    var radius: Float
    var ore: Int
    var angle: Float
    var spin: Float
}

/// Abandoned wreck — mine for scrap; rare blueprints for ship mods.
struct Derelict: Identifiable {
    let id: UUID
    /// Stable name used for discovery keys (not UUID).
    var name: String
    var position: SIMD2<Float>
    var radius: Float
    var scrap: Int
    var blueprint: Blueprint?
    var angle: Float
    var spin: Float

    var mineRadius: Float { radius + 48 }
    var discoveryRadius: Float { radius + 220 }
}

enum ProjectileSource: Equatable {
    case player
    case enemy
    case station
}

enum ProjectileKind: Equatable {
    case laser
    case plasma
    case pulse
    case rail
    case missile
    case mine
}

struct Projectile: Identifiable {
    let id: UUID
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var damage: Float
    var life: Float
    var source: ProjectileSource
    var ownerID: UUID?
    var kind: ProjectileKind = .laser
    /// Homing target NPC for missiles.
    var targetID: UUID? = nil
    /// Homing lock on the player (enemy missiles).
    var tracksPlayer: Bool = false
    /// Radians/sec turn for guided weapons.
    var turnRate: Float = 0
    var speed: Float = 0

    var fromPlayer: Bool { source == .player }
}

struct Particle: Identifiable {
    let id: UUID
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var life: Float
    var maxLife: Float
    var color: (Float, Float, Float)
    var size: Float
}

struct LootDrop: Identifiable {
    let id: UUID
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var credits: Int
    var scrap: Int
    var life: Float
    /// Soft bob phase for visuals.
    var phase: Float
}

// MARK: - In-system navigation

/// Pilot-selected waypoint for in-system flying (not saved).
enum NavWaypoint: Equatable {
    case station(UUID)
    case gate(UUID)
    case escort
    /// Mission destination station by name (resolved in current system).
    case missionStation(name: String)
}

// MARK: - Missions

enum MissionKind: Codable, Equatable {
    case bounty(targetFaction: Faction, count: Int)
    case delivery(commodity: Commodity, amount: Int, destStation: String, destSystem: String)
    case patrol(kills: Int)
    case explore(system: String)
    /// Defend named station until capital/assault ends or timer kills reached.
    case stationDefense(stationName: String, system: String, killsNeeded: Int)
    /// Protect a bulk hauler / tanker to a destination station (freelane ambushes apply).
    case escort(destStation: String, destSystem: String, haulerName: String)
    /// Pirate career: hit freighters on a named freelane (law responds).
    case freelaneRaid(laneName: String, system: String, freightersNeeded: Int)
    /// Drop a survey beacon at a planet, wreck field, or anomaly; turn in for pay.
    case survey(targetName: String, system: String, kind: SurveyTargetKind)
}

enum SurveyTargetKind: String, Codable, Equatable {
    case planet
    case wreck
    case anomaly

    var label: String {
        switch self {
        case .planet: return "planet"
        case .wreck: return "wreck field"
        case .anomaly: return "anomaly"
        }
    }
}

// MARK: - Anomaly sites

enum AnomalyKind: String, Codable, Equatable {
    /// Unstable jump pocket — short-range teleport + discovery pay.
    case jumpPocket
    /// Silent wreck field — cold hulls, rare relic chance.
    case silentField
    /// Freelane mystery echo (thread step 1...3).
    case laneEcho
}

struct AnomalySite: Identifiable {
    let id: UUID
    var name: String
    var kind: AnomalyKind
    var position: SIMD2<Float>
    var radius: Float
    /// 1...3 for lane mystery thread; nil = standalone.
    var mysteryStep: Int?

    var discoveryRadius: Float { radius + 220 }
    var interactRadius: Float { radius + 55 }

    var flavor: String {
        switch kind {
        case .jumpPocket: return "Unstable jump pocket — spatial shear"
        case .silentField: return "Silent wreck field — no IFF, no chatter"
        case .laneEcho: return "Lane echo — freelane ghost signal"
        }
    }
}

// MARK: - Environment zones (nebula, radiation, storms…)

/// Localized space weather / scenic fields inside a system.
enum EnvironmentKind: String, CaseIterable {
    case nebula
    case radiation
    case ionStorm
    case dust
    case ice
    case gravSheer
    case emBlackout

    var displayName: String {
        switch self {
        case .nebula: return "Nebula"
        case .radiation: return "Radiation Field"
        case .ionStorm: return "Ion Storm"
        case .dust: return "Dust Cloud"
        case .ice: return "Cryo Field"
        case .gravSheer: return "Grav Sheer"
        case .emBlackout: return "EM Blackout"
        }
    }

    var shortAlert: String {
        switch self {
        case .nebula: return "NEBULA"
        case .radiation: return "RADIATION"
        case .ionStorm: return "ION STORM"
        case .dust: return "DUST"
        case .ice: return "CRYO"
        case .gravSheer: return "GRAV SHEER"
        case .emBlackout: return "EM BLACKOUT"
        }
    }

    var blurb: String {
        switch self {
        case .nebula: return "Pretty gas — scanners struggle"
        case .radiation: return "Hull/shield damage over time"
        case .ionStorm: return "Drains energy · weapons sluggish"
        case .dust: return "Thrust and top speed reduced"
        case .ice: return "Turn rate reduced · chilling"
        case .gravSheer: return "Pulls your vector off course"
        case .emBlackout: return "Sensors fail · hard to scan"
        }
    }
}

struct EnvironmentZone: Identifiable {
    let id: UUID
    var name: String
    var kind: EnvironmentKind
    var position: SIMD2<Float>
    var radius: Float
    /// 0.4…1.2 — strength of gameplay effects.
    var intensity: Float

    func contains(_ pos: SIMD2<Float>) -> Bool {
        distance(pos, position) <= radius
    }

    /// Strength while inside: full power in the inner ~55%, then linear to the rim.
    /// Minimum ~40% of intensity anywhere inside so the edge still feels bad.
    func strength(at pos: SIMD2<Float>) -> Float {
        let d = distance(pos, position)
        guard d <= radius else { return 0 }
        let edge = d / max(1, radius) // 0 center → 1 rim
        let core: Float
        if edge <= 0.55 {
            core = 1.0
        } else {
            core = max(0, (1.0 - edge) / 0.45)
        }
        return max(0.4, core) * max(0.5, intensity)
    }
}

/// Combined modifiers while flying through environment zones.
struct EnvironmentEffects {
    var labels: [String] = []
    var scanMult: Float = 1
    var thrustMult: Float = 1
    var speedMult: Float = 1
    var turnMult: Float = 1
    var energyDrainPerSec: Float = 0
    var damagePerSec: Float = 0
    var gravPull: SIMD2<Float> = .zero
    var sensorsBlind: Bool = false
    var weaponCooldownMult: Float = 1

    var isHazardous: Bool {
        damagePerSec > 0.01 || energyDrainPerSec > 0.01 || sensorsBlind
            || thrustMult < 0.95 || turnMult < 0.95 || speedMult < 0.95
    }

    var primaryAlert: String? {
        labels.first
    }
}

/// Deployed proximity mine (runtime — not saved).
struct SpaceMine: Identifiable {
    let id: UUID
    var position: SIMD2<Float>
    var armTimer: Float
    var life: Float
    var radius: Float
    var damage: Float
    var fromPlayer: Bool
}

struct Mission: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var kind: MissionKind
    var reward: Int
    var progress: Int
    var target: Int
    var completed: Bool
    var offeredAtStation: String
    var offeredAtSystem: String
    /// Live countdown (seconds). Nil = untimed / old saves.
    var timeRemaining: Float? = nil
    /// Original limit when accepted (display).
    var timeLimit: Float? = nil
    /// Cargo stowed in hidden hold; turn-in pulls from smuggle bay.
    var isSmuggle: Bool? = nil
    /// Law scan while active tanks militia rep + heat.
    var isDirty: Bool? = nil
    /// Bounty requires identify-scan before kill credit (default true for new bounties).
    var requiresScan: Bool? = nil
}

// MARK: - Game phases

enum GamePhase: Equatable {
    case title
    case playing
    case docked
    case paused
    case dead
    case howToPlay
    case settings
    case galaxyMap
    /// Full-screen in-system map — pick a destination.
    case systemMap
    /// Free-fly camera (world frozen) for screenshots / ship art.
    case photo
    /// Pick a manual slot (1...3) to write.
    case saveSlots
    /// Pick autosave or slot 1...3 to load.
    case loadSlots
    case logbook
}

/// Selectable destination on the expanded system map.
struct SystemMapEntry: Equatable, Identifiable {
    enum Kind: Equatable {
        case station
        case gate
        case escort
        case planet
        case wreck
        case anomaly
    }

    var id: String
    var kind: Kind
    var title: String
    var subtitle: String
    var position: SIMD2<Float>
    /// Nil for info-only markers (planets/wrecks) that aren't fly-to nav targets.
    var waypoint: NavWaypoint?
}

enum StationTab: Int, CaseIterable {
    case status, trade, warehouse, missions, outfit, undock

    var title: String {
        switch self {
        case .status: return "Status"
        case .trade: return "Trade"
        case .warehouse: return "Warehouse"
        case .missions: return "Missions"
        case .outfit: return "Outfit"
        case .undock: return "Undock"
        }
    }
}

// MARK: - Helpers

func angleToVector(_ a: Float) -> SIMD2<Float> {
    SIMD2(cos(a), sin(a))
}

func distance(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
    simd_length(a - b)
}

func normalizeSafe(_ v: SIMD2<Float>) -> SIMD2<Float> {
    let l = simd_length(v)
    if l < 0.0001 { return .zero }
    return v / l
}

func angleToward(_ from: SIMD2<Float>, _ to: SIMD2<Float>) -> Float {
    let d = to - from
    return atan2(d.y, d.x)
}

func wrapAngle(_ a: Float) -> Float {
    var x = a
    while x > .pi { x -= 2 * .pi }
    while x < -.pi { x += 2 * .pi }
    return x
}

func lerpAngle(_ from: Float, _ to: Float, _ t: Float) -> Float {
    let d = wrapAngle(to - from)
    return wrapAngle(from + d * min(1, max(0, t)))
}
