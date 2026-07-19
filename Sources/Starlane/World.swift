import Foundation
import simd

struct StarSystem {
    let name: String
    let displayName: String
    let blurb: String
    var stations: [Station]
    var gates: [JumpGate]
    var asteroids: [Asteroid]
    var planets: [Planet]
    var tradeLanes: [TradeLane]
    var wrecks: [Derelict]
    var anomalies: [AnomalySite] = []
    /// Localized hazards and scenic fields (nebula, radiation, dust…).
    var environmentZones: [EnvironmentZone] = []
    var star: SystemStar?
    var spawn: SIMD2<Float>
    var bounds: Float
    var piratePressure: Float
    var nebulaTint: (Float, Float, Float)
}

enum GalaxyBuilder {
    /// Multiplier applied to all system layouts after authoring.
    /// Free flight should be a long haul; freelanes are the fast path.
    /// ~7× → gate hops ~25–30k units (~50–70s free flight at typical cruise).
    static let worldScale: Float = 7.0
    /// Target spacing between freelane rings after scaling (world units).
    static let freelaneRingSpacing: Float = 1_100

    /// Known frontier systems (galaxy map always lists these).
    static let systemNames = [
        "Solara", "Vesper", "Ironreach", "Cinder", "Azurel",
        "Nyx", "Helion", "Drift", "Kestrel", "Umbra",
    ]

    /// Outer sector — only appears after the wormhole is found / Voidreach is visited.
    static let outerSystemNames = ["Voidreach"]

    static var allSystemNames: [String] { systemNames + outerSystemNames }

    static let stationCatalog: [String: [String]] = [
        "Solara": ["Freeport 7", "Helios Depot", "Solara Relay"],
        "Vesper": ["Night Market", "Twilight Yard", "Silk Hab"],
        "Ironreach": ["Forge Station", "Border Watch", "Slag Anchorage"],
        "Cinder": ["Ashport", "Ember Outpost"],
        "Azurel": ["Coral Lab", "Reef Anchorage", "Tide Array"],
        "Nyx": ["Eclipse Dock", "Shadow Buoy"],
        "Helion": ["Sunspan Exchange", "Corona Yard"],
        "Drift": ["Belt Haven", "Prospector's Rest"],
        "Kestrel": ["Fort Kestrel", "Wing Barracks"],
        "Umbra": ["Black Market Ring", "Quiet Hold"],
        "Voidreach": ["Spire of Vael", "Resonance Anchorage"],
    ]

