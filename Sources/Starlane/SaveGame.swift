import Foundation

struct GameSnapshot: Codable {
    var player: Player
    var currentSystemName: String
    var activeMissions: [Mission]
    var savedAt: Date
    /// Optional label for UI (e.g. "Autosave", "Slot 2")
    var slotLabel: String?
    var ironmanMode: Bool? // optional for back-compat; mirrored on player
}

/// Three manual slots + one autosave (written on dock).
/// Saves live in `~/Documents/Starlane/`.
enum SaveGame {
    static let manualSlotCount = 3

    /// User-visible save folder: `~/Documents/Starlane`
    static var directory: URL {
        migrateFromApplicationSupportIfNeeded()
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Starlane", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Previous location (pre-1.0.13): Application Support.
    private static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Starlane", isDirectory: true)
    }

    private static var legacyURL: URL {
        directory.appendingPathComponent("save.json")
    }

    private static func slotURL(_ slot: Int) -> URL {
        directory.appendingPathComponent("save_slot_\(slot).json")
    }

    private static var autosaveURL: URL {
        directory.appendingPathComponent("save_autosave.json")
    }

    // MARK: - Existence

    static var hasAnySave: Bool {
        migrateLegacyIfNeeded()
        if existsAutosave { return true }
        for s in 1...manualSlotCount where exists(slot: s) { return true }
        return false
    }

    static func exists(slot: Int) -> Bool {
        migrateLegacyIfNeeded()
        guard (1...manualSlotCount).contains(slot) else { return false }
        return FileManager.default.fileExists(atPath: slotURL(slot).path)
    }

    static var existsAutosave: Bool {
        migrateLegacyIfNeeded()
        return FileManager.default.fileExists(atPath: autosaveURL.path)
    }

    /// True if any slot (including legacy) has data — used by title menu.
    static var exists: Bool { hasAnySave }

    // MARK: - Meta

    static func description(slot: Int) -> String? {
        guard exists(slot: slot) else { return nil }
        do {
            let snap = try load(slot: slot)
            return formatDescription(snap, prefix: "Slot \(slot)")
        } catch {
            // File exists but decode failed — still show a row so the player knows
            return "Slot \(slot) — unreadable (corrupt or outdated)"
        }
    }

    static var autosaveDescription: String? {
        guard existsAutosave else { return nil }
        do {
            let snap = try loadAutosave()
            return formatDescription(snap, prefix: "Autosave")
        } catch {
            return "Autosave — unreadable (corrupt or outdated)"
        }
    }

    /// Best single-line summary for title screen footer.
    static var savedAtDescription: String? {
        migrateLegacyIfNeeded()
        var best: (Date, String)?
        if let snap = try? loadAutosave() {
            best = (snap.savedAt, formatDescription(snap, prefix: "Autosave"))
        }
        for s in 1...manualSlotCount {
            if let snap = try? load(slot: s) {
                if best == nil || snap.savedAt > best!.0 {
                    best = (snap.savedAt, formatDescription(snap, prefix: "Slot \(s)"))
                }
            }
        }
        return best?.1
    }

    private static func formatDescription(_ snap: GameSnapshot, prefix: String) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        let sys = snap.currentSystemName
        let cr = snap.player.credits
        return "\(prefix) · \(sys) · \(cr) cr · \(f.string(from: snap.savedAt))"
    }

    // MARK: - Save / Load

    static func save(_ snapshot: GameSnapshot, slot: Int) throws {
        migrateLegacyIfNeeded()
        guard (1...manualSlotCount).contains(slot) else {
            throw SaveError.invalidSlot
        }
        var snap = snapshot
        snap.slotLabel = "Slot \(slot)"
        let data = try JSONEncoder().encode(snap)
        try data.write(to: slotURL(slot), options: .atomic)
    }

    static func load(slot: Int) throws -> GameSnapshot {
        migrateLegacyIfNeeded()
        guard (1...manualSlotCount).contains(slot) else {
            throw SaveError.invalidSlot
        }
        let data = try Data(contentsOf: slotURL(slot))
        return try JSONDecoder().decode(GameSnapshot.self, from: data)
    }

    static func autosave(_ snapshot: GameSnapshot) throws {
        migrateLegacyIfNeeded()
        var snap = snapshot
        snap.slotLabel = "Autosave"
        let data = try JSONEncoder().encode(snap)
        try data.write(to: autosaveURL, options: .atomic)
    }

    static func loadAutosave() throws -> GameSnapshot {
        migrateLegacyIfNeeded()
        let data = try Data(contentsOf: autosaveURL)
        return try JSONDecoder().decode(GameSnapshot.self, from: data)
    }

    /// One-time: copy saves from Application Support → Documents if Documents is empty.
    private static func migrateFromApplicationSupportIfNeeded() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Starlane", isDirectory: true)
        let appSupport = applicationSupportDirectory

        // Ensure Documents folder exists
        try? fm.createDirectory(at: docs, withIntermediateDirectories: true)

        guard fm.fileExists(atPath: appSupport.path) else { return }

        let names = [
            "save.json",
            "save_autosave.json",
            "save_slot_1.json",
            "save_slot_2.json",
            "save_slot_3.json",
        ]
        for name in names {
            let src = appSupport.appendingPathComponent(name)
            let dst = docs.appendingPathComponent(name)
            guard fm.fileExists(atPath: src.path) else { continue }
            // Never overwrite a newer Documents save
            guard !fm.fileExists(atPath: dst.path) else { continue }
            try? fm.copyItem(at: src, to: dst)
        }
    }

    /// Back-compat: old single `save.json` → Slot 1 once (within Documents folder).
    static func migrateLegacyIfNeeded() {
        migrateFromApplicationSupportIfNeeded()
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacyURL.path) else { return }
        // Only migrate if slot 1 empty
        if !fm.fileExists(atPath: slotURL(1).path) {
            try? fm.copyItem(at: legacyURL, to: slotURL(1))
        }
        // Keep legacy file as backup; also copy to autosave if missing
        if !fm.fileExists(atPath: autosaveURL.path) {
            try? fm.copyItem(at: legacyURL, to: autosaveURL)
        }
    }

    /// Default load target: newest among autosave + slots.
    static func loadMostRecent() throws -> GameSnapshot {
        migrateLegacyIfNeeded()
        var candidates: [(Date, GameSnapshot)] = []
        if let s = try? loadAutosave() { candidates.append((s.savedAt, s)) }
        for i in 1...manualSlotCount {
            if let s = try? load(slot: i) { candidates.append((s.savedAt, s)) }
        }
        guard let best = candidates.max(by: { $0.0 < $1.0 }) else {
            throw SaveError.noData
        }
        return best.1
    }

    enum SaveError: Error {
        case invalidSlot
        case noData
    }

    static func eraseAutosave() {
        try? FileManager.default.removeItem(at: autosaveURL)
    }

    /// Delete every manual slot whose snapshot is flagged ironman.
    static func eraseIronmanSlots() {
        for s in 1...manualSlotCount {
            if let snap = try? load(slot: s), snap.player.ironmanMode {
                try? FileManager.default.removeItem(at: slotURL(s))
            }
        }
        if let snap = try? loadAutosave(), snap.player.ironmanMode {
            eraseAutosave()
        }
    }
}
