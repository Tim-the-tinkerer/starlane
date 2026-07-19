# Starlane

**Version 1.0.26**

A Freelancer-style space adventure for macOS. Pilot across the frontier — trade, ride freelanes, fight pirates, take contracts, chart anomalies, and outfit a ship that can survive Cinder and beyond.

See [CHANGELOG.md](CHANGELOG.md) for full release notes. In-app **Help → Starlane Help** and [docs/HELP.md](docs/HELP.md) cover controls and systems.

## Highlights

- **Large systems** — free flight is a long haul; **freelanes** are the fast path (plus end-to-end **time trials** with ghost PBs)
- **Stations** — trade, missions, outfitter, repairs, investment, Freeport 7 warehouse
- **Combat** — lasers, plasma, missiles, mines, countermeasures; hull classes change the feel
- **Contracts** — bounties (scan first), timed cargo, smuggling, escorts, freelane raids, surveys
- **Space weather** — nebulae, radiation, ion storms, dust, cryo, grav sheer, EM blackout
- **Exploration** — planets, wrecks, anomalies, lane mystery → Ancient Lane Core
- **Progression** — reputation/wanted, wingman roles, insurance, freighter loans, achievements
- **Saves** — 3 slots + autosave on dock in `~/Documents/Starlane/`

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

## Controls (essentials)

| Action | Keys |
|--------|------|
| Fly | WASD / arrows |
| Fire | Space |
| Lasers / plasma | Q or 1 / 2 |
| Missile | B |
| Mine / chaff | J / K |
| Target | T / Tab |
| Scan | Hold I |
| Dock / jump / freelane | F or E |
| Exit freelane | Hold S |
| Nav / autopilot | V · C · hold H |
| System / galaxy map | Z · G |
| Photo mode | Y / O |
| Pause / mute | P · M |
| Save / load | ⌘S / ⌘L |

Full control list: **Settings → Controls…** or Help.

## Systems

**Frontier:** Solara, Vesper, Ironreach, Cinder, Azurel, Nyx, Helion, Drift, Kestrel, Umbra  

**Outer sector:** Voidreach (hidden wormhole from Nyx)

## Project layout

| Path | Purpose |
|------|---------|
| `Sources/Starlane/` | Game source (Swift / AppKit) |
| `docs/HELP.md` | Player help (also bundled in the app) |
| `docs/IDEAS.md` | Original feature checklist (shipped) |
| `docs/IDEAS_NEXT.md` | Further design ideas |
| `docs/VOIDREACH.md` | Outer sector notes |
| `CHANGELOG.md` | Version history |
| `build-app.sh` | Release build → `~/Applications/Starlane.app` |

## License / credit

Personal project — a Freelancer-inspired sandbox for macOS.