    static func build() -> [String: StarSystem] {
        var systems: [String: StarSystem] = [:]

        // ========== SOLARA ==========
        let solFreeport = SIMD2<Float>(0, 0)
        let solHelios = SIMD2<Float>(2800, -1600)
        let solRelay = SIMD2<Float>(-2400, 2800)
        let solGateV = SIMD2<Float>(4200, 400)
        let solGateI = SIMD2<Float>(-3400, 3000)
        let solGateH = SIMD2<Float>(900, -4000)

        systems["Solara"] = StarSystem(
            name: "Solara", displayName: "Solara System",
            blurb: "Core trade hub. Trade lanes stitch the inner worlds together.",
            stations: [
                makeStation("Freeport 7", solFreeport, "Independent",
                            "Bustling freeport at the lane hub.", .electronics, .food, .ore),
                makeStation("Helios Depot", solHelios, "Solar Corp",
                            "Industrial outpost near Helios III.", .fuelCells, .fuelCells, .medical),
                makeStation("Solara Relay", solRelay, "Independent",
                            "Outer relay on the Ironreach lane.", .electronics, .electronics, .scrap),
            ],
            gates: [
                gate(solGateV, "Vesper", SIMD2(-3800, 0)),
                gate(solGateI, "Ironreach", SIMD2(3600, -500)),
                gate(solGateH, "Helion", SIMD2(-400, 3800)),
            ],
            asteroids:
                field(SIMD2(-2200, -2000), 20, 550, 3...9) +
                field(SIMD2(3200, 2200), 14, 400, 2...7),
            planets: [
                planet("Solara Prime", SIMD2(-900, 700), 160,
                       (0.25, 0.45, 0.85), atmo: (0.4, 0.65, 1.0), gas: false,
                       moons: [
                        moon("Lumen", 240, 0.18, 28, (0.7, 0.7, 0.75)),
                        moon("Ashen", 340, -0.12, 18, (0.55, 0.5, 0.45)),
                       ]),
                planet("Helios III", SIMD2(2400, -1100), 120,
                       (0.85, 0.55, 0.25), atmo: (1.0, 0.7, 0.3), gas: false,
                       moons: [moon("Spark", 190, 0.25, 16, (0.6, 0.55, 0.5))]),
                planet("Cirrus", SIMD2(1800, 2600), 200,
                       (0.55, 0.6, 0.9), atmo: (0.6, 0.7, 1.0), gas: true,
                       bands: (0.7, 0.75, 0.95),
                       moons: [moon("Nimbus", 300, 0.1, 22, (0.8, 0.8, 0.85))]),
            ],
            tradeLanes: [
                lane("Lane · Freeport ↔ Helios", [solFreeport, solHelios], rings: 6),
                lane("Lane · Freeport ↔ Relay", [solFreeport, solRelay], rings: 6),
                lane("Lane · Freeport ↔ Vesper Gate", [solFreeport, solGateV], rings: 7),
                lane("Lane · Freeport ↔ Ironreach Gate", [solFreeport, solGateI], rings: 7),
                lane("Lane · Freeport ↔ Helion Gate", [solFreeport, solGateH], rings: 7),
                lane("Lane · Helios ↔ Helion Gate", [solHelios, solGateH], rings: 5),
            ],
            wrecks: [],
            star: SystemStar(id: UUID(), position: SIMD2(-3200, -2800), radius: 220,
                             color: (1.0, 0.92, 0.55), name: "Solara"),
            spawn: SIMD2(180, 120),
            bounds: 5200,
            piratePressure: 0.65,
            nebulaTint: (0.12, 0.22, 0.45)
        )

        // ========== VESPER ==========
        let vesMarket = SIMD2<Float>(0, 200)
        let vesYard = SIMD2<Float>(-2600, 2300)
        let vesSilk = SIMD2<Float>(3000, -2000)
        let vesGateS = SIMD2<Float>(-4000, 0)
        let vesGateA = SIMD2<Float>(3200, -3000)
        let vesGateC = SIMD2<Float>(1600, 3800)
        let vesGateN = SIMD2<Float>(-2000, -3600)

        systems["Vesper"] = StarSystem(
            name: "Vesper", displayName: "Vesper System",
            blurb: "Twilight markets linked by violet trade lanes.",
            stations: [
                makeStation("Night Market", vesMarket, "Merchants Guild",
                            "Luxury goods and medical supplies.", .luxury, .luxury, .weapons),
                makeStation("Twilight Yard", vesYard, "Merchants Guild",
                            "Outfitters and electronics.", .electronics, .electronics, .ore),
                makeStation("Silk Hab", vesSilk, "Merchants Guild",
                            "High-end habitat. Pays for luxury.", .luxury, .medical, .scrap),
            ],
            gates: [
                gate(vesGateS, "Solara", SIMD2(3900, 350)),
                gate(vesGateA, "Azurel", SIMD2(-3000, 1200)),
                gate(vesGateC, "Cinder", SIMD2(-1200, -3400)),
                gate(vesGateN, "Nyx", SIMD2(3600, 500)),
            ],
            asteroids: field(SIMD2(2200, 1500), 16, 450, 2...7) + field(SIMD2(-1500, -2400), 12, 350, 2...6),
            planets: [
                planet("Vesper", SIMD2(600, -400), 180,
                       (0.55, 0.25, 0.65), atmo: (0.75, 0.4, 0.9), gas: false,
                       moons: [
                        moon("Dusk", 270, 0.15, 24, (0.5, 0.4, 0.55)),
                        moon("Gloam", 380, -0.09, 14, (0.4, 0.35, 0.45)),
                       ]),
                planet("Nocturne", SIMD2(-2000, 1600), 140,
                       (0.2, 0.15, 0.35), atmo: (0.4, 0.3, 0.55), gas: false,
                       moons: [moon("Wisp", 210, 0.2, 15, (0.65, 0.6, 0.7))]),
            ],
            tradeLanes: [
                lane("Lane · Market ↔ Yard", [vesMarket, vesYard], rings: 6),
                lane("Lane · Market ↔ Silk", [vesMarket, vesSilk], rings: 6),
                lane("Lane · Market ↔ Solara Gate", [vesMarket, vesGateS], rings: 7),
                lane("Lane · Market ↔ Azurel Gate", [vesMarket, vesGateA], rings: 7),
                lane("Lane · Market ↔ Cinder Gate", [vesMarket, vesGateC], rings: 7),
                lane("Lane · Market ↔ Nyx Gate", [vesMarket, vesGateN], rings: 7),
                lane("Lane · Silk ↔ Azurel Gate", [vesSilk, vesGateA], rings: 4),
            ],
            wrecks: [],
            star: SystemStar(id: UUID(), position: SIMD2(3800, 3200), radius: 180,
                             color: (0.85, 0.55, 1.0), name: "Vesper"),
            spawn: SIMD2(-3800, 0),
            bounds: 5000,
            piratePressure: 1.0,
            nebulaTint: (0.35, 0.12, 0.40)
        )

        // ========== IRONREACH ==========
        let irnForge = SIMD2<Float>(200, -80)
        let irnBorder = SIMD2<Float>(-2000, -3000)
        let irnSlag = SIMD2<Float>(3400, 2200)
        let irnGateS = SIMD2<Float>(3800, -400)
        let irnGateC = SIMD2<Float>(-4000, 1200)
        let irnGateD = SIMD2<Float>(500, 4000)
        let irnGateK = SIMD2<Float>(-3000, -3600)

        systems["Ironreach"] = StarSystem(
            name: "Ironreach", displayName: "Ironreach System",
            blurb: "Foundries and ore lanes. Trade rings hum with freighters.",
            stations: [
                makeStation("Forge Station", irnForge, "Iron Combine",
                            "Heavy industry. Ore cheap.", .ore, .ore, .electronics),
                makeStation("Border Watch", irnBorder, "Militia",
                            "Militia garrison. Weapons & contracts.", .weapons, .weapons, .food),
                makeStation("Slag Anchorage", irnSlag, "Iron Combine",
                            "Scrap and reclamation.", .scrap, .scrap, .medical),
            ],
            gates: [
                gate(irnGateS, "Solara", SIMD2(-3200, 2800)),
                gate(irnGateC, "Cinder", SIMD2(3600, 600)),
                gate(irnGateD, "Drift", SIMD2(-400, -3800)),
                gate(irnGateK, "Kestrel", SIMD2(3200, 900)),
            ],
            asteroids:
                field(SIMD2(1500, 2500), 28, 650, 4...14) +
                field(SIMD2(-2800, 400), 18, 480, 3...11),
            planets: [
                planet("Ironreach", SIMD2(-600, 400), 150,
                       (0.55, 0.35, 0.22), atmo: (0.7, 0.45, 0.25), gas: false,
                       moons: [moon("Anvil", 230, 0.16, 20, (0.45, 0.4, 0.38))]),
                planet("Slag Giant", SIMD2(2000, 1600), 240,
                       (0.7, 0.4, 0.2), atmo: (0.9, 0.5, 0.25), gas: true,
                       bands: (0.85, 0.55, 0.3),
                       moons: [
                        moon("Cinderlet", 340, 0.11, 26, (0.5, 0.35, 0.3)),
                        moon("Spar", 450, -0.08, 14, (0.4, 0.38, 0.35)),
                       ]),
            ],
            tradeLanes: [
                lane("Lane · Forge ↔ Border", [irnForge, irnBorder], rings: 6),
                lane("Lane · Forge ↔ Slag", [irnForge, irnSlag], rings: 6),
                lane("Lane · Forge ↔ Solara Gate", [irnForge, irnGateS], rings: 7),
                lane("Lane · Forge ↔ Cinder Gate", [irnForge, irnGateC], rings: 7),
                lane("Lane · Forge ↔ Drift Gate", [irnForge, irnGateD], rings: 7),
                lane("Lane · Border ↔ Kestrel Gate", [irnBorder, irnGateK], rings: 5),
                lane("Lane · Slag ↔ Drift Gate", [irnSlag, irnGateD], rings: 5),
            ],
            wrecks: [],
            star: SystemStar(id: UUID(), position: SIMD2(-3600, -3200), radius: 200,
                             color: (1.0, 0.7, 0.35), name: "Ironreach"),
            spawn: SIMD2(3600, -450),
            bounds: 5200,
            piratePressure: 1.35,
            nebulaTint: (0.40, 0.22, 0.10)
        )

        // ========== CINDER ==========
        let cinAsh = SIMD2<Float>(0, 0)
        let cinEmber = SIMD2<Float>(-3000, 2300)
        let cinGateV = SIMD2<Float>(-1400, -3600)
        let cinGateI = SIMD2<Float>(3800, 700)
        let cinGateU = SIMD2<Float>(2200, 3600)

        systems["Cinder"] = StarSystem(
            name: "Cinder", displayName: "Cinder System",
            blurb: "Burned worlds. Broken lanes and hot salvage.",
            stations: [
                makeStation("Ashport", cinAsh, "Frontier",
                            "Last honest dock. Expensive repairs.", .scrap, .scrap, .medical, repairMult: 1.6),
                makeStation("Ember Outpost", cinEmber, "Frontier",
                            "Mining camp on a dead moon's orbit.", .ore, .ore, .food, repairMult: 1.5),
            ],
            gates: [
                gate(cinGateV, "Vesper", SIMD2(1500, 3600)),
                gate(cinGateI, "Ironreach", SIMD2(-3800, 1100)),
                gate(cinGateU, "Umbra", SIMD2(-3200, -900)),
            ],
            asteroids:
                field(SIMD2(-2500, 1800), 24, 580, 5...15) +
                field(SIMD2(2700, -2200), 18, 480, 4...13),
            planets: [
                planet("Cinder", SIMD2(800, -600), 170,
                       (0.7, 0.2, 0.12), atmo: (0.9, 0.3, 0.15), gas: false,
                       moons: [moon("Char", 250, 0.2, 18, (0.35, 0.3, 0.28))]),
                planet("Pyre", SIMD2(-1800, 1200), 280,
                       (0.9, 0.35, 0.15), atmo: (1.0, 0.45, 0.2), gas: true,
                       bands: (1.0, 0.55, 0.25),
                       moons: [moon("Soot", 380, 0.09, 22, (0.3, 0.28, 0.28))]),
            ],
            tradeLanes: [
                lane("Lane · Ashport ↔ Ember", [cinAsh, cinEmber], rings: 6),
                lane("Lane · Ashport ↔ Vesper Gate", [cinAsh, cinGateV], rings: 6),
                lane("Lane · Ashport ↔ Ironreach Gate", [cinAsh, cinGateI], rings: 7),
                lane("Lane · Ashport ↔ Umbra Gate", [cinAsh, cinGateU], rings: 7),
                lane("Lane · Ember ↔ Umbra Gate", [cinEmber, cinGateU], rings: 5),
            ],
            wrecks: [],
            star: SystemStar(id: UUID(), position: SIMD2(3400, -3000), radius: 190,
                             color: (1.0, 0.4, 0.2), name: "Cinder"),
            spawn: SIMD2(-1300, -3400),
            bounds: 4800,
            piratePressure: 1.9,
            nebulaTint: (0.50, 0.12, 0.10)
        )

        // ========== AZUREL ==========
        let azuCoral = SIMD2<Float>(-200, 100)
        let azuReef = SIMD2<Float>(2800, -2300)
        let azuTide = SIMD2<Float>(-3200, 2000)
        let azuGateV = SIMD2<Float>(-3200, 1300)
        let azuGateH = SIMD2<Float>(3800, 400)
        let azuGateN = SIMD2<Float>(900, 3800)

        systems["Azurel"] = StarSystem(
            name: "Azurel", displayName: "Azurel System",
            blurb: "Blue nebulae. Calm lanes between research habitats.",
            stations: [
                makeStation("Coral Lab", azuCoral, "Science Collective",
                            "Medical research station.", .medical, .medical, .ore),
                makeStation("Reef Anchorage", azuReef, "Independent",
                            "Quiet anchorage. Good food prices.", .food, .food, .fuelCells),
                makeStation("Tide Array", azuTide, "Science Collective",
                            "Sensor array studying the azure tides.", .electronics, .medical, .weapons),
            ],
            gates: [
                gate(azuGateV, "Vesper", SIMD2(3000, -2800)),
                gate(azuGateH, "Helion", SIMD2(-3800, -700)),
                gate(azuGateN, "Nyx", SIMD2(-1400, -3600)),
            ],
            asteroids: field(SIMD2(1200, 2700), 12, 360, 2...6) + field(SIMD2(-2000, -1800), 10, 300, 2...6),
            planets: [
                planet("Azurel", SIMD2(400, 500), 190,
                       (0.15, 0.55, 0.7), atmo: (0.3, 0.85, 0.9), gas: false,
                       moons: [
                        moon("Pearl", 280, 0.14, 22, (0.85, 0.9, 0.95)),
                        moon("Kelp", 390, -0.1, 14, (0.3, 0.5, 0.4)),
                       ]),
                planet("Thalassa", SIMD2(-1600, -900), 220,
                       (0.2, 0.4, 0.75), atmo: (0.35, 0.6, 0.95), gas: true,
                       bands: (0.4, 0.7, 0.9),
                       moons: [moon("Spray", 320, 0.12, 20, (0.7, 0.85, 0.9))]),
            ],
            tradeLanes: [
                lane("Lane · Coral ↔ Reef", [azuCoral, azuReef], rings: 6),
                lane("Lane · Coral ↔ Tide", [azuCoral, azuTide], rings: 6),
                lane("Lane · Coral ↔ Vesper Gate", [azuCoral, azuGateV], rings: 6),
                lane("Lane · Coral ↔ Helion Gate", [azuCoral, azuGateH], rings: 7),
                lane("Lane · Coral ↔ Nyx Gate", [azuCoral, azuGateN], rings: 7),
                lane("Lane · Reef ↔ Helion Gate", [azuReef, azuGateH], rings: 5),
            ],
            wrecks: [],
            star: SystemStar(id: UUID(), position: SIMD2(3000, 3200), radius: 170,
                             color: (0.55, 0.95, 1.0), name: "Azurel"),
            spawn: SIMD2(-3000, 1200),
            bounds: 5000,
            piratePressure: 0.8,
            nebulaTint: (0.10, 0.40, 0.38)
        )

        // ========== NYX ==========
        let nyxDock = SIMD2<Float>(100, -80)
        let nyxBuoy = SIMD2<Float>(-2800, -2600)
        let nyxGateV = SIMD2<Float>(3800, 600)
        let nyxGateA = SIMD2<Float>(-1600, -3800)
        let nyxGateU = SIMD2<Float>(2500, 3600)
        let nyxGateD = SIMD2<Float>(-3800, 1400)

        systems["Nyx"] = StarSystem(
            name: "Nyx", displayName: "Nyx System",
            blurb: "Dim stars. Long freelane runs through the dark.",
            stations: [
                makeStation("Eclipse Dock", nyxDock, "Independent",
                            "Deep-range freeport.", .electronics, .scrap, .food),
                makeStation("Shadow Buoy", nyxBuoy, "Independent",
                            "Nav buoy. Thin supplies.", .scrap, .scrap, .luxury),
            ],
            gates: [
                gate(nyxGateV, "Vesper", SIMD2(-1800, -3400)),
                gate(nyxGateA, "Azurel", SIMD2(800, 3600)),
                gate(nyxGateU, "Umbra", SIMD2(-900, 3600)),
                gate(nyxGateD, "Drift", SIMD2(3600, 700)),
                // Hidden wormhole — far off freelanes; scan to chart
                wormhole(SIMD2(-4100, -3800), "Voidreach", SIMD2(200, -200),
                         name: "Unstable Rift"),
            ],
            asteroids: field(SIMD2(1800, -1500), 20, 500, 4...12) + field(SIMD2(-2200, 2200), 16, 400, 3...10)
                + field(SIMD2(-3800, -3400), 12, 350, 2...8),
            planets: [
                planet("Nyx", SIMD2(-500, 300), 140,
                       (0.15, 0.12, 0.28), atmo: (0.25, 0.2, 0.45), gas: false,
                       moons: [moon("Umbrel", 220, 0.17, 16, (0.3, 0.28, 0.4))]),
                planet("Erebus", SIMD2(1600, 1800), 260,
                       (0.12, 0.1, 0.22), atmo: (0.2, 0.15, 0.35), gas: true,
                       bands: (0.25, 0.18, 0.4),
                       moons: [
                        moon("Shade", 360, 0.08, 24, (0.35, 0.32, 0.4)),
                        moon("Veil", 480, -0.06, 12, (0.25, 0.22, 0.3)),
                       ]),
            ],
            tradeLanes: [
                lane("Lane · Eclipse ↔ Buoy", [nyxDock, nyxBuoy], rings: 6),
                lane("Lane · Eclipse ↔ Vesper Gate", [nyxDock, nyxGateV], rings: 7),
                lane("Lane · Eclipse ↔ Azurel Gate", [nyxDock, nyxGateA], rings: 7),
                lane("Lane · Eclipse ↔ Umbra Gate", [nyxDock, nyxGateU], rings: 7),
                lane("Lane · Eclipse ↔ Drift Gate", [nyxDock, nyxGateD], rings: 7),
            ],
            wrecks: [],
            star: SystemStar(id: UUID(), position: SIMD2(-3400, 3000), radius: 140,
                             color: (0.45, 0.4, 0.9), name: "Nyx"),
            spawn: SIMD2(3600, 500),
            bounds: 5200,
            piratePressure: 1.45,
            nebulaTint: (0.08, 0.06, 0.22)
        )

        // ========== HELION ==========
        let helEx = SIMD2<Float>(0, 200)
        let helCor = SIMD2<Float>(3200, 1800)
        let helGateS = SIMD2<Float>(-600, 4000)
        let helGateA = SIMD2<Float>(-4000, -800)
        let helGateK = SIMD2<Float>(3800, -2300)

        systems["Helion"] = StarSystem(
            name: "Helion", displayName: "Helion System",
            blurb: "Solar sails and packed trade corridors.",
            stations: [
                makeStation("Sunspan Exchange", helEx, "Solar Corp",
                            "Primary exchange. Food & fuel cells.", .food, .food, .ore),
                makeStation("Corona Yard", helCor, "Solar Corp",
                            "Shipyard and power-cell manufactory.", .fuelCells, .fuelCells, .weapons),
            ],
            gates: [
                gate(helGateS, "Solara", SIMD2(800, -3800)),
                gate(helGateA, "Azurel", SIMD2(3600, 350)),
                gate(helGateK, "Kestrel", SIMD2(-3600, -500)),
            ],
            asteroids: field(SIMD2(-1800, -2200), 14, 400, 2...8),
            planets: [
                planet("Helion", SIMD2(500, -300), 200,
                       (0.95, 0.75, 0.25), atmo: (1.0, 0.85, 0.4), gas: false,
                       moons: [moon("Ray", 300, 0.15, 20, (0.8, 0.75, 0.6))]),
                planet("Photara", SIMD2(-1400, 1600), 300,
                       (1.0, 0.85, 0.4), atmo: (1.0, 0.9, 0.5), gas: true,
                       bands: (1.0, 0.7, 0.3),
                       moons: [moon("Glint", 420, 0.1, 28, (0.9, 0.85, 0.7))]),
            ],
            tradeLanes: [
                lane("Lane · Exchange ↔ Corona", [helEx, helCor], rings: 6),
                lane("Lane · Exchange ↔ Solara Gate", [helEx, helGateS], rings: 7),
                lane("Lane · Exchange ↔ Azurel Gate", [helEx, helGateA], rings: 7),
                lane("Lane · Exchange ↔ Kestrel Gate", [helEx, helGateK], rings: 7),
                lane("Lane · Corona ↔ Solara Gate", [helCor, helGateS], rings: 5),
            ],
            wrecks: [],
            star: SystemStar(id: UUID(), position: SIMD2(-2800, -3000), radius: 260,
                             color: (1.0, 0.95, 0.55), name: "Helion"),
            spawn: SIMD2(-500, 3800),
            bounds: 5200,
            piratePressure: 0.9,
            nebulaTint: (0.55, 0.42, 0.12)
        )

        // ========== DRIFT ==========
        let drfHaven = SIMD2<Float>(0, 0)
        let drfRest = SIMD2<Float>(3600, -2800)
        let drfGateI = SIMD2<Float>(-600, -4000)
        let drfGateN = SIMD2<Float>(3800, 800)
        let drfGateK = SIMD2<Float>(-3600, 2000)

        systems["Drift"] = StarSystem(
            name: "Drift", displayName: "Drift Belt",
            blurb: "A shattered world's bones. Lanes thread the rock fields.",
            stations: [
                makeStation("Belt Haven", drfHaven, "Prospector's Union",
                            "Hollowed rock station. Ore floods markets.", .ore, .ore, .medical),
                makeStation("Prospector's Rest", drfRest, "Prospector's Union",
                            "Claim office and spare parts.", .scrap, .ore, .electronics),
            ],
            gates: [
                gate(drfGateI, "Ironreach", SIMD2(400, 3800)),
                gate(drfGateN, "Nyx", SIMD2(-3600, 1300)),
                gate(drfGateK, "Kestrel", SIMD2(1000, -3600)),
            ],
            asteroids:
                field(SIMD2(1500, 1200), 36, 900, 5...16) +
                field(SIMD2(-2200, -1200), 30, 750, 4...14) +
                field(SIMD2(500, -3000), 22, 550, 3...12),
            planets: [
                planet("Shard", SIMD2(-800, 900), 110,
                       (0.5, 0.45, 0.4), atmo: nil, gas: false,
                       moons: [moon("Chip", 170, 0.22, 12, (0.45, 0.42, 0.4))]),
                planet("Remnant", SIMD2(2000, -600), 160,
                       (0.4, 0.38, 0.35), atmo: (0.5, 0.45, 0.4), gas: false,
                       moons: []),
            ],
            tradeLanes: [
                lane("Lane · Haven ↔ Rest", [drfHaven, drfRest], rings: 7),
                lane("Lane · Haven ↔ Ironreach Gate", [drfHaven, drfGateI], rings: 7),
                lane("Lane · Haven ↔ Nyx Gate", [drfHaven, drfGateN], rings: 7),
                lane("Lane · Haven ↔ Kestrel Gate", [drfHaven, drfGateK], rings: 7),
                lane("Lane · Rest ↔ Ironreach Gate", [drfRest, drfGateI], rings: 5),
            ],
            wrecks: [],
            star: SystemStar(id: UUID(), position: SIMD2(3200, 3400), radius: 150,
                             color: (0.85, 0.8, 0.7), name: "Drift Primary"),
            spawn: SIMD2(-500, -3800),
            bounds: 5400,
            piratePressure: 1.5,
            nebulaTint: (0.32, 0.28, 0.22)
        )

        // ========== KESTREL ==========
        let kesFort = SIMD2<Float>(0, 100)
        let kesWing = SIMD2<Float>(-2600, 2800)
        let kesGateI = SIMD2<Float>(3600, 900)
        let kesGateH = SIMD2<Float>(-3800, -600)
        let kesGateD = SIMD2<Float>(900, -3800)
        let kesGateU = SIMD2<Float>(3000, 3600)

        systems["Kestrel"] = StarSystem(
            name: "Kestrel", displayName: "Kestrel System",
            blurb: "Militia stronghold. Secured freelanes between forts.",
            stations: [
                makeStation("Fort Kestrel", kesFort, "Militia",
                            "Fortified command dock.", .weapons, .weapons, .luxury),
                makeStation("Wing Barracks", kesWing, "Militia",
                            "Patrol wing barracks.", .weapons, .fuelCells, .ore),
            ],
            gates: [
                gate(kesGateI, "Ironreach", SIMD2(-2800, -3400)),
                gate(kesGateH, "Helion", SIMD2(3600, -2100)),
                gate(kesGateD, "Drift", SIMD2(-3400, 1900)),
                gate(kesGateU, "Umbra", SIMD2(400, -3800)),
            ],
            asteroids: field(SIMD2(2200, -1800), 14, 380, 3...9),
            planets: [
                planet("Kestrel", SIMD2(400, -200), 155,
                       (0.3, 0.4, 0.65), atmo: (0.4, 0.55, 0.85), gas: false,
                       moons: [moon("Talon", 240, 0.18, 18, (0.5, 0.5, 0.55))]),
                planet("Aerie", SIMD2(-1200, 1400), 200,
                       (0.35, 0.45, 0.7), atmo: (0.45, 0.6, 0.9), gas: true,
                       bands: (0.5, 0.65, 0.85),
                       moons: [moon("Nest", 300, 0.11, 20, (0.55, 0.55, 0.6))]),
            ],
            tradeLanes: [
                lane("Lane · Fort ↔ Barracks", [kesFort, kesWing], rings: 6),
                lane("Lane · Fort ↔ Ironreach Gate", [kesFort, kesGateI], rings: 7),
                lane("Lane · Fort ↔ Helion Gate", [kesFort, kesGateH], rings: 7),
                lane("Lane · Fort ↔ Drift Gate", [kesFort, kesGateD], rings: 7),
                lane("Lane · Fort ↔ Umbra Gate", [kesFort, kesGateU], rings: 7),
                lane("Lane · Barracks ↔ Umbra Gate", [kesWing, kesGateU], rings: 5),
            ],
            wrecks: [],
            star: SystemStar(id: UUID(), position: SIMD2(-3000, -3200), radius: 180,
                             color: (0.6, 0.75, 1.0), name: "Kestrel"),
            spawn: SIMD2(3400, 850),
            bounds: 5000,
            piratePressure: 0.75,
            nebulaTint: (0.22, 0.30, 0.48)
        )

        // ========== UMBRA ==========
        let umbRing = SIMD2<Float>(80, -40)
        let umbHold = SIMD2<Float>(-3200, 1800)
        let umbGateC = SIMD2<Float>(-3600, -1100)
        let umbGateN = SIMD2<Float>(-1100, 3800)
        let umbGateK = SIMD2<Float>(400, -4000)

        systems["Umbra"] = StarSystem(
            name: "Umbra", displayName: "Umbra System",
            blurb: "Where cargo manifests go to die. Shadowed freelanes.",
            stations: [
                makeStation("Black Market Ring", umbRing, "Unaligned",
                            "No questions. High prices both ways.", .luxury, .weapons, .food, repairMult: 1.4),
                makeStation("Quiet Hold", umbHold, "Unaligned",
                            "Sealed warehouse station.", .luxury, .luxury, .medical, repairMult: 1.35),
            ],
            gates: [
                gate(umbGateC, "Cinder", SIMD2(2000, 3400)),
                gate(umbGateN, "Nyx", SIMD2(2400, 3400)),
                gate(umbGateK, "Kestrel", SIMD2(2800, 3400)),
            ],
            asteroids: field(SIMD2(2000, 2200), 18, 450, 4...12) + field(SIMD2(-1400, -2500), 14, 400, 3...10),
            planets: [
                planet("Umbra", SIMD2(600, 400), 170,
                       (0.35, 0.12, 0.45), atmo: (0.5, 0.2, 0.65), gas: false,
                       moons: [moon("Mute", 250, 0.16, 16, (0.4, 0.3, 0.45))]),
                planet("Obsidian", SIMD2(-1500, -800), 250,
                       (0.15, 0.08, 0.2), atmo: (0.3, 0.12, 0.35), gas: true,
                       bands: (0.25, 0.1, 0.3),
                       moons: [moon("Ink", 360, 0.09, 22, (0.2, 0.15, 0.25))]),
            ],
            tradeLanes: [
                lane("Lane · Ring ↔ Hold", [umbRing, umbHold], rings: 6),
                lane("Lane · Ring ↔ Cinder Gate", [umbRing, umbGateC], rings: 7),
                lane("Lane · Ring ↔ Nyx Gate", [umbRing, umbGateN], rings: 7),
                lane("Lane · Ring ↔ Kestrel Gate", [umbRing, umbGateK], rings: 7),
                lane("Lane · Hold ↔ Nyx Gate", [umbHold, umbGateN], rings: 5),
            ],
            wrecks: [],
            star: SystemStar(id: UUID(), position: SIMD2(3400, -3000), radius: 160,
                             color: (0.7, 0.35, 0.9), name: "Umbra"),
            spawn: SIMD2(-3400, -1000),
            bounds: 5000,
            piratePressure: 1.75,
            nebulaTint: (0.18, 0.05, 0.28)
        )

        // ========== VOIDREACH (outer sector — wormhole only) ==========
        let vaelSpire = SIMD2<Float>(0, 400)
        let vaelResonance = SIMD2<Float>(3200, -2400)
        let voidRift = SIMD2<Float>(-200, -150) // exit near spawn
        let voidEdge = SIMD2<Float>(-3600, 3200)

        systems["Voidreach"] = StarSystem(
            name: "Voidreach", displayName: "Voidreach (Outer Sector)",
            blurb: "Beyond the charts. The Vael built cities in the dark.",
            stations: [
                makeStation("Spire of Vael", vaelSpire, "Vael Collective",
                            "Alien basalt spire. Sells impossible tech.", .electronics, .luxury, .food,
                            repairMult: 1.6),
                makeStation("Resonance Anchorage", vaelResonance, "Vael Collective",
                            "Harmonic docks — gravity feels wrong here.", .weapons, .medical, .ore,
                            repairMult: 1.5),
            ],
            gates: [
                // Only way home
                wormhole(voidRift, "Nyx", SIMD2(-3900, -3600), name: "Return Rift"),
            ],
            asteroids:
                field(SIMD2(1800, 2200), 16, 500, 5...14) +
                field(SIMD2(-2800, -2000), 18, 480, 4...12) +
                field(voidEdge, 10, 300, 3...9),
            planets: [
                planet("Vael Prime", SIMD2(-1200, 900), 190,
                       (0.25, 0.85, 0.55), atmo: (0.4, 1.0, 0.7), gas: false,
                       moons: [moon("Shard", 280, 0.14, 20, (0.5, 0.9, 0.7))]),
                planet("Glassmere", SIMD2(2400, 1600), 280,
                       (0.15, 0.35, 0.55), atmo: (0.3, 0.55, 0.85), gas: true,
                       bands: (0.4, 0.75, 0.9),
                       moons: [
                        moon("Echo", 400, 0.07, 26, (0.35, 0.6, 0.7)),
                        moon("Whisper", 520, -0.05, 14, (0.25, 0.5, 0.6)),
                       ]),
                planet("Nullseed", SIMD2(-2200, -1800), 110,
                       (0.55, 0.2, 0.7), atmo: (0.7, 0.3, 0.9), gas: false,
                       moons: []),
            ],
            tradeLanes: [
                // Alien "corridors" — still freelane-compatible rings
                lane("Corridor · Spire ↔ Resonance", [vaelSpire, vaelResonance], rings: 7),
                lane("Corridor · Spire ↔ Rift", [vaelSpire, voidRift], rings: 4),
            ],
            wrecks: [],
            star: SystemStar(id: UUID(), position: SIMD2(3800, 3600), radius: 180,
                             color: (0.35, 1.0, 0.75), name: "Vael Light"),
            spawn: SIMD2(80, -80),
            bounds: 5400,
            piratePressure: 0.2, // not pirates — aliens spawn specially
            nebulaTint: (0.05, 0.22, 0.18)
        )

        // Scatter wreck fields after base layout is fixed
        for key in systems.keys {
            systems[key]!.wrecks = makeWrecks(for: systems[key]!)
        }
        // Anomaly sites + lane-mystery thread (Nyx → Umbra → Drift)
        injectAnomalies(into: &systems)
        // Nebulae, radiation belts, dust, storms…
        injectEnvironmentZones(into: &systems)
        // Expand space so freelanes matter (free flight is lengthy)
        scaleSystems(&systems, by: worldScale)

        return systems
    }

