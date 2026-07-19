import Foundation
import CoreGraphics
import AppKit
import simd

@MainActor
final class GameEngine {
    // MARK: - State
    var phase: GamePhase = .title
    var player = Player()
    var systems: [String: StarSystem] = [:]
    var currentSystemName = "Solara"
    var npcs: [NPCShip] = []
    var projectiles: [Projectile] = []
    var particles: [Particle] = []
    var loot: [LootDrop] = []

    var camera: SIMD2<Float> = .zero
    var message = ""
    var messageTimer: Float = 0
    var keysDown = Set<UInt16>()

    // Docking / station UI
    var dockedStationID: UUID?
    var stationTab: StationTab = .status
    var tradeCommodityIndex = 0
    var tradeAmount = 1
    var missionSelectIndex = 0
    var outfitSelectIndex = 0
    var activeMissions: [Mission] = []
    var stationMissions: [Mission] = []

    // Combat
    var targetID: UUID?
    var fireCooldown: Float = 0
    var mineCooldown: Float = 0
    var invuln: Float = 0
    var hurtFlash: Float = 0
    var time: Float = 0

    // In-system navigation waypoint (V to cycle)
    var navWaypoint: NavWaypoint?
    /// Cursor on expanded system map destination list.
    var systemMapSelectIndex = 0
    private var systemMapReturnPhase: GamePhase = .playing
    /// Hold H: face nav waypoint and cruise (drops on hostiles / freelane / steer).
    var autopilotHeld = false
    var autopilotWasActive = false

    // Radio chatter
    var radioLine = ""
    var radioTimer: Float = 0
    private var radioCooldown: Float = 6

    // Ship scan (hold I)
    var scanProgress: Float = 0
    private var scansCompleted: Int = 0
    /// Law is scanning the player (smuggle / dirty heat).
    private var lawScanProgress: Float = 0

    // Photo / free camera (phase .photo)
    var freeCameraPos: SIMD2<Float> = .zero
    var freeCameraSpeed: Float = 420

    // Trade lane cruise (Freelancer-style)
    var onTradeLane = false
    var tradeLaneID: UUID?
    var tradeLaneRingIndex = 0
    var tradeLaneDirection = 1 // +1 toward higher indices, -1 toward lower
    var tradeLaneProgress: Float = 0 // 0...1 between current ring and next
    /// Cruise speed while locked to a freelane (much faster than free flight on expanded systems).
    var tradeLaneSpeed: Float = 3_200

    // Freelane time trials (end-to-end ghost runs)
    var raceActive = false
    var raceTimer: Float = 0
    var raceLaneName = ""
    var raceDirection = 1
    private var raceStartIsEndToEnd = false
    private var raceSamples: [FreelaneGhostSample] = []
    private var raceSampleAcc: Float = 0
    /// Ghost path for the current race (loaded PB).
    var raceGhostSamples: [FreelaneGhostSample] = []
    var racePBTime: Float? = nil
    /// Last finished result flash helpers
    var raceResultBanner = ""
    var raceResultTimer: Float = 0
    // Menus
    var titleMenuIndex = 0
    var pauseMenuIndex = 0
    var settingsMenuIndex = 0
    /// When true, Settings shows the controls reference instead of audio toggles.
    var settingsShowControls = false
    var menuFlash = ""
    var menuFlashTimer: Float = 0
    private var menuReturnPhase: GamePhase = .title

    // Spawning
    private var pirateSpawnTimer: Float = 8
    private var traderSpawnTimer: Float = 15
    private var tradeLaneAmbushTimer: Float = 4
    /// Occasional Vael scout packs on the frontier (not Voidreach-only).
    private var vaelSpawnTimer: Float = 45

    // News ticker
    var newsLine = ""
    var newsTimer: Float = 0
    private var newsQueue: [String] = []
    private var economyNewsCooldown: Float = 0

    // Galaxy map
    var mapSelectedSystem = "Solara"
    var mapSelectedStationIndex = 0
    /// When leaving galaxy map, return here.
    private var galaxyMapReturnPhase: GamePhase = .playing

    // Wingman hire
    var wingmanID: UUID?
    static let wingmanHireCost = 1200
    /// Outfit preview role when browsing wingman row (−/+)
    var wingmanRolePreview: WingmanRole = .gunner
    /// Names of wingmen lost this run (emotional log)
    var fallenWingmen: [String] = []

    // Escort / convoy mission
    var escortShipID: UUID?
    var escortMissionID: UUID?
    private var escortAmbushTimer: Float = 8

    // Proximity mines (deployed)
    var spaceMines: [SpaceMine] = []
    private var spaceMineDropCooldown: Float = 0
    private var cmCooldown: Float = 0
    private var minesDetonated: Int = 0
    /// Cooldown after freelane boost ends before L can fire again.
    private var freelaneBoostCooldown: Float = 0

    /// Active environment effects (nebula, radiation, etc.) at player position.
    var environmentEffects = EnvironmentEffects()
    private var environmentAlertCooldown: Float = 0
    private var lastEnvironmentAlert = ""
    private var enemyBaseAlertCooldown: Float = 0
    private var lastEnemyBaseAlert = ""

    // Capital / assault events
    private var capitalEventTimer: Float = 90
    var capitalAssaultActive = false
    var capitalAssaultStationName: String?
    var capitalAssaultTimer: Float = 0

    /// Outfitter row count: upgrades + paint + wingman + ship hull + fine + missiles + insurance + loan + protection
    /// Base outfit rows; alien stations add Vael tech rows after.
    /// 0 wpn 1 eng 2 shd 3 energy 4 cargo 5 repair 6 paint 7 wingman 8 ship 9 fine 10 missiles
    /// 11 insurance 12 loan 13 pirate protection 14 mines 15 countermeasures
    static let outfitBaseRowCount = 16

    private let audio = AudioManager.shared

    var hasWingman: Bool {
        guard let id = wingmanID else { return false }
        return npcs.contains { $0.id == id && $0.isWingman }
    }

    var currentSystem: StarSystem {
        systems[currentSystemName] ?? systems["Solara"]!
    }

    var dockedStation: Station? {
        guard let id = dockedStationID else { return nil }
        return systems[currentSystemName]?.stations.first { $0.id == id }
    }

    var hasSaveGame: Bool { SaveGame.hasAnySave }
    var saveInfo: String? { SaveGame.savedAtDescription }

    /// Slot picker index: load = 0 autosave + 1...3 manual; save = 0...2 → slots 1...3
    var slotMenuIndex = 0
    private var slotMenuReturnPhase: GamePhase = .title

    // Key codes
    static let keyW: UInt16 = 13
    static let keyA: UInt16 = 0
    static let keyS: UInt16 = 1
    static let keyD: UInt16 = 2
    static let keyQ: UInt16 = 12
    static let keyE: UInt16 = 14
    static let keyF: UInt16 = 3
    static let keyT: UInt16 = 17
    static let keyR: UInt16 = 15
    static let keyUp: UInt16 = 126
    static let keyDown: UInt16 = 125
    static let keyLeft: UInt16 = 123
    static let keyRight: UInt16 = 124
    static let keySpace: UInt16 = 49
    static let keyReturn: UInt16 = 36
    static let keyEscape: UInt16 = 53
    static let keyP: UInt16 = 35
    static let keyM: UInt16 = 46
    static let keyTab: UInt16 = 48
    static let key1: UInt16 = 18
    static let key2: UInt16 = 19
    static let key3: UInt16 = 20
    static let key4: UInt16 = 21
    static let key5: UInt16 = 23
    static let key6: UInt16 = 22
    static let keyComma: UInt16 = 43
    static let keyPeriod: UInt16 = 47
    static let keyMinus: UInt16 = 27
    static let keyEqual: UInt16 = 24
    static let keyBracketL: UInt16 = 33
    static let keyBracketR: UInt16 = 30
    static let keyG: UInt16 = 5
    static let keyV: UInt16 = 9
    static let keyN: UInt16 = 45
    static let keyC: UInt16 = 8
    static let keyZ: UInt16 = 6
    static let keyX: UInt16 = 7
    static let keyB: UInt16 = 11
    static let keyH: UInt16 = 4
    static let keyY: UInt16 = 16
    static let keyO: UInt16 = 31
    static let keyI: UInt16 = 34  // scan / identify
    static let keyU: UInt16 = 32  // pin / save trade route
    static let keyJ: UInt16 = 38  // drop mine
    static let keyK: UInt16 = 40  // countermeasures
    static let keyL: UInt16 = 37  // ancient freelane boost
    /// Missile lock range (world units).
    static let missileLockRange: Float = 520
    static let scanRange: Float = 420
    static let scanDuration: Float = 1.4
    static let missileDamage: Float = 58
    static let enemyMissileDamage: Float = 36
    static let missileSpeed: Float = 340
    static let enemyMissileSpeed: Float = 300
    static let missileTurnRate: Float = 4.2
    static let enemyMissileTurnRate: Float = 3.4
    static let mineArmTime: Float = 1.2
    static let mineRadius: Float = 55
    static let mineDamage: Float = 72
    static let mineLife: Float = 90

    init() {
        systems = GalaxyBuilder.build()
        player.position = currentSystem.spawn
        camera = player.position
        player.applyUpgradeLevels()
        syncMusic()
    }

    // MARK: - Lifecycle

    func newGame(ironman: Bool = false) {
        systems = GalaxyBuilder.build()
        currentSystemName = "Solara"
        player = Player()
        player.ironmanMode = ironman
        player.ironmanFailed = false
        player.position = currentSystem.spawn
        player.angle = 0
        player.velocity = .zero
        player.applyUpgradeLevels()
        player.hull = player.stats.maxHull
        player.shield = player.stats.maxShield
        player.energy = player.stats.maxEnergy
        player.missiles = Player.maxMissiles
        player.mineStock = min(3, player.maxMinesForClass)
        player.cmStock = min(3, player.maxCMForClass)
        player.weaponMode = .laser
        player.credits = ironman ? 2000 : 2500
        player.wingmanRole = .gunner
        player.wingmanPaint = .militiaOlive
        wingmanRolePreview = .gunner
        fallenWingmen = []
        spaceMines = []
        npcs = GalaxyBuilder.spawnNPCs(in: currentSystem, count: 10)
        projectiles = []
        particles = []
        loot = []
        activeMissions = []
        stationMissions = []
        dockedStationID = nil
        targetID = nil
        clearTradeLane()
        wingmanID = nil
        escortShipID = nil
        escortMissionID = nil
        navWaypoint = nil
        capitalAssaultActive = false
        capitalAssaultStationName = nil
        capitalAssaultTimer = 0
        capitalEventTimer = ironman ? 70 : 90
        newsQueue = []
        newsLine = ""
        newsTimer = 0
        economyNewsCooldown = 0
        camera = player.position
        phase = .playing
        keysDown.removeAll()
        player.systemsVisited.insert("Solara")
        suggestNavOnArrival()
        if ironman {
            flash("IRONMAN — death wipes your run. No second chances.")
            newsQueue = ["IRONMAN PROTOCOL ACTIVE. Dock often. Die once."]
        } else {
            flash("Welcome to the frontier. Story: ride a freelane, then dock Freeport 7.")
            newsQueue = ["Solara traffic normal. Freeport 7 welcomes independent pilots."]
        }
        newsLine = newsQueue.removeFirst()
        newsTimer = 5.5
        postNews("Campaign: \(StoryBeat.title(0)) — \(StoryBeat.description(0))")
        audio.play(.select)
        syncMusic()
    }

    func newGame() {
        newGame(ironman: false)
    }

    func returnToTitle() {
        phase = .title
        titleMenuIndex = 0
        keysDown.removeAll()
        dockedStationID = nil
        message = ""
        audio.play(.select)
        syncMusic()
    }

    private func syncMusic() {
        let combat = npcs.contains { $0.isHostile && distance($0.position, player.position) < 500 }
        audio.syncMusic(phase: phase, system: currentSystemName, inCombat: combat, docked: phase == .docked)
    }

    // MARK: - Save / Load

    /// Open slot picker to save (from pause / menu).
    func openSaveSlots(from returnPhase: GamePhase = .paused) {
        let origin: GamePhase
        if phase == .playing || phase == .docked || phase == .paused {
            origin = phase
        } else {
            origin = returnPhase
        }
        guard origin == .playing || origin == .docked || origin == .paused else { return }
        slotMenuReturnPhase = origin
        slotMenuIndex = 0
        phase = .saveSlots
        audio.play(.select)
        syncMusic()
    }

    /// Open slot picker to load (from title / menu).
    func openLoadSlots(from returnPhase: GamePhase = .title) {
        guard SaveGame.hasAnySave else {
            menuNotice("No save data found.")
            audio.play(.hurt)
            return
        }
        slotMenuReturnPhase = returnPhase
        slotMenuIndex = 0
        phase = .loadSlots
        audio.play(.select)
        syncMusic()
    }

    /// Quick-save to a specific manual slot (1...3).
    @discardableResult
    func saveGame(slot: Int) -> Bool {
        guard phase == .playing || phase == .docked || phase == .paused || phase == .saveSlots else {
            return false
        }
        if player.ironmanFailed {
            menuNotice("Ironman run ended — cannot save.")
            audio.play(.hurt)
            return false
        }
        do {
            try SaveGame.save(makeSnapshot(), slot: slot)
            flash(player.ironmanMode ? "Ironman Slot \(slot) saved." : "Saved to Slot \(slot).")
            menuNotice("Saved to Slot \(slot).")
            audio.play(.pickup)
            return true
        } catch {
            flash("Save failed.")
            menuNotice("Save failed.")
            audio.play(.hurt)
            return false
        }
    }

    /// Pause-menu / menu bar convenience: open picker (or slot 1 if already mid-picker).
    @discardableResult
    func saveGame() -> Bool {
        if phase == .saveSlots {
            return saveGame(slot: slotMenuIndex + 1)
        }
        if phase == .playing || phase == .docked || phase == .paused {
            openSaveSlots(from: phase)
            return true
        }
        // Fallback: slot 1
        let prev = phase
        phase = .paused
        let ok = saveGame(slot: 1)
        phase = prev
        return ok
    }

    @discardableResult
    func loadGame(slot: Int) -> Bool {
        do {
            let snap = try SaveGame.load(slot: slot)
            applySnapshot(snap)
            phase = .playing
            dockedStationID = nil
            keysDown.removeAll()
            flash("Loaded Slot \(slot).")
            audio.play(.select)
            syncMusic()
            return true
        } catch {
            print("Starlane load slot \(slot) failed: \(error)")
            menuNotice("Could not load Slot \(slot) — save may be outdated. See console.")
            audio.play(.hurt)
            return false
        }
    }

    @discardableResult
    func loadAutosave() -> Bool {
        do {
            let snap = try SaveGame.loadAutosave()
            applySnapshot(snap)
            phase = .playing
            dockedStationID = nil
            keysDown.removeAll()
            flash("Autosave restored.")
            audio.play(.select)
            syncMusic()
            return true
        } catch {
            print("Starlane load autosave failed: \(error)")
            menuNotice(SaveGame.existsAutosave
                       ? "Autosave unreadable — may need a new save after update."
                       : "No autosave found.")
            audio.play(.hurt)
            return false
        }
    }

    /// Menu bar / Continue: load most recent, or open picker if multiple.
    @discardableResult
    func loadGame() -> Bool {
        if phase == .loadSlots {
            return activateLoadSlotSelection()
        }
        guard SaveGame.hasAnySave else {
            menuNotice("No save data found.")
            audio.play(.hurt)
            return false
        }
        // From title Continue — open picker so player can choose
        if phase == .title {
            openLoadSlots(from: .title)
            return true
        }
        do {
            let snap = try SaveGame.loadMostRecent()
            applySnapshot(snap)
            phase = .playing
            dockedStationID = nil
            keysDown.removeAll()
            flash("Flight log restored.")
            audio.play(.select)
            syncMusic()
            return true
        } catch {
            menuNotice("Could not load save.")
            audio.play(.hurt)
            return false
        }
    }

    @discardableResult
    func autosaveOnDock() -> Bool {
        if player.ironmanFailed { return false }
        do {
            try SaveGame.autosave(makeSnapshot())
            menuNotice(player.ironmanMode ? "Ironman autosaved." : "Autosaved.")
            return true
        } catch {
            return false
        }
    }

    private func makeSnapshot() -> GameSnapshot {
        GameSnapshot(
            player: player,
            currentSystemName: currentSystemName,
            activeMissions: activeMissions,
            savedAt: Date(),
            slotLabel: nil,
            ironmanMode: player.ironmanMode
        )
    }

    /// Load picker rows: optional autosave + 3 manual slots.
    var loadSlotLabels: [String] {
        var rows: [String] = []
        if let d = SaveGame.autosaveDescription {
            rows.append(d)
        } else {
            rows.append("Autosave — empty")
        }
        for s in 1...SaveGame.manualSlotCount {
            // description() returns nil only when the file is missing
            if let d = SaveGame.description(slot: s) {
                rows.append(d)
            } else {
                rows.append("Slot \(s) — empty")
            }
        }
        return rows
    }

    var saveSlotLabels: [String] {
        (1...SaveGame.manualSlotCount).map { s in
            if let d = SaveGame.description(slot: s) {
                return d
            }
            return "Slot \(s) — empty (write here)"
        }
    }

    @discardableResult
    private func activateLoadSlotSelection() -> Bool {
        let hasAuto = SaveGame.existsAutosave
        // Index 0 = autosave, 1...3 = slots
        if slotMenuIndex == 0 {
            if hasAuto {
                return loadAutosave()
            }
            // If autosave empty, treat as slot 1 when user presses on empty auto?
            menuNotice("Autosave is empty.")
            audio.play(.hurt)
            return false
        }
        let slot = slotMenuIndex // 1, 2, 3 when autosave row present
        // loadSlotLabels always has autosave row first, then slots 1-3
        // so index 1 -> slot 1, index 2 -> slot 2, index 3 -> slot 3
        if SaveGame.exists(slot: slot) {
            return loadGame(slot: slot)
        }
        menuNotice("Slot \(slot) is empty.")
        audio.play(.hurt)
        return false
    }

    private func applySnapshot(_ snap: GameSnapshot) {
        systems = GalaxyBuilder.build()
        player = snap.player
        player.normalizeSaveDefaults()
        player.applyUpgradeLevels()
        currentSystemName = snap.currentSystemName
        if systems[currentSystemName] == nil {
            currentSystemName = "Solara"
            player.position = currentSystem.spawn
        }
        // Drop mission kinds that reference missing systems after rebuild (defensive)
        activeMissions = snap.activeMissions
        npcs = GalaxyBuilder.spawnNPCs(in: currentSystem, count: 10)
        projectiles = []
        particles = []
        loot = []
        spaceMines = []
        camera = player.position
        targetID = nil
        clearTradeLane()
        wingmanRolePreview = player.wingmanRole ?? .gunner
    }

    // MARK: - Input

    func keyDown(_ code: UInt16) {
        keysDown.insert(code)

        switch phase {
        case .title:
            handleTitleKey(code)
        case .howToPlay, .settings:
            handleOverlayMenuKey(code)
        case .paused:
            handlePauseKey(code)
        case .docked:
            handleDockedKey(code)
        case .playing:
            handlePlayingKey(code)
        case .photo:
            handlePhotoKey(code)
        case .galaxyMap:
            handleGalaxyMapKey(code)
        case .systemMap:
            handleSystemMapKey(code)
        case .saveSlots:
            handleSaveSlotsKey(code)
        case .loadSlots:
            handleLoadSlotsKey(code)
        case .logbook:
            if code == Self.keyEscape || code == Self.keyReturn || code == Self.keyP || code == Self.keyG {
                phase = galaxyMapReturnPhase
                audio.play(.select)
                syncMusic()
            }
        case .dead:
            if code == Self.keyReturn || code == Self.keySpace {
                if canInsuranceRespawn {
                    respawnWithInsurance()
                } else {
                    phase = .title
                    titleMenuIndex = 0
                    syncMusic()
                }
            }
        }
    }

    var canInsuranceRespawn: Bool {
        !player.ironmanMode
            && player.insured
            && player.lastDockSystem != nil
            && player.lastDockStation != nil
            && systems[player.lastDockSystem ?? ""] != nil
    }

    private func insuranceRespawnFee() -> Int {
        max(500, player.credits / 8)
    }

    private func respawnWithInsurance() {
        guard let sys = player.lastDockSystem,
              let stName = player.lastDockStation,
              let st = systems[sys]?.stations.first(where: { $0.name == stName })
                ?? systems[sys]?.stations.first else {
            phase = .title
            titleMenuIndex = 0
            syncMusic()
            return
        }
        let fee = insuranceRespawnFee()
        player.credits = max(0, player.credits - fee)
        player.cargo.removeAll()
        player.hiddenCargo = [:]
        player.missiles = max(2, player.missiles / 2)
        currentSystemName = sys
        player.position = st.position + SIMD2(0, st.radius + 55)
        player.velocity = .zero
        player.angle = -.pi / 2
        player.applyUpgradeLevels()
        player.hull = player.stats.maxHull
        player.shield = player.stats.maxShield
        player.energy = player.stats.maxEnergy
        invuln = 3
        dockedStationID = nil
        clearTradeLane()
        npcs = GalaxyBuilder.spawnNPCs(in: currentSystem, count: 10)
        projectiles = []
        particles = []
        loot = []
        targetID = nil
        // Fail timed / smuggle contracts on death
        failContractsOnDeath()
        phase = .playing
        camera = player.position
        flash("Insurance claim at \(st.name) (−\(fee) cr). Cargo written off.")
        postNews("Insured pilot recovered at \(st.name), \(sys).")
        audio.play(.dock)
        syncMusic()
    }

    private func failContractsOnDeath() {
        activeMissions.removeAll { m in
            m.timeLimit != nil || m.isSmuggle == true
        }
    }

    func keyUp(_ code: UInt16) {
        keysDown.remove(code)
    }

    private func handleTitleKey(_ code: UInt16) {
        let items = titleItems
        switch code {
        case Self.keyUp, Self.keyW:
            titleMenuIndex = (titleMenuIndex - 1 + items.count) % items.count
            audio.play(.select)
        case Self.keyDown, Self.keyS:
            titleMenuIndex = (titleMenuIndex + 1) % items.count
            audio.play(.select)
        case Self.keyReturn, Self.keySpace:
            activateTitleItem()
        case Self.keyM:
            audio.muted.toggle()
        default: break
        }
    }

    var titleItems: [String] {
        var items = ["New Game", "New Ironman"]
        if hasSaveGame { items.append("Continue") }
        items.append(contentsOf: ["How to Play", "Settings", "Quit"])
        return items
    }

    private func activateTitleItem() {
        let items = titleItems
        guard titleMenuIndex < items.count else { return }
        switch items[titleMenuIndex] {
        case "New Game":
            newGame(ironman: false)
        case "New Ironman":
            newGame(ironman: true)
        case "Continue":
            openLoadSlots(from: .title)
        case "How to Play":
            menuReturnPhase = .title
            phase = .howToPlay
            audio.play(.select)
        case "Settings":
            menuReturnPhase = .title
            phase = .settings
            settingsMenuIndex = 0
            settingsShowControls = false
            audio.play(.select)
        case "Quit":
            NSApp.terminate(nil)
        default: break
        }
    }

    private func handleOverlayMenuKey(_ code: UInt16) {
        if phase == .settings, settingsShowControls {
            if code == Self.keyEscape || code == Self.keyReturn || code == Self.keySpace || code == Self.keyP {
                settingsShowControls = false
                audio.play(.select)
            }
            return
        }
        if code == Self.keyEscape || (code == Self.keyReturn && phase == .howToPlay) {
            phase = menuReturnPhase
            settingsShowControls = false
            audio.play(.select)
            return
        }
        if phase == .settings {
            let count = 4
            switch code {
            case Self.keyUp, Self.keyW:
                settingsMenuIndex = (settingsMenuIndex - 1 + count) % count
                audio.play(.select)
            case Self.keyDown, Self.keyS:
                settingsMenuIndex = (settingsMenuIndex + 1) % count
                audio.play(.select)
            case Self.keyLeft, Self.keyA, Self.keyRight, Self.keyD, Self.keySpace, Self.keyReturn:
                activateSetting(settingsMenuIndex)
            default: break
            }
        } else if phase == .howToPlay, code == Self.keyReturn || code == Self.keySpace {
            phase = menuReturnPhase
            audio.play(.select)
        }
    }

    private func activateSetting(_ index: Int) {
        switch index {
        case 0: audio.muted.toggle(); audio.play(.select)
        case 1: audio.musicEnabled.toggle(); audio.play(.select)
        case 2: audio.sfxEnabled.toggle(); audio.play(.select)
        case 3:
            settingsShowControls = true
            audio.play(.select)
        default: break
        }
    }

    private func handlePauseKey(_ code: UInt16) {
        let pauseCount = 9
        switch code {
        case Self.keyUp, Self.keyW:
            pauseMenuIndex = (pauseMenuIndex - 1 + pauseCount) % pauseCount
            audio.play(.select)
        case Self.keyDown, Self.keyS:
            pauseMenuIndex = (pauseMenuIndex + 1) % pauseCount
            audio.play(.select)
        case Self.keyReturn, Self.keySpace:
            switch pauseMenuIndex {
            case 0: phase = dockedStationID != nil ? .docked : .playing; syncMusic()
            case 1: openSaveSlots(from: .paused)
            case 2: openLoadSlots(from: .paused)
            case 3: openGalaxyMap(from: .paused)
            case 4: openSystemMap(from: .paused)
            case 5: openLogbook(from: .paused)
            case 6:
                menuReturnPhase = .paused
                phase = .settings
                settingsMenuIndex = 0
                settingsShowControls = false
            case 7: returnToTitle()
            case 8: NSApp.terminate(nil)
            default: break
            }
            audio.play(.select)
        case Self.keyEscape, Self.keyP:
            phase = dockedStationID != nil ? .docked : .playing
            audio.play(.select)
            syncMusic()
        case Self.keyG:
            openGalaxyMap(from: .paused)
        default: break
        }
    }

    private func openLogbook(from returnPhase: GamePhase) {
        galaxyMapReturnPhase = returnPhase // reuse return slot
        phase = .logbook
        audio.play(.select)
        syncMusic()
    }

    private func handleSaveSlotsKey(_ code: UInt16) {
        let count = SaveGame.manualSlotCount
        switch code {
        case Self.keyUp, Self.keyW:
            slotMenuIndex = (slotMenuIndex - 1 + count) % count
            audio.play(.select)
        case Self.keyDown, Self.keyS:
            slotMenuIndex = (slotMenuIndex + 1) % count
            audio.play(.select)
        case Self.keyReturn, Self.keySpace:
            let slot = slotMenuIndex + 1
            if saveGame(slot: slot) {
                phase = slotMenuReturnPhase == .title ? .playing : slotMenuReturnPhase
                // After save from pause, stay paused unless we came from docked/playing
                if slotMenuReturnPhase == .paused {
                    phase = .paused
                } else if slotMenuReturnPhase == .docked {
                    phase = .docked
                } else if slotMenuReturnPhase == .playing {
                    phase = .playing
                }
                syncMusic()
            }
        case Self.keyEscape, Self.keyP:
            phase = slotMenuReturnPhase
            audio.play(.select)
            syncMusic()
        default: break
        }
    }

    private func handleLoadSlotsKey(_ code: UInt16) {
        let count = loadSlotLabels.count // 4: autosave + 3
        switch code {
        case Self.keyUp, Self.keyW:
            slotMenuIndex = (slotMenuIndex - 1 + count) % count
            audio.play(.select)
        case Self.keyDown, Self.keyS:
            slotMenuIndex = (slotMenuIndex + 1) % count
            audio.play(.select)
        case Self.keyReturn, Self.keySpace:
            _ = activateLoadSlotSelection()
        case Self.keyEscape, Self.keyP:
            phase = slotMenuReturnPhase
            audio.play(.select)
            syncMusic()
        default: break
        }
    }

    private func handlePlayingKey(_ code: UInt16) {
        switch code {
        case Self.keyEscape, Self.keyP:
            phase = .paused
            pauseMenuIndex = 0
            audio.play(.select)
            syncMusic()
        case Self.keyM:
            audio.muted.toggle()
        case Self.keyG:
            openGalaxyMap(from: .playing)
        case Self.keyZ, Self.keyX:
            openSystemMap(from: .playing)
        case Self.keyT, Self.keyTab:
            cycleTarget()
            audio.play(.select)
        case Self.keyV, Self.keyN:
            cycleNavWaypoint()
            audio.play(.select)
        case Self.keyC:
            clearNavWaypoint()
            audio.play(.select)
        case Self.keyF, Self.keyE:
            tryDockOrJump()
        case Self.keyR:
            if tryPlantSurveyBeacon() { break }
            if tryInteractAnomaly() { break }
            tryMine()
        case Self.keyQ:
            // Cycle primary DE: laser → plasma → pulse → rail
            cycleWeaponMode()
        case Self.keyB:
            firePlayerMissile()
        case Self.key1:
            player.weaponMode = .laser
            flash("Weapon: Lasers")
            audio.play(.select)
        case Self.key2:
            player.weaponMode = .plasma
            flash("Weapon: Plasma Cannon")
            audio.play(.select)
        case Self.key3:
            player.weaponMode = .pulse
            flash("Weapon: Pulse Array")
            audio.play(.select)
        case Self.key4:
            player.weaponMode = .rail
            flash("Weapon: Rail Lance")
            audio.play(.select)
        case Self.keyI:
            break // hold-to-scan handled in updatePlayer
        case Self.keyU:
            pinOrSaveTradeRouteFromFlight()
        case Self.keyJ:
            dropMine()
        case Self.keyK:
            deployCountermeasures()
        case Self.keyL:
            activateFreelaneBoost()
        case Self.keyY, Self.keyO:
            enterPhotoMode()
        default: break
        }
        // H is hold-to-autopilot (tracked via keysDown in updatePlayer)
    }

    private func enterPhotoMode() {
        freeCameraPos = camera
        phase = .photo
        autopilotHeld = false
        flash("Photo mode — WASD pan · −/+ zoom speed · Esc exit")
        audio.play(.select)
        syncMusic()
    }

    private func handlePhotoKey(_ code: UInt16) {
        switch code {
        case Self.keyEscape, Self.keyP, Self.keyY, Self.keyO:
            phase = .playing
            flash("Photo mode off.")
            audio.play(.select)
            syncMusic()
        case Self.keyMinus:
            freeCameraSpeed = max(120, freeCameraSpeed * 0.7)
            flash("Camera speed \(Int(freeCameraSpeed))")
        case Self.keyEqual:
            freeCameraSpeed = min(1400, freeCameraSpeed * 1.35)
            flash("Camera speed \(Int(freeCameraSpeed))")
        case Self.keyM:
            audio.muted.toggle()
        default: break
        }
    }

    private func cycleWeaponMode() {
        let order = WeaponMode.allCases
        guard let i = order.firstIndex(of: player.weaponMode) else {
            player.weaponMode = .laser
            flash("Weapon: Lasers")
            audio.play(.select)
            return
        }
        player.weaponMode = order[(i + 1) % order.count]
        flash("Weapon: \(player.weaponMode.displayName)")
        audio.play(.select)
    }

    private func openGalaxyMap(from returnPhase: GamePhase) {
        galaxyMapReturnPhase = returnPhase
        mapSelectedSystem = currentSystemName
        mapSelectedStationIndex = 0
        phase = .galaxyMap
        audio.play(.select)
        syncMusic()
    }

    func openSystemMap(from returnPhase: GamePhase) {
        systemMapReturnPhase = returnPhase
        let entries = systemMapEntries()
        // Prefer currently navigated destination as selection
        if let nav = navWaypoint,
           let idx = entries.firstIndex(where: { $0.waypoint == nav }) {
            systemMapSelectIndex = idx
        } else {
            systemMapSelectIndex = 0
        }
        if !entries.isEmpty {
            systemMapSelectIndex = min(systemMapSelectIndex, entries.count - 1)
        }
        phase = .systemMap
        audio.play(.select)
        syncMusic()
    }

