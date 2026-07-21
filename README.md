# Starlane

**Version 1.0.31**

A Freelancer-style space adventure for macOS. Pilot across the frontier — trade, ride freelanes, race your own ghost, fight pirates, raid dens, take contracts, chart anomalies, and outfit a modular ship that can survive Cinder and beyond.

See [CHANGELOG.md](CHANGELOG.md) for full release notes. In-app **Help → Starlane Help** and [docs/HELP.md](docs/HELP.md) cover controls and systems.

## Highlights

- **Ship Hangar (Spacecraft Builder)** — modular hulls, wings, engines, weapons, shields, utility, livery
- **Outfit Mk amplifiers** — Gun / Drive / Shield / Power / Hold stack on hangar modules
- **Hull Role / Career** — Hybrid · Freighter · Interceptor (big cargo & combat tradeoffs)
- **Large systems** — free flight is a long haul; **freelanes** are the fast path
- **Hangar combat weapons** — Space primary · Q/1–4 owned guns · B secondary / missiles · **5** toggles B-mode
- **Faction fleets** — pirate / police / militia / Vael hulls with distinct guns and colors
- **Enemy bases** — pirate dens with turrets, garrisons, den markets, and dirty jobs
- **Graphics polish** — additive combat FX, thrust-linked engines, colored starfields, weather grade, dock chrome
- **Freelane time trials** — personal bests and a gold **ghost** of your best lap
- **Stations** — trade, missions, outfitter, repairs, investment, Freeport 7 warehouse
- **Combat** — hangar guns, classic missiles, mines, countermeasures
- **Contracts** — bounties (scan first), timed cargo, smuggling, escorts, freelane raids, surveys
- **Space weather** — nebulae, radiation, ion storms, dust, cryo, grav sheer, EM blackout
- **Exploration** — planets, wrecks, anomalies, lane mystery → Ancient Lane Core
- **Progression** — reputation/wanted, wingman roles, insurance, freighter loans, achievements
- **Saves** — 3 slots + autosave on dock in `~/Documents/Starlane/`

## What’s new in 1.0.31

- **Full visual pass** — projectile glows, soft particles, explosion flash, thrust-reactive engines, richer modular ship art, colored stars, weather screen grade, dock chrome
- **Outfit vs Hangar** — clear split: Outfit amps/ammo/services/career · Hangar modules & guns · B-mode classic missiles ↔ hangar secondary (**5**)
- **Hull Role / Career** labeling — Mk kept; re-fit hangar parts after career swap

**1.0.30** — Spacecraft Builder hangar · modular player art · hangar guns in combat  
**1.0.29** — Compact NEWS ticker · docs refresh  
**1.0.28** — Faction Bomber / Enforcer / Frigate / Stalker  

Full history: [CHANGELOG.md](CHANGELOG.md).

## Outfit vs Hangar

| Where | What you buy |
|-------|----------------|
| **Outfit** | Mk amplifiers (gun / drive / shield / power / cargo), repair, wingman, **Hull Role / Career**, fine, missiles, insurance, loan, protection, mines, chaff, **Ship Hangar** entry |
| **Ship Hangar** (docked only) | Hull frame, wings, engines, **primary gun**, **secondary**, shields, utility, **livery** |

- **Space** fires the hangar primary. **Q / 1–4** cycle owned hangar guns (Pulse Laser free).
- **B** fires classic missiles **or** hangar secondary; press **5** to toggle.
- Career swap keeps Mk levels but applies a class hangar preset — **re-fit owned parts** after.

## Ship Hangar

**Only while docked** (Outfit → Ship Hangar). Parts cost credits; owned parts re-equip free.

1. Dock → **Outfit** → **Ship Hangar**
2. **←/→** hardpoint · **↑/↓** browse · **Enter** buy/fit · **R** randomize · **Esc** finish
3. Your ship in space, ghost races, and the title screen use the hangar design

Standalone companion: `../spacecraft-builder` (same parts catalog & art).

## Freelane time trials

1. Approach either **end** of a freelane and press **F**
2. A **time trial** starts automatically toward the far terminus
3. Finish clean for a time; improve it to set a **PB** and record a **ghost**
4. Next run on the same lane/direction races that ghost

Early exit (**S**), pirate hijack, or ring dump **voids** the trial. Mid-lane entry is a normal freelane ride (no race).

## Build & run

```bash
cd starlane
chmod +x build-app.sh
./build-app.sh
open ~/Applications/Starlane.app
```

Or debug:

```bash
swift run
```

Requires **macOS 13+** and **Swift 5.9+**.

Launches in **full screen** by default; the mouse cursor is hidden while the game is focused in full screen (clicks still work).

**After code changes:** always run `./build-app.sh` (or `swift run`) so you are not on a stale `Starlane.app`.

## Controls (essentials)

| Action | Keys |
|--------|------|
| Fly | WASD / arrows |
| Fire primary | Space (hangar gun) |
| Switch hangar gun | **Q** · **1–4** (owned guns; free Pulse Laser only at start) |
| B-mode fire | **B** (classic missiles or hangar secondary) |
| Toggle B-mode | **5** |
| Mine / chaff | J / K |
| Target | T / Tab |
| Scan | Hold I |
| Dock / jump / freelane | F or E |
| Exit freelane | Hold S |
| Freelane boost | L (Ancient Lane Core) |
| Nav / autopilot | V · C · hold H |
| Pin trade route | U |
| System / galaxy map | Z · G |
| Photo mode | Y / O |
| Pause / mute | P · M |
| Save / load | ⌘S / ⌘L |

Full control list: **Settings → Controls…** or **Help → Starlane Help**.

## Systems

**Frontier:** Solara, Vesper, Ironreach, Cinder, Azurel, Nyx, Helion, Drift, Kestrel, Umbra  

**Outer sector:** Voidreach (hidden wormhole from Nyx) — see [docs/VOIDREACH.md](docs/VOIDREACH.md)

**Pirate dens (red on map):** Bloodwake Den (Umbra), Raider’s Scar (Cinder), Mute Corsair (Nyx), Hullbreaker Yard (Drift)

## Project layout

| Path | Purpose |
|------|---------|
| `Sources/Starlane/` | Game source (Swift / AppKit) |
| `docs/HELP.md` | Player help (mirrored in-app) |
| `docs/VOIDREACH.md` | Outer sector notes |
| `CHANGELOG.md` | Version history |
| `AppInfo.plist` | Bundle version (`CFBundleShortVersionString`) |
| `build-app.sh` | Release build → `~/Applications/Starlane.app` |

## License / credit

Personal project — a Freelancer-inspired sandbox for macOS.