    /// Scenic + hazardous fields authored in base coords (scaled with the system).
    private static func injectEnvironmentZones(into systems: inout [String: StarSystem]) {
        func zone(
            _ name: String, _ kind: EnvironmentKind,
            _ pos: SIMD2<Float>, _ radius: Float, intensity: Float = 1
        ) -> EnvironmentZone {
            EnvironmentZone(
                id: UUID(), name: name, kind: kind,
                position: pos, radius: radius, intensity: intensity
            )
        }
        func set(_ system: String, _ zones: [EnvironmentZone]) {
            systems[system]?.environmentZones = zones
        }

        set("Solara", [
            zone("Helios Veil", .nebula, SIMD2(2200, -1400), 900, intensity: 0.7),
            zone("Inner Belt Dust", .dust, SIMD2(-1800, -1600), 700, intensity: 0.85),
            zone("Relay Corona", .radiation, SIMD2(-2100, 2600), 450, intensity: 0.55),
        ])
        set("Vesper", [
            zone("Twilight Nebula", .nebula, SIMD2(400, 800), 1_100, intensity: 0.9),
            zone("Silk Ion Wake", .ionStorm, SIMD2(-1600, -1200), 650, intensity: 0.8),
            zone("Night Market Haze", .dust, SIMD2(0, -200), 500, intensity: 0.6),
        ])
        set("Ironreach", [
            zone("Slag Radiation", .radiation, SIMD2(1600, 1400), 800, intensity: 1.0),
            zone("Forge Dust Plume", .dust, SIMD2(-400, 200), 750, intensity: 0.9),
            zone("Ore Grav Trough", .gravSheer, SIMD2(-2000, -800), 600, intensity: 0.85),
        ])
        set("Cinder", [
            zone("Ash Storm", .dust, SIMD2(0, 0), 1_200, intensity: 1.05),
            zone("Ember Radiation", .radiation, SIMD2(-1200, 1000), 900, intensity: 1.15),
            zone("Pyre Ion Front", .ionStorm, SIMD2(1800, -1400), 700, intensity: 1.0),
            zone("Burnt Nebula", .nebula, SIMD2(900, 1600), 800, intensity: 0.75),
        ])
        set("Azurel", [
            zone("Reef Mist", .nebula, SIMD2(600, 400), 950, intensity: 0.8),
            zone("Thalassa Cryo", .ice, SIMD2(-1400, -700), 850, intensity: 0.9),
            zone("Tide Dust", .dust, SIMD2(2000, -1600), 550, intensity: 0.65),
        ])
        set("Nyx", [
            zone("Umbrel Dark", .emBlackout, SIMD2(-900, 400), 750, intensity: 1.0),
            zone("Erebus Nebula", .nebula, SIMD2(1400, 1600), 1_200, intensity: 1.0),
            zone("Shadow Radiation", .radiation, SIMD2(-2800, -2400), 700, intensity: 0.85),
            zone("Rim Grav Sheer", .gravSheer, SIMD2(3000, -800), 650, intensity: 0.9),
        ])
        set("Helion", [
            zone("Corona Radiation", .radiation, SIMD2(-800, 2800), 1_000, intensity: 1.2),
            zone("Photara Wind", .ionStorm, SIMD2(-1200, 1400), 800, intensity: 0.95),
            zone("Sunspan Glow", .nebula, SIMD2(400, -200), 700, intensity: 0.6),
        ])
        set("Drift", [
            zone("Belt Dust Sea", .dust, SIMD2(800, 400), 1_400, intensity: 1.1),
            zone("Shard Ice Pocket", .ice, SIMD2(-1600, 1200), 700, intensity: 0.85),
            zone("Null Grav Trench", .gravSheer, SIMD2(400, -2200), 800, intensity: 0.95),
            zone("Prospector Haze", .nebula, SIMD2(-600, -400), 600, intensity: 0.7),
        ])
        set("Kestrel", [
            zone("Patrol Corridor Clear", .nebula, SIMD2(1200, 800), 500, intensity: 0.45),
            zone("Outer Dust", .dust, SIMD2(-2000, -1600), 700, intensity: 0.75),
            zone("Aerie Ion", .ionStorm, SIMD2(-1000, 1600), 550, intensity: 0.7),
        ])
        set("Umbra", [
            zone("Black Market Smog", .dust, SIMD2(200, 100), 650, intensity: 0.8),
            zone("Mute Nebula", .nebula, SIMD2(-1400, -900), 1_100, intensity: 1.05),
            zone("Quiet EM Shadow", .emBlackout, SIMD2(-2800, 1600), 800, intensity: 1.1),
            zone("Obsidian Radiation", .radiation, SIMD2(1600, 1800), 750, intensity: 0.9),
        ])
        set("Voidreach", [
            zone("Vael Lattice Glow", .nebula, SIMD2(0, 600), 1_000, intensity: 0.95),
            zone("Resonance Storm", .ionStorm, SIMD2(2800, -2000), 900, intensity: 1.15),
            zone("Nullseed Blackout", .emBlackout, SIMD2(-2000, -1600), 850, intensity: 1.2),
            zone("Glassmere Sheer", .gravSheer, SIMD2(2200, 1400), 700, intensity: 1.0),
            zone("Outer Hard Radiation", .radiation, SIMD2(-2800, 2400), 1_000, intensity: 1.25),
        ])
    }