    private func closeSystemMap() {
        if systemMapReturnPhase == .paused {
            phase = dockedStationID != nil ? .docked : .playing
        } else {
            phase = systemMapReturnPhase
        }
        audio.play(.select)
        syncMusic()
    }

    private func handleSystemMapKey(_ code: UInt16) {
        let entries = systemMapEntries()
        switch code {
        case Self.keyEscape, Self.keyP, Self.keyZ, Self.keyX:
            closeSystemMap()
        case Self.keyG:
            // Jump to galaxy map from system map
            openGalaxyMap(from: systemMapReturnPhase == .paused ? .playing : systemMapReturnPhase)
        case Self.keyUp, Self.keyW:
            guard !entries.isEmpty else { return }
            systemMapSelectIndex = (systemMapSelectIndex - 1 + entries.count) % entries.count
            audio.play(.select)
        case Self.keyDown, Self.keyS:
            guard !entries.isEmpty else { return }
            systemMapSelectIndex = (systemMapSelectIndex + 1) % entries.count
            audio.play(.select)
        case Self.keyLeft, Self.keyA:
            // Cycle only travel destinations (skip info-only)
            cycleSystemMapTravel(-1)
        case Self.keyRight, Self.keyD:
            cycleSystemMapTravel(1)
        case Self.keyReturn, Self.keySpace:
            confirmSystemMapDestination(closeAfter: true)
        case Self.keyV, Self.keyN:
            // Set nav without closing
            confirmSystemMapDestination(closeAfter: false)
        case Self.keyC:
            clearNavWaypoint()
            audio.play(.select)
        case Self.keyM:
            audio.muted.toggle()
        default: break
        }
    }

    private func cycleSystemMapTravel(_ delta: Int) {
        let entries = systemMapEntries()
        let travel = entries.enumerated().filter { $0.element.waypoint != nil }
        guard !travel.isEmpty else { return }
        let currentTravelIdx = travel.firstIndex(where: { $0.offset == systemMapSelectIndex }) ?? 0
        let next = travel[(currentTravelIdx + delta + travel.count) % travel.count]
        systemMapSelectIndex = next.offset
        audio.play(.select)
    }

    @discardableResult
    func confirmSystemMapDestination(closeAfter: Bool) -> Bool {
        let entries = systemMapEntries()
        guard entries.indices.contains(systemMapSelectIndex) else {
            flash("No destination selected.")
            return false
        }
        let entry = entries[systemMapSelectIndex]
        guard let wp = entry.waypoint else {
            flash("\(entry.title) is a landmark — pick a station or gate to travel.")
            audio.play(.hurt)
            return false
        }
        navWaypoint = wp
        let d = distance(player.position, entry.position)
        flash("Destination set: \(entry.title)  \(Self.formatNavDistance(d)) — fly or freelane toward it.")
        audio.play(.win)
        if closeAfter {
            // Leave map to play so player can fly there
            phase = .playing
            systemMapReturnPhase = .playing
            syncMusic()
        }
        return true
    }

    /// All map markers: stations, gates, escort, planets, wrecks.
    func systemMapEntries() -> [SystemMapEntry] {
        var list: [SystemMapEntry] = []
        let sys = currentSystem
        for st in sys.stations.sorted(by: {
            distance($0.position, player.position) < distance($1.position, player.position)
        }) {
            let d = GameEngine.formatNavDistance(distance(player.position, st.position))
            list.append(SystemMapEntry(
                id: "st-\(st.id.uuidString)",
                kind: .station,
                title: st.name,
                subtitle: "\(st.faction) · station · \(d)",
                position: st.position,
                waypoint: .station(st.id)
            ))
        }
        for g in sys.gates {
            let d = GameEngine.formatNavDistance(distance(player.position, g.position))
            list.append(SystemMapEntry(
                id: "gate-\(g.id.uuidString)",
                kind: .gate,
                title: g.name,
                subtitle: "Jump gate → \(g.destinationSystem) · \(d)",
                position: g.position,
                waypoint: .gate(g.id)
            ))
        }
        if let eid = escortShipID, let h = npcs.first(where: { $0.id == eid }) {
            let d = GameEngine.formatNavDistance(distance(player.position, h.position))
            list.append(SystemMapEntry(
                id: "escort",
                kind: .escort,
                title: h.name,
                subtitle: "Escort convoy · \(d)",
                position: h.position,
                waypoint: .escort
            ))
        }
        for planet in sys.planets {
            let known = player.discoveredPlanets.contains("\(currentSystemName)/\(planet.name)")
            let d = GameEngine.formatNavDistance(distance(player.position, planet.position))
            list.append(SystemMapEntry(
                id: "pl-\(planet.id.uuidString)",
                kind: .planet,
                title: planet.name,
                subtitle: known ? "Planet · \(d)" : "Unsurveyed body · \(d)",
                position: planet.position,
                waypoint: nil
            ))
        }
        for wreck in sys.wrecks {
            let key = "\(currentSystemName)/\(wreck.name)"
            guard player.discoveredWrecks.contains(key) else { continue }
            let d = GameEngine.formatNavDistance(distance(player.position, wreck.position))
            list.append(SystemMapEntry(
                id: "wk-\(wreck.id.uuidString)",
                kind: .wreck,
                title: wreck.name,
                subtitle: "Wreck · \(d)",
                position: wreck.position,
                waypoint: nil
            ))
        }
        for a in sys.anomalies {
            let key = "\(currentSystemName)/\(a.name)"
            let known = player.anomalyLog.contains(key)
            // Show when near discovery radius or already known
            let d = distance(player.position, a.position)
            guard known || d < a.discoveryRadius + 400 else { continue }
            let dist = GameEngine.formatNavDistance(d)
            list.append(SystemMapEntry(
                id: "an-\(a.id.uuidString)",
                kind: .anomaly,
                title: known ? a.name : "???",
                subtitle: known ? "\(a.flavor) · \(dist)" : "Anomalous reading · \(dist)",
                position: a.position,
                waypoint: nil
            ))
        }
        return list
    }

    // MARK: - Mouse (system map + minimap expand)

    /// View coordinates match CG (origin bottom-left).
    func mouseDown(at point: CGPoint, in bounds: CGRect) {
        switch phase {
        case .playing:
            // Click minimap to expand
            if Self.minimapRect(in: bounds).contains(point) {
                openSystemMap(from: .playing)
            }
        case .systemMap:
            handleSystemMapClick(at: point, in: bounds)
        default:
            break
        }
    }

    private func handleSystemMapClick(at point: CGPoint, in bounds: CGRect) {
        let layout = Self.systemMapLayout(bounds: bounds, worldBounds: currentSystem.bounds)
        // List panel click
        if layout.listPanel.contains(point) {
            let rowH: CGFloat = 36
            let top = layout.listPanel.maxY - 48
            let rel = top - point.y
            guard rel >= 0 else { return }
            let idx = Int(rel / rowH)
            let entries = systemMapEntries()
            guard entries.indices.contains(idx) else { return }
            systemMapSelectIndex = idx
            audio.play(.select)
            return
        }
        // Chart click — nearest marker
        guard layout.chart.contains(point) else { return }
        let world = layout.screenToWorld(point)
        let entries = systemMapEntries()
        guard let nearest = entries.enumerated().min(by: {
            distance($0.element.position, world) < distance($1.element.position, world)
        }) else { return }
        let hitDist = distance(nearest.element.position, world)
        // Threshold scales with system size
        let threshold = currentSystem.bounds * 0.08
        guard hitDist < threshold else { return }
        systemMapSelectIndex = nearest.offset
        audio.play(.select)
        // Double-purpose: if already selected and is travel, confirm? Single click selects; require Enter.
        // Click travel destination twice quickly is hard without tracking — use: click + if waypoint and already selected, set dest
        // Simpler: click on map with travel target sets selection; second click same = confirm
        // Even simpler: Option — click travel marker sets nav immediately if has waypoint
        if nearest.element.waypoint != nil {
            // Set destination on map click for travel targets
            confirmSystemMapDestination(closeAfter: false)
        }
    }

    /// Minimap frame in view space (matches Renderer).
    static func minimapRect(in bounds: CGRect) -> CGRect {
        let size: CGFloat = 188
        let margin: CGFloat = 16
        return CGRect(x: bounds.width - size - margin, y: margin, width: size, height: size)
    }

    struct SystemMapLayout {
        var chart: CGRect
        var listPanel: CGRect
        var scale: CGFloat
        var center: CGPoint
        var worldBounds: Float

        func worldToScreen(_ w: SIMD2<Float>) -> CGPoint {
            CGPoint(
                x: center.x + CGFloat(w.x) * scale,
                y: center.y + CGFloat(w.y) * scale
            )
        }

        func screenToWorld(_ p: CGPoint) -> SIMD2<Float> {
            SIMD2(
                Float((p.x - center.x) / scale),
                Float((p.y - center.y) / scale)
            )
        }
    }

    static func systemMapLayout(bounds: CGRect, worldBounds: Float) -> SystemMapLayout {
        let margin: CGFloat = 28
        let listW = min(300, bounds.width * 0.28)
        let chart = CGRect(
            x: margin,
            y: margin + 36,
            width: bounds.width - listW - margin * 3,
            height: bounds.height - margin * 2 - 50
        )
        let listPanel = CGRect(
            x: chart.maxX + margin,
            y: margin + 36,
            width: listW,
            height: chart.height
        )
        let pad: CGFloat = 36
        let scale = min(chart.width, chart.height) - pad * 2
        let s = scale / CGFloat(worldBounds * 2)
        return SystemMapLayout(
            chart: chart,
            listPanel: listPanel,
            scale: s,
            center: CGPoint(x: chart.midX, y: chart.midY),
            worldBounds: worldBounds
        )
    }

    private func galaxyMapSystemList() -> [String] {
        var names = GalaxyBuilder.systemNames
        if player.systemsVisited.contains("Voidreach")
            || player.discoveredWormholes.contains(where: { $0.contains("Voidreach") }) {
            names.append("Voidreach")
        }
        return names
    }

    private func handleGalaxyMapKey(_ code: UInt16) {
        let names = galaxyMapSystemList()
        switch code {
        case Self.keyEscape, Self.keyG, Self.keyP:
            phase = galaxyMapReturnPhase
            audio.play(.select)
            syncMusic()
        case Self.keyLeft, Self.keyA:
            if let i = names.firstIndex(of: mapSelectedSystem) {
                mapSelectedSystem = names[(i - 1 + names.count) % names.count]
                mapSelectedStationIndex = 0
                audio.play(.select)
            }
        case Self.keyRight, Self.keyD:
            if let i = names.firstIndex(of: mapSelectedSystem) {
                mapSelectedSystem = names[(i + 1) % names.count]
                mapSelectedStationIndex = 0
                audio.play(.select)
            }
        case Self.keyUp, Self.keyW:
            let n = max(1, systems[mapSelectedSystem]?.stations.count ?? 1)
            mapSelectedStationIndex = (mapSelectedStationIndex - 1 + n) % n
            audio.play(.select)
        case Self.keyDown, Self.keyS:
            let n = max(1, systems[mapSelectedSystem]?.stations.count ?? 1)
            mapSelectedStationIndex = (mapSelectedStationIndex + 1) % n
            audio.play(.select)
        case Self.keyM:
            audio.muted.toggle()
        case Self.keyU, Self.keyReturn, Self.keySpace:
            pinRouteFromGalaxyMap()
        default: break
        }
    }

    private func handleDockedKey(_ code: UInt16) {
        switch code {
        case Self.keyEscape, Self.keyP:
            phase = .paused
            pauseMenuIndex = 0
            audio.play(.select)
        case Self.key1, Self.key2, Self.key3, Self.key4, Self.key5, Self.key6:
            selectStationTabByNumber(code)
        case Self.keyLeft, Self.keyA, Self.keyBracketL:
            cycleStationTab(-1)
        case Self.keyRight, Self.keyD, Self.keyBracketR:
            cycleStationTab(1)
        case Self.keyUp, Self.keyW:
            moveStationCursor(-1)
        case Self.keyDown, Self.keyS:
            moveStationCursor(1)
        case Self.keyComma, Self.keyMinus:
            if stationTab == .outfit, outfitSelectIndex == 6 {
                cyclePaint(-1)
            } else if stationTab == .outfit, outfitSelectIndex == 7 {
                cycleWingmanRole(-1)
            } else if stationTab == .outfit, outfitSelectIndex == 8 {
                cycleShipClass(-1)
            } else {
                tradeAmount = max(1, tradeAmount - 1)
            }
        case Self.keyPeriod, Self.keyEqual:
            if stationTab == .outfit, outfitSelectIndex == 6 {
                cyclePaint(1)
            } else if stationTab == .outfit, outfitSelectIndex == 7 {
                cycleWingmanRole(1)
            } else if stationTab == .outfit, outfitSelectIndex == 8 {
                cycleShipClass(1)
            } else {
                tradeAmount = min(99, tradeAmount + 1)
            }
        case Self.keyReturn, Self.keySpace:
            activateStationAction()
        case Self.keyF, Self.keyE:
            if stationTab == .undock { undock() }
            if stationTab == .warehouse { warehouseWithdraw() }
            if stationTab == .outfit, outfitSelectIndex == 6 { cyclePaint(1) }
            if stationTab == .outfit, outfitSelectIndex == 7 { cycleWingmanRole(1) }
            if stationTab == .outfit, outfitSelectIndex == 8 { cycleShipClass(1) }
        case Self.keyM:
            audio.muted.toggle()
        default: break
        }
    }

    /// Tabs shown at the current dock (Warehouse only at Freeport 7).
    var availableStationTabs: [StationTab] {
        if isAtFreeport7 {
            return StationTab.allCases
        }
        return StationTab.allCases.filter { $0 != .warehouse }
    }

    var isAtFreeport7: Bool {
        currentSystemName == PlayerWarehouse.systemName
            && dockedStation?.name == PlayerWarehouse.stationName
    }

    private func selectStationTabByNumber(_ code: UInt16) {
        let tabs = availableStationTabs
        let index: Int?
        switch code {
        case Self.key1: index = 0
        case Self.key2: index = 1
        case Self.key3: index = 2
        case Self.key4: index = 3
        case Self.key5: index = 4
        case Self.key6: index = 5
        default: index = nil
        }
        guard let index, tabs.indices.contains(index) else { return }
        stationTab = tabs[index]
        if stationTab == .trade || stationTab == .warehouse { tradeCommodityIndex = 0 }
        if stationTab == .missions { missionSelectIndex = 0 }
        if stationTab == .outfit {
            outfitSelectIndex = 0
            shipClassPreview = player.shipClass
        }
        audio.play(.select)
    }

    private func cycleStationTab(_ delta: Int) {
        let tabs = availableStationTabs
        guard let i = tabs.firstIndex(of: stationTab) else {
            stationTab = tabs[0]
            return
        }
        stationTab = tabs[(i + delta + tabs.count) % tabs.count]
        if stationTab == .trade || stationTab == .warehouse { tradeCommodityIndex = 0 }
        audio.play(.select)
    }

    private func moveStationCursor(_ delta: Int) {
        switch stationTab {
        case .trade, .warehouse:
            tradeCommodityIndex = (tradeCommodityIndex + delta + Commodity.allCases.count) % Commodity.allCases.count
            audio.play(.select)
        case .missions:
            let count = max(1, stationMissions.count + activeMissions.count)
            missionSelectIndex = (missionSelectIndex + delta + count) % count
            audio.play(.select)
        case .outfit:
            let n = outfitRowCount
            outfitSelectIndex = (outfitSelectIndex + delta + n) % n
            audio.play(.select)
        case .status, .undock:
            break
        }
    }

    /// Total outfitter rows including alien tech when docked at Vael bases.
    var outfitRowCount: Int {
        Self.outfitBaseRowCount + (isAlienOutfitter ? Blueprint.alienTech.count : 0)
    }

    var isAlienOutfitter: Bool {
        dockedStation?.faction == "Vael Collective"
    }

    /// True if docked station can take another investment tier.
    var canInvestAtDock: Bool {
        guard let st = dockedStation else { return false }
        let level = player.investment(system: currentSystemName, station: st.name)?.level ?? 0
        return level < StationInvestment.maxLevel
    }

    var nextInvestmentCost: Int? {
        guard let st = dockedStation else { return nil }
        let level = player.investment(system: currentSystemName, station: st.name)?.level ?? 0
        guard level < StationInvestment.maxLevel else { return nil }
        return StationInvestment.upgradeCost(fromLevel: level)
    }

    /// Alien blueprint for outfit row index ≥ base count.
    func alienTechAtOutfitRow(_ index: Int) -> Blueprint? {
        guard isAlienOutfitter else { return nil }
        let i = index - Self.outfitBaseRowCount
        guard i >= 0, i < Blueprint.alienTech.count else { return nil }
        return Blueprint.alienTech[i]
    }

    private func activateStationAction() {
        guard var station = dockedStation, let sysIdx = systems[currentSystemName] else { return }
        _ = sysIdx

        switch stationTab {
        case .status:
            // Fine → repair → invest → recharge → hire wingman
            if player.isWanted, dockedStation?.faction == "Militia" {
                payWantedFine()
            } else if player.hull < player.stats.maxHull {
                repairHull()
            } else if canInvestAtDock {
                investInStation()
            } else if player.shield < player.stats.maxShield {
                player.shield = player.stats.maxShield
                flash("Shields recharged.")
                audio.play(.pickup)
            } else {
                hireWingman()
            }
        case .trade:
            // Buy by default with return; sell with shift... we use Space buy, and Q-like: period amount
            // Actually: Return = buy, F = sell
            buyCommodity()
        case .warehouse:
            if player.warehouse?.rented == true {
                warehouseDeposit()
            } else {
                rentWarehouse()
            }
        case .missions:
            acceptOrTurnInMission()
        case .outfit:
            purchaseUpgrade()
        case .undock:
            undock()
        }

        // Re-read station after mutations
        if let id = dockedStationID,
           let idx = systems[currentSystemName]?.stations.firstIndex(where: { $0.id == id }) {
            station = systems[currentSystemName]!.stations[idx]
            _ = station
        }
    }

    // MARK: - Update

    func update(dt: Float) {
        time += dt
        if messageTimer > 0 {
            messageTimer -= dt
            if messageTimer <= 0 { message = "" }
        }
        if menuFlashTimer > 0 {
            menuFlashTimer -= dt
            if menuFlashTimer <= 0 { menuFlash = "" }
        }

        if phase == .photo {
            updatePhotoCamera(dt)
            updateParticles(dt)
            return
        }

        guard phase == .playing else {
            // Still animate particles lightly when docked
            if phase == .docked {
                updateParticles(dt)
            }
            return
        }

        if invuln > 0 { invuln -= dt }
        if hurtFlash > 0 { hurtFlash -= dt }
        if fireCooldown > 0 { fireCooldown -= dt }
        if mineCooldown > 0 { mineCooldown -= dt }
        if spaceMineDropCooldown > 0 { spaceMineDropCooldown -= dt }
        if cmCooldown > 0 { cmCooldown -= dt }
        if freelaneBoostCooldown > 0 { freelaneBoostCooldown -= dt }

        // Sample weather before flight so thrust/turn/drag use current zone
        updateEnvironment(dt)
        if raceResultTimer > 0 {
            raceResultTimer -= dt
            if raceResultTimer <= 0 { raceResultBanner = "" }
        }
        if economyNewsCooldown > 0 { economyNewsCooldown -= dt }
        if var boost = player.freelaneBoostSeconds, boost > 0 {
            boost -= dt
            player.freelaneBoostSeconds = max(0, boost)
            if boost <= 0 {
                player.freelaneBoostSeconds = nil
                freelaneBoostCooldown = 75
                flash("Ancient lane boost spent. Cooldown active.")
            }
        }

        updatePlayer(dt)
        updateNPCs(dt)
        resolveTrafficCollisions(dt)
        updateStationDefenses(dt)
        updateLaneDisruptions(dt)
        updateCapitalEvents(dt)
        updateEscortMission(dt)
        updateProjectiles(dt)
        updateMines(dt)
        updateParticles(dt)
        updateLoot(dt)
        updateAsteroids(dt)
        updateWrecks(dt)
        updateDiscoveries()
        updateNews(dt)
        updateRadio(dt)
        updateSpawns(dt)
        updateShieldRegen(dt)
        updateContracts(dt)
        updateScan(dt)
        updateLawPlayerScan(dt)
        updatePirateProtection(dt)
        updateCamera(dt)
        checkBounds(dt)
        checkDeath()
        syncMusic()
    }

    private func updatePhotoCamera(_ dt: Float) {
        var move = SIMD2<Float>.zero
        if keysDown.contains(Self.keyW) || keysDown.contains(Self.keyUp) { move.y += 1 }
        if keysDown.contains(Self.keyS) || keysDown.contains(Self.keyDown) { move.y -= 1 }
        if keysDown.contains(Self.keyA) || keysDown.contains(Self.keyLeft) { move.x -= 1 }
        if keysDown.contains(Self.keyD) || keysDown.contains(Self.keyRight) { move.x += 1 }
        if simd_length(move) > 0.01 {
            freeCameraPos += normalizeSafe(move) * freeCameraSpeed * dt
        }
        let b = currentSystem.bounds * 1.05
        freeCameraPos.x = max(-b, min(b, freeCameraPos.x))
        freeCameraPos.y = max(-b, min(b, freeCameraPos.y))
        camera = freeCameraPos
        time += 0 // already advanced
    }

    private func updatePlayer(_ dt: Float) {
        // Freelane cruise overrides normal flight — cancel autopilot
        if onTradeLane {
            if autopilotHeld || autopilotWasActive {
                disengageAutopilot(reason: "Autopilot off — freelane cruise.")
            }
            // still apply radiation/ion while on freelane via updateEnvironment
            updateTradeLaneTravel(dt)
            if keysDown.contains(Self.keySpace), fireCooldown <= 0 {
                firePrimaryWeapon()
            }
            return
        }

        autopilotHeld = keysDown.contains(Self.keyH)
        let manualSteer = keysDown.contains(Self.keyA) || keysDown.contains(Self.keyLeft)
            || keysDown.contains(Self.keyD) || keysDown.contains(Self.keyRight)
        let manualThrust = keysDown.contains(Self.keyW) || keysDown.contains(Self.keyUp)
            || keysDown.contains(Self.keyS) || keysDown.contains(Self.keyDown)

        // Hostiles nearby cancel autopilot
        let hostileNear = npcs.contains {
            $0.isHostile && !$0.isWingman && distance($0.position, player.position) < 420
        }

        if autopilotHeld, resolveNav() != nil, !hostileNear, !manualSteer {
            if !autopilotWasActive {
                autopilotWasActive = true
                flash("Autopilot engaged — holding H toward NAV.")
            }
            applyAutopilot(dt)
        } else {
            if autopilotWasActive {
                if hostileNear {
                    disengageAutopilot(reason: "Autopilot disengaged — hostiles!")
                } else if !autopilotHeld {
                    disengageAutopilot(reason: nil)
                } else if manualSteer {
                    disengageAutopilot(reason: "Autopilot disengaged — manual helm.")
                } else if resolveNav() == nil {
                    disengageAutopilot(reason: "Autopilot needs a NAV waypoint (V).")
                }
            }
            // Continuous inertial flight — turn while coasting, soft speed envelope
            let turn = player.stats.turnRate * environmentEffects.turnMult
            if keysDown.contains(Self.keyA) || keysDown.contains(Self.keyLeft) {
                player.angle += turn * dt
            }
            if keysDown.contains(Self.keyD) || keysDown.contains(Self.keyRight) {
                player.angle -= turn * dt
            }
        }

        let forward = angleToVector(player.angle)
        var thrusting = false
        var reverse = false
        let thrust = player.stats.thrust * environmentEffects.thrustMult

        if autopilotHeld, resolveNav() != nil, !hostileNear, !manualSteer, !manualThrust {
            // Autopilot provides thrust
            player.velocity += forward * thrust * 0.92 * dt
            thrusting = true
        } else {
            if keysDown.contains(Self.keyW) || keysDown.contains(Self.keyUp) {
                player.velocity += forward * thrust * dt
                thrusting = true
            }
            if keysDown.contains(Self.keyS) || keysDown.contains(Self.keyDown) {
                player.velocity -= forward * thrust * 0.55 * dt
                thrusting = true
                reverse = true
            }
        }

        // Environment modifiers (dust / ice / grav)
        let env = environmentEffects
        if simd_length_squared(env.gravPull) > 0.01 {
            player.velocity += env.gravPull * dt
        }

        // Light space drag; extra soft drag only near/over max speed (no hard clamp)
        var dragPerSec: Float = thrusting ? 0.06 : 0.18
        let speed = simd_length(player.velocity)
        let maxSpd = player.stats.maxSpeed * env.speedMult
        if speed > maxSpd * 0.82 {
            let t = min(1, (speed - maxSpd * 0.82) / max(1, maxSpd * 0.35))
            dragPerSec += t * t * 2.8
        }
        if reverse, speed < 40 {
            dragPerSec += 1.2
        }
        // Dust / ice add drag
        if env.thrustMult < 0.98 {
            dragPerSec += (1 - env.thrustMult) * 0.9
        }
        player.velocity *= exp(-dragPerSec * dt)

        player.position += player.velocity * dt

        // Continuous thruster trail while thrusting
        if thrusting {
            let rate = reverse ? 18 : 28
            if Int(time * Float(rate)) != Int((time - dt) * Float(rate)) {
                let dir = reverse ? forward : -forward
                spawnThrustParticle(at: player.position + dir * 12, dir: dir)
                spawnThrustParticle(
                    at: player.position + dir * 10 + SIMD2(Float.random(in: -4...4), Float.random(in: -4...4)),
                    dir: dir
                )
            }
        }

        // Fire
        if keysDown.contains(Self.keySpace), fireCooldown <= 0 {
            firePrimaryWeapon()
        }
    }

    private func applyAutopilot(_ dt: Float) {
        guard let nav = resolveNav() else { return }
        // Prefer next freelane ring on highlighted path if near it
        var aim = nav.position
        if let path = freelaneNavPath(),
           let nextRing = path.ringPositions.first(where: {
               distance($0, player.position) > 80
           }) {
            // Aim at next path ring if it still leads toward dest
            if distance(nextRing, nav.position) < distance(player.position, nav.position) + 200 {
                aim = nextRing
            }
        }
        let desired = angleToward(player.position, aim)
        player.angle = lerpAngle(player.angle, desired, min(1, player.stats.turnRate * 1.15 * dt))
    }

    private func disengageAutopilot(reason: String?) {
        autopilotWasActive = false
        if let reason {
            flash(reason)
            audio.play(.select)
        }
    }

    // MARK: - Freelane path to NAV

    /// Highlighted freelane rings from a greedy path toward the current nav waypoint.
    struct FreelaneNavPath {
        var laneID: UUID
        var ringIndices: [Int]
        var ringPositions: [SIMD2<Float>]
    }

    private var navPathCache: FreelaneNavPath?
    private var navPathCacheTime: Float = -999

    /// Best freelane segment path toward NAV (entry near player → exit near destination).
    func freelaneNavPath() -> FreelaneNavPath? {
        if navPathCacheTime == time { return navPathCache }
        navPathCacheTime = time
        navPathCache = computeFreelaneNavPath()
        return navPathCache
    }

    private func computeFreelaneNavPath() -> FreelaneNavPath? {
        guard let nav = resolveNav() else { return nil }
        let dest = nav.position
        let origin = player.position
        var best: (UUID, [Int], Float)?

        for lane in currentSystem.tradeLanes {
            let n = lane.points.count
            guard n >= 2 else { continue }
            for i in 0..<n {
                if lane.isRingDisrupted(i) { continue }
                for j in 0..<n {
                    if i == j { continue }
                    if lane.isRingDisrupted(j) { continue }
                    let step = j > i ? 1 : -1
                    var ok = true
                    var indices: [Int] = []
                    var k = i
                    while true {
                        if lane.isRingDisrupted(k) { ok = false; break }
                        indices.append(k)
                        if k == j { break }
                        k += step
                    }
                    guard ok, indices.count >= 2 else { continue }
                    var pathLen: Float = 0
                    for t in 0..<(indices.count - 1) {
                        pathLen += distance(lane.points[indices[t]], lane.points[indices[t + 1]])
                    }
                    let cost = distance(origin, lane.points[i]) + pathLen + distance(lane.points[j], dest) * 0.85
                    let approach = distance(origin, dest) - distance(lane.points[j], dest)
                    guard approach > 80 else { continue }
                    if best == nil || cost < best!.2 {
                        best = (lane.id, indices, cost)
                    }
                }
            }
        }
        guard let b = best, let lane = currentSystem.tradeLanes.first(where: { $0.id == b.0 }) else {
            return nil
        }
        return FreelaneNavPath(
            laneID: b.0,
            ringIndices: b.1,
            ringPositions: b.1.map { lane.points[$0] }
        )
    }

    func isNavPathRing(laneID: UUID, index: Int) -> Bool {
        guard let path = freelaneNavPath() else { return false }
        return path.laneID == laneID && path.ringIndices.contains(index)
    }

    // MARK: - Radio chatter

    private func updateRadio(_ dt: Float) {
        if radioTimer > 0 {
            radioTimer -= dt
            if radioTimer <= 0 { radioLine = "" }
        }
        radioCooldown -= dt
        guard radioCooldown <= 0, phase == .playing else { return }
        radioCooldown = Float.random(in: 9...18)
        guard Float.random(in: 0...1) < 0.55 else { return }
        emitRadioChatter()
    }

    // MARK: - Contracts, scan, protection

    private func updateContracts(_ dt: Float) {
        var failed: [UUID] = []
        for i in activeMissions.indices {
            guard var rem = activeMissions[i].timeRemaining else { continue }
            rem -= dt
            activeMissions[i].timeRemaining = rem
            if rem <= 0 {
                failed.append(activeMissions[i].id)
            }
        }
        for id in failed {
            guard let idx = activeMissions.firstIndex(where: { $0.id == id }) else { continue }
            let m = activeMissions[idx]
            // Spoil perishable cargo
            if case .delivery(let commodity, let amount, _, _) = m.kind, m.isSmuggle != true {
                _ = player.removeCargo(commodity, amount: min(amount, player.cargo[commodity, default: 0]))
            }
            if m.isSmuggle == true, case .delivery(let commodity, let amount, _, _) = m.kind {
                _ = player.removeHiddenCargo(commodity, amount: min(amount, player.smuggleHold[commodity, default: 0]))
            }
            activeMissions.remove(at: idx)
            flash("CONTRACT FAILED: \(m.title) — cargo spoiled / voided.")
            postNews("Timed contract lapsed in \(currentSystemName).")
            audio.play(.hurt)
        }
    }

    // MARK: - Environment zones

