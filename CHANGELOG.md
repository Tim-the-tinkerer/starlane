# Changelog

All notable changes to **Starlane** are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/). Versioning follows [Semantic Versioning](https://semver.org/).

---

## [1.0.29] — 2026-07-19

### Changed
- **NEWS / RADIO ticker** — compact centered strip (sized to headline, max ~520px) instead of a full-width bar; long lines ellipsize
- **Documentation** — README, HELP.md, VOIDREACH.md, in-app Help, and AppInfo brought up to date for dens, weapons, saves, and HUD polish

### Fixed
- (carried from 1.0.28) Save load after pulse/rail weapon fields; Outfitter scroll; top HUD stacking

---

## [1.0.28] — 2026-07-19

### Added
- **Player weapons** — **Pulse Array** (rapid twin bolts) and **Rail Lance** (long-range heavy slug); **Q** cycles; **1–4** select
- **Faction hulls** with new art and loadouts:
  - Pirates: **Bomber** (missile racks + plasma)
  - Police: **Enforcer** (heavy rail cruiser)
  - Militia: **Frigate** (armored rail wing)
  - Vael: **Stalker** (pulse hunter)
- **Faction-colored bolts** — pirates red, police blue, militia green, Vael teal

### Fixed
- **Save loading** — older flight logs failed to decode after pulse/rail weapon stats were added; `ShipStats` now fills missing fields with defaults

---

## [1.0.27] — 2026-07-19

### Added
- **Enemy bases / pirate dens** across the rim:
  - **Bloodwake Den** (Umbra) — Pirate Clan capital
  - **Raider's Scar** (Cinder)
  - **Mute Corsair** (Nyx)
  - **Hullbreaker Yard** (Drift)
- **Hostile dens** — turrets fire on law and on clean pilots; garrison patrols + occasional capitals
- **Dock rules** — dens welcome dirty / high pirate rep / protection; refuse clean pilots
- **Den markets & jobs** — cheap guns, black-market stock, freelane raids, “Bleed the Badge” law bounties
- **Map / HUD** — dens mark red on minimap & system map; proximity warnings

### Fixed
- Outfitter list scroll keeps Weapons / top rows fully visible
- Top-center HUD stack (campaign, weather, compass) no longer overlaps

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

### Changed
- **Larger systems** (~7× world scale) — free flight is a long haul; freelanes matter
- Freelane cruise speeds tuned for expanded layouts

### Fixed
- **Save load** — older pilots missing mine/chaff racks (and other post-1.0.20 fields) now load; defaults filled on restore

---

## [1.0.22] — 2026-07-17

### Added
- **Anomalies** — jump pockets, silent fields, lane echoes
- **Lane mystery** — Nyx → Umbra → Drift → Ancient Lane Core (bypass offline freelane rings; **L** boost)
- **Survey missions** — plant beacons at planets, wrecks, anomalies

---

## [1.0.21] — 2026-07-17

### Added
- **Wingman roles** — Gunner, Scout, Freighter Tug (Outfit −/+)
- **Mines & countermeasures** — **J** drop mines, **K** chaff (racks scale by hull)
- **Freelane raids** — dirty contracts to hit freighters on lanes

---

## [1.0.20] — 2026-07-17

### Added
- **Timed cargo** and **smuggling** (hidden hold)
- **Insurance** and **freighter loans**
- **Trade route pin** (**U**)
- **Station investment** tiers
- **Freeport 7 warehouse**

---

## [1.0.19] — 2026-07-16 … [1.0.0] — 2026-07-16

Earlier releases: Voidreach / Vael tech, reputation & wanted, hull classes, paint jobs, scanner, capital raids, station defenses, ironman, three-slot saves + autosave, galaxy/system maps, freelanes, and core sandbox loop. See git history for full detail on 1.0.0–1.0.19.

---

[1.0.29]: #1029---2026-07-19
[1.0.28]: #1028---2026-07-19
[1.0.27]: #1027---2026-07-19
[1.0.1]: #101---2026-07-16
[1.0.0]: #100---2026-07-16