    /// Scale positions/bounds only — keep station radii, ship dock ranges, ring hitboxes playable.
    private static func scaleSystems(_ systems: inout [String: StarSystem], by s: Float) {
        guard s != 1 else { return }
        for key in systems.keys {
            var sys = systems[key]!
            sys.bounds *= s
            sys.spawn *= s
            for i in sys.stations.indices {
                sys.stations[i].position *= s
            }
            for i in sys.gates.indices {
                sys.gates[i].position *= s
                sys.gates[i].destinationSpawn *= s
            }
            for i in sys.asteroids.indices {
                sys.asteroids[i].position *= s
            }
            for i in sys.planets.indices {
                // Body radii stay local-scale so docking/survey ranges feel normal
                sys.planets[i].position *= s
            }
            for i in sys.wrecks.indices {
                sys.wrecks[i].position *= s
            }
            for i in sys.anomalies.indices {
                sys.anomalies[i].position *= s
            }
            for i in sys.environmentZones.indices {
                sys.environmentZones[i].position *= s
                sys.environmentZones[i].radius *= s
            }
            if var star = sys.star {
                star.position *= s
                sys.star = star
            }
            // Freelanes: scale endpoints then re-ring for good density on long hauls
            sys.tradeLanes = sys.tradeLanes.map { lane in
                let pts = lane.points.map { $0 * s }
                return densifyLane(
                    TradeLane(id: lane.id, name: lane.name, points: pts, ringRadius: lane.ringRadius),
                    spacing: freelaneRingSpacing
                )
            }
            systems[key] = sys
        }
    }