    /// Recompute which zones the pilot is in and apply damage / energy / alerts.
    private func updateEnvironment(_ dt: Float) {
        environmentEffects = sampleEnvironment(at: player.position)
        let e = environmentEffects

        if environmentAlertCooldown > 0 { environmentAlertCooldown -= dt }
        if let alert = e.primaryAlert, e.isHazardous {
            if alert != lastEnvironmentAlert {
                flash("⚠ \(alert) — \(environmentZoneHint(alert))")
                audio.play(e.damagePerSec > 1 || e.sensorsBlind ? .hurt : .select)
                lastEnvironmentAlert = alert
                environmentAlertCooldown = 3.5
            } else if environmentAlertCooldown <= 0, e.damagePerSec > 1 {
                // Periodic reminder while cooking in radiation
                flash("⚠ \(alert) still cooking your ship!")
                environmentAlertCooldown = 4.0
                audio.play(.hurt)
            }
        }
        if e.labels.isEmpty {
            lastEnvironmentAlert = ""
        }

        // Proximity warning for pirate dens / enemy bases
        if enemyBaseAlertCooldown > 0 { enemyBaseAlertCooldown -= dt }
        if let den = currentSystem.stations.first(where: {
            $0.isEnemyBase && distance(player.position, $0.position) < $0.defenseRange * 1.15
        }) {
            if den.name != lastEnemyBaseAlert || enemyBaseAlertCooldown <= 0 {
                if playerAlliedWithPirates() || player.rep.repPirate >= 15 || player.isDirty {
                    if den.name != lastEnemyBaseAlert {
                        flash("\(den.name) — pirate den. Friendly if you keep standing.")
                        lastEnemyBaseAlert = den.name
                        enemyBaseAlertCooldown = 12
                    }
                } else {
                    flash("⚠ \(den.name) turrets — hostile den. Leave or earn pirate standing.")
                    audio.play(.hurt)
                    lastEnemyBaseAlert = den.name
                    enemyBaseAlertCooldown = 5
                }
            }
        } else {
            lastEnemyBaseAlert = ""
        }

        // Continuous environmental damage — beats shield regen in full fields
        if e.damagePerSec > 0.01 {
            var dmg = e.damagePerSec * dt
            if player.shield > 0 {
                let absorbed = min(player.shield, dmg)
                player.shield -= absorbed
                dmg -= absorbed
            }
            if dmg > 0 {
                player.hull -= dmg
            }
            hurtFlash = max(hurtFlash, 0.22)
        }

        // Ion drain — empties capacitor fast
        if e.energyDrainPerSec > 0.01 {
            player.energy = max(0, player.energy - e.energyDrainPerSec * dt)
        }
    }

    private func environmentZoneHint(_ alert: String) -> String {
        switch alert {
        case "RADIATION": return "shields melting"
        case "ION STORM": return "capacitors dumping"
        case "DUST": return "engines choked hard"
        case "CRYO": return "helm nearly frozen"
        case "GRAV SHEER": return "vector yanked"
        case "EM BLACKOUT": return "scanners dead"
        case "NEBULA": return "sensors muddied"
        default: return "space weather"
        }
    }

    func sampleEnvironment(at pos: SIMD2<Float>) -> EnvironmentEffects {
        var e = EnvironmentEffects()
        var grav = SIMD2<Float>.zero
        for zone in currentSystem.environmentZones {
            let s = zone.strength(at: pos)
            guard s > 0.02 else { continue }
            if !e.labels.contains(zone.kind.shortAlert) {
                e.labels.append(zone.kind.shortAlert)
            }
            switch zone.kind {
            case .nebula:
                // Hard scan penalty even at the rim
                e.scanMult *= max(0.2, 1 - 0.75 * s)
            case .radiation:
                // ~18–35 dps — outpaces typical shield regen
                e.damagePerSec += 28 * s
                e.scanMult *= max(0.35, 1 - 0.4 * s)
                e.speedMult *= max(0.7, 1 - 0.25 * s)
            case .ionStorm:
                // Drain full capacitor in ~1.5–3s at center
                e.energyDrainPerSec += 55 * s
                e.weaponCooldownMult *= 1 + 1.4 * s
                e.scanMult *= max(0.25, 1 - 0.5 * s)
            case .dust:
                // Feels like flying through mud
                e.thrustMult *= max(0.35, 1 - 0.6 * s)
                e.speedMult *= max(0.4, 1 - 0.55 * s)
            case .ice:
                e.turnMult *= max(0.28, 1 - 0.7 * s)
                e.thrustMult *= max(0.55, 1 - 0.35 * s)
            case .gravSheer:
                let dir = normalizeSafe(zone.position - pos)
                let side = SIMD2(-dir.y, dir.x)
                // Strong pull — noticeable course change every second
                grav += (dir * 280 + side * 180) * s
            case .emBlackout:
                e.sensorsBlind = true
                e.scanMult = 0
                e.weaponCooldownMult *= 1 + 0.35 * s
            }
        }
        e.gravPull = grav
        return e
    }

    /// Zones the player is currently inside (for HUD/minimap).
    func activeEnvironmentZones() -> [EnvironmentZone] {
        currentSystem.environmentZones.filter { $0.contains(player.position) }
    }

    private func updateScan(_ dt: Float) {
        guard keysDown.contains(Self.keyI) else {
            scanProgress = max(0, scanProgress - dt * 1.5)
            return
        }
        if environmentEffects.sensorsBlind {
            scanProgress = max(0, scanProgress - dt * 2)
            if scanProgress <= 0.05 {
                flash("EM blackout — scanners offline.")
            }
            return
        }
        guard let tid = targetID, let idx = npcs.firstIndex(where: { $0.id == tid }) else {
            scanProgress = 0
            return
        }
        let ship = npcs[idx]
        let d = distance(ship.position, player.position)
        let range = Self.scanRange * environmentEffects.scanMult
        guard d <= range else {
            scanProgress = max(0, scanProgress - dt)
            return
        }
        if ship.scannedByPlayer {
            scanProgress = 1
            return
        }
        let rate = (dt / Self.scanDuration) * max(0.25, environmentEffects.scanMult)
        scanProgress = min(1, scanProgress + rate)
        if scanProgress >= 1 {
            npcs[idx].scannedByPlayer = true
            scansCompleted += 1
            let want = npcs[idx].isWanted ? " WANTED" : ""
            let cargoBits = npcs[idx].manifest
                .sorted { $0.key.rawValue < $1.key.rawValue }
                .prefix(3)
                .map { "\($0.key.rawValue) ×\($0.value)" }
                .joined(separator: ", ")
            let cargo = cargoBits.isEmpty ? "no manifest" : cargoBits
            flash("ID: \(ship.name) · \(ship.faction.displayName)\(want) · \(cargo)")
            audio.play(.select)
            if scansCompleted >= 10 {
                grantAchievement(.scannerAce)
            }
        }
    }

    private func updateLawPlayerScan(_ dt: Float) {
        let dirtyActive = activeMissions.contains { $0.isDirty == true || $0.isSmuggle == true }
        let hot = dirtyActive || !player.smuggleHold.isEmpty
        guard hot else {
            lawScanProgress = 0
            return
        }
        let law = npcs.filter {
            ($0.faction == .police || $0.faction == .militia)
                && distance($0.position, player.position) < 300
        }
        guard let scanner = law.first else {
            lawScanProgress = max(0, lawScanProgress - dt * 0.5)
            return
        }
        _ = scanner
        lawScanProgress += dt
        if lawScanProgress >= 2.2 {
            lawScanProgress = 0
            // Bust: dump heat, confiscate hidden cargo
            let seized = player.smuggleHold
            player.hiddenCargo = [:]
            var r = player.rep
            r.adjust(police: -12, militia: -25, pirate: 8)
            r.addWanted(1)
            player.rep = r
            // Fail dirty missions
            activeMissions.removeAll { $0.isDirty == true || $0.isSmuggle == true }
            let goods = seized.keys.map(\.rawValue).joined(separator: ", ")
            flash("SCANNED by law — contraband seized\(goods.isEmpty ? "" : ": \(goods)"). Militia rep tanked.")
            postNews("\(currentSystemName): customs seizure — independent pilot cited.")
            audio.play(.hurt)
        }
    }

    private func updatePirateProtection(_ dt: Float) {
        guard var rem = player.pirateProtectionSeconds, rem > 0 else { return }
        rem -= dt
        player.pirateProtectionSeconds = max(0, rem)
        if rem <= 0 {
            player.pirateProtectionSeconds = nil
            flash("Pirate protection expired.")
        }
    }

    private func emitRadioChatter() {
        // Prefer nearby ships; fall back to ambient
        let nearby = npcs.filter {
            !$0.isWingman && distance($0.position, player.position) < 900
        }
        let speaker = nearby.randomElement()
        let line: String
        if let s = speaker {
            switch s.faction {
            case .trader:
                line = [
                    "\(s.name): Lane's quiet. For now.",
                    "\(s.name): Thanks for the escort, whoever you are.",
                    "\(s.name): Prices at \(currentSystem.stations.first?.name ?? "dock") look soft.",
                    "\(s.name): Watching the rings — pirates love this stretch.",
                    "\(s.name): Hold is full. Making for the freelane.",
                ].randomElement()!
            case .police:
                line = [
                    "Patrol: Maintain lane discipline.",
                    "Patrol: Any pilots with bounties — dock and settle.",
                    "Patrol: Sensors clean. Stay sharp.",
                    "Patrol: Report freelane sabotage immediately.",
                ].randomElement()!
            case .militia:
                line = [
                    "Militia: Keep your weapons cold near stations.",
                    "Militia: Kestrel freelancers, check in when you can.",
                    "Militia: We saw Vael signatures on the rim.",
                ].randomElement()!
            case .pirate:
                line = [
                    "Unknown: Nice ship. Shame if something happened.",
                    "Raider net: Fat freighter on the lane. Eyes open.",
                    "Unknown: Don't cross us, lane-runner.",
                ].randomElement()!
            case .alien:
                line = [
                    "…static… harmonic bleed…",
                    "Unknown band: [untranslatable pulse]",
                    "Sensors: Vael telemetry leaking into comms.",
                ].randomElement()!
            }
        } else {
            line = [
                "Traffic control: \(currentSystem.displayName) approach nominal.",
                "Comms: Freelane beacons responding.",
                "Relay: Watch the NEWS feed for market shifts.",
            ].randomElement()!
        }
        radioLine = line
        radioTimer = 4.2
    }

    // MARK: - Trade lanes

    private func clearTradeLane() {
        onTradeLane = false
        tradeLaneID = nil
        tradeLaneRingIndex = 0
        tradeLaneDirection = 1
        tradeLaneProgress = 0
    }

    /// Ghost world position at current race timer (nil if no ghost / not racing).
    func raceGhostPose() -> (position: SIMD2<Float>, angle: Float)? {
        guard raceActive, !raceGhostSamples.isEmpty else { return nil }
        let samples = raceGhostSamples
        let t = raceTimer
        if t <= samples[0].t {
            return (samples[0].position, samples[0].angle)
        }
        if t >= samples[samples.count - 1].t {
            let last = samples[samples.count - 1]
            return (last.position, last.angle)
        }
        for i in 0..<(samples.count - 1) {
            let a = samples[i]
            let b = samples[i + 1]
            if t >= a.t, t <= b.t {
                let span = max(0.001, b.t - a.t)
                let u = (t - a.t) / span
                let pos = a.position + (b.position - a.position) * u
                let ang = a.angle + wrapAngle(b.angle - a.angle) * u
                return (pos, ang)
            }
        }
        let last = samples[samples.count - 1]
        return (last.position, last.angle)
    }

    static func formatRaceTime(_ t: Float) -> String {
        let m = Int(t) / 60
        let s = t - Float(m * 60)
        if m > 0 {
            return String(format: "%d:%05.2f", m, s)
        }
        return String(format: "%.2f", s)
    }

    private func currentTradeLane() -> TradeLane? {
        guard let id = tradeLaneID else { return nil }
        return currentSystem.tradeLanes.first { $0.id == id }
    }

    /// Nearest trade-lane ring within enter range, if any.
    func nearbyTradeRing() -> (lane: TradeLane, index: Int)? {
        var best: (TradeLane, Int, Float)?
        for lane in currentSystem.tradeLanes {
            for (i, p) in lane.points.enumerated() {
                let d = distance(player.position, p)
                if d < lane.ringRadius + 25 {
                    if best == nil || d < best!.2 {
                        best = (lane, i, d)
                    }
                }
            }
        }
        if let b = best { return (b.0, b.1) }
        return nil
    }

    private func enterTradeLane(_ lane: TradeLane, at index: Int, direction: Int) {
        let canBypass = player.hasAncientLaneCore
        if lane.isRingDisrupted(index), !canBypass {
            flash("Ring offline — freelane segment disrupted by pirates.")
            audio.play(.hurt)
            return
        }
        var dir = direction
        if index == 0 { dir = 1 }
        if index >= lane.points.count - 1 { dir = -1 }
        let next = index + dir
        guard next >= 0, next < lane.points.count else { return }
        if lane.isRingDisrupted(next), !canBypass {
            flash("Next ring is disrupted — cannot enter this direction.")
            audio.play(.hurt)
            return
        }

        onTradeLane = true
        tradeLaneID = lane.id
        tradeLaneRingIndex = index
        tradeLaneDirection = dir
        tradeLaneProgress = 0
        player.position = lane.points[index]
        player.velocity = .zero
        let target = lane.points[next]
        player.angle = angleToward(lane.points[index], target)
        var msg = "Trade lane locked — \(lane.name). Hold S to exit."
        if canBypass, lane.isRingDisrupted(index) || lane.isRingDisrupted(next) {
            msg = "Lane Core bypass — \(lane.name) (offline ring overridden)."
        }
        if player.freelaneBoostActive {
            msg += " BOOST"
        }
        // End-to-end time trial when entering at a terminus
        beginFreelaneRaceIfEligible(lane: lane, index: index, direction: dir)
        if raceActive {
            if let pb = racePBTime {
                msg = "TIME TRIAL — \(lane.name)  PB \(Self.formatRaceTime(pb))"
            } else {
                msg = "TIME TRIAL — \(lane.name)  (set a personal best)"
            }
        }
        flash(msg)
        audio.play(.freelaneEnter)
        player.log.freelanesRidden += 1
        if !player.storyFreelaneDone {
            player.storyFreelaneDone = true
            checkStoryProgress(context: "freelane")
        }
        grantAchievement(.firstFreelane)
    }

    private func beginFreelaneRaceIfEligible(lane: TradeLane, index: Int, direction: Int) {
        let last = lane.points.count - 1
        // Only full terminus → terminus runs count
        let endToEnd = (index == 0 && direction > 0) || (index == last && direction < 0)
        guard endToEnd, lane.points.count >= 3 else {
            abortFreelaneRace(silent: true)
            return
        }
        raceActive = true
        raceStartIsEndToEnd = true
        raceTimer = 0
        raceLaneName = lane.name
        raceDirection = direction
        raceSamples = []
        raceSampleAcc = 0
        let rec = player.freelanePB(
            system: currentSystemName, lane: lane.name, direction: direction
        )
        racePBTime = rec?.bestTime
        raceGhostSamples = rec?.ghost ?? []
        // Seed first sample
        raceSamples.append(FreelaneGhostSample(
            t: 0, x: player.position.x, y: player.position.y, angle: player.angle
        ))
    }

    private func abortFreelaneRace(silent: Bool) {
        guard raceActive || !raceSamples.isEmpty else {
            raceActive = false
            raceGhostSamples = []
            racePBTime = nil
            return
        }
        if raceActive, !silent {
            flash("Time trial voided — \(raceLaneName).")
        }
        raceActive = false
        raceSamples = []
        raceGhostSamples = []
        racePBTime = nil
        raceTimer = 0
    }

    private func finishFreelaneRace() {
        guard raceActive, raceStartIsEndToEnd else {
            abortFreelaneRace(silent: true)
            return
        }
        let time = raceTimer
        // Final sample
        raceSamples.append(FreelaneGhostSample(
            t: time, x: player.position.x, y: player.position.y, angle: player.angle
        ))
        let prevPB = racePBTime
        let beatGhost = prevPB != nil && time < (prevPB ?? .greatestFiniteMagnitude)
        let isPB = player.setFreelanePB(
            system: currentSystemName,
            lane: raceLaneName,
            direction: raceDirection,
            time: time,
            ghost: raceSamples
        )
        let timeStr = Self.formatRaceTime(time)
        if isPB {
            if let prev = prevPB {
                let delta = prev - time
                raceResultBanner = "NEW BEST \(timeStr)  (−\(Self.formatRaceTime(delta)))"
                flash("NEW BEST on \(raceLaneName)! \(timeStr) (−\(Self.formatRaceTime(delta)))")
                if beatGhost {
                    grantAchievement(.laneGhost)
                }
            } else {
                raceResultBanner = "PB SET \(timeStr)"
                flash("Personal best on \(raceLaneName)! \(timeStr)")
            }
            audio.play(.win)
            postNews("Lane trial: \(raceLaneName) — \(timeStr) (personal best).")
            if (player.freelanePBsSet ?? 0) >= 5 {
                grantAchievement(.laneRacer)
            }
            evaluateAchievements()
        } else if let pb = prevPB {
            let delta = time - pb
            raceResultBanner = "\(timeStr)  (+\(Self.formatRaceTime(delta)) vs PB)"
            flash("Lane run \(timeStr) — PB is \(Self.formatRaceTime(pb)) (+\(Self.formatRaceTime(delta)))")
            audio.play(.select)
        } else {
            raceResultBanner = timeStr
            flash("Lane run \(timeStr).")
        }
        raceResultTimer = 4.5
        raceActive = false
        raceSamples = []
        raceGhostSamples = []
        racePBTime = nil
    }

    private func activateFreelaneBoost() {
        guard player.hasAncientLaneCore else {
            flash("No Ancient Lane Core — finish the freelane mystery (Nyx → Umbra → Drift).")
            audio.play(.hurt)
            return
        }
        guard freelaneBoostCooldown <= 0 else {
            flash("Lane boost recharging (\(Int(freelaneBoostCooldown))s).")
            audio.play(.hurt)
            return
        }
        guard !player.freelaneBoostActive else {
            flash("Lane boost already active (\(Int(player.freelaneBoostSeconds ?? 0))s).")
            return
        }
        player.freelaneBoostSeconds = 40
        flash("ANCIENT LANE BOOST — freelane cruise supercharged for 40s.")
        postNews("Freelane harmonics spike — pilot using pre-war lane tech.")
        audio.play(.win)
    }

    /// Effective freelane cruise speed (boost from ancient core + weather).
    private var effectiveTradeLaneSpeed: Float {
        var base = tradeLaneSpeed
        // Ancient core: even faster lane run on top of already-high cruise
        if player.freelaneBoostActive { base *= 1.65 }
        // Dust / radiation still slow freelane travel (lanes help, not ignore weather)
        base *= environmentEffects.speedMult
        return base
    }

    private func exitTradeLane(reason: String) {
        guard onTradeLane else { return }
        let finished = reason == "Trade lane complete." || reason == "Trade lane terminus."
        if finished, raceActive {
            finishFreelaneRace() // flashes result
        } else if raceActive {
            abortFreelaneRace(silent: false) // flashes voided
        } else {
            flash(reason)
        }
        // Carry some residual cruise velocity outward
        let forward = angleToVector(player.angle)
        player.velocity = forward * min(player.stats.maxSpeed * 0.85, 280)
        clearTradeLane()
        audio.play(.freelaneExit)
    }

    /// Pirates knock you off freelane immediately — classic Freelancer risk.
    private func hijackTradeLane(by pirateName: String?) {
        guard onTradeLane else { return }
        if raceActive { abortFreelaneRace(silent: false) }
        let forward = angleToVector(player.angle)
        // Violent drop: dump sideways with residual speed
        let side = SIMD2(-forward.y, forward.x)
        player.velocity = forward * 160 + side * Float.random(in: -120...120)
        clearTradeLane()
        let who = pirateName ?? "Pirates"
        flash("\(who) hijacked the trade lane!")
        audio.play(.freelaneExit)
        audio.play(.hurt)
        spawnHitParticles(at: player.position, enemy: true)
        invuln = 0.2
    }

    /// Check nearby hostiles for freelane disruption (boarding range / ambush).
    private func checkTradeLaneHijack() {
        guard onTradeLane else { return }
        // Close-range boarding / sabotage
        let boardingRange: Float = 95
        for ship in npcs where ship.isHostile {
            if distance(ship.position, player.position) < boardingRange {
                hijackTradeLane(by: ship.name)
                return
            }
        }
    }

    private func updateTradeLaneTravel(_ dt: Float) {
        // Exit on reverse / brake
        if keysDown.contains(Self.keyS) || keysDown.contains(Self.keyDown) {
            exitTradeLane(reason: "Left the trade lane.")
            return
        }

        // Pirates can rip you out of the freelane
        checkTradeLaneHijack()
        if !onTradeLane { return }

        guard let lane = currentTradeLane() else {
            clearTradeLane()
            return
        }
        let points = lane.points
        let i = tradeLaneRingIndex
        let next = i + tradeLaneDirection
        guard next >= 0, next < points.count else {
            exitTradeLane(reason: "Trade lane complete.")
            return
        }

        let from = points[i]
        let to = points[next]
        // Block mid-run if next ring is sabotaged (unless ancient core)
        if lane.isRingDisrupted(next), !player.hasAncientLaneCore {
            exitTradeLane(reason: "Forward ring offline — dumped from freelane.")
            return
        }
        let segLen = max(1, distance(from, to))
        tradeLaneProgress += (effectiveTradeLaneSpeed * dt) / segLen

        // Time trial clock + ghost samples
        if raceActive {
            raceTimer += dt
            raceSampleAcc += dt
            if raceSampleAcc >= 0.12 {
                raceSampleAcc = 0
                raceSamples.append(FreelaneGhostSample(
                    t: raceTimer,
                    x: player.position.x,
                    y: player.position.y,
                    angle: player.angle
                ))
            }
        }

        // Cruise particles
        if Int(time * 40) != Int((time - dt) * 40) {
            let along = normalizeSafe(to - from)
            spawnThrustParticle(at: player.position - along * 10, dir: -along)
        }

        // Approaching a disrupted ring — forced dump (unless ancient core)
        if lane.isRingDisrupted(next), !player.hasAncientLaneCore, tradeLaneProgress > 0.55 {
            player.position = from + (to - from) * tradeLaneProgress
            exitTradeLane(reason: "Disrupted freelane ring — forced disconnect!")
            postNews("\(currentSystemName): freelane segment offline.")
            return
        }

        if tradeLaneProgress >= 1 {
            tradeLaneProgress = 0
            tradeLaneRingIndex = next
            player.position = points[next]
            if lane.isRingDisrupted(next), !player.hasAncientLaneCore {
                player.angle = angleToward(from, to)
                exitTradeLane(reason: "Disrupted freelane ring — forced disconnect!")
                return
            }
            let ahead = next + tradeLaneDirection
            if ahead < 0 || ahead >= points.count {
                player.angle = angleToward(from, to)
                exitTradeLane(reason: "Trade lane complete.")
            } else if lane.isRingDisrupted(ahead), !player.hasAncientLaneCore {
                player.angle = angleToward(from, to)
                exitTradeLane(reason: "Next freelane ring is offline — dumped early.")
                postNews("\(lane.name): ring offline until patrols clear it.")
            } else {
                player.angle = angleToward(points[next], points[ahead])
            }
        } else {
            player.position = from + (to - from) * tradeLaneProgress
            player.angle = angleToward(from, to)
            player.velocity = normalizeSafe(to - from) * effectiveTradeLaneSpeed
        }
    }

    /// Pirates sabotage rings; militia clears them over time.
    private func updateLaneDisruptions(_ dt: Float) {
        guard var sys = systems[currentSystemName] else { return }
        for li in sys.tradeLanes.indices {
            // Tick down existing disruptions
            var rings = sys.tradeLanes[li].disruptedRings
            for key in rings.keys {
                rings[key] = (rings[key] ?? 0) - dt
                if (rings[key] ?? 0) <= 0 { rings.removeValue(forKey: key) }
            }
            sys.tradeLanes[li].disruptedRings = rings

            let lane = sys.tradeLanes[li]
            // Pirates near a ring sabotage it
            for (ri, ringPos) in lane.points.enumerated() {
                guard !lane.isRingDisrupted(ri) else { continue }
                let piratesNear = npcs.filter {
                    $0.isHostile && !$0.isWingman && distance($0.position, ringPos) < 140
                }
                if piratesNear.count >= 1, Float.random(in: 0...1) < 0.012 * Float(piratesNear.count) {
                    let duration = Float.random(in: 25...50)
                    sys.tradeLanes[li].disruptedRings[ri] = duration
                    postNews("\(currentSystemName): pirates disrupted a freelane ring!")
                    flash("Freelane ring sabotaged!")
                    audio.play(.hurt)
                }
            }
            // Militia / police near disrupted ring repair faster
            for (ri, ringPos) in lane.points.enumerated() {
                guard sys.tradeLanes[li].isRingDisrupted(ri) else { continue }
                let helpers = npcs.filter {
                    ($0.faction == .militia || $0.faction == .police || $0.isWingman)
                        && distance($0.position, ringPos) < 160
                }
                if !helpers.isEmpty {
                    let left = (sys.tradeLanes[li].disruptedRings[ri] ?? 0) - dt * 3.5 * Float(helpers.count)
                    if left <= 0 {
                        sys.tradeLanes[li].disruptedRings.removeValue(forKey: ri)
                        postNews("\(currentSystemName): freelane ring restored by patrols.")
                    } else {
                        sys.tradeLanes[li].disruptedRings[ri] = left
                    }
                }
            }
        }
        systems[currentSystemName] = sys
    }

    private func firePrimaryWeapon() {
        switch player.weaponMode {
        case .laser: firePlayerLaser()
        case .plasma: firePlayerPlasma()
        case .pulse: firePlayerPulse()
        case .rail: firePlayerRail()
        }
    }

    private func firePlayerLaser() {
        let cost = player.stats.laserEnergyCost
        guard player.energy >= cost else {
            if fireCooldown <= 0 {
                flash("Energy low — capacitors charging.")
                fireCooldown = 0.2
                audio.play(.hurt)
            }
            return
        }
        player.energy -= cost
        fireCooldown = player.stats.laserCooldown * environmentEffects.weaponCooldownMult
        let dir = angleToVector(player.angle)
        let muzzle = player.position + dir * 18
        projectiles.append(Projectile(
            id: UUID(),
            position: muzzle,
            velocity: dir * 520 + player.velocity * 0.3,
            damage: player.stats.laserDamage,
            life: 1.2,
            source: .player,
            ownerID: nil,
            kind: .laser
        ))
        audio.play(.laser)
        particles.append(Particle(
            id: UUID(), position: muzzle, velocity: dir * 40,
            life: 0.12, maxLife: 0.12,
            color: (0.4, 1.0, 0.9), size: 4
        ))
    }

    private func firePlayerPlasma() {
        let cost = player.stats.plasmaEnergyCost
        guard player.energy >= cost else {
            if fireCooldown <= 0 {
                flash("Energy low — plasma offline.")
                fireCooldown = 0.25
                audio.play(.hurt)
            }
            return
        }
        player.energy -= cost
        fireCooldown = player.stats.plasmaCooldown * environmentEffects.weaponCooldownMult
        let dir = angleToVector(player.angle)
        let muzzle = player.position + dir * 20
        projectiles.append(Projectile(
            id: UUID(),
            position: muzzle,
            velocity: dir * 380 + player.velocity * 0.25,
            damage: player.stats.plasmaDamage,
            life: 1.35,
            source: .player,
            ownerID: nil,
            kind: .plasma
        ))
        audio.play(.laser)
        // Heavier muzzle flash
        for _ in 0..<4 {
            let a = player.angle + Float.random(in: -0.3...0.3)
            particles.append(Particle(
                id: UUID(), position: muzzle,
                velocity: angleToVector(a) * Float.random(in: 30...90),
                life: Float.random(in: 0.12...0.22), maxLife: 0.22,
                color: (0.7, 0.35, 1.0), size: Float.random(in: 3...7)
            ))
        }
    }

    private func firePlayerPulse() {
        let cost = player.stats.pulseEnergyCost
        guard player.energy >= cost else {
            if fireCooldown <= 0 {
                flash("Energy low — pulse offline.")
                fireCooldown = 0.15
                audio.play(.hurt)
            }
            return
        }
        player.energy -= cost
        fireCooldown = player.stats.pulseCooldown * environmentEffects.weaponCooldownMult
        let dir = angleToVector(player.angle)
        let muzzle = player.position + dir * 16
        // Twin staggered bolts
        for side: Float in [-1, 1] {
            let offset = angleToVector(player.angle + .pi / 2) * side * 4
            projectiles.append(Projectile(
                id: UUID(),
                position: muzzle + offset,
                velocity: dir * 580 + player.velocity * 0.25,
                damage: player.stats.pulseDamage,
                life: 0.85,
                source: .player,
                ownerID: nil,
                kind: .pulse
            ))
        }
        audio.play(.laser)
        particles.append(Particle(
            id: UUID(), position: muzzle, velocity: dir * 50,
            life: 0.08, maxLife: 0.08,
            color: (1.0, 0.92, 0.35), size: 3
        ))
    }

    private func firePlayerRail() {
        let cost = player.stats.railEnergyCost
        guard player.energy >= cost else {
            if fireCooldown <= 0 {
                flash("Energy low — rail capacitors charging.")
                fireCooldown = 0.3
                audio.play(.hurt)
            }
            return
        }
        player.energy -= cost
        fireCooldown = player.stats.railCooldown * environmentEffects.weaponCooldownMult
        let dir = angleToVector(player.angle)
        let muzzle = player.position + dir * 22
        projectiles.append(Projectile(
            id: UUID(),
            position: muzzle,
            velocity: dir * 900 + player.velocity * 0.1,
            damage: player.stats.railDamage,
            life: 1.6,
            source: .player,
            ownerID: nil,
            kind: .rail
        ))
        audio.play(.laser)
        for _ in 0..<5 {
            particles.append(Particle(
                id: UUID(), position: muzzle,
                velocity: dir * Float.random(in: 40...120) + angleToVector(player.angle + Float.random(in: -0.4...0.4)) * 20,
                life: Float.random(in: 0.1...0.2), maxLife: 0.2,
                color: (0.55, 0.8, 1.0), size: Float.random(in: 2...5)
            ))
        }
    }

    private func firePlayerMissile() {
        guard player.missiles > 0 else {
            flash("No missiles — buy reloads at any station Outfitter.")
            audio.play(.hurt)
            return
        }
        // Lock: current target if in range & hostile, else nearest hostile in range
        let lock = missileLockTarget()
        guard let lock else {
            flash("No lock — target hostiles within \(Int(Self.missileLockRange))m (T).")
            audio.play(.hurt)
            return
        }
        player.missiles -= 1
        let dir = angleToVector(player.angle)
        let muzzle = player.position + dir * 16
        let toTarget = normalizeSafe(lock.position - player.position)
        let launchDir = simd_length(toTarget) > 0.1 ? toTarget : dir
        let dmg = Self.missileDamage * player.missileDamageMult
        projectiles.append(Projectile(
            id: UUID(),
            position: muzzle,
            velocity: launchDir * Self.missileSpeed + player.velocity * 0.15,
            damage: dmg,
            life: 4.5,
            source: .player,
            ownerID: nil,
            kind: .missile,
            targetID: lock.id,
            turnRate: Self.missileTurnRate,
            speed: Self.missileSpeed
        ))
        flash("Missile away → \(lock.name)  (\(player.missiles) left)")
        audio.play(.hurt) // distinct enough until dedicated SFX
        for _ in 0..<6 {
            particles.append(Particle(
                id: UUID(), position: muzzle,
                velocity: -dir * Float.random(in: 40...100) + SIMD2(Float.random(in: -20...20), Float.random(in: -20...20)),
                life: 0.3, maxLife: 0.3,
                color: (1.0, 0.55, 0.2), size: 3
            ))
        }
    }

    private func missileLockTarget() -> NPCShip? {
        if let tid = targetID,
           let t = npcs.first(where: { $0.id == tid && $0.isHostile && !$0.isWingman }),
           distance(t.position, player.position) <= Self.missileLockRange {
            return t
        }
        return npcs
            .filter { $0.isHostile && !$0.isWingman && distance($0.position, player.position) <= Self.missileLockRange }
            .min(by: { distance($0.position, player.position) < distance($1.position, player.position) })
    }

