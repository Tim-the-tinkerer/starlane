# Starlane

**Version 1.0.29**

A Freelancer-style space adventure for macOS. Pilot across the frontier — trade, ride freelanes, race your own ghost, fight pirates, raid dens, take contracts, chart anomalies, and outfit a ship that can survive Cinder and beyond.

See [CHANGELOG.md](CHANGELOG.md) for full release notes. In-app **Help → Starlane Help** and [docs/HELP.md](docs/HELP.md) cover controls and systems.

## Highlights

- **Large systems** — free flight is a long haul; **freelanes** are the fast path
- **Weapons** — lasers, plasma, pulse array, rail lance (**Q** / **1–4**)
- **Faction fleets** — pirate / police / militia / Vael hulls with distinct guns and colors
- **Enemy bases** — pirate dens with turrets, garrisons, den markets, and dirty jobs
- **Freelane time trials** — personal bests and a gold **ghost** of your best lap
- **Stations** — trade, missions, outfitter, repairs, investment, Freeport 7 warehouse
- **Combat** — missiles, mines, countermeasures; hull classes change the feel
- **Contracts** — bounties (scan first), timed cargo, smuggling, escorts, freelane raids, surveys
- **Space weather** — nebulae, radiation, ion storms, dust, cryo, grav sheer, EM blackout
- **Exploration** — planets, wrecks, anomalies, lane mystery → Ancient Lane Core
- **Progression** — reputation/wanted, wingman roles, insurance, freighter loans, achievements
- **Saves** — 3 slots + autosave on dock in `~/Documents/Starlane/`

## What’s new in 1.0.29

- **Compact NEWS / RADIO ticker** — centered, size-to-text (no full-width bar)
- **Docs refresh** — README, HELP, VOIDREACH, and in-app Help match dens, weapons, and HUD

**1.0.28** — Pulse Array, Rail Lance, faction Bomber / Enforcer / Frigate / Stalker  
**1.0.27** — Pirate dens (Bloodwake, Raider’s Scar, Mute Corsair, Hullbreaker)  
**1.0.26** — Freelane time trials & ghost PB  

Full history: [CHANGELOG.md](CHANGELOG.md).

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

## Controls (essentials)

| Action | Keys |
|--------|------|
| Fly | WASD / arrows |
| Fire primary | Space |
| Weapon select | **Q** cycle · **1** laser · **2** plasma · **3** pulse · **4** rail |
| Missile | B |
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