    /// Rebuild freelane rings along first→last with roughly even spacing.
    private static func densifyLane(_ lane: TradeLane, spacing: Float) -> TradeLane {
        guard lane.points.count >= 2 else { return lane }
        let a = lane.points[0]
        let b = lane.points[lane.points.count - 1]
        let len = max(1, distance(a, b))
        let n = max(5, Int(len / max(200, spacing)) + 1)
        var points: [SIMD2<Float>] = []
        points.reserveCapacity(n)
        for i in 0..<n {
            let t = Float(i) / Float(n - 1)
            points.append(a + (b - a) * t)
        }
        return TradeLane(id: lane.id, name: lane.name, points: points, ringRadius: lane.ringRadius)
    }

    /// Unstable pockets, silent fields, and freelane mystery echoes.
    private static func injectAnomalies(into systems: inout [String: StarSystem]) {
        func add(_ system: String, _ sites: [AnomalySite]) {
            systems[system]?.anomalies = sites
        }

        // Mystery thread steps 1–3
        add("Nyx", [
            AnomalySite(id: UUID(), name: "Lane Echo Alpha", kind: .laneEcho,
                        position: SIMD2(-3200, -2900), radius: 70, mysteryStep: 1),
            AnomalySite(id: UUID(), name: "Shear Pocket", kind: .jumpPocket,
                        position: SIMD2(2400, 2100), radius: 55, mysteryStep: nil),
            AnomalySite(id: UUID(), name: "Cold Quiet", kind: .silentField,
                        position: SIMD2(-800, 1600), radius: 90, mysteryStep: nil),
        ])
        add("Umbra", [
            AnomalySite(id: UUID(), name: "Quiet Fracture", kind: .laneEcho,
                        position: SIMD2(-2100, 900), radius: 65, mysteryStep: 2),
            AnomalySite(id: UUID(), name: "Null Pocket", kind: .jumpPocket,
                        position: SIMD2(1800, -1600), radius: 50, mysteryStep: nil),
            AnomalySite(id: UUID(), name: "Mute Grave", kind: .silentField,
                        position: SIMD2(1100, 2200), radius: 85, mysteryStep: nil),
        ])
        add("Drift", [
            AnomalySite(id: UUID(), name: "Null Segment", kind: .laneEcho,
                        position: SIMD2(-1800, -1400), radius: 75, mysteryStep: 3),
            AnomalySite(id: UUID(), name: "Belt Pocket", kind: .jumpPocket,
                        position: SIMD2(1500, 1200), radius: 50, mysteryStep: nil),
        ])
        add("Cinder", [
            AnomalySite(id: UUID(), name: "Ash Shear", kind: .jumpPocket,
                        position: SIMD2(-1400, -900), radius: 55, mysteryStep: nil),
            AnomalySite(id: UUID(), name: "Ember Silence", kind: .silentField,
                        position: SIMD2(900, 1600), radius: 80, mysteryStep: nil),
        ])
        add("Voidreach", [
            AnomalySite(id: UUID(), name: "Resonance Fold", kind: .jumpPocket,
                        position: SIMD2(-2200, -1800), radius: 60, mysteryStep: nil),
        ])
    }

    /// Hidden derelicts / wreck fields per system.
    private static func makeWrecks(for system: StarSystem) -> [Derelict] {
        let catalogs: [String: [(String, SIMD2<Float>, Blueprint?)]] = [
            "Solara": [
                ("Broken Freighter", SIMD2(-1800, -1400), .tractorArray),
                ("Patrol Debris", SIMD2(2100, 1600), nil),
            ],
            "Vesper": [
                ("Silk Convoy Remains", SIMD2(1500, 900), .expandedHold),
                ("Shadow Hull", SIMD2(-1900, -800), nil),
            ],
            "Ironreach": [
                ("Slag Yard Wreck", SIMD2(900, 1800), .hullPlating),
                ("Ore Tug Grave", SIMD2(-1600, -900), nil),
                ("Convoy Scatter", SIMD2(2200, -700), nil),
            ],
            "Cinder": [
                ("Ash Fleet Grave", SIMD2(-900, 1400), .overchargedLasers),
                ("Burned Hauler", SIMD2(1600, -1100), nil),
                ("Raider Hulk", SIMD2(400, 900), .afterburnerCore),
            ],
            "Azurel": [
                ("Research Pod", SIMD2(-700, 1100), .adaptiveShields),
                ("Tidewreck", SIMD2(1400, -600), nil),
            ],
            "Nyx": [
                ("Silent Derelict", SIMD2(1100, -900), .tractorArray),
                ("Umbrel Hulk", SIMD2(-1300, 800), nil),
                ("Hushed Convoy", SIMD2(-2400, 400), nil),
            ],
            "Helion": [
                ("Solar Sail Frame", SIMD2(-1000, -1200), nil),
                ("Corona Debris", SIMD2(1800, 400), .afterburnerCore),
            ],
            "Drift": [
                ("Belt Bone Field", SIMD2(800, 600), .hullPlating),
                ("Prospector Loss", SIMD2(-1400, -700), nil),
                ("Shattered Barge", SIMD2(400, -1600), .expandedHold),
            ],
            "Kestrel": [
                ("Militia Loss", SIMD2(1200, -900), nil),
                ("War Hulk", SIMD2(-800, 1000), .overchargedLasers),
            ],
            "Umbra": [
                ("Black Market Scrap", SIMD2(900, 700), .adaptiveShields),
                ("Silent Broker", SIMD2(-1000, -900), .tractorArray),
            ],
            "Voidreach": [
                ("Vael Shell Fragment", SIMD2(1400, -900), nil),
                ("Crystal Tomb", SIMD2(-1600, 1200), nil),
                ("Failed Probe", SIMD2(800, 2000), nil),
            ],
        ]

        guard let list = catalogs[system.name] else { return [] }
        return list.map { name, pos, bp in
            Derelict(
                id: UUID(),
                name: name,
                position: pos,
                radius: Float.random(in: 28...48),
                scrap: Int.random(in: 6...18),
                blueprint: bp,
                angle: Float.random(in: 0...(2 * .pi)),
                spin: Float.random(in: -0.4...0.4)
            )
        }
    }

    // MARK: - Builders

    private static func gate(_ pos: SIMD2<Float>, _ dest: String, _ destSpawn: SIMD2<Float>) -> JumpGate {
        JumpGate(id: UUID(), position: pos, radius: 80,
                 destinationSystem: dest, destinationSpawn: destSpawn,
                 name: "Gate → \(dest)", isWormhole: false)
    }

    private static func wormhole(
        _ pos: SIMD2<Float>, _ dest: String, _ destSpawn: SIMD2<Float>, name: String
    ) -> JumpGate {
        JumpGate(id: UUID(), position: pos, radius: 95,
                 destinationSystem: dest, destinationSpawn: destSpawn,
                 name: name, isWormhole: true)
    }

    /// Trade lane with rings spaced between endpoints (offset slightly off stations so rings don't sit inside docks).
    private static func lane(_ name: String, _ ends: [SIMD2<Float>], rings: Int) -> TradeLane {
        guard ends.count >= 2 else {
            return TradeLane(id: UUID(), name: name, points: ends, ringRadius: 60)
        }
        let a = ends[0]
        let b = ends[1]
        let dir = normalizeSafe(b - a)
        // Pull endpoints outward from stations/gates a bit
        let start = a + dir * 140
        let end = b - dir * 140
        var points: [SIMD2<Float>] = []
        let n = max(3, rings)
        for i in 0..<n {
            let t = Float(i) / Float(n - 1)
            points.append(start + (end - start) * t)
        }
        return TradeLane(id: UUID(), name: name, points: points, ringRadius: 58)
    }

    private static func planet(
        _ name: String, _ pos: SIMD2<Float>, _ radius: Float,
        _ color: (Float, Float, Float),
        atmo: (Float, Float, Float)?,
        gas: Bool,
        bands: (Float, Float, Float)? = nil,
        moons: [Moon]
    ) -> Planet {
        Planet(id: UUID(), name: name, position: pos, radius: radius,
               color: color, atmosphere: atmo, isGasGiant: gas,
               bandColor: bands, moons: moons)
    }

    private static func moon(
        _ name: String, _ orbitR: Float, _ speed: Float,
        _ radius: Float, _ color: (Float, Float, Float)
    ) -> Moon {
        Moon(id: UUID(), name: name, orbitRadius: orbitR, orbitSpeed: speed,
             orbitPhase: Float.random(in: 0...(2 * .pi)),
             radius: radius, color: color)
    }