    private func updateNPCs(_ dt: Float) {
        let playerPos = player.position

        for i in npcs.indices.reversed() {
            var ship = npcs[i]
            ship.aiTimer -= dt
            ship.fireCooldown -= dt
            if ship.missileCooldown > 0 { ship.missileCooldown -= dt }
            if ship.shield < ship.maxShield {
                let regen: Float = ship.isCapital ? 6 : 4
                ship.shield = min(ship.maxShield, ship.shield + regen * dt)
            }

            // Disabled freighters drift slowly (drop freelane)
            if ship.enginesDisabled {
                ship.onTradeLane = false
                ship.tradeLaneID = nil
                ship.velocity *= exp(-1.5 * dt)
                ship.position += ship.velocity * dt
                npcs[i] = ship
                continue
            }

            // Wingman: escort player and engage hostiles
            if ship.isWingman {
                updateWingmanAI(&ship, dt: dt, playerPos: playerPos)
                let sp = simd_length(ship.velocity)
                if sp > ship.speed {
                    ship.velocity = normalizeSafe(ship.velocity) * ship.speed
                }
                ship.velocity *= pow(0.99, dt * 60)
                ship.position += ship.velocity * dt
                npcs[i] = ship
                continue
            }

            // Cargo freelane cruise takes priority over normal tramp AI
            if ship.isCargo, ship.onTradeLane {
                updateNPCFreelaneTravel(&ship, dt: dt)
                // Soft bounds still apply
                let b = currentSystem.bounds
                ship.position.x = max(-b, min(b, ship.position.x))
                ship.position.y = max(-b, min(b, ship.position.y))
                npcs[i] = ship
                continue
            }

            // AI behavior
            switch ship.faction {
            case .pirate:
                let d = distance(ship.position, playerPos)
                // High pirate rep or paid Umbra protection: largely ignore the player
                let toleratePlayer = player.rep.repPirate >= 30 || player.protectionActive
                let huntRange: Float = toleratePlayer
                    ? (onTradeLane ? 400 : 220)
                    : (onTradeLane ? 1400 : 700)
                let fireRange: Float = onTradeLane ? 520 : 420
                let turnRate: Float = onTradeLane ? 3.4 : 2.5
                let thrust: Float = onTradeLane ? 220 : 160

                // Flee friendly station defenses — not their own pirate dens
                var fleeingStation = false
                if let st = currentSystem.stations.first(where: {
                    $0.hasDefenses && !$0.isEnemyBase
                        && distance(ship.position, $0.position) < $0.defenseRange * 0.75
                }), ship.hull < ship.maxHull * 0.7 || distance(ship.position, st.position) < st.defenseRange * 0.45 {
                    let away = angleToward(st.position, ship.position)
                    ship.angle = lerpAngle(ship.angle, away, 3.2 * dt)
                    ship.velocity += angleToVector(ship.angle) * 200 * dt
                    fleeingStation = true
                }

                let nearbyTrader = npcs.first(where: {
                    $0.isCargo && !$0.isWingman && distance($0.position, ship.position) < (toleratePlayer ? 520 : 400)
                })

                if !fleeingStation, toleratePlayer, let trader = nearbyTrader {
                    let desired = angleToward(ship.position, trader.position)
                    ship.angle = lerpAngle(ship.angle, desired, 1.8 * dt)
                    ship.velocity += angleToVector(ship.angle) * 140 * dt
                    if distance(ship.position, trader.position) < 360, ship.fireCooldown <= 0 {
                        fireNPC(&ship)
                    }
                } else if !fleeingStation, d < huntRange {
                    var aim = playerPos
                    if onTradeLane, simd_length(player.velocity) > 50 {
                        aim = playerPos + normalizeSafe(player.velocity) * min(280, d * 0.35)
                    }
                    let desired = angleToward(ship.position, aim)
                    ship.angle = lerpAngle(ship.angle, desired, turnRate * dt)
                    let fwd = angleToVector(ship.angle)
                    ship.velocity += fwd * thrust * dt
                    if d < fireRange, ship.fireCooldown <= 0, abs(wrapAngle(desired - ship.angle)) < 0.4 {
                        fireNPC(&ship)
                    }
                    if onTradeLane, d < 200 {
                        ship.velocity += fwd * 80 * dt
                    } else if d < 120 {
                        ship.velocity -= fwd * 80 * dt
                    }
                } else if !fleeingStation {
                    if let lane = currentSystem.tradeLanes.randomElement(),
                       let ring = lane.points.randomElement(),
                       ship.aiTimer <= 0 {
                        let desired = angleToward(ship.position, ring)
                        ship.angle = lerpAngle(ship.angle, desired, 1.5 * dt)
                        ship.velocity += angleToVector(ship.angle) * 100 * dt
                        if distance(ship.position, ring) < 80 {
                            ship.aiTimer = Float.random(in: 2...5)
                        }
                    } else {
                        wander(&ship, dt: dt)
                    }
                }
                if !toleratePlayer, let trader = nearbyTrader {
                    let desired = angleToward(ship.position, trader.position)
                    ship.angle = lerpAngle(ship.angle, desired, 1.5 * dt)
                    if distance(ship.position, trader.position) < 350, ship.fireCooldown <= 0 {
                        fireNPC(&ship)
                    }
                }

            case .trader:
                updateCargoAI(&ship, dt: dt, index: i)
                // Despawn if reached station (dock complete)
                if !ship.onTradeLane,
                   let st = currentSystem.stations.min(by: {
                       distance($0.position, ship.position) < distance($1.position, ship.position)
                   }),
                   distance(ship.position, st.position) < st.radius {
                    npcs.remove(at: i)
                    continue
                }

            case .police, .militia:
                updateLawEnforcementAI(&ship, dt: dt, faction: ship.faction)

            case .alien:
                // Vael: aggressive hunters, ignore freelane pirates playbook — focus the player
                let d = distance(ship.position, playerPos)
                let huntRange: Float = onTradeLane ? 1600 : 900
                let fireRange: Float = onTradeLane ? 560 : 440
                if d < huntRange {
                    var aim = playerPos
                    if onTradeLane, simd_length(player.velocity) > 40 {
                        aim = playerPos + normalizeSafe(player.velocity) * min(300, d * 0.4)
                    }
                    let desired = angleToward(ship.position, aim)
                    ship.angle = lerpAngle(ship.angle, desired, 2.8 * dt)
                    ship.velocity += angleToVector(ship.angle) * 190 * dt
                    if d < fireRange, ship.fireCooldown <= 0, abs(wrapAngle(desired - ship.angle)) < 0.45 {
                        fireNPC(&ship)
                    }
                    if d < 100 {
                        ship.velocity -= angleToVector(ship.angle) * 50 * dt
                    }
                } else {
                    // Patrol alien corridors / stations
                    if let st = currentSystem.stations.randomElement(), ship.aiTimer <= 0 {
                        let desired = angleToward(ship.position, st.position)
                        ship.angle = lerpAngle(ship.angle, desired, 1.4 * dt)
                        ship.velocity += angleToVector(ship.angle) * 100 * dt
                        if distance(ship.position, st.position) < 200 {
                            ship.aiTimer = Float.random(in: 2...5)
                        }
                    } else {
                        wander(&ship, dt: dt)
                    }
                }
            }

            // Cap speed
            let sp = simd_length(ship.velocity)
            if sp > ship.speed {
                ship.velocity = normalizeSafe(ship.velocity) * ship.speed
            }
            ship.velocity *= pow(0.99, dt * 60)
            ship.position += ship.velocity * dt

            // Soft bounds
            let b = currentSystem.bounds
            ship.position.x = max(-b, min(b, ship.position.x))
            ship.position.y = max(-b, min(b, ship.position.y))

            npcs[i] = ship
        }
    }

    private func wander(_ ship: inout NPCShip, dt: Float) {
        if ship.aiTimer <= 0 {
            ship.aiTimer = Float.random(in: 1.5...4)
            ship.angle += Float.random(in: -1.2...1.2)
        }
        ship.velocity += angleToVector(ship.angle) * 60 * dt
    }

    /// Police/militia: chase wanted player, help allies with high rep, otherwise hunt pirates.
    private func updateLawEnforcementAI(_ ship: inout NPCShip, dt: Float, faction: Faction) {
        let playerPos = player.position
        let dPlayer = distance(ship.position, playerPos)
        let rep = faction == .police ? player.rep.repPolice : player.rep.repMilitia
        let huntPlayer = player.isWanted && dPlayer < (500 + Float(player.wantedLevel) * 120)

        // High standing + clean: ignore player aggression range, focus pirates harder
        let helpPlayer = !player.isWanted && rep >= 20

        if huntPlayer {
            // Chase the fugitive
            let desired = angleToward(ship.position, playerPos)
            ship.angle = lerpAngle(ship.angle, desired, 2.6 * dt)
            ship.velocity += angleToVector(ship.angle) * 180 * dt
            if dPlayer < 400, ship.fireCooldown <= 0, abs(wrapAngle(desired - ship.angle)) < 0.45 {
                fireNPC(&ship)
            }
            if dPlayer < 100 {
                ship.velocity -= angleToVector(ship.angle) * 70 * dt
            }
            return
        }

        // Hunt pirates (wider range when helping a reputable pilot)
        let pirateRange: Float = helpPlayer ? 750 : 600
        if let pirate = npcs.first(where: { $0.isHostile && distance($0.position, ship.position) < pirateRange }) {
            let desired = angleToward(ship.position, pirate.position)
            ship.angle = lerpAngle(ship.angle, desired, 2.2 * dt)
            ship.velocity += angleToVector(ship.angle) * 150 * dt
            if distance(ship.position, pirate.position) < 380, ship.fireCooldown <= 0,
               abs(wrapAngle(desired - ship.angle)) < 0.4 {
                fireNPC(&ship)
            }
            // When helping, also push toward player if pirate is near them
            if helpPlayer, distance(pirate.position, playerPos) < 500 {
                ship.velocity += normalizeSafe(playerPos - ship.position) * 40 * dt
            }
        } else if helpPlayer, dPlayer < 900, dPlayer > 150 {
            // Escort orbit when no hostiles
            let form = playerPos + angleToVector(player.angle + 1.4) * 90
            let desired = angleToward(ship.position, form)
            ship.angle = lerpAngle(ship.angle, desired, 1.8 * dt)
            ship.velocity += angleToVector(ship.angle) * 120 * dt
        } else {
            wander(&ship, dt: dt)
        }
    }

    // MARK: - Cargo freelanes & traffic

    private func updateCargoAI(_ ship: inout NPCShip, dt: Float, index: Int) {
        // Flee pirates — drop freelane if boarded-threat close
        if let pirate = npcs.first(where: {
            $0.isHostile && !$0.isWingman && distance($0.position, ship.position) < 380
        }) {
            if ship.onTradeLane {
                exitNPCFreelane(&ship, residual: true)
            }
            let away = angleToward(pirate.position, ship.position)
            ship.angle = lerpAngle(ship.angle, away, 3 * dt)
            ship.velocity += angleToVector(ship.angle) * min(ship.speed * 0.95, 170) * dt
            return
        }

        // Already handled freelane cruise above; seek and enter freelanes
        if tryEnterNPCFreelane(&ship) {
            return
        }

        // Navigate toward nearest usable freelane ring (prefer non-disrupted)
        if let target = nearestOpenFreelaneRing(from: ship.position) {
            let desired = angleToward(ship.position, target.pos)
            ship.angle = lerpAngle(ship.angle, desired, 1.4 * dt)
            let thrust = ship.hullType == .courier ? ship.speed * 0.85 : ship.speed * 0.6
            ship.velocity += angleToVector(ship.angle) * thrust * dt
            return
        }

        // Fallback: station approach
        if let st = currentSystem.stations.min(by: {
            distance($0.position, ship.position) < distance($1.position, ship.position)
        }) {
            let desired = angleToward(ship.position, st.position)
            ship.angle = lerpAngle(ship.angle, desired, 1.2 * dt)
            ship.velocity += angleToVector(ship.angle) * (ship.speed * 0.55) * dt
        } else {
            wander(&ship, dt: dt)
        }
        _ = index
        _ = dt
    }

    private func nearestOpenFreelaneRing(from pos: SIMD2<Float>) -> (lane: TradeLane, index: Int, pos: SIMD2<Float>)? {
        var best: (TradeLane, Int, SIMD2<Float>, Float)?
        for lane in currentSystem.tradeLanes {
            for (i, p) in lane.points.enumerated() {
                if lane.isRingDisrupted(i) { continue }
                // Need at least one free neighbor direction
                let canFwd = i + 1 < lane.points.count && !lane.isRingDisrupted(i + 1)
                let canBack = i - 1 >= 0 && !lane.isRingDisrupted(i - 1)
                guard canFwd || canBack else { continue }
                let d = distance(pos, p)
                if best == nil || d < best!.3 {
                    best = (lane, i, p, d)
                }
            }
        }
        if let b = best { return (b.0, b.1, b.2) }
        return nil
    }

    @discardableResult
    private func tryEnterNPCFreelane(_ ship: inout NPCShip) -> Bool {
        guard !ship.onTradeLane else { return true }
        for lane in currentSystem.tradeLanes {
            for (i, p) in lane.points.enumerated() {
                guard distance(ship.position, p) < lane.ringRadius + 30 else { continue }
                guard !lane.isRingDisrupted(i) else { continue }
                var dir = 1
                if i == 0 { dir = 1 }
                else if i >= lane.points.count - 1 { dir = -1 }
                else {
                    // Prefer direction toward farthest end / denser traffic away from pirates
                    let face = angleToVector(ship.angle)
                    let toNext = normalizeSafe(lane.points[i + 1] - p)
                    let toPrev = normalizeSafe(lane.points[i - 1] - p)
                    dir = simd_dot(face, toNext) >= simd_dot(face, toPrev) ? 1 : -1
                    if lane.isRingDisrupted(i + dir) {
                        dir = -dir
                    }
                }
                let next = i + dir
                guard next >= 0, next < lane.points.count, !lane.isRingDisrupted(next) else { continue }

                ship.onTradeLane = true
                ship.tradeLaneID = lane.id
                ship.tradeLaneRingIndex = i
                ship.tradeLaneDirection = dir
                ship.tradeLaneProgress = 0
                ship.position = p
                ship.velocity = .zero
                ship.angle = angleToward(p, lane.points[next])
                return true
            }
        }
        return false
    }

    private func exitNPCFreelane(_ ship: inout NPCShip, residual: Bool) {
        guard ship.onTradeLane else { return }
        if residual {
            let forward = angleToVector(ship.angle)
            ship.velocity = forward * min(ship.speed * 0.7, 180)
        }
        ship.onTradeLane = false
        ship.tradeLaneID = nil
        ship.tradeLaneRingIndex = 0
        ship.tradeLaneDirection = 1
        ship.tradeLaneProgress = 0
    }

    private func updateNPCFreelaneTravel(_ ship: inout NPCShip, dt: Float) {
        // Drop freelane if pirate too close (ambush exits)
        if let pirate = npcs.first(where: {
            $0.isHostile && !$0.isWingman && distance($0.position, ship.position) < 120
        }) {
            exitNPCFreelane(&ship, residual: true)
            let away = angleToward(pirate.position, ship.position)
            ship.angle = away
            return
        }

        guard let laneID = ship.tradeLaneID,
              let lane = currentSystem.tradeLanes.first(where: { $0.id == laneID }) else {
            exitNPCFreelane(&ship, residual: true)
            return
        }
        let points = lane.points
        let i = ship.tradeLaneRingIndex
        let next = i + ship.tradeLaneDirection
        guard next >= 0, next < points.count else {
            exitNPCFreelane(&ship, residual: true)
            return
        }

        // Spacing: slow if another freelane ship is ahead on same lane
        var cruise = ship.freelaneCruiseSpeed
        for other in npcs where other.id != ship.id && other.onTradeLane && other.tradeLaneID == laneID {
            if other.tradeLaneRingIndex == i,
               other.tradeLaneDirection == ship.tradeLaneDirection,
               other.tradeLaneProgress > ship.tradeLaneProgress,
               other.tradeLaneProgress - ship.tradeLaneProgress < 0.12 {
                cruise *= 0.45
            } else if other.tradeLaneRingIndex == next,
                      other.tradeLaneDirection == ship.tradeLaneDirection,
                      ship.tradeLaneProgress > 0.85 {
                cruise *= 0.5
            }
        }

        let from = points[i]
        let to = points[next]
        let segLen = max(1, distance(from, to))
        ship.tradeLaneProgress += (cruise * dt) / segLen

        if lane.isRingDisrupted(next), ship.tradeLaneProgress > 0.5 {
            ship.position = from + (to - from) * ship.tradeLaneProgress
            exitNPCFreelane(&ship, residual: true)
            return
        }

        if ship.tradeLaneProgress >= 1 {
            ship.tradeLaneProgress = 0
            ship.tradeLaneRingIndex = next
            ship.position = points[next]
            if lane.isRingDisrupted(next) {
                exitNPCFreelane(&ship, residual: true)
                return
            }
            let ahead = next + ship.tradeLaneDirection
            if ahead < 0 || ahead >= points.count || lane.isRingDisrupted(ahead) {
                exitNPCFreelane(&ship, residual: true)
                // Head toward nearest station after dump
                if let st = currentSystem.stations.min(by: {
                    distance($0.position, ship.position) < distance($1.position, ship.position)
                }) {
                    ship.angle = angleToward(ship.position, st.position)
                    ship.velocity = angleToVector(ship.angle) * ship.speed * 0.5
                }
            } else {
                ship.angle = angleToward(points[next], points[ahead])
            }
        } else {
            ship.position = from + (to - from) * ship.tradeLaneProgress
            ship.angle = angleToward(from, to)
            ship.velocity = normalizeSafe(to - from) * cruise
        }
    }

    /// Soft push between ships (and player) so freelanes feel busy.
    private func resolveTrafficCollisions(_ dt: Float) {
        let sepStrength: Float = 420

        // NPC ↔ NPC
        if npcs.count > 1 {
            for i in 0..<npcs.count {
                for j in (i + 1)..<npcs.count {
                    var a = npcs[i]
                    var b = npcs[j]
                    // Skip pairs both locked mid-lane far apart in progress? still push laterally
                    let minDist = a.radius + b.radius + 8
                    let delta = b.position - a.position
                    let d = simd_length(delta)
                    guard d > 0.001, d < minDist else { continue }
                    let n = delta / d
                    let overlap = minDist - d
                    let push = n * overlap * 0.5
                    // Heavier ships move less
                    let massA = max(1, a.radius)
                    let massB = max(1, b.radius)
                    let total = massA + massB
                    if !a.onTradeLane { a.position -= push * (massB / total) }
                    else { a.position -= push * (massB / total) * 0.35 } // light lateral nudge on freelane
                    if !b.onTradeLane { b.position += push * (massA / total) }
                    else { b.position += push * (massA / total) * 0.35 }
                    // Damp relative velocity into each other
                    let rel = b.velocity - a.velocity
                    let closing = simd_dot(rel, n)
                    if closing < 0 {
                        let impulse = n * closing * 0.55
                        if !a.enginesDisabled { a.velocity += impulse * (massB / total) }
                        if !b.enginesDisabled { b.velocity -= impulse * (massA / total) }
                    }
                    npcs[i] = a
                    npcs[j] = b
                }
            }
        }

        // Player ↔ NPC soft push
        guard phase == .playing else { return }
        for i in npcs.indices {
            var ship = npcs[i]
            let minDist = ship.radius + 16
            let delta = player.position - ship.position
            let d = simd_length(delta)
            guard d > 0.001, d < minDist else { continue }
            let n = delta / d
            let overlap = minDist - d
            // Player is "heavier" when thrusting freelane
            let playerMass: Float = onTradeLane ? 2.2 : 1.4
            let shipMass = max(1, ship.radius / 10)
            let total = playerMass + shipMass
            if !onTradeLane {
                player.position += n * overlap * (shipMass / total)
            } else {
                // Slight lateral bump only
                let side = SIMD2(-n.y, n.x)
                player.position += side * overlap * 0.15 * (n.x + n.y > 0 ? 1 : -1)
            }
            if !ship.onTradeLane && !ship.enginesDisabled {
                ship.position -= n * overlap * (playerMass / total)
            } else if ship.onTradeLane {
                ship.position -= n * overlap * 0.25
            }
            let rel = player.velocity - ship.velocity
            let closing = simd_dot(rel, n)
            if closing < 0 {
                let bounce = n * closing * 0.35
                if !onTradeLane {
                    player.velocity -= bounce * 0.55
                }
                if !ship.enginesDisabled {
                    ship.velocity += bounce * 0.65
                }
            }
            // Soft separation force over time
            let force = n * (overlap / minDist) * sepStrength * dt
            if !onTradeLane { player.velocity += force * 0.4 }
            if !ship.onTradeLane && !ship.enginesDisabled { ship.velocity -= force * 0.6 }
            npcs[i] = ship
        }
    }

    private func updateWingmanAI(_ ship: inout NPCShip, dt: Float, playerPos: SIMD2<Float>) {
        let role = ship.wingmanRole ?? .gunner
        let engageRange: Float
        let formOffset: Float
        let formSide: Float
        let thrust: Float
        let fireRange: Float
        switch role {
        case .gunner:
            engageRange = 720; formOffset = 65; formSide = 1.15; thrust = 210; fireRange = 400
        case .scout:
            engageRange = 980; formOffset = 110; formSide = 1.6; thrust = 240; fireRange = 460
            // Scout auto-IDs nearby hostiles
            for i in npcs.indices where npcs[i].isHostile && !npcs[i].scannedByPlayer
                && distance(npcs[i].position, ship.position) < 420 {
                npcs[i].scannedByPlayer = true
            }
        case .tug:
            engageRange = 640; formOffset = 85; formSide = 0.9; thrust = 160; fireRange = 340
        }

        // Tug prioritizes threats to freighters / escort hauler
        var preferredFoe: NPCShip?
        if role == .tug {
            if let eid = escortShipID, let hauler = npcs.first(where: { $0.id == eid }) {
                preferredFoe = npcs.filter {
                    $0.isHostile && !$0.isWingman && distance($0.position, hauler.position) < 500
                }.min(by: { distance($0.position, ship.position) < distance($1.position, ship.position) })
            }
            if preferredFoe == nil {
                preferredFoe = npcs.filter { foe in
                    foe.isHostile && !foe.isWingman
                        && npcs.contains(where: {
                            $0.isCargo && !$0.isWingman && distance($0.position, foe.position) < 450
                        })
                }.min(by: { distance($0.position, ship.position) < distance($1.position, ship.position) })
            }
        }

        let foe = preferredFoe ?? npcs.filter({
            $0.isHostile && !$0.isWingman && distance($0.position, playerPos) < engageRange
        }).min(by: { distance($0.position, ship.position) < distance($1.position, ship.position) })

        if let foe {
            let desired = angleToward(ship.position, foe.position)
            ship.angle = lerpAngle(ship.angle, desired, 3.0 * dt)
            ship.velocity += angleToVector(ship.angle) * thrust * dt
            let d = distance(ship.position, foe.position)
            if d < fireRange, ship.fireCooldown <= 0, abs(wrapAngle(desired - ship.angle)) < 0.42 {
                fireNPC(&ship)
            }
            if d < 90 {
                ship.velocity -= angleToVector(ship.angle) * 60 * dt
            }
        } else {
            let form = playerPos + angleToVector(player.angle + formSide) * formOffset
                - angleToVector(player.angle) * (role == .scout ? 10 : 40)
            let desired = angleToward(ship.position, form)
            ship.angle = lerpAngle(ship.angle, desired, 2.5 * dt)
            let d = distance(ship.position, form)
            if d > 40 {
                ship.velocity += angleToVector(ship.angle) * (thrust * 0.9) * dt
            } else {
                ship.velocity += player.velocity * 0.4 * dt
            }
        }
    }

    private func wasRecentlyOnFreelane(_ ship: NPCShip) -> Bool {
        // Treat cargo near freelane rings as raid-valid
        for lane in currentSystem.tradeLanes {
            for p in lane.points {
                if distance(ship.position, p) < lane.ringRadius + 80 { return true }
            }
        }
        return false
    }

    private func progressFreelaneRaid(shipWasOnLane: Bool) {
        guard shipWasOnLane else { return }
        var advanced = false
        for i in activeMissions.indices {
            if case .freelaneRaid(_, let system, _) = activeMissions[i].kind {
                guard system == currentSystemName || system.isEmpty else { continue }
                activeMissions[i].progress = min(activeMissions[i].target, activeMissions[i].progress + 1)
                advanced = true
            }
        }
        guard advanced else { return }
        // Law responds harder with heat
        var r = player.rep
        r.addWanted(1)
        r.adjust(police: -14, militia: -10, pirate: 12)
        player.rep = r
        spawnRaidLawResponse()
        flash("Raid tally +1. Law is scrambling. Wanted: \(player.rep.wantedLabel).")
        postNews("\(currentSystemName): freighter hit on the freelanes — patrols inbound.")
    }

    private func spawnRaidLawResponse() {
        let count = min(4, 1 + player.wantedLevel)
        for _ in 0..<count {
            let a = Float.random(in: 0...(2 * .pi))
            let pos = player.position + angleToVector(a) * Float.random(in: 420...700)
            let faction: Faction = Bool.random() ? .police : .militia
            npcs.append(GalaxyBuilder.makeNPC(faction: faction, at: pos))
        }
    }

    private func fireNPC(_ ship: inout NPCShip) {
        let profile = npcWeaponProfile(for: ship)
        ship.fireCooldown = Float.random(in: profile.cooldown)
        for s in 0..<profile.shots {
            let spread: Float
            if profile.shots <= 1 {
                spread = 0
            } else {
                spread = (Float(s) / Float(profile.shots - 1) - 0.5) * profile.spread
            }
            let d = angleToVector(ship.angle + spread)
            let dmg = ship.damage * profile.damageMult
            projectiles.append(Projectile(
                id: UUID(),
                position: ship.position + d * profile.muzzle,
                velocity: d * profile.speed + ship.velocity * 0.2,
                damage: dmg,
                life: profile.life,
                // Wingman shots treat as friendly / player team
                source: ship.isWingman ? .player : .enemy,
                ownerID: ship.id,
                kind: profile.kind
            ))
        }
        // Occasional guided missile after primary (bombers / heavies more often)
        tryFireNPCMissile(&ship)
    }

    /// Faction / hull primary weapon feel (shot pattern + projectile kind).
    private func npcWeaponProfile(for ship: NPCShip) -> (
        kind: ProjectileKind, speed: Float, life: Float, cooldown: ClosedRange<Float>,
        shots: Int, spread: Float, muzzle: Float, damageMult: Float
    ) {
        if ship.isCapital {
            return (.plasma, 360, 1.35, 0.28...0.5, 3, 0.18, 28, 1.0)
        }
        switch ship.hullType {
        case .pirateBomber:
            return (.plasma, 340, 1.15, 0.55...0.9, 1, 0, 18, 0.85)
        case .pirateGunship:
            return (.laser, 400, 1.0, 0.4...0.7, 2, 0.1, 18, 1.0)
        case .pirateRaider:
            return (.laser, 420, 0.95, 0.35...0.65, 1, 0, 15, 1.0)
        case .policeEnforcer:
            return (.rail, 720, 1.4, 0.7...1.1, 1, 0, 20, 1.15)
        case .interceptor:
            return (.pulse, 560, 0.8, 0.22...0.4, 2, 0.08, 14, 0.7)
        case .patrol:
            return (.laser, 440, 1.05, 0.4...0.7, 2, 0.09, 16, 1.0)
        case .militiaFrigate:
            return (.rail, 680, 1.3, 0.75...1.15, 1, 0, 19, 1.1)
        case .militiaCutter:
            return (.laser, 400, 1.0, 0.45...0.8, 1, 0, 15, 1.0)
        case .alienWarden:
            return (.plasma, 360, 1.25, 0.4...0.7, 2, 0.14, 20, 1.1)
        case .alienStalker:
            return (.pulse, 520, 1.0, 0.28...0.5, 3, 0.12, 16, 0.75)
        case .alienSkimmer:
            return (.plasma, 400, 1.05, 0.35...0.6, 1, 0, 14, 1.0)
        default:
            // Cargo / wingmen fallbacks
            if ship.isWingman {
                return (.laser, 480, 1.0, 0.3...0.55, 2, 0.08, 14, 1.0)
            }
            return (.laser, 380, 0.9, 0.6...1.0, 1, 0, 14, 0.8)
        }
    }

    /// Combat ships may launch a homing missile (ammo-limited).
    private func tryFireNPCMissile(_ ship: inout NPCShip) {
        // Gunner wingmen get limited missiles
        if ship.isWingman, ship.wingmanRole != .gunner { return }
        guard ship.missileAmmo > 0, ship.missileCooldown <= 0 else { return }
        // Bombers fire racks often; light raiders rarely
        let chance: Float
        switch ship.hullType {
        case .pirateBomber: chance = 0.55
        case .pirateGunship, .policeEnforcer, .militiaFrigate, .alienWarden: chance = 0.28
        case .alienStalker, .interceptor: chance = 0.18
        default: chance = ship.isCapital ? 0.4 : 0.12
        }
        guard Float.random(in: 0...1) < chance else { return }

        // Who do we lock?
        let playerPos = player.position
        let dPlayer = distance(ship.position, playerPos)
        var lockPlayer = false
        var lockNPC: NPCShip?

        if ship.isWingman {
            lockNPC = npcs
                .filter {
                    $0.isHostile && !$0.isWingman && $0.id != ship.id
                        && distance($0.position, ship.position) <= Self.missileLockRange
                }
                .min(by: { distance($0.position, ship.position) < distance($1.position, ship.position) })
        } else if ship.isHostile {
            // Pirates / Vael: lock the player when in range
            if dPlayer <= Self.missileLockRange * 1.05 {
                lockPlayer = true
            }
        } else if ship.faction == .police || ship.faction == .militia {
            // Law: lock nearest pirate in range
            lockNPC = npcs
                .filter {
                    $0.isHostile && !$0.isWingman && $0.id != ship.id
                        && distance($0.position, ship.position) <= Self.missileLockRange
                }
                .min(by: { distance($0.position, ship.position) < distance($1.position, ship.position) })
        }

        // Need a valid lock and roughly facing it
        let aimPos: SIMD2<Float>?
        if lockPlayer {
            aimPos = playerPos
        } else if let t = lockNPC {
            aimPos = t.position
        } else {
            return
        }
        guard let aim = aimPos else { return }
        let desired = angleToward(ship.position, aim)
        guard abs(wrapAngle(desired - ship.angle)) < 0.55 else { return }

        ship.missileAmmo -= 1
        // Bombers reload racks faster
        if ship.hullType == .pirateBomber {
            ship.missileCooldown = Float.random(in: 2.0...3.5)
        } else {
            ship.missileCooldown = ship.isCapital ? Float.random(in: 2.8...4.2) : Float.random(in: 3.5...6.5)
        }

        let dir = angleToVector(ship.angle)
        let muzzle = ship.position + dir * (ship.isCapital ? 30 : 18)
        let toAim = normalizeSafe(aim - ship.position)
        let launch = simd_length(toAim) > 0.1 ? toAim : dir
        let spd = Self.enemyMissileSpeed
        projectiles.append(Projectile(
            id: UUID(),
            position: muzzle,
            velocity: launch * spd + ship.velocity * 0.15,
            damage: ship.isCapital ? Self.enemyMissileDamage * 1.35 : Self.enemyMissileDamage,
            life: 4.0,
            source: .enemy,
            ownerID: ship.id,
            kind: .missile,
            targetID: lockNPC?.id,
            tracksPlayer: lockPlayer,
            turnRate: Self.enemyMissileTurnRate,
            speed: spd
        ))
        // Exhaust puff
        particles.append(Particle(
            id: UUID(), position: muzzle, velocity: -dir * 60,
            life: 0.25, maxLife: 0.25,
            color: (1.0, 0.45, 0.15), size: 4
        ))
        if lockPlayer, dPlayer < 700 {
            flash("Incoming missile!")
        }
    }

    // MARK: - Station defenses

