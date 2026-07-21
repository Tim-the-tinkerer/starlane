import AppKit

/// Simple scrollable help panel (also mirrors docs/HELP.md).
@MainActor
final class HelpWindowController: NSWindowController {
    private static var shared: HelpWindowController?
    private let scrollView = NSScrollView()
    private let textView = NSTextView()

    static func show() {
        if shared == nil {
            shared = HelpWindowController()
        }
        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Starlane Help"
        window.minSize = NSSize(width: 420, height: 360)
        super.init(window: window)

        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = Theme.void
        textView.textColor = Theme.textPrimary
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.string = Self.helpText
        textView.textContainerInset = NSSize(width: 16, height: 16)

        scrollView.documentView = textView
        window.contentView = scrollView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private static let helpText = """
    STARLANE  1.0.31
    A Freelancer-style space adventure

    STORY
    The corporate wars left the frontier open. You are an independent
    pilot with a light freighter, a laser battery, and a debt that will
    not wait. Trade between systems, take contracts, hunt pirates, raid
    dens, customize your modular ship in the hangar, and survive Cinder.

    CONTROLS
    Turn ............... A/D or ←/→
    Thrust / Brake ..... W/S or ↑/↓
    Fire primary ....... Space = hangar-fitted gun (buy at dock Hangar)
    Switch hangar gun .. Q / 1–4 among owned guns (Pulse Laser free)
    B-mode fire ........ B = classic missiles OR hangar secondary
    Toggle B-mode ...... 5 = Classic MSL ↔ Hangar secondary
    Gun Amplifiers Mk .. Outfit — scale hangar primary damage
    Drive/Shield/Power . Outfit Mk amps — stack on hangar modules
    Ship Hangar ........ Hull, wings, engines, guns, secondary, shields, utility, livery
    Outfit vs Hangar ... Outfit = amps/ammo/services/career · Hangar = modules & weapons
    Target hostiles .... T or Tab
    Nav waypoint ....... V or N (cycle stations, gates, missions)
    Clear nav .......... C
    Autopilot .......... Hold H (toward NAV; drops on hostiles / freelane)
    System map ......... Z or X (expand; click destination; Enter to travel)
    Photo camera ....... Y or O (WASD pan · −/+ speed · Esc exit)
    Dock / Jump ........ F or E (near station or gate)
    Trade lane ......... F near a freelane ring (manual only)
    Exit trade lane .... Hold S (or F while cruising)
    Freelane time trial  Enter at either END of a freelane → race to the other end
                         Ghost = your best lap (gold). Early exit voids the run.
    Freelane hijack .... Pirate fire or close boarding drops you instantly
    Mine / salvage ..... R (or F near rock / wreck)
    Scan / identify .... Hold I (target in range) — cargo, faction, wanted
    Drop mine .......... J (Outfit mine stock; freelane = chaos)
    Countermeasures .... K (chaff breaks missile locks)
    Freelane boost ..... L (Ancient Lane Core — mystery reward)
    Trade route pin .... U (flight) · Galaxy map: pick sell station + U
    Wingman roles ...... Outfit −/+ Gunner / Scout / Tug · painted like you
    Freelane raids ..... Dirty docks / dens — hit freighters; law responds
    Anomalies .......... Nyx/Umbra/Drift/Cinder — F/R to interact
    Lane mystery ....... Echoes: Nyx → Umbra → Drift → Ancient Lane Core
    Survey probes ...... Missions board — R plant beacon, dock to report
    Galaxy map ......... G (or Pause → Galaxy Map)
    Pause .............. P or Escape
    Mute ............... M
    New Game ........... ⌘N (or Ironman from title)
    Save / Load ........ ⌘S / ⌘L (3 manual slots)
    Autosave ........... On every dock
    Save folder ........ ~/Documents/Starlane/
    Logbook ............ Pause → Logbook
    Quit ............... ⌘Q
    Fullscreen cursor .. Hidden while Starlane is key in full screen

    FACTION FLEETS
    Pirates ............ Raider / Gunship / Bomber (missile racks)
    Police ............. Patrol / Interceptor / Enforcer (rail)
    Militia ............ Cutter / Frigate
    Vael ............... Skimmer / Stalker / Warden (teal plasma)
    Bolts are faction-colored — red, blue, green, teal.

    PIRATE DENS (red on map)
    Bloodwake Den ...... Umbra (Pirate Clan capital)
    Raider’s Scar ...... Cinder
    Mute Corsair ....... Nyx
    Hullbreaker Yard ... Drift
    Turrets fire on law and clean pilots. Dock if dirty, pirate rep ≥ 15,
    or under protection. Den markets sell cheap guns; dirty jobs available.

    SPACE WEATHER (zones + HUD strip + light screen grade)
    Nebula ............. Sensors degraded
    Radiation .......... Continuous shield/hull damage
    Ion storm .......... Energy drain · slower weapons
    Dust cloud ......... Thrust & top speed reduced
    Cryo field ......... Turn rate reduced
    Grav sheer ......... Vector pull off course
    EM blackout ........ Scanners offline

    HUD
    Top center ......... Campaign / missions · weather · race · compass (stacked)
    Bottom ............. Compact NEWS / RADIO tickers (centered, not full-width)
    Combat FX .......... Glowing bolts · soft particles · thrust-linked engines

    CONTRACTS
    Timed cargo ........ ⏱ Live Food/Medical runs — spoil if late
    Smuggling .......... 🔒 Hidden hold; law scan seizes goods + militia heat
    Dirty Umbra/den jobs High pay; scanned while dirty = heat
    Bounties ........... Must scan (I) pirates before kills count
    Freelane raids ..... Hit freighters on lanes; law spawns
    Survey probes ...... Beacon at planet/wreck/anomaly, dock to report

    INSURANCE & LOANS (Outfitter)
    Insurance .......... 800 cr · death → respawn last dock (−fee, cargo lost)
    Freighter loan ..... Down 1200 · owe 3500 · 400 cr auto per dock
    Miss 2 payments .... Repo freighter / heat. Ironman: no insurance

    FACTION HOME BASES
    Kestrel / Militia .. Wingman discounts; better defense retainers
    Umbra protection ... Pay pirates to leave you alone (Outfitter)
    Max heat (★★★★★) ... Law docks refuse — use Umbra / dens / black markets

    STORY (light campaign)
    1. Freelane License — ride a freelane, dock Freeport 7
    2. First Bounty — kill 2 pirates, dock any station
    3. Shadow Markets — jump to Umbra and dock
    4. Lane War — destroy a capital (or finish station defense)
    Ironman .............. Death wipes ironman saves; finish story for Ironman Ace

    SHIP HANGAR (Spacecraft Builder) — docked only
    Open ............... Outfit → Ship Hangar (at a station)
    ←/→ ................ Hardpoint (hull, wings, engines, primary, secondary,
                         shields, utility, livery)
    ↑/↓ · Enter ........ Browse · buy/fit (credits) · R randomize (costs) · Esc finish
    Livery ............. Ship colors live here only (no Outfit paint row)
    Secondaries ........ B + hangar mode (key 5) for seekers/scatter/torp/mines
    Owned parts ........ Refit free after first purchase

    DOCKED STATION
    1–6 or ←/→ ......... Switch tabs (Status, Trade, Warehouse, Missions, Outfit, Undock)
    ↑/↓ ................ Select commodity / mission / upgrade (Outfit scrolls)
    − / + .............. Trade qty · wingman role · Hull Role / Career
    Enter .............. Buy / Accept / Upgrade / Undock
    F .................. Sell (Trade) / withdraw warehouse / shields (Status)
    Invest ............. Status tab, Enter (when hull is full) — permanent stake
    Warehouse .......... Freeport 7 only — rent bay, deposit/withdraw cargo

    STATION INVESTMENT
    Shareholder 5,000 cr · Partner +12,000 · Patron +28,000
    Better buy/sell rates at that station only; private berth on first stake.
    Repair discounts scale with tier. Saved with your pilot.

    FREEPORT 7 WAREHOUSE
    Rent 8,000 cr (not wanted · Police rep ≥ 0). Capacity 120 mass.
    Enter store from ship · F withdraw to ship. Arbitrage without a full hold.

    REPUTATION & WANTED
    Kill pirates ........ Law likes you; pirates dislike you
    Kill traders ........ Wanted heat up; pirates get friendlier
    Kill police/militia . Big heat spike — manhunt
    Clear warrants ...... Dock a Militia station → Outfit “Clear Wanted” or Status Enter
    Dirty pilots ........ Black-market docks open special stock (Umbra, dens, Night Market…)

    HULL ROLE / CAREER (Outfit — not hangar Hull)
    Hybrid Fighter ...... Balanced starter career
    Bulk Freighter ...... Huge hold, tough, slower guns (4500 cr cash or loan)
    Interceptor ......... Hard guns & speed, tiny hold (5200 cr)
    Mk upgrades ......... Kept when you buy or swap careers
    Hangar loadout ...... Resets to class preset — re-fit owned parts after swap
    Mines / chaff ....... Rack size scales by career

    GRAPHICS (1.0.31)
    Pure CoreGraphics — additive weapon glows, soft particles, colored starfield,
    modular ship detail, weather screen grade, faction dock chrome.

    SYSTEMS
    Frontier ........... Solara, Vesper, Ironreach, Cinder, Azurel,
                         Nyx, Helion, Drift, Kestrel, Umbra
    Outer sector ....... Voidreach (hidden wormhole from Nyx)

    TIP
    Systems are large — freelanes are the intended long-range transit.
    Steer around radiation belts when you can; HUD shows live weather rates.
    Older saves load safely (missing fields get defaults).
    After rebuilding, launch ~/Applications/Starlane.app (or swift run).
    """

}