    private static func makeStation(
        _ name: String, _ pos: SIMD2<Float>, _ faction: String, _ desc: String,
        _ specialty: Commodity, _ surplus: Commodity, _ deficit: Commodity,
        repairMult: Float = 1.0
    ) -> Station {
        var market: [Commodity: MarketOffer] = [:]
        for c in Commodity.allCases {
            var buy = c.basePrice
            var sell = Int(Float(c.basePrice) * 1.35)
            var stock = Int.random(in: 20...80)
            if c == surplus || c == specialty {
                buy = Int(Float(c.basePrice) * 0.65)
                sell = Int(Float(c.basePrice) * 0.95)
                stock = Int.random(in: 60...140)
            }
            if c == deficit {
                buy = Int(Float(c.basePrice) * 1.55)
                sell = Int(Float(c.basePrice) * 1.9)
                stock = Int.random(in: 5...25)
            }
            let noise = Float.random(in: 0.9...1.1)
            buy = max(1, Int(Float(buy) * noise))
            sell = max(buy + 1, Int(Float(sell) * noise))
            market[c] = MarketOffer(buyPrice: buy, sellPrice: sell, stock: stock)
        }
        let defense = defenseProfile(for: faction)
        return Station(
            id: UUID(), name: name, position: pos, radius: 95,
            market: market, repairCostPerHull: max(1, Int(4 * repairMult)),
            faction: faction, description: desc,
            defenseRange: defense.range,
            turretDamage: defense.damage,
            turretCooldownMax: defense.cooldown,
            turretCooldown: 0,
            turretAim: 0
        )
    }

    /// Station defense stats by faction flavor.
    private static func defenseProfile(for faction: String) -> (range: Float, damage: Float, cooldown: Float) {
        switch faction {
        case "Militia":
            return (720, 24, 0.28)   // heavy guns
        case "Solar Corp":
            return (600, 20, 0.32)
        case "Iron Combine":
            return (580, 19, 0.34)
        case "Merchants Guild":
            return (540, 16, 0.36)
        case "Science Collective":
            return (520, 15, 0.38)
        case "Prospector's Union":
            return (500, 15, 0.40)
        case "Frontier":
            return (480, 14, 0.42)   // under-equipped
        case "Unaligned":
            return (420, 12, 0.48)   // black market — light guns
        case "Vael Collective":
            return (800, 28, 0.22)   // alien point-defense — lethal
        default: // Independent etc.
            return (560, 17, 0.35)
        }
    }

    private static func field(
        _ center: SIMD2<Float>, _ count: Int, _ radius: Float, _ ore: ClosedRange<Int>
    ) -> [Asteroid] {
        (0..<count).map { _ in
            let a = Float.random(in: 0...(2 * .pi))
            let r = Float.random(in: 50...radius)
            return Asteroid(
                id: UUID(),
                position: center + SIMD2(cos(a), sin(a)) * r,
                radius: Float.random(in: 18...44),
                ore: Int.random(in: ore),
                angle: Float.random(in: 0...(2 * .pi)),
                spin: Float.random(in: -0.6...0.6)
            )
        }
    }

    // MARK: - Spawns & missions

    /// Chance a random spawn roll becomes Vael (frontier only). Higher near Nyx/Umbra.
    static func vaelIntrusionChance(for systemName: String) -> Float {
        switch systemName {
        case "Voidreach": return 1.0
        case "Nyx": return 0.09
        case "Umbra": return 0.07
        case "Cinder": return 0.045
        case "Drift", "Azurel": return 0.03
        case "Ironreach", "Kestrel", "Vesper": return 0.018
        case "Helion", "Solara": return 0.01
        default: return 0.015
        }
    }

    static func spawnNPCs(in system: StarSystem, count: Int) -> [NPCShip] {
        var ships: [NPCShip] = []
        // Outer sector: Vael dominance — almost no humans
        if system.name == "Voidreach" {
            let n = max(count, 12)
            for _ in 0..<n {
                let angle = Float.random(in: 0...(2 * .pi))
                let dist = Float.random(in: 500...(system.bounds * 0.8))
                let pos = SIMD2(cos(angle), sin(angle)) * dist
                ships.append(makeNPC(faction: .alien, at: pos))
            }
            // A few near stations
            for st in system.stations {
                for k in 0..<2 {
                    let a = Float(k) * 1.8
                    ships.append(makeNPC(faction: .alien, at: st.position + angleToVector(a) * 280))
                }
            }
            return ships
        }

        let pirateBias = system.piratePressure
        // Bias toward more civilian traffic in safe systems
        let cargoBoost = max(0.05, 0.28 - pirateBias * 0.08)
        // Rare Vael scouts on the frontier (stronger near the dark rim)
        let vaelChance = vaelIntrusionChance(for: system.name)
        for _ in 0..<count {
            let roll = Float.random(in: 0...1)
            let faction: Faction
            if vaelChance > 0, roll < vaelChance {
                faction = .alien
            } else if roll < vaelChance + 0.30 * pirateBias {
                faction = .pirate
            } else if roll < vaelChance + 0.30 * pirateBias + cargoBoost + 0.22 {
                faction = .trader
            } else if roll < vaelChance + 0.78 {
                faction = .police
            } else {
                faction = .militia
            }
            let angle = Float.random(in: 0...(2 * .pi))
            let dist = Float.random(in: 800...(system.bounds * 0.85))
            var pos = SIMD2(cos(angle), sin(angle)) * dist
            for st in system.stations {
                if distance(pos, st.position) < st.radius + 200 {
                    pos += normalizeSafe(pos - st.position) * 250
                }
            }
            var ship = makeNPC(faction: faction, at: pos)
            if ship.isCargo, Float.random(in: 0...1) < 0.45 {
                placeOnFreelane(&ship, in: system)
            }
            ships.append(ship)
        }
        // Occasional dedicated Vael patrol (1–2 ships) even when rolls miss
        if vaelChance > 0.02, Float.random(in: 0...1) < min(0.55, vaelChance * 8) {
            let pack = Int.random(in: 1...2)
            for _ in 0..<pack {
                let angle = Float.random(in: 0...(2 * .pi))
                let dist = Float.random(in: 1200...(system.bounds * 0.9))
                ships.append(makeNPC(faction: .alien, at: SIMD2(cos(angle), sin(angle)) * dist))
            }
        }
        // Guarantee freighters on freelanes for visible traffic
        let cargoExtra = Int.random(in: 3...5)
        for _ in 0..<cargoExtra {
            var ship: NPCShip
            if let st = system.stations.randomElement() {
                let offset = angleToVector(Float.random(in: 0...(2 * .pi))) * Float.random(in: 180...450)
                ship = makeNPC(faction: .trader, at: st.position + offset)
            } else {
                let a = Float.random(in: 0...(2 * .pi))
                ship = makeNPC(faction: .trader, at: SIMD2(cos(a), sin(a)) * 600)
            }
            placeOnFreelane(&ship, in: system)
            ships.append(ship)
        }
        return ships
    }

    /// Snap a cargo ship onto a random freelane segment for immediate traffic.
    static func placeOnFreelane(_ ship: inout NPCShip, in system: StarSystem) {
        guard ship.isCargo else { return }
        let openLanes = system.tradeLanes.filter { lane in
            lane.points.count >= 2 && (0..<lane.points.count).contains { !lane.isRingDisrupted($0) }
        }
        guard let lane = openLanes.randomElement() else { return }
        // Pick ring with a free next hop
        var candidates: [(Int, Int)] = []
        for i in 0..<lane.points.count {
            if lane.isRingDisrupted(i) { continue }
            if i + 1 < lane.points.count, !lane.isRingDisrupted(i + 1) {
                candidates.append((i, 1))
            }
            if i - 1 >= 0, !lane.isRingDisrupted(i - 1) {
                candidates.append((i, -1))
            }
        }
        guard let pick = candidates.randomElement() else { return }
        let i = pick.0
        let dir = pick.1
        let next = i + dir
        ship.onTradeLane = true
        ship.tradeLaneID = lane.id
        ship.tradeLaneRingIndex = i
        ship.tradeLaneDirection = dir
        ship.tradeLaneProgress = Float.random(in: 0.05...0.7)
        let from = lane.points[i]
        let to = lane.points[next]
        ship.position = from + (to - from) * ship.tradeLaneProgress
        ship.angle = angleToward(from, to)
        ship.velocity = normalizeSafe(to - from) * ship.freelaneCruiseSpeed
    }

    static func makeNPC(faction: Faction, at pos: SIMD2<Float>) -> NPCShip {
        switch faction {
        case .pirate:
            let heavy = Float.random(in: 0...1) < 0.28
            if heavy {
                return NPCShip(
                    id: UUID(), position: pos, velocity: .zero,
                    angle: Float.random(in: 0...(2 * .pi)),
                    hull: Float.random(in: 70...100), maxHull: 100,
                    shield: Float.random(in: 35...55), maxShield: 55,
                    faction: .pirate, hullType: .pirateGunship,
                    targetID: nil, fireCooldown: 0, aiTimer: 0,
                    dropCredits: Int.random(in: 140...320), dropScrap: Int.random(in: 2...6),
                    name: ["Gunship", "Reaver", "Iron Maw", "Marauder"].randomElement()!,
                    speed: Float.random(in: 140...180), damage: Float.random(in: 12...18), radius: 20,
                    missileAmmo: Int.random(in: 3...5)
                )
            }
            var raider = NPCShip(
                id: UUID(), position: pos, velocity: .zero,
                angle: Float.random(in: 0...(2 * .pi)),
                hull: Float.random(in: 40...70), maxHull: 70,
                shield: Float.random(in: 20...40), maxShield: 40,
                faction: .pirate, hullType: .pirateRaider,
                targetID: nil, fireCooldown: 0, aiTimer: 0,
                dropCredits: Int.random(in: 80...220), dropScrap: Int.random(in: 1...4),
                name: ["Raider", "Corsair", "Scourge", "Black Fang", "Wraith"].randomElement()!,
                speed: Float.random(in: 170...230), damage: Float.random(in: 8...14), radius: 16,
                missileAmmo: Int.random(in: 0...2)
            )
            raider.isWanted = true
            raider.manifest = [.weapons: Int.random(in: 1...4), .scrap: Int.random(in: 2...6)]
            return raider

        case .trader:
            return makeCargoShip(at: pos)

        case .police:
            let interceptor = Float.random(in: 0...1) < 0.4
            if interceptor {
                return NPCShip(
                    id: UUID(), position: pos, velocity: .zero,
                    angle: Float.random(in: 0...(2 * .pi)),
                    hull: 70, maxHull: 70, shield: 50, maxShield: 50,
                    faction: .police, hullType: .interceptor,
                    targetID: nil, fireCooldown: 0, aiTimer: 0,
                    dropCredits: 45, dropScrap: 1,
                    name: "Interceptor",
                    speed: 250, damage: 14, radius: 14,
                    missileAmmo: Int.random(in: 2...4)
                )
            }
            return NPCShip(
                id: UUID(), position: pos, velocity: .zero,
                angle: Float.random(in: 0...(2 * .pi)),
                hull: 90, maxHull: 90, shield: 60, maxShield: 60,
                faction: .police, hullType: .patrol,
                targetID: nil, fireCooldown: 0, aiTimer: 0,
                dropCredits: 50, dropScrap: 1, name: "Patrol Cruiser",
                speed: 200, damage: 12, radius: 17,
                missileAmmo: Int.random(in: 1...3)
            )

        case .militia:
            return NPCShip(
                id: UUID(), position: pos, velocity: .zero,
                angle: Float.random(in: 0...(2 * .pi)),
                hull: 80, maxHull: 80, shield: 50, maxShield: 50,
                faction: .militia, hullType: .militiaCutter,
                targetID: nil, fireCooldown: 0, aiTimer: 0,
                dropCredits: 40, dropScrap: 1, name: "Militia Cutter",
                speed: 190, damage: 10, radius: 15,
                missileAmmo: Int.random(in: 1...3)
            )

        case .alien:
            let heavy = Float.random(in: 0...1) < 0.35
            if heavy {
                return NPCShip(
                    id: UUID(), position: pos, velocity: .zero,
                    angle: Float.random(in: 0...(2 * .pi)),
                    hull: Float.random(in: 110...150), maxHull: 150,
                    shield: Float.random(in: 70...100), maxShield: 100,
                    faction: .alien, hullType: .alienWarden,
                    targetID: nil, fireCooldown: 0, aiTimer: 0,
                    dropCredits: Int.random(in: 280...520), dropScrap: Int.random(in: 4...9),
                    name: ["Vael Warden", "Spire Guard", "Lattice Drake", "Resonant"].randomElement()!,
                    speed: Float.random(in: 160...200), damage: Float.random(in: 16...22), radius: 22,
                    missileAmmo: Int.random(in: 4...7)
                )
            }
            return NPCShip(
                id: UUID(), position: pos, velocity: .zero,
                angle: Float.random(in: 0...(2 * .pi)),
                hull: Float.random(in: 55...85), maxHull: 85,
                shield: Float.random(in: 45...70), maxShield: 70,
                faction: .alien, hullType: .alienSkimmer,
                targetID: nil, fireCooldown: 0, aiTimer: 0,
                dropCredits: Int.random(in: 160...340), dropScrap: Int.random(in: 2...6),
                name: ["Vael Skimmer", "Shard Flyer", "Null Ray", "Glass Needle"].randomElement()!,
                speed: Float.random(in: 210...270), damage: Float.random(in: 11...16), radius: 15,
                missileAmmo: Int.random(in: 2...4)
            )
        }
    }