    private func updateStationDefenses(_ dt: Float) {
        guard var sys = systems[currentSystemName] else { return }

        for sidx in sys.stations.indices {
            var st = sys.stations[sidx]
            guard st.hasDefenses else { continue }
            if st.turretCooldown > 0 {
                st.turretCooldown -= dt
            }

            let aimPos: SIMD2<Float>?
            if st.isEnemyBase {
                // Pirate dens: shoot law, and the player unless they're allied / protected
                aimPos = enemyBaseTurretTarget(for: st)
            } else {
                // Friendly stations: shoot hostiles (pirates / aliens)
                aimPos = npcs
                    .filter({ $0.isHostile && distance($0.position, st.position) < st.defenseRange })
                    .min(by: { distance($0.position, st.position) < distance($1.position, st.position) })
                    .map(\.position)
            }

            guard let target = aimPos else {
                sys.stations[sidx] = st
                continue
            }

            st.turretAim = angleToward(st.position, target)

            if st.turretCooldown <= 0 {
                fireStationTurret(&st, at: target)
                st.turretCooldown = st.turretCooldownMax
            }
            sys.stations[sidx] = st
        }

        systems[currentSystemName] = sys
    }

    /// Whether pirate dens treat the player as a friend (dock + no guns).
    private func playerAlliedWithPirates() -> Bool {
        player.rep.repPirate >= 25 || player.protectionActive || player.wantedLevel >= 4
    }

    /// Pick turret aim for an enemy base: prefer law, then hostile player.
    private func enemyBaseTurretTarget(for st: Station) -> SIMD2<Float>? {
        let range = st.defenseRange
        // Police / militia in range
        if let law = npcs
            .filter({
                ($0.faction == .police || $0.faction == .militia)
                    && !$0.isWingman
                    && distance($0.position, st.position) < range
            })
            .min(by: { distance($0.position, st.position) < distance($1.position, st.position) }) {
            return law.position
        }
        // Player if not allied and inside envelope
        if !playerAlliedWithPirates(),
           distance(player.position, st.position) < range {
            return player.position
        }
        return nil
    }

    private func fireStationTurret(_ station: inout Station, at target: SIMD2<Float>) {
        let dir = normalizeSafe(target - station.position)
        // Muzzle on outer ring
        let muzzle = station.position + dir * (station.radius + 12)
        // Lead target slightly
        let lead = dir * 520
        projectiles.append(Projectile(
            id: UUID(),
            position: muzzle,
            velocity: lead,
            damage: station.turretDamage,
            life: 1.4,
            source: .station,
            ownerID: station.id
        ))
        // Muzzle flash particles
        particles.append(Particle(
            id: UUID(), position: muzzle, velocity: dir * 50,
            life: 0.15, maxLife: 0.15,
            color: (1.0, 0.85, 0.35), size: 5
        ))
        audio.play(.stationTurret)
    }

    private func updateProjectiles(_ dt: Float) {
        for i in projectiles.indices.reversed() {
            // Homing missiles steer toward lock (NPC or player)
            if projectiles[i].kind == .missile {
                let aim: SIMD2<Float>?
                if projectiles[i].tracksPlayer {
                    aim = player.position
                } else if let tid = projectiles[i].targetID,
                          let tgt = npcs.first(where: { $0.id == tid }) {
                    aim = tgt.position
                } else {
                    aim = nil
                }
                if let aim {
                    let desired = angleToward(projectiles[i].position, aim)
                    let cur = atan2(projectiles[i].velocity.y, projectiles[i].velocity.x)
                    let next = lerpAngle(cur, desired, min(1, projectiles[i].turnRate * dt))
                    let spd = projectiles[i].speed > 10
                        ? projectiles[i].speed
                        : (projectiles[i].source == .enemy ? Self.enemyMissileSpeed : Self.missileSpeed)
                    projectiles[i].velocity = angleToVector(next) * spd
                }
            }

            projectiles[i].position += projectiles[i].velocity * dt
            projectiles[i].life -= dt
            if projectiles[i].life <= 0 {
                projectiles.remove(at: i)
                continue
            }

            let p = projectiles[i]
            let hitRadius: Float = {
                switch p.kind {
                case .missile: return 14
                case .plasma: return 10
                case .rail: return 8
                case .pulse: return 5
                case .laser, .mine: return 6
                }
            }()

            switch p.source {
            case .player:
                // Hit NPCs (never friendly wingman)
                var hit = false
                for j in npcs.indices.reversed() {
                    if npcs[j].isWingman { continue }
                    if distance(p.position, npcs[j].position) < npcs[j].radius + hitRadius {
                        applyDamageToNPC(j, damage: p.damage, creditKill: true)
                        spawnHitParticles(at: p.position, enemy: true)
                        if p.kind == .missile {
                            spawnExplosion(at: p.position, big: false)
                        }
                        projectiles.remove(at: i)
                        hit = true
                        break
                    }
                }
                if hit { continue }
                // Mine asteroids with lasers/plasma (not missiles)
                if p.kind != .missile {
                    for j in systems[currentSystemName]!.asteroids.indices.reversed() {
                        let ast = systems[currentSystemName]!.asteroids[j]
                        if distance(p.position, ast.position) < ast.radius + 4 {
                            projectiles.remove(at: i)
                            let rockDmg = p.kind == .plasma || p.kind == .rail ? 2 : 1
                            damageAsteroid(j, amount: rockDmg)
                            break
                        }
                    }
                }

            case .station:
                let ownerStation = p.ownerID.flatMap { id in
                    currentSystem.stations.first(where: { $0.id == id })
                }
                let enemyBase = ownerStation?.isEnemyBase == true
                if enemyBase {
                    // Pirate den guns: hit player and law ships
                    let playerHitR: Float = 16
                    if invuln <= 0, distance(p.position, player.position) < playerHitR {
                        applyDamageToPlayer(p.damage, fromHostile: true, attackerName: ownerStation?.name)
                        spawnHitParticles(at: p.position, enemy: false)
                        projectiles.remove(at: i)
                        continue
                    }
                    for j in npcs.indices.reversed() {
                        let f = npcs[j].faction
                        guard f == .police || f == .militia else { continue }
                        if distance(p.position, npcs[j].position) < npcs[j].radius + 8 {
                            applyDamageToNPC(j, damage: p.damage, creditKill: false, stationKill: true)
                            spawnHitParticles(at: p.position, enemy: true)
                            projectiles.remove(at: i)
                            break
                        }
                    }
                } else {
                    // Friendly stations: only hit hostiles — never the player or friendlies
                    for j in npcs.indices.reversed() {
                        guard npcs[j].isHostile else { continue }
                        if distance(p.position, npcs[j].position) < npcs[j].radius + 8 {
                            applyDamageToNPC(j, damage: p.damage, creditKill: false, stationKill: true)
                            spawnHitParticles(at: p.position, enemy: true)
                            projectiles.remove(at: i)
                            break
                        }
                    }
                }

            case .enemy:
                // Hit player (missiles use larger fuse)
                let playerHitR: Float = p.kind == .missile ? 18 : 16
                if invuln <= 0, distance(p.position, player.position) < playerHitR {
                    var fromHostile = false
                    var pirateName: String?
                    if let owner = p.ownerID, let shooter = npcs.first(where: { $0.id == owner }) {
                        fromHostile = shooter.isHostile
                        if fromHostile { pirateName = shooter.name }
                    } else {
                        fromHostile = true
                    }
                    applyDamageToPlayer(p.damage, fromHostile: fromHostile, attackerName: pirateName)
                    spawnHitParticles(at: p.position, enemy: false)
                    if p.kind == .missile {
                        spawnExplosion(at: p.position, big: false)
                        flash("Missile hit!")
                    }
                    projectiles.remove(at: i)
                    continue
                }
                // Enemy missiles / shots can hit traders or other hostiles (law missiles)
                if p.kind == .missile, let tid = p.targetID,
                   let j = npcs.firstIndex(where: { $0.id == tid }) {
                    if distance(p.position, npcs[j].position) < npcs[j].radius + hitRadius {
                        applyDamageToNPC(j, damage: p.damage, creditKill: false)
                        spawnHitParticles(at: p.position, enemy: true)
                        spawnExplosion(at: p.position, big: false)
                        projectiles.remove(at: i)
                        continue
                    }
                }
                // Pirate laser shots hit traders
                if p.kind != .missile,
                   let owner = p.ownerID, let shooter = npcs.first(where: { $0.id == owner }), shooter.isHostile {
                    for j in npcs.indices.reversed() {
                        if npcs[j].isCargo, distance(p.position, npcs[j].position) < npcs[j].radius + 6 {
                            applyDamageToNPC(j, damage: p.damage, creditKill: false)
                            projectiles.remove(at: i)
                            break
                        }
                    }
                }
            }
        }
    }

    private func applyDamageToNPC(_ index: Int, damage: Float, creditKill: Bool = true, stationKill: Bool = false) {
        guard index < npcs.count else { return }
        var ship = npcs[index]
        // Don't kill your own wingman via friendly fire from stations? wingman not hostile so station ok
        var dmg = damage
        if ship.shield > 0 {
            let absorbed = min(ship.shield, dmg)
            ship.shield -= absorbed
            dmg -= absorbed
        }
        ship.hull -= dmg
        audio.play(.hit)

        // Disable freighter engines instead of immediate kill at low hull
        if ship.isCargo, !ship.enginesDisabled, ship.hull > 0, ship.hull <= ship.maxHull * 0.38 {
            ship.enginesDisabled = true
            ship.velocity *= 0.2
            flash("\(ship.name) engines offline — approach and F to loot cargo pods.")
            postNews("\(currentSystemName): freighter disabled — boarding window open.")
            audio.play(.hurt)
        }

        if ship.hull <= 0 {
            destroyNPC(at: index, creditKill: creditKill, stationKill: stationKill)
        } else {
            npcs[index] = ship
        }
    }

    private func destroyNPC(at index: Int, creditKill: Bool = true, stationKill: Bool = false) {
        guard index < npcs.count else { return }
        let ship = npcs[index]
        spawnExplosion(at: ship.position, big: ship.isCapital)
        audio.play(.explode)

        if ship.isWingman {
            wingmanID = nil
            let role = ship.wingmanRole?.displayName ?? "Wingman"
            fallenWingmen.append(ship.name)
            player.wingmenLost = (player.wingmenLost ?? 0) + 1
            let epitaph = [
                "\(ship.name) is gone. \(role) seat empty.",
                "No answer on \(ship.name)'s channel…",
                "\(ship.name) bought you seconds. Don't waste them.",
                "Lost \(ship.name). The second seat stays cold."
            ].randomElement()!
            flash(epitaph)
            postNews("\(currentSystemName): \(ship.name) (\(role)) destroyed escorting an independent.")
            audio.play(.hurt)
            var r = player.rep
            r.adjust(militia: -4)
            player.rep = r
        }

        // Pirate freelane raid progress (player as hunter)
        if creditKill, ship.isCargo, !ship.isWingman {
            progressFreelaneRaid(shipWasOnLane: ship.onTradeLane || wasRecentlyOnFreelane(ship))
        }

        if ship.isHostile {
            if creditKill {
                player.kills += 1
                if ship.isAlien {
                    player.aliensDestroyed += 1
                    grantAchievement(.firstContact)
                    // Alien kills don't help frontier law much
                    flash("Vael vessel destroyed. Exotic salvage ejected.")
                    postNews("\(currentSystemName): unknown craft destroyed — residual energy spikes.")
                } else {
                    player.log.piratesDestroyed += 1
                    progressCombatMissions(scanned: ship.scannedByPlayer, killedFaction: ship.faction)
                    progressDefenseMissions()
                    var r = player.rep
                    r.adjust(police: 4, militia: 5, pirate: -6)
                    player.rep = r
                    if npcs.contains(where: {
                        $0.isCargo && !$0.enginesDisabled && distance($0.position, ship.position) < 500
                    }) {
                        player.log.freightersSaved += 1
                        grantAchievement(.freighterGuardian)
                    }
                    if player.storyStage == 1 {
                        player.storyPirateKills += 1
                    }
                    grantAchievement(.firstBlood)
                    checkStoryProgress(context: "pirate_kill")
                }
            }
            if stationKill {
                player.log.stationKillsAssisted += 1
            }
            spawnLoot(at: ship.position, credits: ship.dropCredits, scrap: ship.dropScrap)
            if ship.isCapital {
                flash("Capital ship destroyed! Massive salvage.")
                postNews("\(currentSystemName): pirate capital \(ship.name) destroyed!")
                capitalAssaultActive = false
                capitalAssaultStationName = nil
                capitalAssaultTimer = 0
                capitalEventTimer = Float.random(in: 120...200)
                player.log.capitalsDestroyed += 1
                player.storyCapitalKill = true
                var r = player.rep
                r.adjust(police: 12, militia: 15, pirate: -20)
                player.rep = r
                grantAchievement(.capitalSlayer)
                checkStoryProgress(context: "capital")
            } else if stationKill {
                flash("Station defenses destroyed a \(ship.name).")
            } else if creditKill, !ship.isAlien {
                flash("Salvage ejected — fly close to tractor it in.")
            }
            if (creditKill || stationKill), !ship.isAlien {
                applyPirateKillEconomy()
            }
            evaluateAchievements()
        } else if creditKill, !ship.isWingman {
            // Player destroyed a non-hostile — heat + pirate friendship
            applyCivilianKillReputation(ship)
            // Dirty dens offer bounties on law ships
            if ship.faction == .police || ship.faction == .militia {
                progressCombatMissions(scanned: ship.scannedByPlayer, killedFaction: ship.faction)
            }
            if ship.isCargo {
                let pods = max(1, ship.cargoPodsRemaining)
                for _ in 0..<pods {
                    spawnLoot(
                        at: ship.position + SIMD2(Float.random(in: -30...30), Float.random(in: -30...30)),
                        credits: ship.dropCredits / max(1, pods),
                        scrap: max(1, ship.dropScrap / pods)
                    )
                }
            } else {
                spawnLoot(at: ship.position, credits: ship.dropCredits / 2, scrap: ship.dropScrap)
            }
        } else if ship.isCargo {
            // Remaining pods dump on death (non-player kills)
            let pods = max(1, ship.cargoPodsRemaining)
            for _ in 0..<pods {
                spawnLoot(
                    at: ship.position + SIMD2(Float.random(in: -30...30), Float.random(in: -30...30)),
                    credits: ship.dropCredits / max(1, pods),
                    scrap: max(1, ship.dropScrap / pods)
                )
            }
        }

        // Escort failure if protected hauler dies
        if let eid = escortShipID, ship.id == eid {
            failEscortMission(reason: "\(ship.name) destroyed — escort failed.")
        }

        if targetID == ship.id { targetID = nil }
        if wingmanID == ship.id { wingmanID = nil }
        npcs.remove(at: index)
    }

    private func applyCivilianKillReputation(_ ship: NPCShip) {
        var r = player.rep
        switch ship.faction {
        case .trader:
            r.tradersKilled += 1
            r.civiliansKilled += 1
            r.addWanted(1)
            r.adjust(police: -12, militia: -10, pirate: 14)
            flash("Civilian destroyed! Wanted: \(r.wantedLabel).")
            postNews("\(currentSystemName): civilian freighter lost — authorities alerted.")
        case .police:
            r.lawKilled += 1
            r.addWanted(2)
            r.adjust(police: -35, militia: -20, pirate: 18)
            flash("Police down! Wanted: \(r.wantedLabel).")
            postNews("\(currentSystemName): lawship destroyed — manhunt underway.")
        case .militia:
            r.lawKilled += 1
            r.addWanted(2)
            r.adjust(police: -18, militia: -40, pirate: 16)
            flash("Militia down! Wanted: \(r.wantedLabel).")
            postNews("\(currentSystemName): militia cutter lost — Kestrel wants blood.")
        case .pirate, .alien:
            break
        }
        player.rep = r
        if player.isWanted {
            postNews("WANTED level \(player.wantedLevel) — dock at a Militia station to pay the fine.")
        }
    }

    private func applyDamageToPlayer(_ damage: Float, fromHostile: Bool = false, attackerName: String? = nil) {
        // Any hostile hit while freelane-locked immediately drops you (even shield-only)
        if fromHostile, onTradeLane {
            hijackTradeLane(by: attackerName)
        }

        var dmg = damage
        if player.shield > 0 {
            let absorbed = min(player.shield, dmg)
            player.shield -= absorbed
            dmg -= absorbed
        }
        if dmg > 0 {
            player.hull -= dmg
            hurtFlash = 0.25
            invuln = 0.35
            audio.play(.hurt)
        } else {
            audio.play(.hit)
        }
    }

    private func updateShieldRegen(_ dt: Float) {
        // Shields and weapons share capacitor energy. Engines do not.
        // Radiation / ion storms suppress shield recharge and capacitor fill.
        let e = environmentEffects
        let radSlow: Float = e.damagePerSec > 1 ? 0.15 : 1.0
        let ionSlow: Float = e.energyDrainPerSec > 1 ? 0.2 : 1.0
        let regenMult = min(radSlow, ionSlow)
        // 1) Shield recharge draws energy — nearly off inside radiation
        if hurtFlash <= 0, player.shield < player.stats.maxShield, player.energy > 0.5, regenMult > 0.05 {
            let want = min(player.stats.maxShield - player.shield, player.stats.shieldRegen * dt * regenMult)
            let cost = want * player.stats.shieldEnergyPerPoint
            if player.energy >= cost {
                player.energy -= cost
                player.shield += want
            } else {
                let actual = player.energy / max(0.01, player.stats.shieldEnergyPerPoint)
                player.energy = 0
                player.shield = min(player.stats.maxShield, player.shield + actual)
            }
        }
        // 2) Capacitor recharges — ion storms nearly stop fill
        if player.energy < player.stats.maxEnergy, e.energyDrainPerSec < 8 {
            let regen = player.stats.energyRegen * dt * ionSlow
            player.energy = min(player.stats.maxEnergy, player.energy + regen)
        }
    }

    private func updateParticles(_ dt: Float) {
        for i in particles.indices.reversed() {
            particles[i].position += particles[i].velocity * dt
            particles[i].life -= dt
            particles[i].velocity *= 0.96
            if particles[i].life <= 0 {
                particles.remove(at: i)
            }
        }
        if particles.count > 400 {
            particles.removeFirst(particles.count - 400)
        }
    }

    /// Tractor range grows with cargo upgrades and tractor blueprint.
    private var lootMagnetRange: Float {
        (200 + Float(player.cargoLevel - 1) * 35) * player.tractorRangeBonus
    }

    private var lootPickupRange: Float { 36 }

    private func spawnLoot(at position: SIMD2<Float>, credits: Int, scrap: Int) {
        // Slight scatter so multiple drops don't stack perfectly
        let scatter = SIMD2(Float.random(in: -25...25), Float.random(in: -25...25))
        loot.append(LootDrop(
            id: UUID(),
            position: position + scatter,
            velocity: SIMD2(Float.random(in: -40...40), Float.random(in: -40...40)),
            credits: credits,
            scrap: scrap,
            life: 28,
            phase: Float.random(in: 0...(2 * .pi))
        ))
    }

    private func updateLoot(_ dt: Float) {
        let magnetRange = lootMagnetRange
        let pickupRange = lootPickupRange
        // Pull strength scales with engine level (stronger tractor)
        let pullBase: Float = 380 + Float(player.engineLevel - 1) * 60

        for i in loot.indices.reversed() {
            loot[i].life -= dt
            loot[i].phase += dt * 3
            if loot[i].life <= 0 {
                loot.remove(at: i)
                continue
            }

            let toPlayer = player.position - loot[i].position
            let dist = simd_length(toPlayer)

            if dist < magnetRange, dist > 0.001 {
                let dir = toPlayer / dist
                // Stronger pull the closer you get (smooth tractor curve)
                let falloff = 1 - (dist / magnetRange)
                let pull = pullBase * (0.35 + falloff * falloff * 1.8)
                loot[i].velocity += dir * pull * dt
                // Damp sideways drift so it streams cleanly into the hold
                let along = dir * simd_dot(loot[i].velocity, dir)
                let side = loot[i].velocity - along
                loot[i].velocity = along + side * exp(-4 * dt)
                // Cap magnet speed so it doesn't overshoot wildly
                let maxPullSpeed: Float = 420 + Float(player.engineLevel) * 40
                let sp = simd_length(loot[i].velocity)
                if sp > maxPullSpeed {
                    loot[i].velocity = normalizeSafe(loot[i].velocity) * maxPullSpeed
                }
            } else {
                // Free drift / gentle settle when outside magnet range
                loot[i].velocity *= exp(-0.8 * dt)
            }

            loot[i].position += loot[i].velocity * dt

            // Scoop when close enough (also if magnet yanked it into us)
            if dist < pickupRange || distance(loot[i].position, player.position) < pickupRange {
                collectLoot(at: i)
            }
        }
    }

    private func collectLoot(at index: Int) {
        guard index < loot.count else { return }
        let drop = loot[index]
        player.credits += drop.credits
        player.log.lifetimeCreditsEarned += drop.credits
        var scrapNote = ""
        if drop.scrap > 0 {
            if player.addCargo(.scrap, amount: drop.scrap) {
                scrapNote = " + \(drop.scrap) scrap"
            } else {
                scrapNote = " (hold full — scrap lost)"
            }
        }
        audio.play(.tractor)
        // Tractor sparkle
        for _ in 0..<8 {
            let a = Float.random(in: 0...(2 * .pi))
            particles.append(Particle(
                id: UUID(),
                position: drop.position,
                velocity: angleToVector(a) * Float.random(in: 20...80),
                life: Float.random(in: 0.2...0.45),
                maxLife: 0.45,
                color: (1.0, 0.85, 0.3),
                size: Float.random(in: 2...5)
            ))
        }
        flash("Tractor: +\(drop.credits) cr\(scrapNote)")
        loot.remove(at: index)
    }

    private func updateAsteroids(_ dt: Float) {
        guard var sys = systems[currentSystemName] else { return }
        for i in sys.asteroids.indices {
            sys.asteroids[i].angle += sys.asteroids[i].spin * dt
        }
        systems[currentSystemName] = sys

        // Collision with player (soft bounce)
        for ast in currentSystem.asteroids {
            let d = distance(player.position, ast.position)
            if d < ast.radius + 12 {
                let n = normalizeSafe(player.position - ast.position)
                player.position = ast.position + n * (ast.radius + 14)
                player.velocity = reflect(player.velocity, n) * 0.4
                if invuln <= 0 {
                    applyDamageToPlayer(5)
                    invuln = 0.5
                }
            }
        }
    }

    private func reflect(_ v: SIMD2<Float>, _ n: SIMD2<Float>) -> SIMD2<Float> {
        v - 2 * simd_dot(v, n) * n
    }

    private func updateSpawns(_ dt: Float) {
        pirateSpawnTimer -= dt
        traderSpawnTimer -= dt
        tradeLaneAmbushTimer -= dt
        vaelSpawnTimer -= dt
        let maxShips = 18
        if pirateSpawnTimer <= 0, npcs.count < maxShips {
            pirateSpawnTimer = Float.random(in: 5...11) / max(0.4, currentSystem.piratePressure)
            let angle = Float.random(in: 0...(2 * .pi))
            let dist = currentSystem.bounds * 0.9
            let pos = SIMD2(cos(angle), sin(angle)) * dist
            // Spawn off-screen relative to player
            var spawnPos = player.position + normalizeSafe(pos - player.position) * 700
            // Prefer reinforcing pirate dens when present
            if currentSystemName != "Voidreach",
               let den = currentSystem.stations.filter(\.isEnemyBase).randomElement(),
               Float.random(in: 0...1) < 0.45 {
                let a = Float.random(in: 0...(2 * .pi))
                spawnPos = den.position + angleToVector(a) * Float.random(in: 280...640)
            }
            let clamped = SIMD2(
                max(-currentSystem.bounds, min(currentSystem.bounds, spawnPos.x)),
                max(-currentSystem.bounds, min(currentSystem.bounds, spawnPos.y))
            )
            let faction: Faction
            if currentSystemName == "Voidreach" {
                faction = .alien
            } else if currentSystem.stations.contains(where: {
                $0.isEnemyBase && distance($0.position, clamped) < $0.defenseRange * 1.4
            }) {
                // Near dens: almost always pirates
                faction = Float.random(in: 0...1) < 0.12 ? .militia : .pirate
            } else {
                let vael = GalaxyBuilder.vaelIntrusionChance(for: currentSystemName)
                let r = Float.random(in: 0...1)
                if r < vael * 1.4 {
                    faction = .alien
                } else if r < vael * 1.4 + 0.62 {
                    faction = .pirate
                } else if r < vael * 1.4 + 0.81 {
                    faction = .police
                } else {
                    faction = .militia
                }
            }
            npcs.append(GalaxyBuilder.makeNPC(faction: faction, at: clamped))
        }

        // Periodic Vael scouting packs on the frontier
        if currentSystemName != "Voidreach", vaelSpawnTimer <= 0, npcs.count < maxShips + 2 {
            let chance = GalaxyBuilder.vaelIntrusionChance(for: currentSystemName)
            // Interval shorter near the rim
            vaelSpawnTimer = Float.random(in: 35...75) / max(0.35, chance * 12)
            if Float.random(in: 0...1) < min(0.7, chance * 6 + 0.08) {
                spawnVaelIntrusion()
            }
        }

        let cargoCount = npcs.filter(\.isCargo).count
        // No human freighters in Voidreach
        if currentSystemName != "Voidreach", traderSpawnTimer <= 0, cargoCount < 7 {
            traderSpawnTimer = Float.random(in: 7...14)
            var ship: NPCShip
            if let st = currentSystem.stations.randomElement() {
                let offset = angleToVector(Float.random(in: 0...(2 * .pi))) * Float.random(in: 200...400)
                ship = GalaxyBuilder.makeCargoShip(at: st.position + offset)
            } else {
                let a = Float.random(in: 0...(2 * .pi))
                ship = GalaxyBuilder.makeCargoShip(at: SIMD2(cos(a), sin(a)) * 800)
            }
            // Most new freighters join freelane traffic immediately
            if Float.random(in: 0...1) < 0.75 {
                GalaxyBuilder.placeOnFreelane(&ship, in: currentSystem)
            }
            npcs.append(ship)
        }

        // Freelane ambushes: pirates stage ahead on your lane while you're cruising
        if onTradeLane, tradeLaneAmbushTimer <= 0, npcs.count < maxShips + 4 {
            tradeLaneAmbushTimer = Float.random(in: 6...12) / max(0.5, currentSystem.piratePressure)
            // Higher chance in dangerous systems
            let ambushChance = min(0.85, 0.35 + currentSystem.piratePressure * 0.25)
            // Rare Vael freelane ambush on dark systems
            if Float.random(in: 0...1) < GalaxyBuilder.vaelIntrusionChance(for: currentSystemName) * 0.35 {
                spawnVaelIntrusion(nearPlayerLane: true)
            } else if Float.random(in: 0...1) < ambushChance {
                spawnTradeLaneAmbush()
            }
        } else if !onTradeLane {
            tradeLaneAmbushTimer = min(tradeLaneAmbushTimer, 3)
        }
    }

    /// 1–3 Vael craft enter the system (edge spawn, or near freelane if cruising).
    private func spawnVaelIntrusion(nearPlayerLane: Bool = false) {
        let count = Int.random(in: 1...3)
        var base = player.position
        if nearPlayerLane, onTradeLane, let lane = currentTradeLane() {
            let i = tradeLaneRingIndex
            let next = min(lane.points.count - 1, max(0, i + tradeLaneDirection))
            let from = lane.points[i]
            let to = lane.points[next]
            base = from + (to - from) * min(0.9, tradeLaneProgress + 0.3)
        } else {
            let a = Float.random(in: 0...(2 * .pi))
            base = player.position + angleToVector(a) * Float.random(in: 550...850)
        }
        let b = currentSystem.bounds
        for k in 0..<count {
            let offset = angleToVector(Float(k) * 1.1 + Float.random(in: 0...0.5)) * Float.random(in: 40...140)
            var pos = base + offset
            pos.x = max(-b, min(b, pos.x))
            pos.y = max(-b, min(b, pos.y))
            var vael = GalaxyBuilder.makeNPC(faction: .alien, at: pos)
            vael.angle = angleToward(pos, player.position)
            npcs.append(vael)
        }
        postNews("\(currentSystemName): unidentified Vael craft on sensors.")
        if distance(base, player.position) < 900 {
            flash("Vael contacts inbound!")
        }
    }

    private func spawnTradeLaneAmbush() {
        guard let lane = currentTradeLane() else { return }
        let points = lane.points
        let i = tradeLaneRingIndex
        let next = i + tradeLaneDirection
        guard next >= 0, next < points.count else { return }

        // Place 1–2 pirates along the segment ahead of the player
        let from = points[i]
        let to = points[next]
        let count = Int.random(in: 1...2)
        for n in 0..<count {
            let t = min(0.92, tradeLaneProgress + 0.25 + Float(n) * 0.18)
            let along = from + (to - from) * t
            let side = normalizeSafe(SIMD2(-(to.y - from.y), to.x - from.x))
            let offset = side * Float.random(in: 90...160) * (n == 0 ? 1 : -1)
            let pos = along + offset
            var pirate = GalaxyBuilder.makeNPC(faction: .pirate, at: pos)
            pirate.angle = angleToward(pos, player.position)
            npcs.append(pirate)
        }
        flash("Pirate ambush on the freelane!")
        audio.play(.hurt)
    }

    private func updateCamera(_ dt: Float) {
        // Lead further ahead of velocity for a continuous flight feel
        let leadScale: Float = onTradeLane ? 0.55 : 0.42
        let lead = player.velocity * leadScale
        let target = player.position + lead
        let followRate: Float = onTradeLane ? 7.5 : 5.5
        let follow = 1 - exp(-followRate * dt)
        camera += (target - camera) * follow
    }

    private func checkBounds(_ dt: Float) {
        // Soft system edge — continuous push-back instead of a hard bounce
        let b = currentSystem.bounds
        let margin = b * 0.88
        let pushStrength: Float = 520
        var hitHardEdge = false

        if abs(player.position.x) > margin {
            let over = (abs(player.position.x) - margin) / max(1, b - margin)
            let sign: Float = player.position.x > 0 ? 1 : -1
            player.velocity.x -= sign * over * over * pushStrength * dt * 60
            if abs(player.position.x) > b {
                player.position.x = sign * b
                player.velocity.x *= -0.12
                hitHardEdge = true
            }
        }
        if abs(player.position.y) > margin {
            let over = (abs(player.position.y) - margin) / max(1, b - margin)
            let sign: Float = player.position.y > 0 ? 1 : -1
            player.velocity.y -= sign * over * over * pushStrength * dt * 60
            if abs(player.position.y) > b {
                player.position.y = sign * b
                player.velocity.y *= -0.12
                hitHardEdge = true
            }
        }
        if hitHardEdge {
            flash("Nav hazard: system edge.")
        }
    }

    private func checkDeath() {
        if player.hull <= 0 {
            player.hull = 0
            phase = .dead
            spawnExplosion(at: player.position, big: true)
            audio.play(.explode)
            if player.ironmanMode {
                player.ironmanFailed = true
                SaveGame.eraseIronmanSlots()
                message = "IRONMAN RUN ENDED — ironman saves wiped."
                postNews("Ironman protocol: pilot lost. Run terminated.")
            } else if canInsuranceRespawn {
                let fee = insuranceRespawnFee()
                let dock = player.lastDockStation ?? "last dock"
                message = "Insured — Enter to respawn at \(dock) (−\(fee) cr). Cargo lost."
                postNews("Insurance beacon lit — recovery craft en route.")
            } else {
                message = "Ship destroyed. Buy insurance at Outfitter, or load a save. Enter → title."
            }
            messageTimer = 10
            syncMusic()
        }
    }

    // MARK: - Actions

    private func cycleTarget() {
        // Prefer hostiles, then any non-wingman within sensor range (for scanning traders)
        let hostiles = npcs.filter { $0.isHostile }.sorted {
            distance($0.position, player.position) < distance($1.position, player.position)
        }
        let others = npcs.filter {
            !$0.isHostile && !$0.isWingman && distance($0.position, player.position) < 900
        }.sorted {
            distance($0.position, player.position) < distance($1.position, player.position)
        }
        let list = hostiles + others
        guard !list.isEmpty else {
            targetID = nil
            flash("No contacts on sensors.")
            return
        }
        if let tid = targetID, let idx = list.firstIndex(where: { $0.id == tid }) {
            targetID = list[(idx + 1) % list.count].id
        } else {
            targetID = list[0].id
        }
        if let t = npcs.first(where: { $0.id == targetID }) {
            let tag = t.scannedByPlayer ? " [ID]" : " [hold I to scan]"
            flash("Target: \(t.name)\(tag)")
        }
    }

