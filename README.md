# Starlane

**Version 1.0.26**

A Freelancer-style space adventure for macOS. Pilot across the frontier — trade, ride freelanes, race your own ghost, fight pirates, take contracts, chart anomalies, and outfit a ship that can survive Cinder and beyond.

See [CHANGELOG.md](CHANGELOG.md) for full release notes. In-app **Help → Starlane Help** and [docs/HELP.md](docs/HELP.md) cover controls and systems.

## Highlights

- **Large systems** — free flight is a long haul; **freelanes** are the fast path
- **Freelane time trials** — end-to-end races with personal bests and a gold **ghost** of your best lap
- **Stations** — trade, missions, outfitter, repairs, investment, Freeport 7 warehouse
- **Combat** — lasers, plasma, missiles, mines, countermeasures; hull classes change the feel
- **Contracts** — bounties (scan first), timed cargo, smuggling, escorts, freelane raids, surveys
- **Space weather** — nebulae, radiation, ion storms, dust, cryo, grav sheer, EM blackout
- **Exploration** — planets, wrecks, anomalies, lane mystery → Ancient Lane Core
- **Progression** — reputation/wanted, wingman roles, insurance, freighter loans, achievements
- **Saves** — 3 slots + autosave on dock in `~/Documents/Starlane/`

## What’s new in 1.0.26

- **Time trials** — enter a freelane at either **terminus** for an automatic race to the other end
- **Personal bests** — times and ghost paths save with your pilot
- **Ghost runner** — translucent gold ship of your best lap; beat it for the **Ghost Runner** achievement
- **HUD race strip** — live clock, PB delta (`▲` / `▼`), GHOST indicator
- **Lane Racer** — set PBs on 5 different freelane runs

Earlier recent releases: **space weather** (1.0.24–25), larger systems & freelane speed (1.0.23), exploration/mystery (1.0.22), wingmen/mines/raids (1.0.21), contracts/insurance/routes (1.0.20). Full history in the changelog.

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
| Fire | Space |
| Lasers / plasma | Q or 1 / 2 |
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