    /// Civilian cargo fleet — freighters, tankers, barges, couriers, etc.
    static func makeCargoShip(at pos: SIMD2<Float>) -> NPCShip {
        let hullType = HullType.cargoTypes.randomElement()!
        let angle = Float.random(in: 0...(2 * .pi))
        switch hullType {
        case .freighter:
            return cargoShip(pos, angle, hull: 75, shield: 35, hullType: .freighter,
                             names: ["Star Hauler", "Lane Trader", "Merchant", "Wayfarer"],
                             speed: 125, damage: 6, radius: 19, pods: 3,
                             credits: 60...140, scrap: 1...3)
        case .bulkHauler:
            return cargoShip(pos, angle, hull: 110, shield: 40, hullType: .bulkHauler,
                             names: ["Bulk Runner", "Deep Hold", "Goliath", "Cargo Titan"],
                             speed: 95, damage: 5, radius: 24, pods: 5,
                             credits: 90...200, scrap: 2...5)
        case .tanker:
            return cargoShip(pos, angle, hull: 90, shield: 30, hullType: .tanker,
                             names: ["Fuel Tanker", "Cell Carrier", "Cryo Tanker", "Helios Tanker"],
                             speed: 105, damage: 4, radius: 22, pods: 4,
                             credits: 80...170, scrap: 1...3)
        case .containerShip:
            return cargoShip(pos, angle, hull: 85, shield: 32, hullType: .containerShip,
                             names: ["Box Runner", "Stack Freighter", "Canister King", "Pod Liner"],
                             speed: 115, damage: 5, radius: 21, pods: 4,
                             credits: 70...160, scrap: 1...4)
        case .oreBarge:
            return cargoShip(pos, angle, hull: 100, shield: 25, hullType: .oreBarge,
                             names: ["Ore Barge", "Slag Tug", "Rock Hauler", "Mine Skiff"],
                             speed: 90, damage: 4, radius: 23, pods: 4,
                             credits: 50...130, scrap: 3...7)
        case .courier:
            return cargoShip(pos, angle, hull: 45, shield: 40, hullType: .courier,
                             names: ["Courier", "Express Runner", "Packet Boat", "Dispatch"],
                             speed: 200, damage: 8, radius: 14, pods: 2,
                             credits: 100...220, scrap: 1...1)
        default:
            return cargoShip(pos, angle, hull: 70, shield: 30, hullType: .freighter,
                             names: ["Freighter"], speed: 120, damage: 5, radius: 18, pods: 3,
                             credits: 80...80, scrap: 2...2)
        }
    }

    private static func cargoShip(
        _ pos: SIMD2<Float>, _ angle: Float,
        hull: Float, shield: Float, hullType: HullType,
        names: [String], speed: Float, damage: Float, radius: Float, pods: Int,
        credits: ClosedRange<Int>, scrap: ClosedRange<Int>
    ) -> NPCShip {
        var ship = NPCShip(
            id: UUID(), position: pos, velocity: .zero, angle: angle,
            hull: hull, maxHull: hull, shield: shield, maxShield: shield,
            faction: .trader, hullType: hullType,
            targetID: nil, fireCooldown: 0, aiTimer: 0,
            dropCredits: Int.random(in: credits), dropScrap: Int.random(in: scrap),
            name: names.randomElement()!,
            speed: speed, damage: damage, radius: radius,
            cargoPodsRemaining: pods
        )
        ship.manifest = randomManifest(for: hullType)
        ship.isWanted = Float.random(in: 0...1) < 0.08
        return ship
    }

    private static func randomManifest(for hull: HullType) -> [Commodity: Int] {
        switch hull {
        case .tanker:
            return [.fuelCells: Int.random(in: 8...20)]
        case .oreBarge:
            return [.ore: Int.random(in: 10...28)]
        case .courier:
            return [Bool.random() ? .electronics : .luxury: Int.random(in: 2...6)]
        case .bulkHauler, .containerShip:
            let a = Commodity.allCases.randomElement()!
            let b = Commodity.allCases.randomElement()!
            var m = [a: Int.random(in: 6...16)]
            if b != a { m[b] = Int.random(in: 3...10) }
            return m
        default:
            let c = Commodity.allCases.randomElement()!
            return [c: Int.random(in: 4...12)]
        }
    }

    static func makeWingman(at pos: SIMD2<Float>, role: WingmanRole = .gunner, paint: ShipPaint = .militiaOlive) -> NPCShip {
        var ship: NPCShip
        switch role {
        case .gunner:
            ship = NPCShip(
                id: UUID(), position: pos, velocity: .zero, angle: 0,
                hull: 110, maxHull: 110, shield: 80, maxShield: 80,
                faction: .militia, hullType: .interceptor,
                targetID: nil, fireCooldown: 0, aiTimer: 0,
                dropCredits: 0, dropScrap: 0,
                name: role.callsign,
                speed: 250, damage: 18, radius: 14,
                missileAmmo: 5, isWingman: true
            )
        case .scout:
            ship = NPCShip(
                id: UUID(), position: pos, velocity: .zero, angle: 0,
                hull: 75, maxHull: 75, shield: 55, maxShield: 55,
                faction: .militia, hullType: .courier,
                targetID: nil, fireCooldown: 0, aiTimer: 0,
                dropCredits: 0, dropScrap: 0,
                name: role.callsign,
                speed: 290, damage: 11, radius: 13,
                missileAmmo: 2, isWingman: true
            )
        case .tug:
            ship = NPCShip(
                id: UUID(), position: pos, velocity: .zero, angle: 0,
                hull: 160, maxHull: 160, shield: 90, maxShield: 90,
                faction: .militia, hullType: .freighter,
                targetID: nil, fireCooldown: 0, aiTimer: 0,
                dropCredits: 0, dropScrap: 0,
                name: role.callsign,
                speed: 180, damage: 12, radius: 18,
                missileAmmo: 1, isWingman: true
            )
        }
        ship.wingmanRole = role
        ship.wingmanPaint = paint
        return ship
    }

    static func makePirateCapital(at pos: SIMD2<Float>) -> NPCShip {
        NPCShip(
            id: UUID(), position: pos, velocity: .zero,
            angle: Float.random(in: 0...(2 * .pi)),
            hull: 420, maxHull: 420, shield: 180, maxShield: 180,
            faction: .pirate, hullType: .pirateGunship,
            targetID: nil, fireCooldown: 0, aiTimer: 0,
            dropCredits: Int.random(in: 800...1400), dropScrap: Int.random(in: 8...14),
            name: ["Dread Hulk", "Black Sovereign", "Raid Carrier", "Void Tyrant"].randomElement()!,
            speed: 95, damage: 22, radius: 36,
            missileAmmo: Int.random(in: 6...10),
            isCapital: true
        )
    }