    // MARK: - In-system nav

    /// Resolved nav for HUD / minimap / edge markers.
    struct ResolvedNav {
        var position: SIMD2<Float>
        var label: String
        var detail: String
        var colorHint: String // "station" | "gate" | "escort" | "mission"
    }

    func resolveNav() -> ResolvedNav? {
        guard let wp = navWaypoint else { return nil }
        switch wp {
        case .station(let id):
            guard let st = currentSystem.stations.first(where: { $0.id == id }) else { return nil }
            return ResolvedNav(position: st.position, label: st.name,
                               detail: st.faction, colorHint: "station")
        case .gate(let id):
            guard let g = currentSystem.gates.first(where: { $0.id == id }) else { return nil }
            return ResolvedNav(position: g.position, label: g.name,
                               detail: "→ \(g.destinationSystem)", colorHint: "gate")
        case .escort:
            guard let id = escortShipID, let h = npcs.first(where: { $0.id == id }) else { return nil }
            return ResolvedNav(position: h.position, label: h.name,
                               detail: "Escort convoy", colorHint: "escort")
        case .missionStation(let name):
            guard let st = currentSystem.stations.first(where: { $0.name == name }) else { return nil }
            return ResolvedNav(position: st.position, label: st.name,
                               detail: "Mission dest", colorHint: "mission")
        }
    }

    /// Distance (m), absolute bearing (deg), turn angle relative to nose (−180…180, + = port/left).
    func navMetrics() -> (distance: Float, bearingDeg: Float, turnDeg: Float)? {
        guard let nav = resolveNav() else { return nil }
        let d = distance(player.position, nav.position)
        let bearing = angleToward(player.position, nav.position)
        let bearingDeg = bearing * 180 / .pi
        var turn = wrapAngle(bearing - player.angle) * 180 / .pi
        // Present as −180…180
        if turn > 180 { turn -= 360 }
        if turn < -180 { turn += 360 }
        return (d, bearingDeg, turn)
    }

    private func navCycleList() -> [NavWaypoint?] {
        var list: [NavWaypoint?] = []
        // Nearest stations first for friendlier cycling
        let stations = currentSystem.stations.sorted {
            distance($0.position, player.position) < distance($1.position, player.position)
        }
        for st in stations {
            list.append(.station(st.id))
        }
        for g in currentSystem.gates {
            list.append(.gate(g.id))
        }
        if escortShipID != nil {
            list.append(.escort)
        }
        // Mission destinations in this system
        for m in activeMissions {
            switch m.kind {
            case .delivery(_, _, let destStation, let destSystem)
                where destSystem == currentSystemName:
                list.append(.missionStation(name: destStation))
            case .escort(let destStation, let destSystem, _)
                where destSystem == currentSystemName:
                list.append(.missionStation(name: destStation))
            case .stationDefense(let stationName, let system, _)
                where system == currentSystemName:
                list.append(.missionStation(name: stationName))
            case .explore(let system) where system == currentSystemName:
                if let first = currentSystem.stations.first {
                    list.append(.missionStation(name: first.name))
                }
            default: break
            }
        }
        // Deduplicate by label-ish: keep unique enum values
        var seen = Set<String>()
        var unique: [NavWaypoint?] = []
        for item in list {
            let key: String
            switch item {
            case .station(let id): key = "s:\(id)"
            case .gate(let id): key = "g:\(id)"
            case .escort: key = "escort"
            case .missionStation(let n): key = "m:\(n)"
            case .none: key = "none"
            }
            if seen.insert(key).inserted {
                unique.append(item)
            }
        }
        unique.append(nil) // clear
        return unique
    }

    private func cycleNavWaypoint() {
        let list = navCycleList()
        guard list.count > 1 else {
            // At least stations or clear
            if let first = list.first, first != nil {
                navWaypoint = first
                announceNav()
            } else {
                flash("No nav beacons in this system.")
            }
            return
        }
        if let current = navWaypoint, let idx = list.firstIndex(of: current) {
            navWaypoint = list[(idx + 1) % list.count]
        } else if navWaypoint == nil, let idx = list.firstIndex(of: nil) {
            navWaypoint = list[(idx + 1) % list.count]
        } else {
            navWaypoint = list[0]
        }
        announceNav()
    }

    private func clearNavWaypoint() {
        navWaypoint = nil
        flash("Nav cleared.")
    }

    private func announceNav() {
        guard let nav = resolveNav(), let m = navMetrics() else {
            flash("Nav cleared.")
            return
        }
        let distStr = Self.formatNavDistance(m.distance)
        let turn = Int(m.turnDeg.rounded())
        let dir = turn > 8 ? "port \(abs(turn))°" : (turn < -8 ? "starboard \(abs(turn))°" : "nose-on")
        flash("NAV → \(nav.label)  \(distStr)  \(dir)")
    }

    static func formatNavDistance(_ d: Float) -> String {
        if d >= 1000 {
            return String(format: "%.1fk", d / 1000)
        }
        return "\(Int(d))m"
    }

    /// Auto-pick nearest station when jumping into a system (if no nav set).
    private func suggestNavOnArrival() {
        // Pinned trade route takes priority for next hop
        if applyPinnedRouteNav() { return }

        if navWaypoint != nil {
            // Drop invalid waypoints from previous system
            if resolveNav() == nil {
                navWaypoint = nil
            } else {
                return
            }
        }
        // Prefer mission dest in this system
        for m in activeMissions {
            switch m.kind {
            case .delivery(_, _, let destStation, let destSystem)
                where destSystem == currentSystemName:
                navWaypoint = .missionStation(name: destStation)
                return
            case .escort(let destStation, let destSystem, _)
                where destSystem == currentSystemName:
                navWaypoint = .missionStation(name: destStation)
                return
            case .stationDefense(let stationName, let system, _)
                where system == currentSystemName:
                navWaypoint = .missionStation(name: stationName)
                return
            default: break
            }
        }
        if let nearest = currentSystem.stations.min(by: {
            distance($0.position, player.position) < distance($1.position, player.position)
        }) {
            navWaypoint = .station(nearest.id)
        }
    }

    /// NAV for pinned route: gate toward next system, or station hop in-system.
    @discardableResult
    private func applyPinnedRouteNav() -> Bool {
        guard let route = player.pinnedRoute else { return false }
        if currentSystemName == route.sellSystem {
            setNavToStationNamed(route.sellStation)
            flash("ROUTE: sell hop → \(route.sellStation)")
            return true
        }
        if currentSystemName == route.buySystem {
            setNavToStationNamed(route.buyStation)
            flash("ROUTE: buy hop → \(route.buyStation)")
            return true
        }
        // Aim at gate toward sell (or buy) system
        let want = route.sellSystem
        if let gate = currentSystem.gates.first(where: { $0.destinationSystem == want }) {
            navWaypoint = .gate(gate.id)
            flash("ROUTE: jump toward \(want) via \(gate.name)")
            return true
        }
        if let gate = currentSystem.gates.first(where: { $0.destinationSystem == route.buySystem }) {
            navWaypoint = .gate(gate.id)
            flash("ROUTE: jump toward \(route.buySystem) via \(gate.name)")
            return true
        }
        if let gate = currentSystem.gates.min(by: {
            distance($0.position, player.position) < distance($1.position, player.position)
        }) {
            navWaypoint = .gate(gate.id)
            return true
        }
        return false
    }

    private func pinRouteFromGalaxyMap() {
        let sellSys = mapSelectedSystem
        let stations = systems[sellSys]?.stations ?? []
        guard !stations.isEmpty else { return }
        let idx = min(mapSelectedStationIndex, stations.count - 1)
        let sellSt = stations[idx]
        let buySys = player.lastDockSystem ?? currentSystemName
        let buySt = player.lastDockStation
            ?? systems[buySys]?.stations.first?.name
            ?? "Freeport 7"
        guard buySys != sellSys || buySt != sellSt.name else {
            flash("Pick a different sell station on the galaxy map.")
            audio.play(.hurt)
            return
        }
        let commodity = bestRouteCommodity(buySystem: buySys, buyStation: buySt,
                                           sellSystem: sellSys, sellStation: sellSt.name)
        let route = TradeRoute(
            id: UUID(),
            name: "\(buySys) → \(sellSys)",
            buySystem: buySys,
            buyStation: buySt,
            sellSystem: sellSys,
            sellStation: sellSt.name,
            commodity: commodity
        )
        var routes = player.routes
        routes.removeAll { $0.buySystem == buySys && $0.sellSystem == sellSys && $0.sellStation == sellSt.name }
        routes.insert(route, at: 0)
        if routes.count > 8 { routes = Array(routes.prefix(8)) }
        player.routes = routes
        player.pinnedRouteID = route.id
        flash("Pinned route: \(route.shortLabel)  (U in flight to re-pin / clear)")
        postNews("Trade route filed: \(route.shortLabel).")
        audio.play(.select)
        applyPinnedRouteNav()
    }

    private func pinOrSaveTradeRouteFromFlight() {
        if player.pinnedRouteID != nil {
            player.pinnedRouteID = nil
            flash("Trade route unpinned.")
            audio.play(.select)
            return
        }
        if let r = player.routes.first {
            player.pinnedRouteID = r.id
            flash("Pinned: \(r.shortLabel)")
            applyPinnedRouteNav()
            audio.play(.select)
            return
        }
        flash("No saved routes — open Galaxy map (G), pick sell station, press U.")
        audio.play(.hurt)
    }

    private func bestRouteCommodity(buySystem: String, buyStation: String,
                                    sellSystem: String, sellStation: String) -> Commodity? {
        let buyKey = "\(buySystem)/\(buyStation)"
        let sellKey = "\(sellSystem)/\(sellStation)"
        let buyIntel = player.marketIntel[buyKey]
        let sellIntel = player.marketIntel[sellKey]
        var best: (Commodity, Int)?
        for c in Commodity.allCases {
            let buyP = buyIntel?.sellPrices[c] ?? c.basePrice
            let sellP = sellIntel?.buyPrices[c] ?? c.basePrice
            let margin = sellP - buyP
            if best == nil || margin > best!.1 {
                best = (c, margin)
            }
        }
        return best.map { $0.0 }
    }

    func setNavToStationNamed(_ name: String) {
        if let st = currentSystem.stations.first(where: { $0.name == name }) {
            navWaypoint = .station(st.id)
        } else {
            navWaypoint = .missionStation(name: name)
        }
    }

    private func tryDockOrJump() {
        // Exit trade lane if cruising
        if onTradeLane {
            exitTradeLane(reason: "Left the trade lane.")
            return
        }
        // Enter trade lane ring
        if let hit = nearbyTradeRing() {
            let i = hit.index
            let points = hit.lane.points
            var dir = 1
            if i == 0 {
                dir = 1
            } else if i >= points.count - 1 {
                dir = -1
            } else {
                let face = angleToVector(player.angle)
                let toNext = normalizeSafe(points[i + 1] - points[i])
                let toPrev = normalizeSafe(points[i - 1] - points[i])
                dir = simd_dot(face, toNext) >= simd_dot(face, toPrev) ? 1 : -1
            }
            enterTradeLane(hit.lane, at: i, direction: dir)
            return
        }
        // Board disabled freighter for cargo pods
        if tryBoardFreighter() { return }
        // Dock
        for st in currentSystem.stations {
            if distance(player.position, st.position) < st.dockRadius {
                if !canDockAt(st) {
                    if st.isEnemyBase {
                        flash("\(st.name) turrets locked — raise pirate rep, buy protection, or get dirty.")
                    } else {
                        flash("Docking refused — heat too high. Try Umbra / pirate dens / black markets.")
                    }
                    audio.play(.hurt)
                    return
                }
                dock(at: st)
                return
            }
        }
        // Jump gate
        for gate in currentSystem.gates {
            if distance(player.position, gate.position) < gate.radius + 30 {
                jump(through: gate)
                return
            }
        }
        // Anomaly interact
        if tryInteractAnomaly() { return }
        // Survey beacon plant (planet / wreck / anomaly)
        if tryPlantSurveyBeacon() { return }
        // Near asteroid or derelict — mine
        if tryMine() { return }
        flash("Nothing in range. Approach a station, freelane, gate, wreck, freighter, anomaly, or asteroid.")
    }

    @discardableResult
    private func tryBoardFreighter() -> Bool {
        guard let idx = npcs.enumerated()
            .filter({
                $0.element.isCargo && $0.element.enginesDisabled
                    && $0.element.cargoPodsRemaining > 0
                    && distance($0.element.position, player.position) < $0.element.radius + 55
            })
            .min(by: {
                distance($0.element.position, player.position) < distance($1.element.position, player.position)
            })?.offset else { return false }

        var ship = npcs[idx]
        ship.cargoPodsRemaining -= 1
        let credits = max(40, ship.dropCredits / 3)
        let scrap = max(1, ship.dropScrap / 2)
        spawnLoot(at: ship.position + angleToVector(player.angle) * 20, credits: credits, scrap: scrap)
        flash("Cargo pod ejected from \(ship.name) — tractor it in.")
        audio.play(.pickup)
        postNews("Cargo seized from disabled \(ship.name).")
        player.log.cargoPodsLooted += 1
        if ship.cargoPodsRemaining <= 0 {
            flash("\(ship.name) holds empty. Finish or leave.")
        }
        npcs[idx] = ship
        return true
    }

    private func isDirtyFriendlyStation(_ station: Station) -> Bool {
        station.isOutlawDock || currentSystemName == "Umbra"
    }

    private func canDockAt(_ station: Station) -> Bool {
        // Lawful stations refuse max-wanted pilots
        if player.wantedLevel >= 5 && !isDirtyFriendlyStation(station) {
            return false
        }
        // Pirate dens refuse clean pilots with no standing
        if station.isEnemyBase {
            return playerAlliedWithPirates()
                || player.rep.repPirate >= 15
                || player.isDirty
        }
        return true
    }

    private func dock(at station: Station) {
        clearTradeLane()
        dockedStationID = station.id
        phase = .docked
        stationTab = .status
        // Drop warehouse tab if we left Freeport 7
        if stationTab == .warehouse, !isAtFreeport7 {
            stationTab = .status
        }
        player.velocity = .zero
        player.position = station.position + SIMD2(0, station.radius + 40)
        // Recharge shields + capacitors free when docked
        player.shield = player.stats.maxShield
        player.energy = player.stats.maxEnergy

        player.lastDockSystem = currentSystemName
        player.lastDockStation = station.name
        processLoanOnDock()

        // Black-market / den special stock when dirty or at pirate dens
        if (player.isDirty || station.isEnemyBase), var sys = systems[currentSystemName],
           let sidx = sys.stations.firstIndex(where: { $0.id == station.id }) {
            GalaxyBuilder.applyBlackMarketStock(to: &sys.stations[sidx], dirty: true)
            systems[currentSystemName] = sys
            if sys.stations[sidx].isOutlawDock {
                if station.isEnemyBase {
                    flash("Den market open — guns cheap, questions none.")
                    postNews("\(station.name): pirate stock unlocked.")
                } else {
                    flash("Black market open — dirty goods on special.")
                    postNews("\(station.name): underworld stock unlocked for known operators.")
                }
            }
        }

        let docked = dockedStation ?? station
        stationMissions = GalaxyBuilder.generateMissions(station: docked, system: currentSystemName)
        missionSelectIndex = 0
        // Explore mission progress
        progressExploreMissions(station: station.name)
        // Escort delivery check while docked
        tryCompleteEscortOnDock(station: station)
        recordMarketIntel(for: dockedStation ?? station, system: currentSystemName)
        var msg = "Docked at \(station.name)."
        if station.isEnemyBase {
            msg = "Docked at \(station.name) — pirate den. Watch your back."
        } else if let inv = player.investment(system: currentSystemName, station: station.name) {
            msg = "\(inv.berthName) — \(inv.tierLabel). Welcome home."
        } else if player.isWanted, station.faction == "Militia" {
            msg += " Militia desk can clear your bounty."
        } else if player.isWanted {
            msg += " Wanted \(player.rep.wantedLabel)."
        }
        if player.loanOutstanding > 0 {
            msg += " Loan due \(Player.loanPaymentPerDock) cr."
        }
        flash(msg)
        audio.play(.dock)
        player.log.docks += 1
        grantAchievement(.firstDock)
        checkStoryProgress(context: "dock:\(station.name)")
        evaluateAchievements()
        _ = autosaveOnDock()
        syncMusic()
    }

    private func processLoanOnDock() {
        let principal = player.loanOutstanding
        guard principal > 0 else { return }
        let due = min(Player.loanPaymentPerDock, principal)
        if player.credits >= due {
            player.credits -= due
            player.loanPrincipal = principal - due
            player.loanMissedPayments = 0
            if player.loanOutstanding <= 0 {
                player.loanPrincipal = nil
                flash("Loan paid in full.")
                postNews("Shipyard loan cleared.")
            }
        } else {
            let misses = (player.loanMissedPayments ?? 0) + 1
            player.loanMissedPayments = misses
            if misses >= 2 {
                repoFreighterLoan()
            } else {
                var r = player.rep
                r.addWanted(1)
                player.rep = r
                flash("Missed loan payment — heat rising. Next miss: repossession.")
                audio.play(.hurt)
            }
        }
    }

    private func repoFreighterLoan() {
        player.loanPrincipal = nil
        player.loanMissedPayments = nil
        var r = player.rep
        r.addWanted(1)
        r.adjust(police: -10, militia: -5, pirate: 5)
        if player.shipClass == .freighter {
            r.shipClass = r.ownedShips.contains(.hybrid) ? .hybrid : (r.ownedShips.first ?? .hybrid)
            r.ownedShips.remove(.freighter)
            player.rep = r
            player.applyUpgradeLevels()
            trimCargoToCapacity()
            flash("REPO: freighter seized for default. Back to \(player.shipClass.shortName).")
            postNews("Shipyard repo teams claim a freighter for unpaid debt.")
        } else {
            r.ownedShips.remove(.freighter)
            player.rep = r
            // Repo wingman if present
            if let wid = wingmanID, let idx = npcs.firstIndex(where: { $0.id == wid }) {
                npcs.remove(at: idx)
                wingmanID = nil
                flash("REPO: wingman contract voided + freighter claim. Wanted up.")
            } else {
                flash("REPO: freighter title reclaimed. Wanted level up.")
            }
            postNews("Debt collectors mark a pilot for repossession.")
        }
        audio.play(.hurt)
    }

    private func undock() {
        guard let st = dockedStation else {
            phase = .playing
            dockedStationID = nil
            return
        }
        player.position = st.position + SIMD2(0, st.radius + 50)
        player.velocity = .zero
        player.angle = -.pi / 2
        dockedStationID = nil
        phase = .playing
        // Don't keep an unpurchased paint preview after undock
        if !player.ownedPaints.contains(player.paintJob) {
            player.paintJob = player.ownedPaints.sorted(by: { $0.rawValue < $1.rawValue }).first ?? .arctic
        }
        flash("Undocked. Safe flying.")
        audio.play(.undock)
        syncMusic()
    }

    private func jump(through gate: JumpGate) {
        clearTradeLane()
        let dest = gate.destinationSystem
        currentSystemName = dest
        player.position = gate.destinationSpawn
        player.velocity = .zero
        let firstVisit = !player.systemsVisited.contains(dest)
        player.systemsVisited.insert(dest)
        // Preserve escort hauler + wingman across jumps
        var keep: [NPCShip] = []
        if let eid = escortShipID, var hauler = npcs.first(where: { $0.id == eid }) {
            hauler.position = player.position + angleToVector(player.angle + 0.9) * 90
            hauler.velocity = .zero
            hauler.onTradeLane = false
            hauler.tradeLaneID = nil
            keep.append(hauler)
        }
        if let wid = wingmanID, var wing = npcs.first(where: { $0.id == wid }) {
            wing.position = player.position + angleToVector(player.angle - 0.9) * 70
            wing.velocity = .zero
            keep.append(wing)
        }
        npcs = GalaxyBuilder.spawnNPCs(in: currentSystem, count: 10) + keep
        projectiles = []
        loot = []
        spaceMines = []
        targetID = nil
        camera = player.position
        spawnJumpEffect(at: player.position)
        if firstVisit {
            let bonus = dest == "Voidreach" ? 2000 : 500
            awardDiscovery(
                credits: bonus,
                headline: dest == "Voidreach"
                    ? "FIRST CONTACT ZONE: Voidreach charted"
                    : "First chart of \(currentSystem.displayName)",
                detail: dest == "Voidreach"
                    ? "Outer sector bonus +\(bonus) cr — Vael space"
                    : "Navigation bonus +\(bonus) cr"
            )
            if dest == "Voidreach" {
                grantAchievement(.beyondTheVeil)
                // Auto-discover return rift
                for g in currentSystem.gates where g.isWormhole {
                    player.discoveredWormholes.insert(g.wormholeKey)
                }
            }
        }
        if dest == "Umbra", !player.storyVisitedUmbra {
            player.storyVisitedUmbra = true
        }
        suggestNavOnArrival()
        if dest == "Voidreach" {
            flash("VOIDREACH — unknown contacts everywhere. Dock Spire of Vael for alien tech.")
        } else if let nav = resolveNav(), let m = navMetrics() {
            flash("Arrived \(currentSystem.displayName). NAV → \(nav.label) \(Self.formatNavDistance(m.distance))")
        } else if !firstVisit {
            flash("Jumped to \(currentSystem.displayName).")
        }
        postNews("Arrived \(currentSystem.displayName). \(currentSystem.blurb)")
        audio.play(.jump)
        syncMusic()
    }

    @discardableResult
    private func tryMine() -> Bool {
        guard mineCooldown <= 0 else { return false }
        // Prefer derelicts when in range
        if tryMineWreck() { return true }
        guard var sys = systems[currentSystemName] else { return false }
        guard let idx = sys.asteroids.enumerated()
            .filter({ distance($0.element.position, player.position) < $0.element.radius + 50 })
            .min(by: { distance($0.element.position, player.position) < distance($1.element.position, player.position) })?
            .offset else { return false }

        mineCooldown = 0.35
        damageAsteroid(idx, amount: 1)
        return true
    }

    private func damageAsteroid(_ index: Int, amount: Int) {
        guard var sys = systems[currentSystemName], index < sys.asteroids.count else { return }
        var ast = sys.asteroids[index]
        let take = min(amount, ast.ore)
        if take > 0 {
            if player.addCargo(.ore, amount: take) {
                ast.ore -= take
                flash("Mined \(take) Ore.")
                audio.play(.mine)
                spawnHitParticles(at: ast.position, enemy: false)
            } else {
                flash("Cargo full!")
                audio.play(.hurt)
                systems[currentSystemName] = sys
                return
            }
        }
        if ast.ore <= 0 {
            spawnExplosion(at: ast.position, big: false)
            sys.asteroids.remove(at: index)
        } else {
            sys.asteroids[index] = ast
        }
        systems[currentSystemName] = sys
    }

    // MARK: - Station services

    /// Effective unit prices at the docked station (investment discounts applied).
    /// `playerPays` = station sell price; `stationPays` = station buy price.
    func effectiveTradePrice(offer: MarketOffer, station: Station) -> (playerPays: Int, stationPays: Int) {
        let inv = player.investment(system: currentSystemName, station: station.name)
        let disc = inv?.buyDiscount ?? 0
        let bonus = inv?.sellBonus ?? 0
        let playerPays = max(1, Int((Float(offer.sellPrice) * (1 - disc)).rounded()))
        var stationPays = max(1, Int((Float(offer.buyPrice) * (1 + bonus)).rounded()))
        // Keep a 1cr spread minimum after bonuses
        if stationPays >= playerPays {
            stationPays = max(1, playerPays - 1)
        }
        return (playerPays, stationPays)
    }

    private func repairHull() {
        guard let st = dockedStation else { return }
        let need = player.stats.maxHull - player.hull
        guard need > 0.5 else {
            flash("Hull already sound.")
            return
        }
        let inv = player.investment(system: currentSystemName, station: st.name)
        let mult = inv?.repairMult ?? 1
        let cost = max(1, Int((Float(Int(ceil(need)) * st.repairCostPerHull) * mult).rounded()))
        guard player.credits >= cost else {
            flash("Need \(cost) cr for full repair.")
            audio.play(.hurt)
            return
        }
        player.credits -= cost
        player.hull = player.stats.maxHull
        let note = mult < 1 ? " (investor rate)" : ""
        flash("Hull repaired (−\(cost) cr)\(note).")
        audio.play(.pickup)
    }

    func buyCommodity() {
        guard var st = dockedStation,
              let sysName = Optional(currentSystemName),
              var sys = systems[sysName],
              let sidx = sys.stations.firstIndex(where: { $0.id == st.id }) else { return }
        let c = Commodity.allCases[tradeCommodityIndex]
        guard var offer = st.market[c] else { return }
        let amount = min(tradeAmount, offer.stock)
        guard amount > 0 else {
            flash("Out of stock.")
            return
        }
        let unit = effectiveTradePrice(offer: offer, station: st).playerPays
        let cost = unit * amount
        guard player.credits >= cost else {
            flash("Not enough credits.")
            audio.play(.hurt)
            return
        }
        guard player.addCargo(c, amount: amount) else {
            flash("Cargo hold full.")
            audio.play(.hurt)
            return
        }
        player.credits -= cost
        offer.stock -= amount
        // Large buys create local shortages
        if amount >= 8 {
            offer.sellPrice = Int(Float(offer.sellPrice) * 1.12)
            offer.buyPrice = Int(Float(offer.buyPrice) * 1.08)
            if economyNewsCooldown <= 0 {
                postNews("\(st.name): \(c.rawValue) shortage after heavy buying.")
                economyNewsCooldown = 12
            }
        }
        st.market[c] = offer
        sys.stations[sidx] = st
        systems[sysName] = sys
        recordMarketIntel(for: st, system: sysName)
        let invNote = player.investment(system: sysName, station: st.name) != nil ? " · investor price" : ""
        flash("Bought \(amount) \(c.rawValue) (−\(cost) cr)\(invNote).")
        audio.play(.pickup)
    }

    func sellCommodity() {
        guard var st = dockedStation,
              let sysName = Optional(currentSystemName),
              var sys = systems[sysName],
              let sidx = sys.stations.firstIndex(where: { $0.id == st.id }) else { return }
        let c = Commodity.allCases[tradeCommodityIndex]
        let have = player.cargo[c, default: 0]
        let amount = min(tradeAmount, have)
        guard amount > 0 else {
            flash("You have no \(c.rawValue).")
            return
        }
        guard var offer = st.market[c] else { return }
        guard player.removeCargo(c, amount: amount) else { return }
        let unit = effectiveTradePrice(offer: offer, station: st).stationPays
        let gain = unit * amount
        player.credits += gain
        player.log.lifetimeCreditsEarned += gain
        offer.stock += amount
        // Dumping goods floods the market
        if amount >= 8 || (c == .ore && amount >= 5) {
            offer.buyPrice = max(1, Int(Float(offer.buyPrice) * 0.88))
            offer.sellPrice = max(offer.buyPrice + 1, Int(Float(offer.sellPrice) * 0.92))
            if economyNewsCooldown <= 0 {
                let label = c == .ore ? "ore glut" : "\(c.rawValue.lowercased()) glut"
                postNews("\(currentSystemName) \(label) — \(st.name) buy prices soft.")
                economyNewsCooldown = 12
            }
        }
        st.market[c] = offer
        sys.stations[sidx] = st
        systems[sysName] = sys
        recordMarketIntel(for: st, system: sysName)
        let invNote = player.investment(system: sysName, station: st.name) != nil ? " · investor premium" : ""
        flash("Sold \(amount) \(c.rawValue) (+\(gain) cr)\(invNote).")
        audio.play(.pickup)
        evaluateAchievements()
    }

    /// Buy or upgrade stake at the docked station.
    private func investInStation() {
        guard let st = dockedStation else { return }
        // Vael bases: flavor restriction optional — allow invest everywhere for long-term goals
        let key = Player.stationKey(system: currentSystemName, station: st.name)
        let current = player.investments[key]
        let level = current?.level ?? 0
        guard level < StationInvestment.maxLevel else {
            flash("Max investment — \(current!.tierLabel) at \(st.name).")
            return
        }
        let cost = StationInvestment.upgradeCost(fromLevel: level)
        guard player.credits >= cost else {
            flash("Need \(cost) cr to \(level == 0 ? "buy a stake" : "raise stake") at \(st.name).")
            audio.play(.hurt)
            return
        }
        player.credits -= cost
        let newLevel = level + 1
        let berth = current?.berthName ?? StationInvestment.defaultBerthName(station: st.name)
        let inv = StationInvestment(level: newLevel, berthName: berth)
        player.setInvestment(inv, system: currentSystemName, station: st.name)
        let disc = Int((inv.buyDiscount * 100).rounded())
        let bonus = Int((inv.sellBonus * 100).rounded())
        flash("\(inv.tierLabel) at \(st.name) (−\(cost) cr). Trade: −\(disc)% buy / +\(bonus)% sell.")
        postNews("\(st.name): independent pilot registered as \(inv.tierLabel.lowercased()).")
        if newLevel == 1 {
            postNews("\(st.name): private berth reserved — \(berth).")
            grantAchievement(.stationInvestor)
        }
        if newLevel >= StationInvestment.maxLevel {
            grantAchievement(.stationPatron)
        }
        audio.play(.win)
        evaluateAchievements()
    }

    private func acceptOrTurnInMission() {
        let offerCount = stationMissions.count
        if missionSelectIndex < offerCount {
            // Accept
            guard activeMissions.count < 5 else {
                flash("Mission log full (max 5).")
                return
            }
            var m = stationMissions[missionSelectIndex]
            if case .escort = m.kind, escortShipID != nil {
                flash("Already escorting a convoy. Finish or abandon first.")
                return
            }
            // Start countdown for timed runs
            if let limit = m.timeLimit {
                m.timeRemaining = limit
            }
            // Smuggle: stow contraband in hidden hold immediately
            if m.isSmuggle == true, case .delivery(let commodity, let amount, _, _) = m.kind {
                guard player.addHiddenCargo(commodity, amount: amount) else {
                    flash("Hidden hold full — free \(Player.hiddenCargoCapacity) mass for contraband.")
                    audio.play(.hurt)
                    return
                }
            }
            activeMissions.append(m)
            stationMissions.remove(at: missionSelectIndex)
            missionSelectIndex = min(missionSelectIndex, max(0, stationMissions.count + activeMissions.count - 1))
            var acceptMsg = "Mission accepted: \(m.title)"
            if m.isSmuggle == true { acceptMsg += " — contraband in hidden hold" }
            if let t = m.timeRemaining { acceptMsg += " — \(Int(t))s remaining" }
            flash(acceptMsg)
            audio.play(.select)
            switch m.kind {
            case .escort:
                beginEscortMission(m)
                navWaypoint = .escort
            case .delivery(_, _, let destStation, let destSystem):
                if destSystem == currentSystemName {
                    setNavToStationNamed(destStation)
                } else if let gate = currentSystem.gates.first(where: { $0.destinationSystem == destSystem }) {
                    navWaypoint = .gate(gate.id)
                    flash("\(acceptMsg) — NAV to gate \(gate.name)")
                } else if let gate = currentSystem.gates.min(by: {
                    distance($0.position, player.position) < distance($1.position, player.position)
                }) {
                    navWaypoint = .gate(gate.id)
                }
            case .explore(let system):
                if let gate = currentSystem.gates.first(where: { $0.destinationSystem == system }) {
                    navWaypoint = .gate(gate.id)
                }
            case .stationDefense(let stationName, let system, _) where system == currentSystemName:
                setNavToStationNamed(stationName)
            case .freelaneRaid(_, let system, _):
                if let gate = currentSystem.gates.first(where: { $0.destinationSystem == system }) {
                    navWaypoint = .gate(gate.id)
                    flash("Raid accepted — you are the hunter. NAV toward \(system).")
                } else if system == currentSystemName {
                    flash("Raid accepted — hit freighters on freelanes. Law will answer.")
                }
            case .survey(_, let system, _):
                if system == currentSystemName {
                    flash("Survey accepted — R near the target to plant the probe.")
                } else if let gate = currentSystem.gates.first(where: { $0.destinationSystem == system }) {
                    navWaypoint = .gate(gate.id)
                    flash("Survey accepted — NAV toward \(system).")
                }
            default:
                break
            }
            _ = m
        } else {
            let aidx = missionSelectIndex - offerCount
            guard aidx >= 0, aidx < activeMissions.count else { return }
            tryCompleteMission(at: aidx)
        }
    }

