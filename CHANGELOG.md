# Changelog

All notable changes to **Starlane** are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/). Versioning follows [Semantic Versioning](https://semver.org/).

---

## [1.0.26] — 2026-07-17

### Added
- **Freelane time trials** — enter a freelane at either terminus for an automatic end-to-end race
- **Personal bests** — times + ghost paths saved with your pilot
- **Ghost runner** — translucent gold ghost of your best lap; beat it for **Ghost Runner**
- **HUD race strip** — live time, PB delta, GHOST indicator
- Achievements: **Lane Racer** (5 PBs), **Ghost Runner** (beat your ghost)

---

## [1.0.25] — 2026-07-17

### Changed
- **Space weather polish** — stronger zone visibility (fills, borders, labels, particles) and much stronger in-zone gameplay effects
- **HUD weather strip** — live rates (e.g. shield damage/s, thrust %) without full-screen edge tint

### Fixed
- **Removed screen-edge weather vignette** — red/blue side bands no longer surround the playfield
- **Fullscreen cursor** — mouse pointer hidden while Starlane is key and full screen; restored on exit / Cmd-Tab

### Documentation
- README, in-app Help, and HELP.md brought up to date with 1.0.20–1.0.25 systems

---

## [1.0.24] — 2026-07-17

### Added
- **Environment zones** across every system — named nebulae, radiation belts, ion storms, dust clouds, cryo fields, grav sheer, EM blackouts
- **Gameplay effects** — damage, energy drain, thrust/turn penalties, scanner blackout, grav pull
- **Visuals** — radial fields, dust/ice motes, hazard rings; HUD weather strip; system map overlays

---

## [1.0.23] — 2026-07-17

### Fixed
- **Save load** — older pilots missing mine/chaff racks (and other post-1.0.20 fields) now load; defaults filled on restore

### Changed
- **Much larger systems** (~7× layout scale) — free flight across a system is a real haul (~45–80s gate-to-hub)
- **Freelanes are the fast path** — cruise speed raised (~3200); lanes re-ringed for long runs so rings stay dense
- NPC freelane traffic speeds raised to match expanded lanes

---

## [1.0.22] — 2026-07-17

### Added
- **Anomaly sites** — jump pockets, silent wreck fields, and **lane echoes** in Nyx / Umbra / Drift / Cinder (and Voidreach)
- **Lane mystery thread** — chart echoes in order (Nyx → Umbra → Drift) for a light multi-system story without killing the sandbox
- **Probe / survey missions** — plant a beacon (R near planet, wreck, or anomaly), dock to cash out
- **Ancient Lane Core** — mystery reward: **bypass offline freelane rings**; **L** triggers temporary freelane super-cruise

---

## [1.0.21] — 2026-07-17

### Added
- **Wingman loadouts** — hire **Gunner**, **Scout**, or **Freighter Tug** (−/+ on Outfit row); painted to match you; named callsigns; personal loss messages when they die
- **Freelane raid contracts** — pirate-career jobs (Umbra/Cinder/Nyx): ambush freighters on the lanes; law spawns and heat rises; dock to cash out
- **Proximity mines (J)** — arm delay, freelane drops are nastier; racks scale by hull (interceptor > hybrid > freighter)
- **Countermeasures (K)** — chaff breaks nearby enemy missile locks; freighters carry more chaff, interceptors hit harder with missiles

---

## [1.0.20] — 2026-07-17

### Added
- **Contracts with stakes** — timed live cargo (food/medical spoil), smuggling into a **hidden hold**, Umbra “no questions” jobs (militia heat if law scans you)
- **Scan / identify (hold I)** — faction, wanted flag, cargo manifest; **bounties only credit scanned kills**
- **Hull insurance** — Outfitter policy; non-Ironman death respawns at last dock for a fee (cargo written off)
- **Freighter loans** — finance a freighter early; auto payments on dock; miss twice → repo + heat
- **Trade routes** — Galaxy map **U** pins buy→sell route; HUD strip; auto-NAV next hop after jump; **U** in flight clears/re-pins
- **Faction home bases** — Kestrel/militia wingman discounts + defense retainers; Umbra pirate protection; **max heat** refused at law docks (black markets still open)

---

## [1.0.19] — 2026-07-16

### Added
- **Autopilot (hold H)** — faces NAV and cruises; drops on hostiles, freelane enter, or manual turn
- **Freelane route highlight** — gold ROUTE rings/beams toward your nav destination
- **Radio chatter** — nearby traders, patrols, pirates, Vael one-liners on a RADIO strip
- **Photo mode (Y / O)** — free camera (WASD), frozen world, −/+ speed, Esc to exit

---

## [1.0.18] — 2026-07-16

### Added
- **Freeport 7 warehouse bay** — rent for 8,000 cr (must be clean: not wanted, Police rep ≥ 0)
- **Warehouse tab** at Freeport 7: deposit (Enter) / withdraw (F) cargo by commodity
- Bay capacity **120 mass** — store goods between arbitrage legs without filling your ship
- Achievement: **Bay Lease**

---

## [1.0.17] — 2026-07-16

### Added
- **Station investment** — buy a stake at any dock (Status tab Enter when hull is sound)
- Three tiers: **Shareholder** (5k) → **Partner** (12k) → **Patron** (28k)
- Permanent **trade bonuses** at that station (cheaper buys / higher sells) + investor repair rates
- **Named private berth** on first stake; welcome message on dock
- Achievements: Stakeholder, Station Patron

---

## [1.0.16] — 2026-07-16

### Added
- **Vael frontier patrols** — aliens occasionally appear in normal systems (most often Nyx/Umbra/Cinder)
- Periodic scout packs + rare freelane Vael ambushes; NEWS when contacts enter the system

---

## [1.0.15] — 2026-07-16

### Added
- **Enemy missiles** — pirates, Vael, police, and militia can fire limited homing missiles
- Incoming-missile flash when a hostile locks you; capital ships hit harder
- Law missiles prefer pirate locks; combat ships have finite missile ammo racks

---

## [1.0.14] — 2026-07-16

### Added
- **Settings → Controls…** — full in-game control reference (flight, combat, nav, docked, menus)

---

## [1.0.13] — 2026-07-16

### Changed
- **Save location** — slots and autosave now live in **`~/Documents/Starlane/`**
- Existing saves under Application Support are **copied once** into Documents if the Documents folder has no matching file (nothing is deleted)

---

## [1.0.12] — 2026-07-16

### Added
- **Ship energy system** — lasers and shield recharge share a capacitor; engines are independent
- **Energy Plant upgrades** (Mk1–5) at Outfitter — higher capacity and faster energy regen
- **Plasma cannon** — switch with **Q** or **1**/**2**; slower fire, higher damage, high energy cost
- **Homing missiles** — **B** to fire; auto-lock hostiles within 520m; racks hold **10**
- **Missile reloads** — buy packs of 5 at any station Outfitter (450 cr)

### Changed
- HUD shows ENRG bar, weapon mode, missile count, and MSL LOCK when in range
- Shield regen pauses/slows when energy is depleted
- Help documents energy, plasma, and missiles

---

## [1.0.11] — 2026-07-16

### Added
- **Voidreach** — outer sector only reachable via a **hidden wormhole** in Nyx (far SW rim)
- **Unstable Rift / Return Rift** — wormhole gates (dim until scanned; purple on galaxy map once known)
- **Vael aliens** — skimmers & wardens, hostile AI, unique vector art, rich salvage
- **Alien bases** — Spire of Vael & Resonance Anchorage (Vael Collective) with heavy defenses
- **Purchasable alien tech** (outfitter at Vael docks only): Plasma Locus, Void Shroud, Gravitic Drive, Crystal Lattice, Phase Needle, Neural Tractor
- Achievements: **Beyond the Veil**, **First Contact**, **Alien Alloy**
- First chart of Voidreach pays **2000 cr**

### Changed
- Galaxy map hides Voidreach / wormhole link until the rift is discovered
- Mission board never auto-routes cargo into Voidreach
- Help documents the wormhole hunt and Vael sector

---

## [1.0.10] — 2026-07-16

### Added
- **Expanded system map** — press **Z** / **X**, Pause → System Map, or **click the mini map**
- Full-system chart with freelanes, stations, gates, planets, wrecks, and your ship
- **Destination list** — ↑↓ select; **Enter** sets travel destination and returns to flight
- **Click a station or gate** on the map to set it as your NAV destination
- Path preview line from you to the selected destination
- Planets/wrecks listed as landmarks (not travel targets)

### Changed
- Mini map footer: “Z expand · click”
- Pause menu includes System Map
- Help documents expanded map workflow

---

## [1.0.9] — 2026-07-16

### Added
- **In-system navigation** — waypoint system for stations, jump gates, escorts, and mission destinations
- **NAV panel** — range + port/starboard turn cue + heading dial (V/N cycle, C clear)
- **Compass strip** — stations and gates relative to your nose
- **Edge markers** — diamond + label when the nav target is off-screen
- **System map upgrades** — larger minimap, station/gate labels, player heading wedge, dashed nav line
- World labels: station range, gate → destination + range, planet names when visible
- Auto-nav on jump (mission dest or nearest station) and when accepting delivery/escort/scout jobs

### Changed
- Bottom control hint lists V/N nav and C clear
- Help text documents the nav suite

---

## [1.0.8] — 2026-07-16

### Added
- **Reputation / factions** — standing with Police, Militia, and Pirates (−100…100); pirate kills raise law rep, trader kills raise pirate rep
- **Wanted level** (0–5) — killing civilians or law ships adds heat; police/militia chase fugitives; HUD WANTED badge
- **Militia clearance** — pay a fine at Militia stations (Border Watch, Fort Kestrel, Wing Barracks…) to wipe warrants
- **Black-market stock** — dirty pilots unlock discounted weapons/luxury/scrap at Unaligned / black-market docks
- **Ship purchase & swap** — Hybrid Fighter (starter), Bulk Freighter (hold), Interceptor (guns) at Outfitter; Mk upgrades transfer; excess cargo jettisons
- **Trading UX** — galaxy map BUY LOW / SELL HIGH tags, multi-station route planner, rolling price history per dock
- **Escort / convoy missions** — protect a named hauler to another station; freelane ambushes; hauler rides jumps with you

### Changed
- Police/militia AI: hunt wanted players; high-rep clean pilots get wider pirate-hunting support
- Friendly pirate standing (≥30): raiders prefer freighters over you
- Outfitter rows: ship hulls + clear wanted; Status tab shows rep & heat
- Help / how-to-play updated for reputation, ships, escorts, trade tips

---

## [1.0.7] — 2026-07-16

### Added
- **Story campaign** (4 beats): Freelane License → First Bounty → Shadow Markets (Umbra) → Lane War
- **Pilot logbook** (Pause → Logbook): stats + 12 achievements
- **Ironman mode** from title menu — death wipes ironman autosave/slots; finish story for Ironman Ace
- HUD story objective line; IRONMAN badge when hardcore

### Changed
- Title menu: New Game / New Ironman / Continue
- Credits from missions, sales, salvage, discoveries feed lifetime log

---

## [1.0.6] — 2026-07-16

### Added
- **Cargo freelane traffic** — freighters lock rings and cruise lanes (slower than you); dump on pirate threat or disrupted rings
- **Soft traffic collisions** — freighters/NPCs (and you) gently push apart so lanes feel crowded
- Freelane spacing: trailing freighters slow when stacked on the same segment
- Labels show `· LANE` on freelane cargo ships

### Changed
- System spawn places more freighters already mid-lane for visible traffic

---

## [1.0.5] — 2026-07-16

### Added
- **3 manual save slots** — pick slot when saving or loading (title Continue, pause menu, ⌘S / ⌘L)
- **Autosave on dock** — silent flight-log write to a dedicated autosave file
- Load picker includes **Autosave** plus Slots 1–3 with system / credits / timestamp
- Legacy `save.json` migrates into Slot 1 (and autosave if empty)

### Changed
- Pause menu: Save Game / Load Game open slot pickers
- Help notes autosave and multi-slot saves

---

## [1.0.4] — 2026-07-16

### Added
- **Disrupted freelane rings** — pirates sabotage rings (red OFFLINE); travel dumps early; militia/police repair
- **Hireable wingman** — 1200 cr at dock (Status/Outfit); escorts player and engages hostiles
- **Pirate capital assaults** — rare capital + raiders hit a station; auto defense contract; big salvage
- **Freighter boarding** — cripple engines (~38% hull), approach and **F** to eject cargo pods (tractor loot)

### Changed
- Freighter combat supports non-lethal cargo theft before destruction
- Help text updated for combat freelane features

---

## [1.0.3] — 2026-07-16

### Added
- **Ship paint jobs** — 8 cosmetic liveries (Arctic free; others unlockable at outfitter)
- **Audio stingers** — distinct freelane enter/exit, station turret fire, salvage tractor lock
- **Galaxy map** (G) — all 10 systems, gate links, station list, last-known market prices after docking

### Changed
- Pause menu includes Galaxy Map
- Outfit tab includes paint cycle (− / +) and swatch preview

---

## [1.0.2] — 2026-07-16

### Added
- **Discovery bonuses** — first visit to a system, planet survey, or wreck find pays credits; planets/wrecks marked on the minimap
- **Wreck fields & derelicts** — salvage scrap with R/F; rare **blueprints** unlock permanent ship mods (lasers, afterburner, shields, hold, tractor, hull)
- **Dynamic economy** — large buys/sells and pirate kills shift station prices/stock; temporary gluts and shortages
- **News ticker** — HUD feed for arrivals, discoveries, market shifts, freelane raids, and tech recoveries

### Changed
- Status dock tab lists charted systems/planets/wrecks and installed blueprints
- Help text updated for exploration and salvage

---

## [1.0.1] — 2026-07-16

### Added
- **Ten star systems** with expanded layout: Solara, Vesper, Ironreach, Cinder, Azurel, Nyx, Helion, Drift, Kestrel, Umbra
- **Planets, moons, and system stars** with distinct colors, atmospheres, and orbits
- **Freelancer-style trade lanes** (manual enter with F; exit with S/F)
- **Pirate freelane hijack** — hostile fire or boarding range drops you off the lane instantly
- **Freelane ambushes** — pirates stage ahead on your cruise path
- **Station defenses** — turrets engage pirates; gold lasers; defense rings; faction-based strength
- **Salvage tractor** — credits/scrap canisters pull toward the ship within magnet range
- **Civilian cargo fleet** with distinct hulls: freighter, bulk hauler, tanker, container ship, ore barge, courier
- **Pirate gunship**, **police interceptor**, and **militia cutter** variants
- Detailed **vector ship art** (player white industrial fighter, faction hulls, stations with turrets)
- Design notes: `docs/IDEAS.txt` / `docs/IDEAS.md`

### Changed
- **Fuel removed** as a ship resource (Fuel Cells remain a trade commodity only)
- **Larger systems** (bounds ~4800–5400) and denser stations, gates, and asteroid fields
- **Continuous inertial flight** — softer drag, soft speed envelope, smoother camera, soft system edges
- Trade lanes no longer auto-enter when flying through rings
- More cargo traffic near stations and freelanes
- Help / README updated for freelanes, tractor, stations, and the full system list

### Fixed
- Crash when purchasing ship upgrades (Swift exclusivity violation on `inout` player fields)

---

## [1.0.0] — 2026-07-16

### Added
- Initial macOS release: freelane-style space adventure
- Space flight, laser combat, targeting
- Docking, commodity trade, missions, outfit upgrades
- Jump gates between systems
- Procedural music and SFX
- Save / load, pause, mute, full-screen window

---

[1.0.1]: #101---2026-07-16
[1.0.0]: #100---2026-07-16