    static func generateMissions(station: Station, system: String) -> [Mission] {
        var list: [Mission] = []
        let dirtyStation = station.faction == "Unaligned"
            || station.name.localizedCaseInsensitiveContains("Black Market")
            || station.name.localizedCaseInsensitiveContains("Quiet Hold")
            || station.name.localizedCaseInsensitiveContains("Night Market")
            || system == "Umbra"
        let militiaStation = station.faction == "Militia" || system == "Kestrel"

        let bountyCount = Int.random(in: 2...6)
        list.append(Mission(
            id: UUID(), title: "Pirate Sweep",
            description: "Identify (hold I) then destroy \(bountyCount) pirate ships. Unscanned kills do not pay.",
            kind: .bounty(targetFaction: .pirate, count: bountyCount),
            reward: 400 + bountyCount * 180, progress: 0, target: bountyCount,
            completed: false, offeredAtStation: station.name, offeredAtSystem: system,
            requiresScan: true
        ))

        let goods = Commodity.allCases.randomElement()!
        let amount = Int.random(in: 3...10)
        // Never auto-generate contracts into the outer sector (no charts)
        let destSystems = systemNames.filter { $0 != system && $0 != "Voidreach" }
        if let destSys = destSystems.randomElement() {
            let destStation = stationCatalog[destSys]?.randomElement() ?? "Freeport 7"
            list.append(Mission(
                id: UUID(), title: "Cargo Run: \(goods.rawValue)",
                description: "Deliver \(amount) \(goods.rawValue) to \(destStation) in \(destSys).",
                kind: .delivery(commodity: goods, amount: amount, destStation: destStation, destSystem: destSys),
                reward: 350 + amount * goods.basePrice * 2 + 150,
                progress: 0, target: amount, completed: false,
                offeredAtStation: station.name, offeredAtSystem: system
            ))
        }

        // Timed perishable run — food/medical spoil if late
        if Float.random(in: 0...1) < 0.45, let destSys = destSystems.randomElement() {
            let perishable: Commodity = Bool.random() ? .food : .medical
            let amt = Int.random(in: 4...9)
            let destStation = stationCatalog[destSys]?.randomElement() ?? "Freeport 7"
            let limit = Float.random(in: 160...280)
            list.append(Mission(
                id: UUID(), title: "Live Cargo: \(perishable.rawValue)",
                description: "Rush \(amt) \(perishable.rawValue) to \(destStation), \(destSys) before it spoils (\(Int(limit))s). Buy goods first.",
                kind: .delivery(commodity: perishable, amount: amt, destStation: destStation, destSystem: destSys),
                reward: 700 + amt * perishable.basePrice * 3,
                progress: 0, target: amt, completed: false,
                offeredAtStation: station.name, offeredAtSystem: system,
                timeLimit: limit
            ))
        }

        // Smuggling / Umbra "no questions" jobs
        if dirtyStation, Float.random(in: 0...1) < 0.85, let destSys = destSystems.randomElement() {
            let contraband: Commodity = [.weapons, .luxury, .electronics].randomElement()!
            let amt = Int.random(in: 3...7)
            // Prefer law systems for risk
            let lawDest = ["Ironreach", "Kestrel", "Solara"].filter { $0 != system }.randomElement() ?? destSys
            let destStation = stationCatalog[lawDest]?.randomElement() ?? "Freeport 7"
            list.append(Mission(
                id: UUID(), title: "No Questions: \(contraband.rawValue)",
                description: "Smuggle \(amt) \(contraband.rawValue) (hidden hold) to \(destStation), \(lawDest). Law scan = militia heat.",
                kind: .delivery(commodity: contraband, amount: amt, destStation: destStation, destSystem: lawDest),
                reward: 1_100 + amt * contraband.basePrice * 4,
                progress: 0, target: amt, completed: false,
                offeredAtStation: station.name, offeredAtSystem: system,
                isSmuggle: true, isDirty: true
            ))
        }

        let patrolKills = Int.random(in: 3...7)
        list.append(Mission(
            id: UUID(), title: "Sector Patrol",
            description: "Eliminate \(patrolKills) hostiles while flying the lanes.",
            kind: .patrol(kills: patrolKills),
            reward: 350 + patrolKills * 120 + (militiaStation ? 150 : 0),
            progress: 0, target: patrolKills,
            completed: false, offeredAtStation: station.name, offeredAtSystem: system
        ))

        // Militia home: extra defense retainer contracts
        if militiaStation, Float.random(in: 0...1) < 0.55 {
            let kills = Int.random(in: 3...5)
            list.append(Mission(
                id: UUID(), title: "Militia Retainer: \(station.name)",
                description: "Stand ready — destroy \(kills) hostiles near \(station.name) (or during any assault).",
                kind: .stationDefense(stationName: station.name, system: system, killsNeeded: kills),
                reward: 800 + kills * 160, progress: 0, target: kills,
                completed: false, offeredAtStation: station.name, offeredAtSystem: system
            ))
        }

        if let target = destSystems.randomElement() {
            list.append(Mission(
                id: UUID(), title: "Scout \(target)",
                description: "Jump to \(target) and dock at any station to report in.",
                kind: .explore(system: target),
                reward: 450 + Int.random(in: 0...200), progress: 0, target: 1,
                completed: false, offeredAtStation: station.name, offeredAtSystem: system
            ))
        }

        // Escort / convoy — protect a hauler to another station (often via freelanes)
        if Float.random(in: 0...1) < 0.72, let destSys = destSystems.randomElement() {
            let destStation = stationCatalog[destSys]?.randomElement() ?? "Freeport 7"
            let haulerNames = ["Bulk Runner", "Lane Tanker", "Deep Hold", "Goliath Convoy", "Helios Tanker"]
            let hauler = haulerNames.randomElement()!
            let reward = 900 + Int.random(in: 0...500) + (militiaStation ? 350 : 0)
            list.append(Mission(
                id: UUID(), title: "Escort: \(hauler)",
                description: "Protect \(hauler) to \(destStation) in \(destSys). Pirates will ambush the freelanes.",
                kind: .escort(destStation: destStation, destSystem: destSys, haulerName: hauler),
                reward: reward, progress: 0, target: 1,
                completed: false, offeredAtStation: station.name, offeredAtSystem: system
            ))
        }

        // Pirate career: raid a freelane (dirty docks / Umbra / high-risk systems)
        if dirtyStation || system == "Cinder" || system == "Nyx",
           Float.random(in: 0...1) < 0.7 {
            let laneNames = [
                "Core Spine", "Rim Haul", "Ash Corridor", "Night Run",
                "Ore Ribbon", "Shadow Lane", "Bulk Path", "Helios Arc"
            ]
            let lane = laneNames.randomElement()!
            let need = Int.random(in: 2...4)
            let raidSys = [system, "Cinder", "Nyx", "Umbra", "Drift"].filter { $0 != "Voidreach" }.randomElement() ?? system
            list.append(Mission(
                id: UUID(), title: "Raid: \(lane)",
                description: "Hit \(need) freighters on \(lane) freelanes in \(raidSys). You are the ambush — law will answer.",
                kind: .freelaneRaid(laneName: lane, system: raidSys, freightersNeeded: need),
                reward: 1_200 + need * 450,
                progress: 0, target: need,
                completed: false, offeredAtStation: station.name, offeredAtSystem: system,
                isDirty: true
            ))
        }

        // Probe / survey — plant a beacon at a planet, wreck, or anomaly
        if Float.random(in: 0...1) < 0.65 {
            let surveySys = ([system] + destSystems).randomElement() ?? system
            // Prefer mystery systems for flavor
            let flavored = ["Nyx", "Umbra", "Drift", "Cinder"].filter { destSystems.contains($0) || $0 == system }
            let pickSys = flavored.randomElement() ?? surveySys
            if let (kind, target) = surveyTarget(in: pickSys) {
                list.append(Mission(
                    id: UUID(), title: "Survey: \(target)",
                    description: "Drop a probe beacon at \(kind.label) \(target) in \(pickSys) (R near target), then dock to report.",
                    kind: .survey(targetName: target, system: pickSys, kind: kind),
                    reward: 550 + Int.random(in: 0...350) + (kind == .anomaly ? 200 : 0),
                    progress: 0, target: 1,
                    completed: false, offeredAtStation: station.name, offeredAtSystem: system
                ))
            }
        }
        return list
    }

    /// Pick a survey target name from known catalogs (names match world data).
    private static func surveyTarget(in system: String) -> (SurveyTargetKind, String)? {
        var options: [(SurveyTargetKind, String)] = []
        if let planets = [
            "Solara": ["Solara Prime", "Helios III", "Cirrus"],
            "Vesper": ["Vesper", "Nocturne"],
            "Ironreach": ["Ironreach", "Slag Giant"],
            "Cinder": ["Cinder", "Pyre"],
            "Azurel": ["Azurel", "Thalassa"],
            "Nyx": ["Nyx", "Erebus"],
            "Helion": ["Helion", "Photara"],
            "Drift": ["Shard", "Remnant"],
            "Kestrel": ["Kestrel", "Aerie"],
            "Umbra": ["Umbra", "Obsidian"],
            "Voidreach": ["Vael Prime", "Glassmere", "Nullseed"],
        ][system] {
            for p in planets { options.append((.planet, p)) }
        }
        // Wreck names from makeWrecks catalogs (stable)
        let wreckNames: [String: [String]] = [
            "Nyx": ["Silent Derelict", "Umbrel Hulk", "Hushed Convoy"],
            "Umbra": ["Black Market Scrap", "Silent Broker"],
            "Cinder": ["Ash Fleet Grave", "Burned Hauler", "Raider Hulk"],
            "Drift": ["Belt Bone Field", "Prospector Loss", "Shattered Barge"],
            "Solara": ["Broken Freighter", "Patrol Debris"],
        ]
        for w in wreckNames[system] ?? [] {
            options.append((.wreck, w))
        }
        let anomalyNames: [String: [String]] = [
            "Nyx": ["Lane Echo Alpha", "Shear Pocket", "Cold Quiet"],
            "Umbra": ["Quiet Fracture", "Null Pocket", "Mute Grave"],
            "Drift": ["Null Segment", "Belt Pocket"],
            "Cinder": ["Ash Shear", "Ember Silence"],
        ]
        for a in anomalyNames[system] ?? [] {
            options.append((.anomaly, a))
        }
        return options.randomElement()
    }

    /// Black-market / dirty pilot special stock (weapons & luxury deep-discount).
    static func applyBlackMarketStock(to station: inout Station, dirty: Bool) {
        guard dirty else { return }
        let isBlack = station.faction == "Unaligned"
            || station.name.localizedCaseInsensitiveContains("Black Market")
            || station.name.localizedCaseInsensitiveContains("Quiet Hold")
            || station.name.localizedCaseInsensitiveContains("Night Market")
        guard isBlack else { return }
        for c in [Commodity.weapons, Commodity.luxury, Commodity.scrap, Commodity.electronics] {
            guard var offer = station.market[c] else { continue }
            offer.sellPrice = max(1, Int(Float(offer.sellPrice) * 0.72))
            offer.buyPrice = max(1, Int(Float(offer.buyPrice) * 1.15))
            offer.stock = max(offer.stock, Int.random(in: 40...90))
            station.market[c] = offer
        }
    }

    static func refreshMarket(_ station: inout Station) {
        for c in Commodity.allCases {
            guard var offer = station.market[c] else { continue }
            offer.stock = min(150, offer.stock + Int.random(in: 0...8))
            let noise = Float.random(in: 0.97...1.03)
            offer.buyPrice = max(1, Int(Float(offer.buyPrice) * noise))
            offer.sellPrice = max(offer.buyPrice + 1, Int(Float(offer.sellPrice) * noise))
            station.market[c] = offer
        }
    }
}