    private func tryCompleteMission(at index: Int) {
        guard index < activeMissions.count else { return }
        var m = activeMissions[index]
        guard let st = dockedStation else { return }

        switch m.kind {
        case .bounty, .patrol:
            if m.progress >= m.target {
                completeMissionReward(m.reward, message: "Mission complete! +\(m.reward) cr")
                activeMissions.remove(at: index)
            } else {
                flash("Progress \(m.progress)/\(m.target). Keep flying.")
            }
        case .delivery(let commodity, let amount, let destStation, let destSystem):
            guard currentSystemName == destSystem, st.name == destStation else {
                flash("Deliver to \(destStation), \(destSystem).")
                return
            }
            if let rem = m.timeRemaining, rem <= 0 {
                flash("Contract expired — cargo spoiled.")
                return
            }
            let smuggle = m.isSmuggle == true
            if smuggle {
                guard player.smuggleHold[commodity, default: 0] >= amount else {
                    flash("Need \(amount) \(commodity.rawValue) in hidden hold.")
                    return
                }
                _ = player.removeHiddenCargo(commodity, amount: amount)
            } else {
                guard player.cargo[commodity, default: 0] >= amount else {
                    flash("Need \(amount) \(commodity.rawValue) in cargo.")
                    return
                }
                _ = player.removeCargo(commodity, amount: amount)
            }
            let bonus = smuggle ? " (clean drop)" : ""
            completeMissionReward(m.reward, message: "Delivery complete! +\(m.reward) cr\(bonus)")
            activeMissions.remove(at: index)
        case .explore(let system):
            if currentSystemName == system {
                completeMissionReward(m.reward, message: "Scout report filed! +\(m.reward) cr")
                activeMissions.remove(at: index)
            } else {
                flash("Travel to \(system) and dock.")
            }
        case .stationDefense(let stationName, let system, _):
            guard currentSystemName == system, st.name == stationName else {
                flash("Report to \(stationName) in \(system).")
                return
            }
            let capitalDead = !npcs.contains(where: { $0.isCapital })
            if m.progress >= m.target || (capitalDead && !capitalAssaultActive) {
                completeMissionReward(m.reward, message: "Station defended! +\(m.reward) cr")
                activeMissions.remove(at: index)
                player.storyCapitalKill = true // defense counts for lane war
                checkStoryProgress(context: "defense")
            } else {
                flash("Defense progress \(m.progress)/\(m.target).")
            }
        case .escort(let destStation, let destSystem, let haulerName):
            guard currentSystemName == destSystem, st.name == destStation else {
                flash("Escort \(haulerName) to \(destStation), \(destSystem).")
                return
            }
            if m.progress >= m.target || escortHaulerNearStation(st) {
                finishEscortSuccess(at: index)
            } else {
                flash("Hauler not nearby — stay with \(haulerName) until arrival.")
            }
        case .freelaneRaid(let laneName, let system, _):
            if m.progress >= m.target {
                completeMissionReward(m.reward, message: "Raid complete on \(laneName)! +\(m.reward) cr")
                var r = player.rep
                r.adjust(police: -8, militia: -10, pirate: 15)
                player.rep = r
                grantAchievement(.laneRaider)
                activeMissions.remove(at: index)
                postNews("Lane raid settled — \(laneName) bleeds credits.")
            } else {
                flash("Raid \(system): \(m.progress)/\(m.target) freighters on the freelanes.")
            }
        case .survey(let targetName, let system, let kind):
            guard m.progress >= m.target else {
                flash("Plant beacon at \(kind.label) \(targetName) in \(system) (R / F near target).")
                return
            }
            // Turn in at any dock (sandbox-friendly)
            completeMissionReward(m.reward, message: "Survey filed: \(targetName) +\(m.reward) cr")
            player.surveysCompleted = (player.surveysCompleted ?? 0) + 1
            if (player.surveysCompleted ?? 0) >= 3 {
                grantAchievement(.surveyorPro)
            }
            activeMissions.remove(at: index)
            postNews("Probe report accepted — \(targetName) chart data sold.")
        }
        _ = m
    }

    private func completeMissionReward(_ reward: Int, message: String) {
        player.credits += reward
        player.log.lifetimeCreditsEarned += reward
        player.missionsCompleted += 1
        flash(message)
        audio.play(.win)
        evaluateAchievements()
    }

    private func progressCombatMissions(scanned: Bool = true, killedFaction: Faction? = nil) {
        var deniedBounty = false
        for i in activeMissions.indices {
            switch activeMissions[i].kind {
            case .bounty(let faction, _):
                // Police bounty accepts militia kills too (law targets)
                let matches: Bool = {
                    guard let kf = killedFaction else {
                        // Legacy calls from pirate-only path
                        return faction == .pirate
                    }
                    if faction == .police {
                        return kf == .police || kf == .militia
                    }
                    return kf == faction
                }()
                guard matches else { continue }
                let needScan = activeMissions[i].requiresScan != false
                if needScan && !scanned {
                    deniedBounty = true
                    continue
                }
                activeMissions[i].progress = min(activeMissions[i].target, activeMissions[i].progress + 1)
            case .patrol:
                // Patrols credit hostile kills (not law bounties)
                if let kf = killedFaction, kf == .police || kf == .militia { continue }
                activeMissions[i].progress = min(activeMissions[i].target, activeMissions[i].progress + 1)
            default: break
            }
        }
        if deniedBounty {
            flash("Bounty not credited — scan targets first (hold I).")
        }
    }

    private func progressExploreMissions(station: String) {
        for i in activeMissions.indices {
            if case .explore(let system) = activeMissions[i].kind, system == currentSystemName {
                activeMissions[i].progress = 1
            }
        }
        _ = station
    }

    private func purchaseUpgrade() {
        // 0 wpn 1 eng 2 shd 3 energy 4 cargo 5 repair 6 paint 7 wingman 8 ship 9 fine 10 missiles
        // 11+ alien tech at Vael bases
        if let tech = alienTechAtOutfitRow(outfitSelectIndex) {
            buyAlienTech(tech)
            player.applyUpgradeLevels()
            return
        }
        switch outfitSelectIndex {
        case 0: buyUpgrade(kind: .weapons)
        case 1: buyUpgrade(kind: .engines)
        case 2: buyUpgrade(kind: .shields)
        case 3: buyUpgrade(kind: .energy)
        case 4: buyUpgrade(kind: .cargo)
        case 5: repairHull()
        case 6: equipOrBuyPaint()
        case 7: hireWingman()
        case 8: purchaseOrSwapShip()
        case 9: payWantedFine()
        case 10: buyMissilePack()
        case 11: buyInsurance()
        case 12: takeOrPayLoan()
        case 13: buyPirateProtection()
        case 14: buyMinePack()
        case 15: buyCMPack()
        default: break
        }
        player.applyUpgradeLevels()
    }

    private func buyMinePack() {
        let maxM = player.maxMinesForClass
        guard player.mineStock < maxM else {
            flash("Mine racks full (\(maxM)).")
            return
        }
        let add = min(Player.minePackSize, maxM - player.mineStock)
        let cost = Player.minePackCost
        guard player.credits >= cost else {
            flash("Need \(cost) cr for mines.")
            audio.play(.hurt)
            return
        }
        player.credits -= cost
        player.mineStock += add
        flash("Mine pack +\(add) (−\(cost) cr). Racks \(player.mineStock)/\(maxM). J to drop.")
        audio.play(.pickup)
    }

    private func buyCMPack() {
        let maxC = player.maxCMForClass
        guard player.cmStock < maxC else {
            flash("Countermeasure racks full (\(maxC)).")
            return
        }
        let add = min(Player.cmPackSize, maxC - player.cmStock)
        let cost = Player.cmPackCost
        guard player.credits >= cost else {
            flash("Need \(cost) cr for chaff.")
            audio.play(.hurt)
            return
        }
        player.credits -= cost
        player.cmStock += add
        flash("Chaff +\(add) (−\(cost) cr). \(player.cmStock)/\(maxC). K to deploy.")
        audio.play(.pickup)
    }

    private func dropMine() {
        guard phase == .playing else { return }
        guard spaceMineDropCooldown <= 0 else { return }
        guard player.mineStock > 0 else {
            flash("No mines — buy packs at Outfitter.")
            audio.play(.hurt)
            return
        }
        player.mineStock -= 1
        spaceMineDropCooldown = 0.85
        let behind = player.position - angleToVector(player.angle) * 28
        let onLane = onTradeLane
        spaceMines.append(SpaceMine(
            id: UUID(),
            position: behind,
            armTimer: Self.mineArmTime,
            life: Self.mineLife,
            radius: onLane ? Self.mineRadius * 1.15 : Self.mineRadius,
            damage: Self.mineDamage * (player.shipClass == .interceptor ? 1.15 : 1.0),
            fromPlayer: true
        ))
        let laneNote = onLane ? " on the freelane" : ""
        flash("Mine deployed\(laneNote). Arms in \(Int(Self.mineArmTime))s. (\(player.mineStock) left)")
        audio.play(.hurt)
        if onLane {
            postNews("\(currentSystemName): proximity hazard reported on freelane.")
        }
    }

    private func deployCountermeasures() {
        guard phase == .playing else { return }
        guard cmCooldown <= 0 else { return }
        guard player.cmStock > 0 else {
            flash("No countermeasures — buy chaff at Outfitter.")
            audio.play(.hurt)
            return
        }
        player.cmStock -= 1
        cmCooldown = 1.1
        // Break incoming missiles tracking the player
        var broken = 0
        for i in projectiles.indices.reversed() {
            let p = projectiles[i]
            guard p.kind == .missile, p.tracksPlayer || (!p.fromPlayer && p.targetID == nil && p.tracksPlayer) else {
                // Also break any enemy missile near player
                if p.kind == .missile, !p.fromPlayer, distance(p.position, player.position) < 320 {
                    spawnCMBurst(at: p.position)
                    projectiles.remove(at: i)
                    broken += 1
                }
                continue
            }
            if distance(p.position, player.position) < 400 {
                spawnCMBurst(at: p.position)
                projectiles.remove(at: i)
                broken += 1
            }
        }
        // Visual flare cloud
        for _ in 0..<14 {
            let a = Float.random(in: 0...(2 * .pi))
            particles.append(Particle(
                id: UUID(),
                position: player.position,
                velocity: angleToVector(a) * Float.random(in: 40...160),
                life: Float.random(in: 0.4...0.9),
                maxLife: 0.9,
                color: (1.0, 0.75, 0.3),
                size: Float.random(in: 2...5)
            ))
        }
        flash(broken > 0
              ? "Chaff! \(broken) missile\(broken == 1 ? "" : "s") decoyed. (\(player.cmStock) left)"
              : "Chaff burst. (\(player.cmStock) left)")
        audio.play(.select)
    }

    private func spawnCMBurst(at pos: SIMD2<Float>) {
        for _ in 0..<8 {
            particles.append(Particle(
                id: UUID(), position: pos,
                velocity: SIMD2(Float.random(in: -80...80), Float.random(in: -80...80)),
                life: 0.35, maxLife: 0.35,
                color: (1.0, 0.85, 0.4), size: 3
            ))
        }
    }

    private func updateMines(_ dt: Float) {
        for i in spaceMines.indices.reversed() {
            spaceMines[i].life -= dt
            if spaceMines[i].armTimer > 0 {
                spaceMines[i].armTimer -= dt
            }
            if spaceMines[i].life <= 0 {
                spaceMines.remove(at: i)
                continue
            }
            guard spaceMines[i].armTimer <= 0 else { continue }
            let mine = spaceMines[i]
            // Trigger on NPCs (not wingman) or player if enemy mine (none yet)
            var hit = false
            for ni in npcs.indices.reversed() {
                let ship = npcs[ni]
                if ship.isWingman { continue }
                if distance(ship.position, mine.position) < mine.radius + ship.radius {
                    applyDamageToNPC(ni, damage: mine.damage, creditKill: mine.fromPlayer)
                    hit = true
                    break
                }
            }
            if !hit, !mine.fromPlayer, distance(player.position, mine.position) < mine.radius + 14 {
                // Reserved for future enemy mines
            }
            if hit {
                spawnExplosion(at: mine.position, big: false)
                for _ in 0..<12 {
                    particles.append(Particle(
                        id: UUID(), position: mine.position,
                        velocity: SIMD2(Float.random(in: -120...120), Float.random(in: -120...120)),
                        life: 0.4, maxLife: 0.4,
                        color: (1.0, 0.5, 0.15), size: 4
                    ))
                }
                spaceMines.remove(at: i)
                minesDetonated += 1
                if minesDetonated >= 5 { grantAchievement(.mineLayer) }
                audio.play(.explode)
            }
        }
    }

    private func cycleWingmanRole(_ delta: Int) {
        let all = WingmanRole.allCases
        guard let i = all.firstIndex(of: wingmanRolePreview) else {
            wingmanRolePreview = .gunner
            return
        }
        wingmanRolePreview = all[(i + delta + all.count) % all.count]
        // Also cycle paint with secondary: use player paint as wingman paint default
        flash("Wingman: \(wingmanRolePreview.displayName) — \(wingmanRolePreview.blurb) (\(wingmanCostFor(wingmanRolePreview)) cr)")
        audio.play(.select)
    }

    func wingmanCostFor(_ role: WingmanRole) -> Int {
        var cost = role.hireCost
        let militiaHome = dockedStation?.faction == "Militia" || currentSystemName == "Kestrel"
        if militiaHome {
            if player.rep.repMilitia >= 50 { cost = Int(Float(cost) * 0.5) }
            else if player.rep.repMilitia >= 25 { cost = Int(Float(cost) * 0.7) }
        }
        return cost
    }

    private func buyInsurance() {
        if player.ironmanMode {
            flash("Ironman — no insurance. Death is final.")
            audio.play(.hurt)
            return
        }
        if player.insured {
            flash("Hull insurance already active.")
            return
        }
        guard player.credits >= Player.insurancePremium else {
            flash("Need \(Player.insurancePremium) cr for insurance.")
            audio.play(.hurt)
            return
        }
        player.credits -= Player.insurancePremium
        player.hasInsurance = true
        flash("Hull insurance purchased (−\(Player.insurancePremium) cr). Respawn at last dock on death.")
        grantAchievement(.insuredPilot)
        audio.play(.win)
    }

    private func takeOrPayLoan() {
        if player.loanOutstanding > 0 {
            let pay = min(player.loanOutstanding, max(Player.loanPaymentPerDock, player.credits))
            guard player.credits >= 1, pay > 0 else {
                flash("No credits to pay loan.")
                return
            }
            let amount = min(player.loanOutstanding, player.credits)
            player.credits -= amount
            player.loanPrincipal = player.loanOutstanding - amount
            if player.loanOutstanding <= 0 {
                player.loanPrincipal = nil
                player.loanMissedPayments = nil
                flash("Loan paid in full.")
            } else {
                flash("Paid \(amount) cr toward loan. Remaining \(player.loanOutstanding) cr.")
            }
            audio.play(.pickup)
            return
        }
        // Take freighter loan
        var r = player.rep
        if r.ownedShips.contains(.freighter) {
            flash("You already own a freighter — no loan needed.")
            return
        }
        let down = Player.freighterLoanDownPayment
        guard player.credits >= down else {
            flash("Need \(down) cr down payment for freighter loan.")
            audio.play(.hurt)
            return
        }
        player.credits -= down
        player.loanPrincipal = Player.freighterLoanAmount
        player.loanMissedPayments = 0
        r.ownedShips.insert(.freighter)
        r.shipClass = .freighter
        player.rep = r
        player.applyUpgradeLevels()
        player.hull = player.stats.maxHull
        player.shield = player.stats.maxShield
        flash("Freighter loan: −\(down) cr down, \(Player.freighterLoanAmount) cr owed (\(Player.loanPaymentPerDock)/dock).")
        postNews("Shipyard finance: pilot financed a bulk freighter.")
        grantAchievement(.loanShark)
        audio.play(.win)
    }

    private func buyPirateProtection() {
        guard let st = dockedStation, isDirtyFriendlyStation(st) else {
            flash("Pirate protection is sold at dens / Umbra / black markets only.")
            audio.play(.hurt)
            return
        }
        _ = st
        guard player.rep.repPirate >= 10 || player.isDirty else {
            flash("Need pirate standing (rep ≥ 10) or dirty flag for protection.")
            audio.play(.hurt)
            return
        }
        guard player.credits >= Player.pirateProtectionFee else {
            flash("Need \(Player.pirateProtectionFee) cr for protection.")
            audio.play(.hurt)
            return
        }
        player.credits -= Player.pirateProtectionFee
        player.pirateProtectionSeconds = (player.pirateProtectionSeconds ?? 0) + Player.pirateProtectionDuration
        flash("Protection paid (−\(Player.pirateProtectionFee) cr). Pirates stand down ~\(Int(Player.pirateProtectionDuration / 60)) min.")
        postNews("Umbra: pilot bought lane protection.")
        audio.play(.win)
    }

    private func buyMissilePack() {
        guard player.missiles < Player.maxMissiles else {
            flash("Missile racks full (\(Player.maxMissiles)).")
            return
        }
        let need = Player.maxMissiles - player.missiles
        let packs = max(1, (min(Player.missilePackSize, need) + Player.missilePackSize - 1) / Player.missilePackSize)
        // Buy one pack at a time (up to pack size or space)
        let add = min(Player.missilePackSize, need)
        let cost = Player.missilePackCost
        guard player.credits >= cost else {
            flash("Need \(cost) cr for \(add) missiles.")
            audio.play(.hurt)
            return
        }
        player.credits -= cost
        player.missiles = min(Player.maxMissiles, player.missiles + add)
        flash("Missile reload +\(add) (−\(cost) cr). Racks \(player.missiles)/\(Player.maxMissiles).")
        audio.play(.pickup)
        _ = packs
    }

    private func buyAlienTech(_ tech: Blueprint) {
        guard tech.isAlien else { return }
        guard isAlienOutfitter else {
            flash("Alien tech is only sold at Vael bases in Voidreach.")
            return
        }
        if player.unlockedBlueprints.contains(tech) {
            flash("\(tech.displayName) already integrated.")
            return
        }
        let cost = tech.alienPurchaseCost
        guard player.credits >= cost else {
            flash("Need \(cost) cr for \(tech.displayName).")
            audio.play(.hurt)
            return
        }
        player.credits -= cost
        player.unlockedBlueprints.insert(tech)
        player.applyUpgradeLevels()
        player.hull = player.stats.maxHull
        player.shield = player.stats.maxShield
        flash("Installed \(tech.displayName) (−\(cost) cr). \(tech.blurb)")
        postNews("Vael tech acquired: \(tech.displayName).")
        grantAchievement(.vaelTech)
        audio.play(.win)
    }

    func wingmanHireCostCurrent() -> Int {
        wingmanCostFor(wingmanRolePreview)
    }

    private func hireWingman() {
        if hasWingman {
            flash("\(activeWingmanName()) already on station. −/+ change role for next hire.")
            return
        }
        let role = wingmanRolePreview
        let cost = wingmanCostFor(role)
        guard player.credits >= cost else {
            flash("Need \(cost) cr for \(role.displayName).")
            audio.play(.hurt)
            return
        }
        player.credits -= cost
        let paint = player.paintJob // match pilot colors
        player.wingmanRole = role
        player.wingmanPaint = paint
        let offset = angleToVector(player.angle + 1.0) * 80
        var wing = GalaxyBuilder.makeWingman(at: player.position + offset, role: role, paint: paint)
        wing.angle = player.angle
        wingmanID = wing.id
        npcs.append(wing)
        let disc = cost < role.hireCost ? " (militia discount)" : ""
        flash("\(wing.name) hired as \(role.displayName) (−\(cost) cr)\(disc). \(role.blurb)")
        postNews("Second seat: \(wing.name) (\(role.displayName)) signed on at \(dockedStation?.name ?? "dock").")
        grantAchievement(.wingmanHired)
        // Track unique roles hired this run via log unlocks
        _ = player.log.unlock("wingRole_\(role.rawValue)")
        if WingmanRole.allCases.allSatisfy({ player.log.unlocked.contains("wingRole_\($0.rawValue)") }) {
            grantAchievement(.wingBoss)
        }
        audio.play(.win)
    }

    func activeWingmanName() -> String {
        guard let id = wingmanID, let w = npcs.first(where: { $0.id == id }) else {
            return "Wingman"
        }
        return w.name
    }

    private func updateCapitalEvents(_ dt: Float) {
        capitalEventTimer -= dt
        if capitalAssaultActive {
            capitalAssaultTimer -= dt
            if capitalAssaultTimer <= 0 {
                capitalAssaultActive = false
                capitalAssaultStationName = nil
                // Despawn living capitals if timer expired without kill
                npcs.removeAll { $0.isCapital }
                postNews("\(currentSystemName): assault force withdrew.")
                flash("Capital assault ended.")
                capitalEventTimer = Float.random(in: 100...180)
            }
            return
        }
        guard capitalEventTimer <= 0 else { return }
        capitalEventTimer = Float.random(in: 100...180)
        // More likely in dangerous systems
        let chance = min(0.75, 0.25 + currentSystem.piratePressure * 0.2)
        guard Float.random(in: 0...1) < chance else { return }
        spawnCapitalAssault()
    }

    private func spawnCapitalAssault() {
        guard let st = currentSystem.stations.randomElement() else { return }
        let angle = Float.random(in: 0...(2 * .pi))
        let pos = st.position + angleToVector(angle) * 550
        let capital = GalaxyBuilder.makePirateCapital(at: pos)
        npcs.append(capital)
        // Support raiders
        for k in 0..<3 {
            let a = angle + Float(k) * 0.7
            npcs.append(GalaxyBuilder.makeNPC(faction: .pirate, at: pos + angleToVector(a) * 120))
        }
        capitalAssaultActive = true
        capitalAssaultStationName = st.name
        capitalAssaultTimer = 90
        postNews("ALERT \(currentSystemName): \(capital.name) assaulting \(st.name)!")
        flash("Pirate capital inbound on \(st.name)!")
        audio.play(.hurt)

        // Offer defense contract if mission log has room
        if activeMissions.count < 5,
           !activeMissions.contains(where: {
               if case .stationDefense = $0.kind { return true }
               return false
           }) {
            let militiaBonus = (st.faction == "Militia" || currentSystemName == "Kestrel") && player.rep.repMilitia >= 20
            let reward = militiaBonus ? 1400 : 900
            let m = Mission(
                id: UUID(),
                title: "Defend \(st.name)",
                description: "Destroy 4 hostiles (or the capital) near \(st.name).\(militiaBonus ? " Militia retainer bonus." : "")",
                kind: .stationDefense(stationName: st.name, system: currentSystemName, killsNeeded: 4),
                reward: reward,
                progress: 0,
                target: 4,
                completed: false,
                offeredAtStation: st.name,
                offeredAtSystem: currentSystemName
            )
            activeMissions.append(m)
            flash("Defense contract auto-accepted: Defend \(st.name).")
        }
    }

    private func progressDefenseMissions() {
        for i in activeMissions.indices {
            if case .stationDefense(_, let system, _) = activeMissions[i].kind,
               system == currentSystemName {
                activeMissions[i].progress = min(activeMissions[i].target, activeMissions[i].progress + 1)
            }
        }
    }

    private func cyclePaint(_ delta: Int) {
        let all = ShipPaint.allCases
        guard let i = all.firstIndex(of: player.paintJob) else { return }
        let next = all[(i + delta + all.count) % all.count]
        // Preview only owned paints freely; unowned stay preview until purchased
        player.paintJob = next
        audio.play(.select)
        if player.ownedPaints.contains(next) {
            flash("Paint: \(next.displayName)")
        } else {
            flash("Preview: \(next.displayName) — \(next.unlockCost) cr to unlock")
        }
    }

    private func equipOrBuyPaint() {
        let paint = player.paintJob
        if player.ownedPaints.contains(paint) {
            flash("Equipped \(paint.displayName).")
            audio.play(.select)
            return
        }
        guard player.credits >= paint.unlockCost else {
            flash("Need \(paint.unlockCost) cr for \(paint.displayName).")
            audio.play(.hurt)
            return
        }
        player.credits -= paint.unlockCost
        player.ownedPaints.insert(paint)
        flash("Unlocked paint: \(paint.displayName) (−\(paint.unlockCost) cr).")
        audio.play(.win)
    }

    func recordMarketIntel(for station: Station, system: String) {
        var buy: [Commodity: Int] = [:]
        var sell: [Commodity: Int] = [:]
        for c in Commodity.allCases {
            if let o = station.market[c] {
                buy[c] = o.buyPrice
                sell[c] = o.sellPrice
            }
        }
        let key = "\(system)/\(station.name)"
        let prev = player.marketIntel[key]
        var sellAvg = prev?.sellAvg ?? [:]
        var buyAvg = prev?.buyAvg ?? [:]
        let samples = (prev?.samples ?? 0) + 1
        for c in Commodity.allCases {
            if let s = sell[c] {
                let old = sellAvg[c] ?? s
                sellAvg[c] = (old * (samples - 1) + s) / samples
            }
            if let b = buy[c] {
                let old = buyAvg[c] ?? b
                buyAvg[c] = (old * (samples - 1) + b) / samples
            }
        }
        player.marketIntel[key] = StationPriceIntel(
            buyPrices: buy, sellPrices: sell,
            sellAvg: sellAvg, buyAvg: buyAvg, samples: min(samples, 20)
        )
    }

    // MARK: - Reputation / wanted / ship hull / escort

    private func payWantedFine() {
        guard player.isWanted else {
            flash("No outstanding warrants.")
            return
        }
        guard let st = dockedStation, st.faction == "Militia" else {
            flash("Only Militia stations process clearance (Border Watch, Fort Kestrel…).")
            audio.play(.hurt)
            return
        }
        let cost = player.rep.fineCost()
        guard player.credits >= cost else {
            flash("Fine is \(cost) cr — not enough credits.")
            audio.play(.hurt)
            return
        }
        player.credits -= cost
        var r = player.rep
        r.clearWanted()
        r.adjust(police: 8, militia: 12, pirate: -5)
        player.rep = r
        flash("Warrants cleared at \(st.name) (−\(cost) cr). Status: Clean.")
        postNews("\(st.name): pilot cleared — no longer wanted.")
        audio.play(.win)
    }

    /// Outfitter hull preview (cycled with − / + on ship row).
    var shipClassPreview: PlayerShipClass = .hybrid

    private func cycleShipClass(_ delta: Int) {
        let all = PlayerShipClass.allCases
        guard let i = all.firstIndex(of: shipClassPreview) else {
            shipClassPreview = player.shipClass
            return
        }
        shipClassPreview = all[(i + delta + all.count) % all.count]
        let owned = player.rep.ownedShips.contains(shipClassPreview) || shipClassPreview == .hybrid
        if owned {
            let tag = shipClassPreview == player.shipClass ? " (equipped)" : " — Enter to swap"
            flash("Hull: \(shipClassPreview.displayName)\(tag)")
        } else {
            flash("Preview: \(shipClassPreview.displayName) — \(shipClassPreview.purchaseCost) cr · Enter buy")
        }
        audio.play(.select)
    }

    private func purchaseOrSwapShip() {
        let choice = shipClassPreview
        var r = player.rep
        if !r.ownedShips.contains(.hybrid) {
            r.ownedShips.insert(.hybrid)
        }
        if r.ownedShips.contains(choice) {
            if choice == player.shipClass {
                flash("Already flying \(choice.displayName).")
                return
            }
            // Partial transfer: keep Mk levels but soft cargo overflow dump
            r.shipClass = choice
            player.rep = r
            player.applyUpgradeLevels()
            trimCargoToCapacity()
            flash("Transferred into \(choice.displayName). Upgrades retained.")
            postNews("Hull swap: now piloting a \(choice.displayName).")
            audio.play(.win)
            return
        }
        let cost = choice.purchaseCost
        guard player.credits >= cost else {
            flash("Need \(cost) cr for \(choice.displayName).")
            audio.play(.hurt)
            return
        }
        player.credits -= cost
        r.ownedShips.insert(choice)
        r.shipClass = choice
        player.rep = r
        player.applyUpgradeLevels()
        // Fresh purchase: full hull/shields for new frame
        player.hull = player.stats.maxHull
        player.shield = player.stats.maxShield
        trimCargoToCapacity()
        flash("Purchased \(choice.displayName) (−\(cost) cr). Mk upgrades kept.")
        postNews("Shipyard: pilot acquired a \(choice.displayName).")
        audio.play(.win)
    }

    private func trimCargoToCapacity() {
        // Drop excess cargo when swapping to a smaller hold
        while player.cargoUsed > player.stats.cargoCapacity + 0.01, let (c, n) = player.cargo.first, n > 0 {
            _ = player.removeCargo(c, amount: 1)
        }
        if player.cargoUsed > player.stats.cargoCapacity {
            flash("Excess cargo jettisoned to fit hold.")
        }
    }

    private func beginEscortMission(_ m: Mission) {
        guard case .escort(_, _, let haulerName) = m.kind else { return }
        // Spawn protected hauler near player / station
        let offset = angleToVector(player.angle + 0.8) * 100
        var hauler = GalaxyBuilder.makeCargoShip(at: player.position + offset)
        // Prefer bulk/tanker silhouette
        if Float.random(in: 0...1) < 0.5 {
            hauler = GalaxyBuilder.makeNPC(faction: .trader, at: player.position + offset)
        }
        hauler.name = haulerName
        hauler.hull = max(hauler.hull, 100)
        hauler.maxHull = max(hauler.maxHull, 100)
        hauler.shield = max(hauler.shield, 45)
        hauler.maxShield = max(hauler.maxShield, 45)
        hauler.cargoPodsRemaining = max(3, hauler.cargoPodsRemaining)
        escortShipID = hauler.id
        escortMissionID = m.id
        escortAmbushTimer = Float.random(in: 10...18)
        npcs.append(hauler)
        flash("Convoy online: protect \(haulerName). Stay close through freelanes.")
        postNews("Escort contract: \(haulerName) under your protection.")
    }

    private func escortHaulerNearStation(_ st: Station) -> Bool {
        guard let id = escortShipID,
              let hauler = npcs.first(where: { $0.id == id }) else { return false }
        return distance(hauler.position, st.position) < st.dockRadius + 120
            && distance(player.position, hauler.position) < 700
    }

    private func tryCompleteEscortOnDock(station: Station) {
        guard let mid = escortMissionID,
              let idx = activeMissions.firstIndex(where: { $0.id == mid }),
              case .escort(let destStation, let destSystem, _) = activeMissions[idx].kind else { return }
        guard currentSystemName == destSystem, station.name == destStation else { return }
        if escortHaulerNearStation(station) {
            finishEscortSuccess(at: idx)
        }
    }

    private func finishEscortSuccess(at index: Int) {
        guard index < activeMissions.count else { return }
        let m = activeMissions[index]
        completeMissionReward(m.reward, message: "Convoy delivered! +\(m.reward) cr")
        var r = player.rep
        r.adjust(police: 3, militia: 6, pirate: -2)
        player.rep = r
        player.log.freightersSaved += 1
        grantAchievement(.freighterGuardian)
        // Despawn hauler (docked)
        if let id = escortShipID {
            npcs.removeAll { $0.id == id }
        }
        escortShipID = nil
        escortMissionID = nil
        activeMissions.remove(at: index)
        postNews("Escort complete — hauler safe at destination.")
    }

