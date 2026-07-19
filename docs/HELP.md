# Starlane Help

**Version 1.0.29**

A Freelancer-style space adventure — trade, fight, dock, and freelane across the frontier.

## Controls

| Action | Keys |
|--------|------|
| Turn | A/D or ←/→ |
| Thrust / Brake | W/S or ↑/↓ |
| Fire primary | Space (laser / plasma / pulse / rail — uses energy) |
| Switch weapon | **Q** cycle · **1** laser · **2** plasma · **3** pulse · **4** rail |
| Fire missile | B (auto-lock hostiles within 520m) |
| Target | T or Tab |
| Scan / identify | Hold **I** (in range) — cargo, faction, wanted |
| Drop mine | **J** |
| Countermeasures | **K** (break missile locks) |
| Freelane boost | **L** (Ancient Lane Core) |
| Nav waypoint | V or N |
| Clear nav | C |
| Autopilot | Hold **H** (toward NAV; drops on hostiles / freelane / steer) |
| System map | Z or X (click destination; Enter to travel) |
| Galaxy map | G |
| Photo / free camera | Y or O (WASD · −/+ speed · Esc exit) |
| Dock / Jump | F or E (near station or gate) |
| Trade lane | F near freelane ring (manual only) |
| Exit trade lane | Hold S (or F while cruising) |
| Pin trade route | **U** (Galaxy map sell station, or clear in flight) |
| Survey / anomaly | **R** or **F** near target |
| Mine asteroid / salvage | R (or F near rock / wreck) |
| Pause | P or Escape |
| Mute | M |
| Save / Load | ⌘S / ⌘L (3 slots + autosave) |
| New game | ⌘N |

**Fullscreen:** the mouse cursor is hidden while Starlane is focused in full screen (clicks still work).

## Stations

When docked, use **1–6** or **←/→** to switch tabs (Warehouse only at Freeport 7):

1. **Status** — ship, cargo, hidden hold, insurance/loan; repair / invest (Enter when hull full)
2. **Trade** — buy (Enter) / sell (F); −/+ quantity
3. **Warehouse** — Freeport 7 only — deposit (Enter) / withdraw (F)
4. **Missions** — accept and turn in contracts
5. **Outfit** — upgrades, paints, wingman roles, hulls, missiles, mines, chaff, insurance, loan, protection (scrollable list)
6. **Undock**

## Weapons

| Mode | Key | Role |
|------|-----|------|
| **Lasers** | 1 | Balanced bolts |
| **Plasma** | 2 | Slow, hard hit, more energy |
| **Pulse Array** | 3 | Twin rapid bolts, cheap energy |
| **Rail Lance** | 4 | Long-range heavy slug |

**Q** cycles all four. Weapon Mk upgrades improve every mode. Interceptors favor rate of fire; freighters hit softer.

### Faction ships you'll meet

| Faction | Hulls | Guns |
|---------|-------|------|
| **Pirates** | Raider, Gunship, **Bomber** | Red lasers / plasma; bombers rack missiles |
| **Police** | Patrol, Interceptor, **Enforcer** | Blue lasers / pulse; enforcers rail |
| **Militia** | Cutter, **Frigate** | Green bolts / rail frigate |
| **Vael** | Skimmer, Stalker, Warden | Teal plasma / pulse stalkers |

## Contracts & scan

- **⏱ Live cargo** — food/medical timed runs; late = spoil + fail
- **🔒 Smuggle** — contraband in the **hidden hold**; law scan seizes goods + militia heat
- **Bounties** — hold **I** first; unscanned kills do not pay
- **Freelane raids** — dirty docks / dens; hit freighters on lanes; law responds
- **Survey probes** — plant beacon at planet/wreck/anomaly (R), dock to report
- **Insurance** — Outfitter; death respawns at last dock (fee, cargo lost). Not on Ironman
- **Loan** — finance a freighter; 400 cr per dock or face repo

## Space weather

Colored regions in open space (also on the system map). HUD strip shows active effects (no full-screen edge tint).

| Zone | Effect |
|------|--------|
| **Nebula** | Sensors degraded |
| **Radiation** | Continuous shield/hull damage — transit quickly |
| **Ion storm** | Energy drain · slower weapons |
| **Dust cloud** | Thrust & top speed reduced |
| **Cryo field** | Turn rate reduced |
| **Grav sheer** | Pulls your vector off course |
| **EM blackout** | Scanners offline |

Freelanes still work inside weather, but radiation and ion storms still hurt. Prefer lanes or detours around red belts.

## Exploration & mystery

- **Anomalies** — jump pockets, silent fields, lane echoes (Nyx / Umbra / Drift / Cinder…)
- **Lane mystery** — chart echoes Nyx → Umbra → Drift → **Ancient Lane Core** (bypass offline freelane rings; **L** boost)
- **Wrecks & blueprints** — salvage scrap and ship mods
- **Voidreach** — outer sector via hidden wormhole in Nyx (see [VOIDREACH.md](VOIDREACH.md))

## Wingmen & hulls

- Outfit **−/+** on wingman row: **Gunner**, **Scout**, **Freighter Tug** (painted like you)
- Hulls: Hybrid · Freighter · Interceptor (mines/chaff racks and missile punch scale by class)

## Faction notes

- **Kestrel / Militia** — wingman discounts, defense retainers when rep is high
- **Umbra** — black market stock when dirty; pirate protection for a fee
- **Pirate dens** — red enemy bases on the map
  - **Bloodwake Den** (Umbra), **Raider’s Scar** (Cinder), **Mute Corsair** (Nyx), **Hullbreaker Yard** (Drift)
  - Turrets fire on law and on clean pilots
  - Dock if dirty, pirate rep ≥ 15, or under protection
  - Cheap weapons, den missions (raids, bleed the badge)
- **Max wanted** — law docks refuse; use Umbra / dens / black markets

## HUD

- **Top center** — campaign / missions, weather, race timer, compass (stacked, no overlap)
- **Bottom** — compact centered **NEWS** / **RADIO** tickers (not full-width); control hints
- **Flash toasts** — lower band so they don’t cover the story strip

## Gameplay loop

1. Buy low, sell high (pin routes with **U** on the galaxy map).
2. **Use freelanes** — systems are large; free flight is slow. **F** at a ring.
   - **Time trials:** enter a freelane at either **end** for an automatic race to the other end. Beat your PB; race a gold **ghost** of your best run. Early exit / hijack voids the trial.
3. Mine ore, scan and fight, take contracts.
4. Chart systems, planets, wrecks, and anomalies.
5. Watch NEWS for markets, raids, and discoveries.
6. Outfit for riskier routes (Cinder, Umbra, dens, Voidreach).

## Systems

**Frontier (10):** Solara · Vesper · Ironreach · Cinder · Azurel · Nyx · Helion · Drift · Kestrel · Umbra  

**Outer:** Voidreach (wormhole from Nyx)

## Saves

- **3 manual slots** + **autosave on every dock**
- Folder: `~/Documents/Starlane/`
- Older saves load with safe defaults for new fields (mines, investments, pulse/rail stats, etc.)

## Story (light campaign)

1. Freelane License — ride a freelane, dock Freeport 7  
2. First Bounty — kill 2 pirates, dock any station  
3. Shadow Markets — jump to Umbra and dock  
4. Lane War — destroy a capital (or finish station defense)  

**Ironman** — death wipes ironman saves; finish story for Ironman Ace.