    private func failEscortMission(reason: String) {
        if let mid = escortMissionID,
           let idx = activeMissions.firstIndex(where: { $0.id == mid }) {
            activeMissions.remove(at: idx)
        }
        escortShipID = nil
        escortMissionID = nil
        flash(reason)
        postNews("Escort failed in \(currentSystemName).")
        audio.play(.hurt)
        var r = player.rep
        r.adjust(police: -4, militia: -8)
        player.rep = r
    }

    private func updateEscortMission(_ dt: Float) {
        guard let eid = escortShipID else { return }
        guard let hidx = npcs.firstIndex(where: { $0.id == eid }) else {
            failEscortMission(reason: "Escort target lost.")
            return
        }
        // Keep hauler somewhat near player — soft magnet
        var hauler = npcs[hidx]
        let d = distance(hauler.position, player.position)
        if d > 900 {
            // Catch up toward player
            let desired = angleToward(hauler.position, player.position)
            hauler.angle = lerpAngle(hauler.angle, desired, 2.0 * dt)
            hauler.velocity += angleToVector(hauler.angle) * min(hauler.speed, 160) * dt
            if !hauler.onTradeLane, d > 1400 {
                // Warp-ish snap if player jumped far without them — fail if system change handled separately
            }
            npcs[hidx] = hauler
        }

        // Ambush waves while escorting
        escortAmbushTimer -= dt
        if escortAmbushTimer <= 0 {
            escortAmbushTimer = Float.random(in: 14...28) / max(0.5, currentSystem.piratePressure)
            if Float.random(in: 0...1) < 0.55 + currentSystem.piratePressure * 0.15 {
                spawnEscortAmbush(near: hauler.position)
            }
        }

        // Mark mission progress when in destination system near dest station
        if let mid = escortMissionID,
           let midx = activeMissions.firstIndex(where: { $0.id == mid }),
           case .escort(let destStation, let destSystem, _) = activeMissions[midx].kind,
           currentSystemName == destSystem,
           let st = currentSystem.stations.first(where: { $0.name == destStation }),
           distance(hauler.position, st.position) < 400 {
            activeMissions[midx].progress = 1
        }
    }

    private func spawnEscortAmbush(near pos: SIMD2<Float>) {
        let count = Int.random(in: 1...2)
        for k in 0..<count {
            let a = Float.random(in: 0...(2 * .pi))
            let p = pos + angleToVector(a) * Float.random(in: 280...420)
            var pirate = GalaxyBuilder.makeNPC(faction: .pirate, at: p)
            pirate.angle = angleToward(p, pos)
            pirate.name = k == 0 ? "Lane Ambusher" : pirate.name
            npcs.append(pirate)
        }
        flash("Pirate ambush on the convoy!")
        postNews("\(currentSystemName): freelane ambush targets the escort!")
        audio.play(.hurt)
    }

    /// Best known buy-low / sell-high pairs from market intel (for galaxy map).
    func tradeRouteHints(limit: Int = 4) -> [(commodity: Commodity, buyAt: String, sellAt: String, margin: Int)] {
        struct Entry {
            var key: String
            var sell: Int // price you pay
            var buy: Int  // price they pay you
        }
        var byCommodity: [Commodity: [Entry]] = [:]
        for (key, intel) in player.marketIntel {
            for c in Commodity.allCases {
                guard let sell = intel.sellPrices[c], let buy = intel.buyPrices[c] else { continue }
                byCommodity[c, default: []].append(Entry(key: key, sell: sell, buy: buy))
            }
        }
        var routes: [(Commodity, String, String, Int)] = []
        for (c, entries) in byCommodity {
            guard entries.count >= 2 else { continue }
            // Cheapest place to buy (lowest sellPrice) → highest place to sell (highest buyPrice)
            guard let cheap = entries.min(by: { $0.sell < $1.sell }),
                  let rich = entries.max(by: { $0.buy < $1.buy }),
                  cheap.key != rich.key else { continue }
            let margin = rich.buy - cheap.sell
            guard margin >= 4 else { continue }
            routes.append((c, cheap.key, rich.key, margin))
        }
        return routes.sorted { $0.3 > $1.3 }.prefix(limit).map {
            (commodity: $0.0, buyAt: $0.1, sellAt: $0.2, margin: $0.3)
        }
    }

    /// Station-level buy-low / sell-high tags for a commodity vs known averages.
    func marketHint(for commodity: Commodity, intel: StationPriceIntel) -> String? {
        let sell = intel.sellPrices[commodity] ?? 0
        let buy = intel.buyPrices[commodity] ?? 0
        // Compare to galaxy averages from all intel
        var sellSum = 0, sellN = 0, buySum = 0, buyN = 0
        for (_, i) in player.marketIntel {
            if let s = i.sellPrices[commodity] { sellSum += s; sellN += 1 }
            if let b = i.buyPrices[commodity] { buySum += b; buyN += 1 }
        }
        guard sellN >= 2, buyN >= 2 else { return nil }
        let avgSell = sellSum / sellN
        let avgBuy = buySum / buyN
        if sell > 0, sell <= Int(Float(avgSell) * 0.88) { return "BUY LOW" }
        if buy > 0, buy >= Int(Float(avgBuy) * 1.12) { return "SELL HIGH" }
        // History vs current
        if let avg = intel.sellAvg?[commodity], sell > 0, sell < Int(Float(avg) * 0.9) {
            return "↓ cheaper"
        }
        if let avg = intel.buyAvg?[commodity], buy > 0, buy > Int(Float(avg) * 1.1) {
            return "↑ pays more"
        }
        return nil
    }

    private enum UpgradeKind {
        case weapons, engines, shields, cargo, energy

        var name: String {
            switch self {
            case .weapons: return "Weapons"
            case .engines: return "Engines"
            case .shields: return "Shields"
            case .cargo: return "Cargo Hold"
            case .energy: return "Energy Plant"
            }
        }

        var baseCost: Int {
            switch self {
            case .weapons: return 1200
            case .engines: return 1000
            case .shields: return 1100
            case .cargo: return 900
            case .energy: return 1150
            }
        }
    }

    /// Does not take `inout` into `player` subfields — that conflicts with exclusive access
    /// when also reading/writing `player.credits` (Swift exclusivity / abort).
    private func buyUpgrade(kind: UpgradeKind) {
        let level: Int
        switch kind {
        case .weapons: level = player.weaponLevel
        case .engines: level = player.engineLevel
        case .shields: level = player.shieldLevel
        case .cargo: level = player.cargoLevel
        case .energy: level = player.energyLevel
        }
        guard level < 5 else {
            flash("\(kind.name) already maxed.")
            return
        }
        let cost = kind.baseCost * level
        guard player.credits >= cost else {
            flash("Need \(cost) cr for \(kind.name) Mk\(level + 1).")
            audio.play(.hurt)
            return
        }
        player.credits -= cost
        let newLevel = level + 1
        switch kind {
        case .weapons: player.weaponLevel = newLevel
        case .engines: player.engineLevel = newLevel
        case .shields: player.shieldLevel = newLevel
        case .cargo: player.cargoLevel = newLevel
        case .energy: player.energyLevel = newLevel
        }
        flash("\(kind.name) upgraded to Mk\(newLevel) (−\(cost) cr).")
        audio.play(.win)
    }

    // MARK: - Discovery, wrecks, economy, news

    private func planetKey(_ planet: Planet) -> String {
        "\(currentSystemName)/\(planet.name)"
    }

    private func wreckKey(_ wreck: Derelict) -> String {
        "\(currentSystemName)/\(wreck.name)"
    }

    private func awardDiscovery(credits: Int, headline: String, detail: String) {
        player.credits += credits
        player.discoveryCreditsEarned += credits
        player.log.lifetimeCreditsEarned += credits
        flash("\(detail)")
        postNews(headline)
        audio.play(.win)
        evaluateAchievements()
    }

    // MARK: - Story & achievements

    /// Current story objective text for HUD.
    var storyHUDLine: String {
        // Lane mystery overlay when in progress
        let mystery = player.laneMystery
        if mystery > 0, mystery < 4 {
            let hints = ["", "→ Umbra Quiet Fracture", "→ Drift Null Segment", "reconstructing…"]
            let h = mystery < hints.count ? hints[mystery] : ""
            return "Lane Mystery \(mystery)/3 \(h)"
        }
        if player.storyStage >= StoryBeat.count {
            return player.hasAncientLaneCore
                ? "Campaign complete · Lane Core ready (L)"
                : "Campaign complete — Frontier Ace"
        }
        let stage = player.storyStage
        let prog: String
        switch stage {
        case 0: prog = player.storyFreelaneDone ? "1/1 freelane · dock Freeport 7" : "0/1 freelane"
        case 1: prog = "\(min(2, player.storyPirateKills))/2 pirates · dock any station"
        case 2: prog = player.storyVisitedUmbra ? "in Umbra · dock any station" : "jump to Umbra"
        case 3: prog = player.storyCapitalKill ? "done" : "destroy capital or finish defense"
        default: prog = ""
        }
        return "Story: \(StoryBeat.title(stage)) — \(prog)"
    }

    private func checkStoryProgress(context: String) {
        guard player.storyStage < StoryBeat.count else { return }
        let stage = player.storyStage
        var complete = false
        switch stage {
        case 0:
            // freelane done + dock Freeport 7
            if player.storyFreelaneDone, context.hasPrefix("dock:"), context.contains("Freeport 7") {
                complete = true
            }
        case 1:
            if player.storyPirateKills >= 2, context.hasPrefix("dock:") {
                complete = true
            }
        case 2:
            if player.storyVisitedUmbra,
               currentSystemName == "Umbra",
               context.hasPrefix("dock:") {
                complete = true
            }
        case 3:
            if player.storyCapitalKill, context == "capital" || context == "defense" || context.hasPrefix("dock:") {
                // Require capital/defense flag; dock optional celebration
                if context == "capital" || context == "defense" {
                    complete = true
                }
            }
        default: break
        }
        if complete {
            let reward = StoryBeat.reward(stage)
            player.credits += reward
            player.log.lifetimeCreditsEarned += reward
            player.missionsCompleted += 1
            flash("Story: \(StoryBeat.title(stage)) complete! +\(reward) cr")
            postNews("Campaign beat complete: \(StoryBeat.title(stage)).")
            audio.play(.win)
            player.storyStage += 1
            if player.storyStage < StoryBeat.count {
                postNews("Next: \(StoryBeat.title(player.storyStage)) — \(StoryBeat.description(player.storyStage))")
                flash("Next story: \(StoryBeat.description(player.storyStage))")
            } else {
                grantAchievement(.storyComplete)
                if player.ironmanMode {
                    grantAchievement(.ironmanVictory)
                }
                postNews("Campaign complete. You are Frontier Ace.")
                flash("Campaign complete — Frontier Ace!")
            }
            evaluateAchievements()
        }
    }

    @discardableResult
    private func grantAchievement(_ ach: Achievement) -> Bool {
        // Conditional requirements
        switch ach {
        case .freighterGuardian:
            guard player.log.freightersSaved >= 5 else { return false }
        case .systemsFive:
            guard player.systemsVisited.count >= 5 else { return false }
        case .systemsTen:
            // Frontier systems only (Voidreach is outer sector)
            let frontier = GalaxyBuilder.systemNames.filter { player.systemsVisited.contains($0) }
            guard frontier.count >= 10 else { return false }
        case .deepPockets:
            guard player.credits >= 25_000 else { return false }
        case .wreckDiver:
            guard player.discoveredWrecks.count >= 5 else { return false }
        case .storyComplete:
            guard player.storyStage >= StoryBeat.count else { return false }
        case .ironmanVictory:
            guard player.ironmanMode, player.storyStage >= StoryBeat.count else { return false }
        case .stationInvestor:
            guard player.investments.values.contains(where: { $0.level >= 1 }) else { return false }
        case .stationPatron:
            guard player.investments.values.contains(where: { $0.level >= StationInvestment.maxLevel }) else { return false }
        case .warehouseBay:
            guard player.warehouse?.rented == true else { return false }
        case .scannerAce:
            guard scansCompleted >= 10 else { return false }
        case .insuredPilot:
            guard player.insured else { return false }
        case .loanShark:
            guard (player.loanPrincipal ?? 0) > 0 || player.rep.ownedShips.contains(.freighter) else { return false }
        case .wingBoss:
            guard WingmanRole.allCases.allSatisfy({ player.log.unlocked.contains("wingRole_\($0.rawValue)") }) else { return false }
        case .laneRaider:
            return false // granted on raid complete only
        case .mineLayer:
            guard minesDetonated >= 5 else { return false }
        case .anomalyHunter:
            guard player.anomalyLog.count >= 5 else { return false }
        case .surveyorPro:
            guard (player.surveysCompleted ?? 0) >= 3 else { return false }
        case .laneWhisper:
            guard player.laneMystery >= 4 || player.hasAncientLaneCore else { return false }
        case .laneRacer:
            guard (player.freelanePBsSet ?? player.laneRecords.count) >= 5 else { return false }
        case .laneGhost:
            return false // granted on beat-ghost only
        default:
            break
        }
        guard player.log.unlock(ach.rawValue) else { return false }
        flash("Achievement: \(ach.title)")
        postNews("Logbook: \(ach.title) — \(ach.detail)")
        audio.play(.win)
        return true
    }

    private func evaluateAchievements() {
        grantAchievement(.systemsFive)
        grantAchievement(.systemsTen)
        grantAchievement(.deepPockets)
        grantAchievement(.wreckDiver)
        grantAchievement(.freighterGuardian)
        grantAchievement(.storyComplete)
        grantAchievement(.ironmanVictory)
        grantAchievement(.stationInvestor)
        grantAchievement(.stationPatron)
        grantAchievement(.warehouseBay)
        grantAchievement(.scannerAce)
        grantAchievement(.insuredPilot)
        grantAchievement(.loanShark)
        grantAchievement(.anomalyHunter)
        grantAchievement(.surveyorPro)
        grantAchievement(.laneWhisper)
        grantAchievement(.laneRacer)
    }

    private func updateDiscoveries() {
        // Hidden wormholes — must fly close before they chart / name
        for gate in currentSystem.gates where gate.isWormhole {
            let key = gate.wormholeKey
            guard !player.discoveredWormholes.contains(key) else { continue }
            if distance(player.position, gate.position) < gate.discoveryRadius {
                player.discoveredWormholes.insert(key)
                awardDiscovery(
                    credits: 750,
                    headline: "Spatial anomaly locked: \(gate.name)",
                    detail: "Wormhole charted → \(gate.destinationSystem) (+750 cr)"
                )
                flash("WORMHOLE: \(gate.name) → \(gate.destinationSystem). Approach and F to transit.")
                postNews("\(currentSystemName): unstable rift opens a path beyond known space.")
            }
        }

        // Planets
        for planet in currentSystem.planets {
            let key = planetKey(planet)
            guard !player.discoveredPlanets.contains(key) else { continue }
            if distance(player.position, planet.position) < planet.radius + 180 {
                player.discoveredPlanets.insert(key)
                awardDiscovery(
                    credits: 200,
                    headline: "Survey complete: \(planet.name) (\(currentSystemName))",
                    detail: "First survey of \(planet.name) +200 cr"
                )
            }
        }
        // Wrecks — mark discovered when near (bonus once)
        guard var sys = systems[currentSystemName] else { return }
        for i in sys.wrecks.indices {
            let w = sys.wrecks[i]
            let key = wreckKey(w)
            guard !player.discoveredWrecks.contains(key) else { continue }
            if distance(player.position, w.position) < w.discoveryRadius {
                player.discoveredWrecks.insert(key)
                let bonus = w.blueprint != nil ? 350 : 150
                awardDiscovery(
                    credits: bonus,
                    headline: "Derelict marked: \(w.name) — \(currentSystemName)",
                    detail: "Wreck located: \(w.name) +\(bonus) cr"
                )
            }
        }
        // Anomaly sites — chart when near
        for a in sys.anomalies {
            let key = "\(currentSystemName)/\(a.name)"
            guard !player.anomalyLog.contains(key) else { continue }
            if distance(player.position, a.position) < a.discoveryRadius {
                discoverAnomaly(a, interact: false)
            }
        }
        _ = sys
    }

    private func anomalyKey(_ a: AnomalySite) -> String {
        "\(currentSystemName)/\(a.name)"
    }

    /// Chart and optionally interact with an anomaly.
    @discardableResult
    private func discoverAnomaly(_ a: AnomalySite, interact: Bool) -> Bool {
        let key = anomalyKey(a)
        let first = !player.anomalyLog.contains(key)
        if first {
            var log = player.anomalyLog
            log.insert(key)
            player.anomalyLog = log
            let bonus = a.kind == .laneEcho ? 400 : (a.kind == .silentField ? 300 : 250)
            awardDiscovery(
                credits: bonus,
                headline: "Anomaly charted: \(a.name) — \(currentSystemName)",
                detail: "\(a.flavor) +\(bonus) cr"
            )
            if player.anomalyLog.count >= 5 {
                grantAchievement(.anomalyHunter)
            }
        }
        if interact {
            resolveAnomalyInteract(a)
        }
        return true
    }

    private func resolveAnomalyInteract(_ a: AnomalySite) {
        switch a.kind {
        case .jumpPocket:
            // Unstable short hop within system
            let b = currentSystem.bounds * 0.75
            let ang = Float.random(in: 0...(2 * .pi))
            let dist = Float.random(in: 800...min(2200, b * 0.5))
            player.position = SIMD2(cos(ang), sin(ang)) * dist
            player.velocity = .zero
            clearTradeLane()
            camera = player.position
            spawnJumpEffect(at: player.position)
            flash("JUMP POCKET — flung across \(currentSystemName). Sensors scrambled.")
            postNews("\(currentSystemName): unstable jump pocket discharged.")
            audio.play(.jump)
            invuln = 1.5

        case .silentField:
            flash("Silent field — cold wrecks, no IFF. Salvage with R.")
            postNews("\(currentSystemName): silent wreck field hums at zero band.")
            audio.play(.select)
            // Small scrap bonus if hold free
            if player.addCargo(.scrap, amount: 2) {
                flash("Silent field: scraped 2 Scrap from cold hulls.")
            }

        case .laneEcho:
            advanceLaneMystery(from: a)
        }
    }

    private func advanceLaneMystery(from a: AnomalySite) {
        guard let step = a.mysteryStep else {
            flash("Lane echo recorded — freelane ghost signal.")
            return
        }
        let stage = player.laneMystery
        if stage >= 4 {
            flash("Lane mystery already complete. Core installed.")
            return
        }
        if stage >= step {
            flash("Lane Echo \(step) already logged. Seek the next fracture.")
            return
        }
        if step > stage + 1 {
            // Allow out-of-order but don't skip reward path
            flash("Lane Echo \(step) — out of sequence. Still logging…")
        }
        player.laneMystery = max(stage, step)
        let nextHint: String
        switch player.laneMystery {
        case 1:
            nextHint = "Signal points toward Umbra — seek Quiet Fracture."
        case 2:
            nextHint = "Thread continues in Drift — Null Segment."
        case 3:
            nextHint = "Pattern complete — reconstructing Ancient Lane Core…"
        default:
            nextHint = ""
        }
        flash("LANE MYSTERY \(player.laneMystery)/3 — \(a.name). \(nextHint)")
        postNews("Something wrong with the freelanes: echo \(player.laneMystery) logged.")
        audio.play(.win)

        if player.laneMystery >= 3 {
            completeLaneMystery()
        }
    }

    private func completeLaneMystery() {
        guard player.laneMystery < 4 else { return }
        player.laneMystery = 4
        if !player.unlockedBlueprints.contains(.ancientLaneCore) {
            player.unlockedBlueprints.insert(.ancientLaneCore)
            player.applyUpgradeLevels()
            flash("ANCIENT LANE CORE reconstructed. Bypass offline rings · L freelane boost.")
            postNews("Pre-war freelane technology restored — pilot carries a Lane Core.")
            grantAchievement(.laneWhisper)
            audio.play(.win)
        }
    }

    @discardableResult
    private func tryInteractAnomaly() -> Bool {
        guard let a = currentSystem.anomalies
            .filter({ distance($0.position, player.position) < $0.interactRadius })
            .min(by: { distance($0.position, player.position) < distance($1.position, player.position) })
        else { return false }
        discoverAnomaly(a, interact: true)
        return true
    }

    /// Plant survey probe at planet / wreck / anomaly for active survey missions.
    @discardableResult
    private func tryPlantSurveyBeacon() -> Bool {
        for i in activeMissions.indices {
            guard case .survey(let targetName, let system, let kind) = activeMissions[i].kind else { continue }
            guard system == currentSystemName else { continue }
            guard activeMissions[i].progress < activeMissions[i].target else { continue }
            let near: Bool
            switch kind {
            case .planet:
                near = currentSystem.planets.contains {
                    $0.name == targetName && distance($0.position, player.position) < $0.radius + 120
                }
            case .wreck:
                near = currentSystem.wrecks.contains {
                    $0.name == targetName && distance($0.position, player.position) < $0.mineRadius + 20
                }
            case .anomaly:
                near = currentSystem.anomalies.contains {
                    $0.name == targetName && distance($0.position, player.position) < $0.interactRadius + 30
                }
            }
            guard near else { continue }
            activeMissions[i].progress = 1
            flash("Probe beacon planted at \(targetName). Dock to report survey.")
            postNews("Survey beacon online: \(targetName), \(currentSystemName).")
            audio.play(.pickup)
            // Soft particles
            for _ in 0..<10 {
                particles.append(Particle(
                    id: UUID(), position: player.position,
                    velocity: SIMD2(Float.random(in: -40...40), Float.random(in: -40...40)),
                    life: 0.6, maxLife: 0.6,
                    color: (0.4, 0.9, 1.0), size: 3
                ))
            }
            return true
        }
        return false
    }

    private func updateWrecks(_ dt: Float) {
        guard var sys = systems[currentSystemName] else { return }
        for i in sys.wrecks.indices {
            sys.wrecks[i].angle += sys.wrecks[i].spin * dt
        }
        systems[currentSystemName] = sys
    }

    @discardableResult
    private func tryMineWreck() -> Bool {
        guard mineCooldown <= 0 else { return false }
        guard var sys = systems[currentSystemName] else { return false }
        guard let idx = sys.wrecks.enumerated()
            .filter({ distance($0.element.position, player.position) < $0.element.mineRadius })
            .min(by: { distance($0.element.position, player.position) < distance($1.element.position, player.position) })?
            .offset else { return false }

        mineCooldown = 0.4
        var wreck = sys.wrecks[idx]
        let take = min(2, wreck.scrap)
        if take > 0 {
            if player.addCargo(.scrap, amount: take) {
                wreck.scrap -= take
                flash("Salvaged \(take) Scrap from \(wreck.name).")
                audio.play(.mine)
                spawnHitParticles(at: wreck.position, enemy: false)
            } else {
                flash("Cargo hold full!")
                audio.play(.hurt)
                return true
            }
        }

        // Pull blueprint when wreck is nearly depleted
        if wreck.scrap <= 2, let bp = wreck.blueprint, !player.unlockedBlueprints.contains(bp) {
            player.unlockedBlueprints.insert(bp)
            wreck.blueprint = nil
            player.applyUpgradeLevels()
            flash("Blueprint recovered: \(bp.displayName) — \(bp.blurb)")
            postNews("Tech recovery: \(bp.displayName) installed on your ship.")
            audio.play(.win)
        }

        if wreck.scrap <= 0 && wreck.blueprint == nil {
            spawnExplosion(at: wreck.position, big: false)
            sys.wrecks.remove(at: idx)
            postNews("\(wreck.name) fully stripped in \(currentSystemName).")
        } else {
            sys.wrecks[idx] = wreck
        }
        systems[currentSystemName] = sys
        return true
    }

    private func applyPirateKillEconomy() {
        guard var sys = systems[currentSystemName] else { return }
        // Weapons demand up; scrap buy price up slightly across the system
        for i in sys.stations.indices {
            if var weapons = sys.stations[i].market[.weapons] {
                weapons.buyPrice = Int(Float(weapons.buyPrice) * 1.06)
                weapons.sellPrice = Int(Float(weapons.sellPrice) * 1.05)
                weapons.stock = max(0, weapons.stock - Int.random(in: 0...3))
                sys.stations[i].market[.weapons] = weapons
            }
            if var scrap = sys.stations[i].market[.scrap] {
                scrap.buyPrice = Int(Float(scrap.buyPrice) * 1.04)
                sys.stations[i].market[.scrap] = scrap
            }
        }
        systems[currentSystemName] = sys
        if economyNewsCooldown <= 0, Float.random(in: 0...1) < 0.45 {
            postNews("\(currentSystemName): pirate activity drives weapons demand.")
            economyNewsCooldown = 14
        }
        // Chance freelane raid news
        if onTradeLane, economyNewsCooldown <= 8, Float.random(in: 0...1) < 0.35 {
            postNews("\(currentSystemName) freelane under attack — escorts advised.")
        }
    }

    func postNews(_ text: String) {
        newsQueue.append(text)
        if newsLine.isEmpty {
            advanceNews()
        }
    }

    private func updateNews(_ dt: Float) {
        if newsTimer > 0 {
            newsTimer -= dt
            if newsTimer <= 0 {
                newsLine = ""
                advanceNews()
            }
        } else if !newsQueue.isEmpty {
            advanceNews()
        }
    }

    private func advanceNews() {
        guard !newsQueue.isEmpty else {
            newsLine = ""
            return
        }
        newsLine = newsQueue.removeFirst()
        newsTimer = 5.5
    }

    // MARK: - VFX helpers

    private func spawnThrustParticle(at pos: SIMD2<Float>, dir: SIMD2<Float>) {
        particles.append(Particle(
            id: UUID(),
            position: pos + SIMD2(Float.random(in: -3...3), Float.random(in: -3...3)),
            velocity: dir * Float.random(in: 40...90) + SIMD2(Float.random(in: -20...20), Float.random(in: -20...20)),
            life: Float.random(in: 0.2...0.45),
            maxLife: 0.45,
            color: (1.0, Float.random(in: 0.5...0.85), 0.2),
            size: Float.random(in: 2...4)
        ))
    }

    private func spawnHitParticles(at pos: SIMD2<Float>, enemy: Bool) {
        for _ in 0..<6 {
            let a = Float.random(in: 0...(2 * .pi))
            particles.append(Particle(
                id: UUID(),
                position: pos,
                velocity: angleToVector(a) * Float.random(in: 30...100),
                life: Float.random(in: 0.15...0.4),
                maxLife: 0.4,
                color: enemy ? (1.0, 0.5, 0.2) : (0.5, 0.9, 1.0),
                size: Float.random(in: 2...5)
            ))
        }
    }

    private func spawnExplosion(at pos: SIMD2<Float>, big: Bool) {
        let n = big ? 28 : 12
        for _ in 0..<n {
            let a = Float.random(in: 0...(2 * .pi))
            particles.append(Particle(
                id: UUID(),
                position: pos,
                velocity: angleToVector(a) * Float.random(in: 40...200),
                life: Float.random(in: 0.3...0.9),
                maxLife: 0.9,
                color: (1.0, Float.random(in: 0.3...0.8), 0.1),
                size: Float.random(in: 3...8)
            ))
        }
    }

    private func spawnJumpEffect(at pos: SIMD2<Float>) {
        for _ in 0..<40 {
            let a = Float.random(in: 0...(2 * .pi))
            particles.append(Particle(
                id: UUID(),
                position: pos,
                velocity: angleToVector(a) * Float.random(in: 80...280),
                life: Float.random(in: 0.4...1.0),
                maxLife: 1.0,
                color: (0.6, 0.4, 1.0),
                size: Float.random(in: 2...6)
            ))
        }
    }

    func flash(_ text: String) {
        message = text
        messageTimer = 3.2
    }

    private func menuNotice(_ text: String) {
        menuFlash = text
        menuFlashTimer = 2.5
    }

    // Allow renderer / keys to sell via F when on trade tab
    func handleTradeSellShortcut() {
        if phase == .docked, stationTab == .trade {
            sellCommodity()
        }
    }

    func dockedSecondaryAction() {
        if stationTab == .trade {
            sellCommodity()
        } else if stationTab == .warehouse {
            warehouseWithdraw()
        } else if stationTab == .status {
            // Recharge shields free at dock (hull still costs credits via Enter)
            if player.shield < player.stats.maxShield {
                player.shield = player.stats.maxShield
                flash("Shields recharged.")
                audio.play(.pickup)
            } else {
                flash("Shields already at full.")
            }
        }
    }

    // MARK: - Freeport 7 warehouse

    private func rentWarehouse() {
        guard isAtFreeport7 else {
            flash("Warehouse bay is only at Freeport 7 (Solara).")
            return
        }
        if player.warehouse?.rented == true {
            flash("Bay already leased.")
            return
        }
        guard !player.isWanted else {
            flash("Lease denied — clear your wanted status first.")
            audio.play(.hurt)
            return
        }
        guard player.rep.repPolice >= PlayerWarehouse.minPoliceRep else {
            flash("Lease denied — need clean standing with Police (rep ≥ \(PlayerWarehouse.minPoliceRep)).")
            audio.play(.hurt)
            return
        }
        let cost = PlayerWarehouse.rentCost
        guard player.credits >= cost else {
            flash("Need \(cost) cr to rent Freeport 7 bay.")
            audio.play(.hurt)
            return
        }
        player.credits -= cost
        var bay = player.warehouse ?? PlayerWarehouse()
        bay.rented = true
        player.warehouse = bay
        flash("Warehouse bay leased at Freeport 7 (−\(cost) cr). Capacity \(Int(PlayerWarehouse.bayCapacity)).")
        postNews("Freeport 7: independent pilot leased cargo bay.")
        grantAchievement(.warehouseBay)
        audio.play(.win)
        evaluateAchievements()
    }

    private func warehouseDeposit() {
        guard isAtFreeport7 else { return }
        guard var bay = player.warehouse, bay.rented else {
            flash("Rent the bay first (Enter).")
            return
        }
        let c = Commodity.allCases[tradeCommodityIndex]
        let have = player.cargo[c, default: 0]
        let amount = min(tradeAmount, have)
        guard amount > 0 else {
            flash("No \(c.rawValue) in your hold.")
            return
        }
        // Cap by bay free mass
        var deposit = amount
        while deposit > 0, Float(deposit) * c.unitMass > bay.freeMass + 0.01 {
            deposit -= 1
        }
        guard deposit > 0 else {
            flash("Warehouse bay full.")
            audio.play(.hurt)
            return
        }
        guard player.removeCargo(c, amount: deposit) else { return }
        guard bay.add(c, amount: deposit) else {
            _ = player.addCargo(c, amount: deposit)
            flash("Warehouse bay full.")
            return
        }
        player.warehouse = bay
        flash("Stored \(deposit) \(c.rawValue) in bay (\(String(format: "%.0f", bay.usedMass))/\(Int(PlayerWarehouse.bayCapacity))).")
        audio.play(.pickup)
    }

    private func warehouseWithdraw() {
        guard isAtFreeport7 else { return }
        guard var bay = player.warehouse, bay.rented else {
            flash("No warehouse lease.")
            return
        }
        let c = Commodity.allCases[tradeCommodityIndex]
        let have = bay.cargo[c, default: 0]
        let amount = min(tradeAmount, have)
        guard amount > 0 else {
            flash("Bay has no \(c.rawValue).")
            return
        }
        var take = amount
        while take > 0, !player.addCargo(c, amount: take) {
            take -= 1
        }
        guard take > 0 else {
            flash("Ship hold full.")
            audio.play(.hurt)
            return
        }
        guard bay.remove(c, amount: take) else { return }
        player.warehouse = bay
        flash("Withdrew \(take) \(c.rawValue) to hold.")
        audio.play(.pickup)
    }
}
