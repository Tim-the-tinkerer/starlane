import AppKit
import CoreGraphics
import simd

@MainActor
enum Renderer {
    static func draw(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        let w = bounds.width
        let h = bounds.height

        // Background
        Theme.void.setFill()
        ctx.fill(bounds)

        switch engine.phase {
        case .title:
            drawStars(ctx: ctx, bounds: bounds, camera: .zero, time: engine.time, parallax: 1)
            drawTitle(ctx: ctx, bounds: bounds, engine: engine)
        case .howToPlay:
            drawStars(ctx: ctx, bounds: bounds, camera: .zero, time: engine.time, parallax: 1)
            drawHowToPlay(ctx: ctx, bounds: bounds)
        case .settings:
            drawStars(ctx: ctx, bounds: bounds, camera: .zero, time: engine.time, parallax: 1)
            drawSettings(ctx: ctx, bounds: bounds, engine: engine)
        case .dead:
            drawWorld(ctx: ctx, bounds: bounds, engine: engine)
            drawDeath(ctx: ctx, bounds: bounds, engine: engine)
        case .paused:
            drawWorld(ctx: ctx, bounds: bounds, engine: engine)
            if engine.dockedStationID != nil {
                drawStationUI(ctx: ctx, bounds: bounds, engine: engine, dimmed: true)
            }
            drawPause(ctx: ctx, bounds: bounds, engine: engine)
        case .docked:
            drawWorld(ctx: ctx, bounds: bounds, engine: engine)
            drawStationUI(ctx: ctx, bounds: bounds, engine: engine, dimmed: false)
        case .playing:
            drawWorld(ctx: ctx, bounds: bounds, engine: engine)
            drawHUD(ctx: ctx, bounds: bounds, engine: engine)
        case .photo:
            drawWorld(ctx: ctx, bounds: bounds, engine: engine)
            drawPhotoOverlay(ctx: ctx, bounds: bounds, engine: engine)
        case .galaxyMap:
            drawStars(ctx: ctx, bounds: bounds, camera: .zero, time: engine.time, parallax: 1)
            drawGalaxyMap(ctx: ctx, bounds: bounds, engine: engine)
        case .systemMap:
            drawStars(ctx: ctx, bounds: bounds, camera: .zero, time: engine.time, parallax: 0.5)
            drawSystemMap(ctx: ctx, bounds: bounds, engine: engine)
        case .saveSlots:
            drawStars(ctx: ctx, bounds: bounds, camera: .zero, time: engine.time, parallax: 1)
            drawSlotPicker(ctx: ctx, bounds: bounds, engine: engine, loading: false)
        case .loadSlots:
            drawStars(ctx: ctx, bounds: bounds, camera: .zero, time: engine.time, parallax: 1)
            drawSlotPicker(ctx: ctx, bounds: bounds, engine: engine, loading: true)
        case .logbook:
            drawStars(ctx: ctx, bounds: bounds, camera: .zero, time: engine.time, parallax: 1)
            drawLogbook(ctx: ctx, bounds: bounds, engine: engine)
        case .hangar:
            drawStars(ctx: ctx, bounds: bounds, camera: .zero, time: engine.time, parallax: 1)
            drawHangar(ctx: ctx, bounds: bounds, engine: engine)
        }

        if !engine.message.isEmpty,
           engine.phase == .playing || engine.phase == .docked || engine.phase == .systemMap || engine.phase == .photo {
            drawMessage(ctx: ctx, bounds: bounds, text: engine.message)
        }
        if !engine.menuFlash.isEmpty {
            // Same lower-toast band as gameplay messages (not top HUD)
            drawCenteredText(engine.menuFlash, in: CGRect(x: 0, y: 70, width: w, height: 30),
                             font: .systemFont(ofSize: 14, weight: .medium), color: Theme.gold)
        }

        _ = h
    }

    // MARK: - World

    private static func drawWorld(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        let cam = engine.camera
        drawStars(ctx: ctx, bounds: bounds, camera: cam, time: engine.time, parallax: 1)
        drawNebula(ctx: ctx, bounds: bounds, engine: engine)

        let sys = engine.currentSystem

        // System star (background celestial)
        if let star = sys.star {
            let p = worldToScreen(star.position, camera: cam, bounds: bounds)
            drawSystemStar(ctx: ctx, at: p, star: star, time: engine.time)
        }

        // Planets & moons (behind stations / ships)
        for planet in sys.planets {
            let p = worldToScreen(planet.position, camera: cam, bounds: bounds)
            drawPlanet(ctx: ctx, at: p, planet: planet, time: engine.time)
            for moon in planet.moons {
                let mp = moon.position(around: planet.position, time: engine.time)
                let sp = worldToScreen(mp, camera: cam, bounds: bounds)
                drawMoon(ctx: ctx, at: sp, moon: moon, time: engine.time)
            }
        }

        // Trade lanes (rings + beams)
        let navPath = engine.phase == .playing || engine.phase == .photo ? engine.freelaneNavPath() : nil
        for lane in sys.tradeLanes {
            drawTradeLane(ctx: ctx, lane: lane, camera: cam, bounds: bounds, time: engine.time,
                          activeID: engine.onTradeLane ? engine.tradeLaneID : nil,
                          navPath: navPath)
        }

        // Gates / wormholes
        for gate in sys.gates {
            let p = worldToScreen(gate.position, camera: cam, bounds: bounds)
            let isNav = {
                if case .gate(let id) = engine.navWaypoint { return id == gate.id }
                return false
            }()
            let d = distance(gate.position, engine.player.position)
            let discovered = !gate.isWormhole || engine.player.discoveredWormholes.contains(gate.wormholeKey)
            let label: String
            if gate.isWormhole {
                if discovered {
                    label = "WORMHOLE \(gate.name) → \(gate.destinationSystem)  \(GameEngine.formatNavDistance(d))"
                } else if d < gate.discoveryRadius + 200 {
                    label = "??? spatial anomaly  \(GameEngine.formatNavDistance(d))"
                } else {
                    label = ""
                }
            } else {
                label = "\(gate.name) → \(gate.destinationSystem)  \(GameEngine.formatNavDistance(d))"
            }
            drawGate(ctx: ctx, at: p, radius: gate.radius, name: label, time: engine.time,
                     highlight: isNav || (gate.isWormhole && discovered),
                     wormhole: gate.isWormhole, dim: gate.isWormhole && !discovered)
        }

        // Asteroids
        for ast in sys.asteroids {
            let p = worldToScreen(ast.position, camera: cam, bounds: bounds)
            drawAsteroid(ctx: ctx, at: p, radius: ast.radius, angle: ast.angle)
        }

        // Derelicts / wreck fields
        for wreck in sys.wrecks {
            let p = worldToScreen(wreck.position, camera: cam, bounds: bounds)
            let known = engine.player.discoveredWrecks.contains("\(engine.currentSystemName)/\(wreck.name)")
            drawWreck(ctx: ctx, at: p, wreck: wreck, discovered: known, time: engine.time)
        }

        // Anomaly sites
        for a in sys.anomalies {
            let p = worldToScreen(a.position, camera: cam, bounds: bounds)
            let key = "\(engine.currentSystemName)/\(a.name)"
            let known = engine.player.anomalyLog.contains(key)
            let near = distance(a.position, engine.player.position) < a.discoveryRadius + 500
            guard known || near else { continue }
            drawAnomaly(ctx: ctx, at: p, anomaly: a, known: known, time: engine.time)
        }

        // Stations
        for st in sys.stations {
            let p = worldToScreen(st.position, camera: cam, bounds: bounds)
            let isNav = {
                if case .station(let id) = engine.navWaypoint { return id == st.id }
                if case .missionStation(let name) = engine.navWaypoint { return name == st.name }
                return false
            }()
            let densEngaged = st.isEnemyBase && (
                engine.npcs.contains {
                    ($0.faction == .police || $0.faction == .militia)
                        && distance($0.position, st.position) < st.defenseRange
                }
                || distance(engine.player.position, st.position) < st.defenseRange
            )
            let friendlyEngaged = !st.isEnemyBase && engine.npcs.contains {
                $0.isHostile && distance($0.position, st.position) < st.defenseRange
            }
            ShipArt.drawStation(
                ctx: ctx, at: p, radius: CGFloat(st.radius),
                time: engine.time, name: st.name, faction: st.faction,
                turretAim: st.turretAim,
                defenseRange: st.defenseRange,
                showDefenseRing: densEngaged || friendlyEngaged,
                isEnemyBase: st.isEnemyBase
            )
            // Range under station name (ShipArt already draws name/faction)
            let onScreen = p.x > -40 && p.x < bounds.width + 40 && p.y > -40 && p.y < bounds.height + 40
            if onScreen {
                let d = distance(st.position, engine.player.position)
                let range = GameEngine.formatNavDistance(d)
                let col = isNav ? Theme.gold : Theme.textMuted
                drawText(isNav ? "▸ NAV  \(range)" : range,
                         at: CGPoint(x: p.x, y: p.y - CGFloat(st.radius) - 44),
                         font: .monospacedDigitSystemFont(ofSize: isNav ? 11 : 10, weight: isNav ? .bold : .regular),
                         color: col, align: .center)
                if isNav {
                    ctx.setStrokeColor(Theme.gold.withAlphaComponent(0.7).cgColor)
                    ctx.setLineWidth(2)
                    let br = CGFloat(st.radius) + 22
                    ctx.strokeEllipse(in: CGRect(x: p.x - br, y: p.y - br, width: br * 2, height: br * 2))
                }
            }
        }

        // Planets — name + range when visible
        for planet in sys.planets {
            let p = worldToScreen(planet.position, camera: cam, bounds: bounds)
            let onScreen = p.x > -60 && p.x < bounds.width + 60 && p.y > -60 && p.y < bounds.height + 60
            guard onScreen else { continue }
            let d = distance(planet.position, engine.player.position)
            let known = engine.player.discoveredPlanets.contains("\(engine.currentSystemName)/\(planet.name)")
            drawText("\(planet.name)\(known ? "" : " ?")  \(GameEngine.formatNavDistance(d))",
                     at: CGPoint(x: p.x, y: p.y - CGFloat(planet.radius) - 10),
                     font: .systemFont(ofSize: 10, weight: .medium),
                     color: Theme.textSecondary.withAlphaComponent(known ? 0.95 : 0.55), align: .center)
        }

        // Loot
        for drop in engine.loot {
            let p = worldToScreen(drop.position, camera: cam, bounds: bounds)
            let playerScreen = worldToScreen(engine.player.position, camera: cam, bounds: bounds)
            let worldDist = distance(drop.position, engine.player.position)
            let magnetRange = (200 + Float(engine.player.cargoLevel - 1) * 35) * engine.player.tractorRangeBonus
            drawLoot(
                ctx: ctx, at: p, playerScreen: playerScreen,
                magnetizing: worldDist < magnetRange,
                phase: drop.phase, time: engine.time
            )
        }

        // NPCs
        for ship in engine.npcs {
            let p = worldToScreen(ship.position, camera: cam, bounds: bounds)
            let targeted = ship.id == engine.targetID
            var label = ship.name
            if ship.isWingman {
                let role = ship.wingmanRole?.shortName ?? "WING"
                label = "\(ship.name) · \(role)"
            }
            if ship.enginesDisabled { label = "\(ship.name) [DISABLED]" }
            if ship.isCapital { label = "⚠ \(ship.name)" }
            if ship.onTradeLane, ship.isCargo { label = "\(ship.name) · LANE" }
            let wingPaint = ship.isWingman ? (ship.wingmanPaint ?? .militiaOlive) : nil
            let npcThrust = !ship.enginesDisabled && simd_length(ship.velocity) > 40
            drawShip(
                ctx: ctx, at: p, angle: ship.angle,
                style: .from(hullType: ship.hullType),
                accent: wingPaint?.accent ?? hullColor(ship),
                radius: ship.isCapital ? ship.radius * 1.15 : ship.radius,
                shieldFrac: ship.shield / max(1, ship.maxShield),
                hullFrac: ship.hull / max(1, ship.maxHull),
                targeted: targeted || ship.isCapital,
                name: label,
                time: engine.time,
                paint: wingPaint ?? .arctic,
                thrustActive: npcThrust
            )
            if ship.enginesDisabled {
                ctx.setStrokeColor(Theme.warning.cgColor)
                ctx.setLineWidth(1.5)
                let tr = CGFloat(ship.radius + 18)
                ctx.setLineDash(phase: 0, lengths: [4, 3])
                ctx.strokeEllipse(in: CGRect(x: p.x - tr, y: p.y - tr, width: tr * 2, height: tr * 2))
                ctx.setLineDash(phase: 0, lengths: [])
            }
        }

        // Freelane race ghost (previous best)
        if engine.phase == .playing, engine.raceActive, let ghost = engine.raceGhostPose() {
            let gp = worldToScreen(ghost.position, camera: cam, bounds: bounds)
            // Ghost silhouette — translucent
            ctx.saveGState()
            ctx.setAlpha(0.45)
            drawShip(
                ctx: ctx, at: gp, angle: ghost.angle,
                style: Self.playerArtStyle(engine.player.shipClass),
                accent: Theme.gold,
                radius: engine.player.shipClass == .freighter ? 20 : 16,
                shieldFrac: 0,
                hullFrac: 1,
                targeted: false,
                name: "GHOST",
                time: engine.time,
                paint: .solarGold,
                modularDesign: engine.player.shipDesign,
                isPlayer: true
            )
            ctx.restoreGState()
            // Ghost trail ring
            ctx.setStrokeColor(Theme.gold.withAlphaComponent(0.5).cgColor)
            ctx.setLineWidth(1.5)
            ctx.setLineDash(phase: CGFloat(engine.time * 8), lengths: [4, 4])
            ctx.strokeEllipse(in: CGRect(x: gp.x - 22, y: gp.y - 22, width: 44, height: 44))
            ctx.setLineDash(phase: 0, lengths: [])
        }

        // Player
        if engine.phase != .dead {
            let p = worldToScreen(engine.player.position, camera: cam, bounds: bounds)
            if engine.hurtFlash > 0 {
                ctx.setFillColor(Theme.danger.withAlphaComponent(0.15).cgColor)
                ctx.fill(bounds)
            }
            drawShip(
                ctx: ctx, at: p, angle: engine.player.angle,
                style: Self.playerArtStyle(engine.player.shipClass),
                accent: engine.player.paintJob.accent,
                radius: engine.player.shipClass == .freighter ? 22 : 18,
                shieldFrac: engine.player.shield / max(1, engine.player.stats.maxShield),
                hullFrac: engine.player.hull / max(1, engine.player.stats.maxHull),
                targeted: false,
                name: nil,
                time: engine.time,
                paint: engine.player.paintJob,
                modularDesign: engine.player.shipDesign,
                isPlayer: true,
                thrustActive: engine.isPlayerThrusting
            )
        }

        // Proximity mines
        for mine in engine.spaceMines {
            let p = worldToScreen(mine.position, camera: cam, bounds: bounds)
            let armed = mine.armTimer <= 0
            let pulse = 0.55 + 0.35 * sin(engine.time * (armed ? 8 : 3))
            let col = (armed ? Theme.danger : Theme.warning).withAlphaComponent(CGFloat(pulse))
            ctx.setStrokeColor(col.cgColor)
            ctx.setLineWidth(armed ? 2.0 : 1.2)
            let r = CGFloat(mine.radius * 0.35)
            ctx.strokeEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            ctx.setFillColor(col.cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6))
            if !armed {
                drawText("ARM", at: CGPoint(x: p.x, y: p.y + r + 4),
                         font: .systemFont(ofSize: 8, weight: .bold), color: Theme.warning, align: .center)
            }
        }

        // Projectiles (glow + kind-specific cores)
        for proj in engine.projectiles {
            let p = worldToScreen(proj.position, camera: cam, bounds: bounds)
            let col = projectileColor(proj, engine: engine)
            drawProjectile(ctx: ctx, at: p, proj: proj, color: col)
        }

        // Particles (additive soft cores)
        ctx.saveGState()
        ctx.setBlendMode(.plusLighter)
        for part in engine.particles {
            let p = worldToScreen(part.position, camera: cam, bounds: bounds)
            drawParticle(ctx: ctx, at: p, part: part)
        }
        ctx.restoreGState()

        // Soft weather grade (playing only — under HUD)
        if engine.phase == .playing || engine.phase == .photo {
            drawWeatherGrade(ctx: ctx, bounds: bounds, engine: engine)
        }

        // Range prompts
        if engine.phase == .playing {
            drawProximityHints(ctx: ctx, bounds: bounds, engine: engine)
        }
    }

    private static func projectileColor(_ proj: Projectile, engine: GameEngine) -> NSColor {
        if proj.source == .station { return Theme.gold }
        if proj.source == .enemy {
            if let owner = engine.npcs.first(where: { $0.id == proj.ownerID }) {
                switch owner.faction {
                case .pirate: return Theme.enemyLaser
                case .police: return Theme.police
                case .militia: return Theme.militia
                case .alien: return Theme.alien
                case .trader: return Theme.trader
                }
            }
            switch proj.kind {
            case .plasma: return Theme.plasma
            case .pulse: return Theme.pulse
            case .rail: return Theme.rail
            default: return Theme.enemyLaser
            }
        }
        switch proj.kind {
        case .laser: return Theme.laser
        case .plasma: return Theme.plasma
        case .pulse: return Theme.pulse
        case .rail: return Theme.rail
        case .missile: return Theme.missile
        case .mine: return Theme.danger
        }
    }

    private static func drawProjectile(ctx: CGContext, at p: CGPoint, proj: Projectile, color: NSColor) {
        let dir = normalizeSafe(proj.velocity)
        let width: CGFloat
        let len: Float
        let glowR: CGFloat
        switch proj.kind {
        case .missile: width = 3.2; len = 11; glowR = 10
        case .plasma: width = 4.2; len = 10; glowR = 12
        case .rail: width = 2.4; len = 18; glowR = 9
        case .pulse: width = 2.0; len = 5; glowR = 7
        case .mine: width = 2.0; len = 4; glowR = 6
        case .laser: width = proj.source == .station ? 3.0 : 2.4; len = proj.source == .station ? 10 : 7; glowR = 8
        }
        let dx = CGFloat(dir.x * len)
        let dy = CGFloat(dir.y * len)

        // Soft additive glow
        ctx.saveGState()
        ctx.setBlendMode(.plusLighter)
        ctx.setFillColor(color.withAlphaComponent(0.22).cgColor)
        ctx.fillEllipse(in: CGRect(x: p.x - glowR, y: p.y - glowR, width: glowR * 2, height: glowR * 2))
        ctx.setFillColor(color.withAlphaComponent(0.12).cgColor)
        let outer = glowR * 1.55
        ctx.fillEllipse(in: CGRect(x: p.x - outer, y: p.y - outer, width: outer * 2, height: outer * 2))

        switch proj.kind {
        case .missile:
            // Exhaust streak
            let ex = CGFloat(dir.x * 14)
            let ey = CGFloat(dir.y * 14)
            ctx.setStrokeColor(color.withAlphaComponent(0.45).cgColor)
            ctx.setLineWidth(2.5)
            ctx.move(to: CGPoint(x: p.x - ex, y: p.y - ey))
            ctx.addLine(to: CGPoint(x: p.x - dx * 0.2, y: p.y - dy * 0.2))
            ctx.strokePath()
        case .plasma:
            ctx.setFillColor(color.withAlphaComponent(0.35).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14))
        case .rail:
            ctx.setStrokeColor(color.withAlphaComponent(0.35).cgColor)
            ctx.setLineWidth(5)
            ctx.move(to: CGPoint(x: p.x - dx * 1.1, y: p.y - dy * 1.1))
            ctx.addLine(to: CGPoint(x: p.x + dx * 1.1, y: p.y + dy * 1.1))
            ctx.strokePath()
        default:
            break
        }
        ctx.restoreGState()

        // Core bolt
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: p.x - dx, y: p.y - dy))
        ctx.addLine(to: CGPoint(x: p.x + dx, y: p.y + dy))
        ctx.strokePath()

        // Bright tip / body
        switch proj.kind {
        case .missile:
            // Diamond body
            let px = CGFloat(dir.x), py = CGFloat(dir.y)
            let ox = -py * 3.5, oy = px * 3.5
            let path = CGMutablePath()
            path.move(to: CGPoint(x: p.x + dx * 0.9, y: p.y + dy * 0.9))
            path.addLine(to: CGPoint(x: p.x + ox, y: p.y + oy))
            path.addLine(to: CGPoint(x: p.x - dx * 0.6, y: p.y - dy * 0.6))
            path.addLine(to: CGPoint(x: p.x - ox, y: p.y - oy))
            path.closeSubpath()
            ctx.setFillColor(color.cgColor)
            ctx.addPath(path)
            ctx.fillPath()
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.55).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3))
        case .plasma:
            ctx.setFillColor(color.withAlphaComponent(0.95).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.5).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 1.8, y: p.y - 1.8, width: 3.6, height: 3.6))
        case .pulse:
            for i in 0..<3 {
                let t = CGFloat(i - 1) * 2.2
                ctx.setFillColor(color.withAlphaComponent(0.7 - CGFloat(i) * 0.15).cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x + CGFloat(dir.x) * t - 1.6,
                                           y: p.y + CGFloat(dir.y) * t - 1.6, width: 3.2, height: 3.2))
            }
        case .rail:
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x + dx * 0.85 - 2, y: p.y + dy * 0.85 - 2, width: 4, height: 4))
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.55).cgColor)
            ctx.setLineWidth(1.2)
            ctx.move(to: CGPoint(x: p.x - dx, y: p.y - dy))
            ctx.addLine(to: CGPoint(x: p.x + dx, y: p.y + dy))
            ctx.strokePath()
        default:
            let s: CGFloat = proj.source == .station ? 3.5 : 2.4
            ctx.setFillColor(color.withAlphaComponent(0.95).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - s / 2, y: p.y - s / 2, width: s, height: s))
            ctx.setFillColor(NSColor.white.withAlphaComponent(0.45).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 1, y: p.y - 1, width: 2, height: 2))
        }
    }

    private static func drawParticle(ctx: CGContext, at p: CGPoint, part: Particle) {
        let life = max(0, part.life / max(0.001, part.maxLife))
        // Slight inflate as particle dies for explosion “pop”
        let inflate = 1.0 + (1.0 - life) * 0.35
        let s = CGFloat(part.size) * CGFloat(life) * CGFloat(inflate)
        guard s > 0.3 else { return }
        let r = CGFloat(part.color.0), g = CGFloat(part.color.1), b = CGFloat(part.color.2)
        // Outer soft
        ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 0.22 * CGFloat(life)))
        let outer = s * 1.8
        ctx.fillEllipse(in: CGRect(x: p.x - outer / 2, y: p.y - outer / 2, width: outer, height: outer))
        // Core
        ctx.setFillColor(CGColor(red: min(1, r + 0.15), green: min(1, g + 0.1), blue: min(1, b + 0.05),
                                 alpha: 0.85 * CGFloat(life)))
        ctx.fillEllipse(in: CGRect(x: p.x - s / 2, y: p.y - s / 2, width: s, height: s))
    }

    private static func drawWeatherGrade(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        let env = engine.environmentEffects
        guard env.isHazardous || !env.labels.isEmpty else { return }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if env.damagePerSec > 0.5 {
            r += 0.9; g += 0.15; b += 0.08; a += 0.07
        }
        if env.energyDrainPerSec > 3 {
            r += 0.15; g += 0.55; b += 0.9; a += 0.06
        }
        if env.sensorsBlind {
            r += 0.08; g += 0.06; b += 0.12; a += 0.09
        }
        if env.thrustMult < 0.92 {
            r += 0.75; g += 0.55; b += 0.25; a += 0.05
        }
        if env.turnMult < 0.92 {
            r += 0.35; g += 0.75; b += 0.95; a += 0.04
        }
        if simd_length_squared(env.gravPull) > 1 {
            r += 0.7; g += 0.25; b += 0.9; a += 0.05
        }
        guard a > 0.01 else { return }
        a = min(0.10, a)
        ctx.setFillColor(NSColor(calibratedRed: min(1, r), green: min(1, g), blue: min(1, b), alpha: a).cgColor)
        ctx.fill(bounds)
        // Soft edge vignette for hazards
        if env.isHazardous {
            let colors = [
                CGColor(red: min(1, r), green: min(1, g), blue: min(1, b), alpha: 0),
                CGColor(red: min(1, r), green: min(1, g), blue: min(1, b), alpha: a * 0.9),
            ] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.55, 1]) {
                let c = CGPoint(x: bounds.midX, y: bounds.midY)
                let maxR = hypot(bounds.width, bounds.height) * 0.55
                ctx.drawRadialGradient(grad, startCenter: c, startRadius: 0,
                                       endCenter: c, endRadius: maxR, options: [])
            }
        }
    }

    private static func drawStars(ctx: CGContext, bounds: CGRect, camera: SIMD2<Float>, time: Float, parallax: Float) {
        var rng = SeededRNG(seed: 42)
        for layer in 0..<3 {
            let depth = Float(layer + 1) * 0.15 * parallax
            let count = 90 + layer * 45
            let baseSize: CGFloat = layer == 0 ? 1.1 : (layer == 1 ? 1.55 : 2.15)
            let baseAlpha: CGFloat = layer == 0 ? 0.32 : (layer == 1 ? 0.52 : 0.78)
            // Far layers cooler, near warmer
            let coolBias = CGFloat(2 - layer) * 0.08
            for _ in 0..<count {
                let wx = rng.nextFloat(-3000...3000)
                let wy = rng.nextFloat(-3000...3000)
                let sx = CGFloat(wx - camera.x * depth).truncatingRemainder(dividingBy: bounds.width)
                let sy = CGFloat(wy - camera.y * depth).truncatingRemainder(dividingBy: bounds.height)
                let x = sx < 0 ? sx + bounds.width : sx
                let y = sy < 0 ? sy + bounds.height : sy
                let twinkle = 0.72 + 0.28 * sin(Double(time * 2 + wx * 0.01))
                // Color temperature 0…1 → cool blue / white / warm amber
                let temp = rng.nextFloat(0...1)
                let cr: CGFloat, cg: CGFloat, cb: CGFloat
                if temp < 0.35 {
                    cr = 0.65 + coolBias; cg = 0.78; cb = 1.0
                } else if temp < 0.75 {
                    cr = 0.92; cg = 0.94; cb = 1.0
                } else {
                    cr = 1.0; cg = 0.82 - coolBias * 0.3; cb = 0.55
                }
                let giant = layer == 2 && temp > 0.92
                let size = giant ? baseSize * 1.9 : baseSize
                let alpha = baseAlpha * CGFloat(twinkle) * (giant ? 1.15 : 1.0)
                ctx.setFillColor(NSColor(calibratedRed: min(1, cr), green: min(1, cg), blue: min(1, cb),
                                         alpha: alpha).cgColor)
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
                if giant {
                    ctx.setFillColor(NSColor(calibratedRed: cr, green: cg, blue: cb, alpha: alpha * 0.25).cgColor)
                    ctx.fillEllipse(in: CGRect(x: x - size, y: y - size, width: size * 3, height: size * 3))
                }
            }
        }
    }

    private static func drawNebula(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        let tint = engine.currentSystem.nebulaTint
        let cam = engine.camera
        // Soft ambient wash from system palette
        var rng = SeededRNG(seed: engine.currentSystemName.hashValue &+ 7)
        for _ in 0..<4 {
            let wx = rng.nextFloat(-2500...2500)
            let wy = rng.nextFloat(-2500...2500)
            let p = worldToScreen(SIMD2(wx, wy), camera: cam * 0.25, bounds: bounds)
            let r = CGFloat(rng.nextFloat(280...620))
            let colors = [
                CGColor(red: CGFloat(tint.0), green: CGFloat(tint.1), blue: CGFloat(tint.2), alpha: 0.10),
                CGColor(red: CGFloat(tint.0), green: CGFloat(tint.1), blue: CGFloat(tint.2), alpha: 0.0),
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.drawRadialGradient(gradient,
                                       startCenter: p, startRadius: 0,
                                       endCenter: p, endRadius: r,
                                       options: [])
            }
        }
        // Localized environment zones (nebula clouds, radiation, dust…)
        for zone in engine.currentSystem.environmentZones {
            drawEnvironmentZone(ctx: ctx, zone: zone, camera: cam, bounds: bounds, time: engine.time)
        }
    }

    private static func drawEnvironmentZone(
        ctx: CGContext, zone: EnvironmentZone, camera: SIMD2<Float>, bounds: CGRect, time: Float
    ) {
        let p = worldToScreen(zone.position, camera: camera, bounds: bounds)
        let r = CGFloat(zone.radius)
        // Cull far-off zones (generous margin so large fields still show)
        let margin = r * 0.15
        if p.x < -r - margin || p.y < -r - margin
            || p.x > bounds.width + r + margin || p.y > bounds.height + r + margin { return }

        let (rgb, coreAlpha, edgeStyle): ((CGFloat, CGFloat, CGFloat), CGFloat, String) = {
            switch zone.kind {
            case .nebula:
                return ((0.72, 0.32, 1.0), 0.38, "soft")
            case .radiation:
                return ((1.0, 0.28, 0.12), 0.42, "ring")
            case .ionStorm:
                return ((0.25, 0.85, 1.0), 0.40, "storm")
            case .dust:
                return ((0.92, 0.72, 0.35), 0.36, "soft")
            case .ice:
                return ((0.45, 0.92, 1.0), 0.38, "soft")
            case .gravSheer:
                return ((0.85, 0.35, 1.0), 0.36, "ring")
            case .emBlackout:
                return ((0.15, 0.12, 0.22), 0.55, "black")
            }
        }()

        let pulse = 0.88 + 0.12 * sin(time * (zone.kind == .ionStorm ? 5.0 : 2.0) + Float(zone.radius) * 0.01)
        let a0 = coreAlpha * CGFloat(pulse) * CGFloat(min(1.25, zone.intensity))

        // Strong body fill (harder falloff so the disk reads as a real region)
        let colors = [
            CGColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: a0),
            CGColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: a0 * 0.55),
            CGColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: a0 * 0.18),
            CGColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 0.0),
        ] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.35, 0.72, 1]) {
            ctx.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: p, endRadius: r, options: [])
        }

        // Always draw a clear outer boundary
        let rimAlpha = 0.55 + 0.25 * CGFloat(pulse)
        let rimColor = NSColor(calibratedRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: rimAlpha)
        ctx.setStrokeColor(rimColor.cgColor)
        ctx.setLineWidth(edgeStyle == "storm" ? 3.2 : 2.6)
        if edgeStyle == "storm" {
            ctx.setLineDash(phase: CGFloat(time * 28), lengths: [10, 6])
        } else if edgeStyle == "black" {
            ctx.setLineDash(phase: CGFloat(time * 8), lengths: [5, 4])
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.45 + 0.15 * CGFloat(pulse)).cgColor)
        }
        ctx.strokeEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        ctx.setLineDash(phase: 0, lengths: [])

        // Inner dashed ring (depth cue)
        let r2 = r * 0.72
        ctx.setStrokeColor(NSColor(calibratedRed: rgb.0, green: rgb.1, blue: rgb.2,
                                   alpha: 0.35 + 0.15 * CGFloat(pulse)).cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineDash(phase: CGFloat(time * 12), lengths: [5, 7])
        ctx.strokeEllipse(in: CGRect(x: p.x - r2, y: p.y - r2, width: r2 * 2, height: r2 * 2))
        ctx.setLineDash(phase: 0, lengths: [])

        // Hazard chevrons / tick marks around the rim
        if edgeStyle == "ring" || edgeStyle == "storm" || zone.kind == .radiation {
            let ticks = 12
            for i in 0..<ticks {
                let a = Float(i) / Float(ticks) * (.pi * 2) + time * 0.35
                let outer = r * 1.02
                let inner = r * 0.88
                let ox = p.x + CGFloat(cos(a)) * outer
                let oy = p.y + CGFloat(sin(a)) * outer
                let ix = p.x + CGFloat(cos(a)) * inner
                let iy = p.y + CGFloat(sin(a)) * inner
                ctx.setStrokeColor(rimColor.withAlphaComponent(0.75).cgColor)
                ctx.setLineWidth(2)
                ctx.move(to: CGPoint(x: ix, y: iy))
                ctx.addLine(to: CGPoint(x: ox, y: oy))
                ctx.strokePath()
            }
        }

        // Grav sheer: spiral spokes
        if zone.kind == .gravSheer {
            for i in 0..<6 {
                let a0 = Float(i) / 6 * (.pi * 2) + time * 0.8
                let a1 = a0 + 0.9
                ctx.setStrokeColor(NSColor(calibratedRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 0.4).cgColor)
                ctx.setLineWidth(1.5)
                ctx.move(to: CGPoint(x: p.x + CGFloat(cos(a0)) * r * 0.2,
                                     y: p.y + CGFloat(sin(a0)) * r * 0.2))
                ctx.addLine(to: CGPoint(x: p.x + CGFloat(cos(a1)) * r * 0.95,
                                        y: p.y + CGFloat(sin(a1)) * r * 0.95))
                ctx.strokePath()
            }
        }

        // Dense interior particles (all kinds — more = more readable)
        var rng = SeededRNG(seed: zone.name.hashValue &+ 11)
        let n: Int = {
            switch zone.kind {
            case .dust: return 55
            case .ice: return 42
            case .radiation: return 36
            case .ionStorm: return 40
            case .nebula: return 30
            case .emBlackout: return 22
            case .gravSheer: return 28
            }
        }()
        for _ in 0..<n {
            let ang = rng.nextFloat(0...(2 * .pi)) + time * rng.nextFloat(0.1...0.9)
            let dist = rng.nextFloat(0.08...0.96) * zone.radius
            let wx = zone.position.x + cos(ang) * dist
            let wy = zone.position.y + sin(ang) * dist
            let sp = worldToScreen(SIMD2(wx, wy), camera: camera, bounds: bounds)
            let sz = CGFloat(rng.nextFloat(1.6...3.8))
            let moteAlpha = CGFloat(rng.nextFloat(0.35...0.85))
            ctx.setFillColor(NSColor(calibratedRed: min(1, rgb.0 + 0.15),
                                     green: min(1, rgb.1 + 0.1),
                                     blue: min(1, rgb.2 + 0.1),
                                     alpha: moteAlpha).cgColor)
            ctx.fillEllipse(in: CGRect(x: sp.x, y: sp.y, width: sz, height: sz))
        }

        // Label plate — always when zone is reasonably large on screen
        if r > 28 {
            let title = zone.kind.shortAlert
            let name = zone.name
            let titleFont = NSFont.systemFont(ofSize: 12, weight: .heavy)
            let nameFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
            let titleSize = (title as NSString).size(withAttributes: [.font: titleFont])
            let nameSize = (name as NSString).size(withAttributes: [.font: nameFont])
            let plateW = max(titleSize.width, nameSize.width) + 20
            let plateH: CGFloat = 36
            let plate = CGRect(x: p.x - plateW / 2, y: p.y - plateH / 2, width: plateW, height: plateH)
            NSColor.black.withAlphaComponent(0.55).setFill()
            let path = NSBezierPath(roundedRect: plate, xRadius: 6, yRadius: 6)
            path.fill()
            NSColor(calibratedRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 0.85).setStroke()
            path.lineWidth = 1.5
            path.stroke()
            drawText(title, at: CGPoint(x: p.x, y: p.y + 4),
                     font: titleFont,
                     color: NSColor(calibratedRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1),
                     align: .center)
            drawText(name, at: CGPoint(x: p.x, y: p.y - 12),
                     font: nameFont,
                     color: Theme.textPrimary, align: .center)
        }
    }

    // MARK: - Celestials & trade lanes

    private static func drawSystemStar(ctx: CGContext, at p: CGPoint, star: SystemStar, time: Float) {
        let r = CGFloat(star.radius)
        // Cull if far off screen (rough)
        if p.x < -r * 2 || p.y < -r * 2 { return }
        let colors = [
            CGColor(red: CGFloat(star.color.0), green: CGFloat(star.color.1), blue: CGFloat(star.color.2), alpha: 0.9),
            CGColor(red: CGFloat(star.color.0), green: CGFloat(star.color.1), blue: CGFloat(star.color.2), alpha: 0.0),
        ] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            ctx.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: p, endRadius: r * 2.2, options: [])
        }
        ctx.setFillColor(CGColor(red: CGFloat(min(1, star.color.0 + 0.15)),
                                 green: CGFloat(min(1, star.color.1 + 0.1)),
                                 blue: CGFloat(star.color.2), alpha: 1))
        ctx.fillEllipse(in: CGRect(x: p.x - r * 0.45, y: p.y - r * 0.45, width: r * 0.9, height: r * 0.9))
        let pulse = 0.7 + 0.3 * sin(time * 1.5)
        ctx.setStrokeColor(CGColor(red: CGFloat(star.color.0), green: CGFloat(star.color.1),
                                   blue: CGFloat(star.color.2), alpha: CGFloat(0.35 * pulse)))
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: p.x - r * 0.7, y: p.y - r * 0.7, width: r * 1.4, height: r * 1.4))
        drawText(star.name, at: CGPoint(x: p.x, y: p.y - r * 0.55 - 14),
                 font: .systemFont(ofSize: 11, weight: .medium), color: Theme.gold.withAlphaComponent(0.7), align: .center)
    }

    private static func drawPlanet(ctx: CGContext, at p: CGPoint, planet: Planet, time: Float) {
        let r = CGFloat(planet.radius)
        // Atmosphere glow
        if let atmo = planet.atmosphere {
            let colors = [
                CGColor(red: CGFloat(atmo.0), green: CGFloat(atmo.1), blue: CGFloat(atmo.2), alpha: 0.35),
                CGColor(red: CGFloat(atmo.0), green: CGFloat(atmo.1), blue: CGFloat(atmo.2), alpha: 0.0),
            ] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.drawRadialGradient(g, startCenter: p, startRadius: r * 0.85,
                                       endCenter: p, endRadius: r * 1.45, options: [])
            }
        }
        // Body
        let body = CGColor(red: CGFloat(planet.color.0), green: CGFloat(planet.color.1),
                           blue: CGFloat(planet.color.2), alpha: 1)
        ctx.setFillColor(body)
        ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        // Gas giant bands
        if planet.isGasGiant, let band = planet.bandColor {
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            ctx.clip()
            ctx.setFillColor(CGColor(red: CGFloat(band.0), green: CGFloat(band.1),
                                     blue: CGFloat(band.2), alpha: 0.35))
            for i in stride(from: -3, through: 3, by: 1) {
                let y = p.y + CGFloat(i) * r * 0.22
                ctx.fill(CGRect(x: p.x - r, y: y - r * 0.06, width: r * 2, height: r * 0.1))
            }
            ctx.restoreGState()
        }
        // Specular highlight
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.18).cgColor)
        ctx.fillEllipse(in: CGRect(x: p.x - r * 0.45, y: p.y + r * 0.15, width: r * 0.55, height: r * 0.4))
        // Limb darken ring
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.25).cgColor)
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        // Name
        drawText(planet.name, at: CGPoint(x: p.x, y: p.y - r - 16),
                 font: .systemFont(ofSize: 12, weight: .semibold),
                 color: Theme.textPrimary.withAlphaComponent(0.75), align: .center)
        _ = time
    }

    private static func drawMoon(ctx: CGContext, at p: CGPoint, moon: Moon, time: Float) {
        let r = CGFloat(moon.radius)
        ctx.setFillColor(CGColor(red: CGFloat(moon.color.0), green: CGFloat(moon.color.1),
                                 blue: CGFloat(moon.color.2), alpha: 1))
        ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.12).cgColor)
        ctx.fillEllipse(in: CGRect(x: p.x - r * 0.4, y: p.y + r * 0.1, width: r * 0.5, height: r * 0.35))
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.3).cgColor)
        ctx.setLineWidth(1)
        ctx.strokeEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        drawText(moon.name, at: CGPoint(x: p.x, y: p.y - r - 10),
                 font: .systemFont(ofSize: 9), color: Theme.textMuted, align: .center)
        _ = time
    }

    private static func drawTradeLane(
        ctx: CGContext, lane: TradeLane, camera: SIMD2<Float>, bounds: CGRect,
        time: Float, activeID: UUID?,
        navPath: GameEngine.FreelaneNavPath? = nil
    ) {
        let pts = lane.points
        guard pts.count >= 2 else { return }
        let active = activeID == lane.id
        let onNavPath = navPath?.laneID == lane.id
        let pathSet = Set(navPath?.ringIndices ?? [])
        let beam = active ? Theme.hull : (onNavPath ? Theme.gold : Theme.accent)
        let pulse = 0.55 + 0.45 * sin(time * 3)

        // Connecting freelane beams
        for i in 0..<(pts.count - 1) {
            let a = worldToScreen(pts[i], camera: camera, bounds: bounds)
            let b = worldToScreen(pts[i + 1], camera: camera, bounds: bounds)
            let segOnPath = onNavPath && pathSet.contains(i) && pathSet.contains(i + 1)
            let col = segOnPath ? Theme.gold : beam
            ctx.setStrokeColor(col.withAlphaComponent(active ? 0.45 : (segOnPath ? 0.55 : 0.18)).cgColor)
            ctx.setLineWidth(active ? 3.5 : (segOnPath ? 3.2 : 2))
            ctx.setLineDash(phase: CGFloat(time * 40), lengths: segOnPath ? [14, 6] : [10, 8])
            ctx.move(to: a)
            ctx.addLine(to: b)
            ctx.strokePath()
            ctx.setLineDash(phase: 0, lengths: [])
            // Soft core
            ctx.setStrokeColor(col.withAlphaComponent(active ? 0.25 : (segOnPath ? 0.22 : 0.08)).cgColor)
            ctx.setLineWidth(active ? 8 : (segOnPath ? 7 : 5))
            ctx.move(to: a)
            ctx.addLine(to: b)
            ctx.strokePath()
        }

        // Rings
        for (i, wp) in pts.enumerated() {
            let p = worldToScreen(wp, camera: camera, bounds: bounds)
            let rr = CGFloat(lane.ringRadius)
            let isEnd = i == 0 || i == pts.count - 1
            let disrupted = lane.isRingDisrupted(i)
            let onPath = onNavPath && pathSet.contains(i)
            let ringColor = disrupted ? Theme.danger : (onPath ? Theme.gold : beam)
            // Outer ring
            ctx.setStrokeColor(ringColor.withAlphaComponent(0.3 + 0.25 * CGFloat(pulse)).cgColor)
            ctx.setLineWidth(isEnd || onPath ? 3 : 2)
            ctx.strokeEllipse(in: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2))
            if onPath, !disrupted {
                // Nav route marker
                ctx.setStrokeColor(Theme.gold.withAlphaComponent(0.7).cgColor)
                ctx.setLineWidth(1.5)
                let br = rr + 6
                ctx.strokeEllipse(in: CGRect(x: p.x - br, y: p.y - br, width: br * 2, height: br * 2))
            }
            // Inner energy ring
            let ir = rr * 0.55
            ctx.setStrokeColor(ringColor.withAlphaComponent(0.5 + 0.3 * CGFloat(pulse)).cgColor)
            ctx.setLineWidth(1.5)
            ctx.strokeEllipse(in: CGRect(x: p.x - ir, y: p.y - ir, width: ir * 2, height: ir * 2))
            if disrupted {
                // Offline X
                ctx.setStrokeColor(Theme.danger.cgColor)
                ctx.setLineWidth(2.5)
                let x = rr * 0.45
                ctx.move(to: CGPoint(x: p.x - x, y: p.y - x))
                ctx.addLine(to: CGPoint(x: p.x + x, y: p.y + x))
                ctx.move(to: CGPoint(x: p.x + x, y: p.y - x))
                ctx.addLine(to: CGPoint(x: p.x - x, y: p.y + x))
                ctx.strokePath()
                drawText("OFFLINE", at: CGPoint(x: p.x, y: p.y + rr + 6),
                         font: .systemFont(ofSize: 8, weight: .bold), color: Theme.danger, align: .center)
            } else if onPath {
                drawText("ROUTE", at: CGPoint(x: p.x, y: p.y + rr + 6),
                         font: .systemFont(ofSize: 8, weight: .bold), color: Theme.gold, align: .center)
            }
            // Cross braces (Freelancer-ish)
            ctx.saveGState()
            ctx.translateBy(x: p.x, y: p.y)
            let face: CGFloat
            if i < pts.count - 1 {
                let n = worldToScreen(pts[i + 1], camera: camera, bounds: bounds)
                face = atan2(n.y - p.y, n.x - p.x)
            } else if i > 0 {
                let n = worldToScreen(pts[i - 1], camera: camera, bounds: bounds)
                face = atan2(p.y - n.y, p.x - n.x)
            } else {
                face = 0
            }
            ctx.rotate(by: face)
            ctx.setStrokeColor(ringColor.withAlphaComponent(0.55).cgColor)
            ctx.setLineWidth(2)
            ctx.move(to: CGPoint(x: -rr * 0.15, y: -rr))
            ctx.addLine(to: CGPoint(x: -rr * 0.15, y: rr))
            ctx.move(to: CGPoint(x: rr * 0.15, y: -rr))
            ctx.addLine(to: CGPoint(x: rr * 0.15, y: rr))
            ctx.strokePath()
            ctx.restoreGState()
        }

        // Label near first ring
        if let first = pts.first {
            let p = worldToScreen(first, camera: camera, bounds: bounds)
            drawText(lane.name, at: CGPoint(x: p.x, y: p.y + CGFloat(lane.ringRadius) + 12),
                     font: .systemFont(ofSize: 9, weight: .medium),
                     color: beam.withAlphaComponent(0.65), align: .center)
        }
    }

    private static func drawGate(
        ctx: CGContext, at p: CGPoint, radius: Float, name: String, time: Float,
        highlight: Bool = false, wormhole: Bool = false, dim: Bool = false
    ) {
        let r = CGFloat(radius)
        let pulse = 0.5 + 0.5 * sin(time * (wormhole ? 4.5 : 3))
        let base = wormhole ? Theme.wormhole : Theme.gate
        let alphaMul: CGFloat = dim ? 0.28 : 1.0
        for i in 0..<3 {
            let rr = r * (0.6 + CGFloat(i) * 0.2)
            ctx.setStrokeColor(base.withAlphaComponent((0.35 + 0.2 * CGFloat(pulse) - CGFloat(i) * 0.08) * alphaMul).cgColor)
            ctx.setLineWidth(2.5 - CGFloat(i) * 0.5)
            ctx.strokeEllipse(in: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2))
        }
        if wormhole {
            // Distorted inner core
            ctx.setFillColor(base.withAlphaComponent((0.12 + 0.1 * CGFloat(pulse)) * alphaMul).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - r * 0.35, y: p.y - r * 0.35, width: r * 0.7, height: r * 0.7))
        }
        if highlight {
            ctx.setStrokeColor(Theme.gold.withAlphaComponent(0.75).cgColor)
            ctx.setLineWidth(2)
            let br = r + 16
            ctx.strokeEllipse(in: CGRect(x: p.x - br, y: p.y - br, width: br * 2, height: br * 2))
        }
        ctx.saveGState()
        ctx.translateBy(x: p.x, y: p.y)
        ctx.rotate(by: CGFloat(time * (wormhole ? 2.2 : 1.5)))
        ctx.setStrokeColor(base.withAlphaComponent(0.7 * alphaMul).cgColor)
        ctx.setLineWidth(2)
        ctx.addArc(center: .zero, radius: r * 0.45, startAngle: 0, endAngle: .pi * 1.4, clockwise: false)
        ctx.strokePath()
        ctx.restoreGState()
        if !name.isEmpty {
            drawText(name, at: CGPoint(x: p.x, y: p.y - r - 14),
                     font: .systemFont(ofSize: highlight ? 11 : 10, weight: highlight ? .bold : .medium),
                     color: highlight ? Theme.gold : base.withAlphaComponent(dim ? 0.55 : 1), align: .center)
        }
    }

    private static func drawAnomaly(ctx: CGContext, at p: CGPoint, anomaly: AnomalySite, known: Bool, time: Float) {
        let r = CGFloat(anomaly.radius * 0.55)
        let pulse = 0.5 + 0.35 * sin(time * 2.4)
        let col: NSColor
        switch anomaly.kind {
        case .jumpPocket: col = Theme.accent.withAlphaComponent(CGFloat(pulse))
        case .silentField: col = Theme.textMuted.withAlphaComponent(CGFloat(0.4 + pulse * 0.4))
        case .laneEcho: col = Theme.gold.withAlphaComponent(CGFloat(pulse))
        }
        ctx.setStrokeColor(col.cgColor)
        ctx.setLineWidth(known ? 2.2 : 1.2)
        ctx.setLineDash(phase: CGFloat(time), lengths: [5, 4])
        ctx.strokeEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        ctx.strokeEllipse(in: CGRect(x: p.x - r * 0.55, y: p.y - r * 0.55, width: r * 1.1, height: r * 1.1))
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.setFillColor(col.cgColor)
        ctx.fillEllipse(in: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6))
        let label = known ? anomaly.name : "???"
        drawText(label, at: CGPoint(x: p.x, y: p.y - r - 12),
                 font: .systemFont(ofSize: 10, weight: .semibold),
                 color: known ? Theme.accent : Theme.textMuted, align: .center)
        if known {
            drawText(anomaly.kind == .laneEcho ? "F / R probe" : "F / R interact",
                     at: CGPoint(x: p.x, y: p.y - r - 24),
                     font: .systemFont(ofSize: 9), color: Theme.textSecondary, align: .center)
        }
    }

    private static func drawWreck(ctx: CGContext, at p: CGPoint, wreck: Derelict, discovered: Bool, time: Float) {
        let r = CGFloat(wreck.radius)
        ctx.saveGState()
        ctx.translateBy(x: p.x, y: p.y)
        ctx.rotate(by: CGFloat(wreck.angle))

        // Broken hull silhouette
        let hull = NSColor(calibratedRed: 0.38, green: 0.36, blue: 0.34, alpha: discovered ? 1 : 0.55)
        let dark = NSColor(calibratedRed: 0.2, green: 0.19, blue: 0.18, alpha: 1)
        fillPathLocal(ctx, color: hull, points: [
            CGPoint(x: r * 0.9, y: 0),
            CGPoint(x: r * 0.3, y: r * 0.55),
            CGPoint(x: -r * 0.6, y: r * 0.45),
            CGPoint(x: -r * 0.85, y: 0),
            CGPoint(x: -r * 0.5, y: -r * 0.5),
            CGPoint(x: r * 0.2, y: -r * 0.4),
        ])
        // Gash
        ctx.setStrokeColor(dark.cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: -r * 0.3, y: r * 0.3))
        ctx.addLine(to: CGPoint(x: r * 0.2, y: -r * 0.25))
        ctx.strokePath()
        // Debris spark
        if wreck.blueprint != nil {
            let pulse = 0.4 + 0.4 * sin(time * 4)
            ctx.setFillColor(Theme.gold.withAlphaComponent(CGFloat(pulse)).cgColor)
            ctx.fillEllipse(in: CGRect(x: -3, y: -3, width: 6, height: 6))
        }
        ctx.restoreGState()

        if discovered {
            drawText(wreck.name, at: CGPoint(x: p.x, y: p.y - r - 12),
                     font: .systemFont(ofSize: 9, weight: .medium),
                     color: Theme.warning.withAlphaComponent(0.85), align: .center)
            if wreck.scrap > 0 {
                drawText("Scrap \(wreck.scrap)", at: CGPoint(x: p.x, y: p.y - r - 24),
                         font: .systemFont(ofSize: 8), color: Theme.textMuted, align: .center)
            }
        }
    }

    private static func fillPathLocal(_ ctx: CGContext, color: NSColor, points: [CGPoint]) {
        guard let first = points.first else { return }
        let path = CGMutablePath()
        path.move(to: first)
        for pt in points.dropFirst() { path.addLine(to: pt) }
        path.closeSubpath()
        ctx.setFillColor(color.cgColor)
        ctx.addPath(path)
        ctx.fillPath()
    }

    private static func drawAsteroid(ctx: CGContext, at p: CGPoint, radius: Float, angle: Float) {
        let r = CGFloat(radius)
        ctx.saveGState()
        ctx.translateBy(x: p.x, y: p.y)
        ctx.rotate(by: CGFloat(angle))
        let path = CGMutablePath()
        let sides = 7
        for i in 0..<sides {
            let a = CGFloat(i) / CGFloat(sides) * .pi * 2
            let rr = r * CGFloat(0.75 + 0.25 * sin(Double(i * 3)))
            let pt = CGPoint(x: cos(a) * rr, y: sin(a) * rr)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        ctx.setFillColor(Theme.asteroid.cgColor)
        ctx.addPath(path)
        ctx.fillPath()
        ctx.setStrokeColor(Theme.asteroid.highlight(withLevel: 0.25)?.cgColor ?? NSColor.gray.cgColor)
        ctx.setLineWidth(1.5)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawShip(
        ctx: CGContext, at p: CGPoint, angle: Float,
        style: ShipArt.Style, accent: NSColor,
        radius: Float, shieldFrac: Float, hullFrac: Float,
        targeted: Bool, name: String?, time: Float,
        paint: ShipPaint = .arctic,
        modularDesign: ShipDesign? = nil,
        isPlayer: Bool = false,
        thrustActive: Bool = false
    ) {
        let r = CGFloat(radius)
        ctx.saveGState()
        ctx.translateBy(x: p.x, y: p.y)
        ctx.rotate(by: CGFloat(angle))

        // Shield bubble — soft fill + stroke
        if shieldFrac > 0.05 {
            let sr = r + 8
            let pulse = 0.85 + 0.15 * sin(Double(time * 3))
            let colors = [
                Theme.shield.withAlphaComponent(0.04 * CGFloat(shieldFrac)).cgColor,
                Theme.shield.withAlphaComponent(0.14 * CGFloat(shieldFrac) * CGFloat(pulse)).cgColor,
                Theme.shield.withAlphaComponent(0).cgColor,
            ] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.3, 0.75, 1]) {
                ctx.drawRadialGradient(g, startCenter: .zero, startRadius: r * 0.4,
                                       endCenter: .zero, endRadius: sr + 4, options: [])
            }
            ctx.setStrokeColor(Theme.shield.withAlphaComponent(0.25 + 0.4 * CGFloat(shieldFrac)).cgColor)
            ctx.setLineWidth(1.6)
            ctx.strokeEllipse(in: CGRect(x: -sr, y: -sr, width: sr * 2, height: sr * 2))
        }

        let thrust: CGFloat
        if isPlayer {
            thrust = thrustActive ? 0.88 : 0.16
        } else {
            thrust = thrustActive ? 0.55 : 0.22
        }
        let dmg: CGFloat = hullFrac < 0.35 ? CGFloat(1 - hullFrac) : 0
        ShipArt.draw(
            ctx: ctx, style: style, scale: r, accent: accent, time: time, paint: paint,
            modularDesign: modularDesign,
            thrustGlow: thrust,
            shieldPulse: CGFloat(shieldFrac),
            damaged: dmg
        )
        ctx.restoreGState()

        if targeted {
            let tr = r + 14
            let arm: CGFloat = 7
            ctx.setStrokeColor(Theme.danger.withAlphaComponent(0.95).cgColor)
            ctx.setLineWidth(1.6)
            // Four L-brackets at corners of the target box
            let offs: [(CGFloat, CGFloat)] = [(-tr, -tr), (tr, -tr), (-tr, tr), (tr, tr)]
            for (i, o) in offs.enumerated() {
                let sx: CGFloat = i % 2 == 0 ? 1 : -1
                let sy: CGFloat = i < 2 ? 1 : -1
                let cx = p.x + o.0
                let cy = p.y + o.1
                ctx.move(to: CGPoint(x: cx, y: cy + sy * arm))
                ctx.addLine(to: CGPoint(x: cx, y: cy))
                ctx.addLine(to: CGPoint(x: cx + sx * arm, y: cy))
                ctx.strokePath()
            }
            // Subtle cross ticks
            ctx.setStrokeColor(Theme.danger.withAlphaComponent(0.45).cgColor)
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: p.x - tr - 4, y: p.y))
            ctx.addLine(to: CGPoint(x: p.x - tr + 3, y: p.y))
            ctx.move(to: CGPoint(x: p.x + tr - 3, y: p.y))
            ctx.addLine(to: CGPoint(x: p.x + tr + 4, y: p.y))
            ctx.strokePath()
        }

        if let name {
            drawText(name, at: CGPoint(x: p.x, y: p.y + r + 12),
                     font: .systemFont(ofSize: 9), color: accent.withAlphaComponent(0.9), align: .center)
            drawBar(ctx: ctx, rect: CGRect(x: p.x - 18, y: p.y + r + 18, width: 36, height: 3),
                    frac: CGFloat(hullFrac), color: Theme.hull)
        }
    }

    private static func drawLoot(
        ctx: CGContext, at p: CGPoint, playerScreen: CGPoint,
        magnetizing: Bool, phase: Float, time: Float
    ) {
        let bob = sin(Double(phase)) * 3 + sin(Double(time * 4)) * 1.5
        let cy = p.y + CGFloat(bob)

        // Tractor beam when in magnet range
        if magnetizing {
            let pulse = 0.35 + 0.35 * sin(time * 8 + phase)
            ctx.setStrokeColor(Theme.gold.withAlphaComponent(CGFloat(pulse)).cgColor)
            ctx.setLineWidth(1.5)
            ctx.setLineDash(phase: CGFloat(time * 60), lengths: [6, 5])
            ctx.move(to: CGPoint(x: p.x, y: cy))
            ctx.addLine(to: playerScreen)
            ctx.strokePath()
            ctx.setLineDash(phase: 0, lengths: [])
            // Soft glow core
            ctx.setStrokeColor(Theme.accent.withAlphaComponent(CGFloat(pulse * 0.4)).cgColor)
            ctx.setLineWidth(4)
            ctx.move(to: CGPoint(x: p.x, y: cy))
            ctx.addLine(to: playerScreen)
            ctx.strokePath()
        }

        // Canister body
        ctx.setFillColor(Theme.gold.cgColor)
        ctx.fillEllipse(in: CGRect(x: p.x - 6, y: cy - 6, width: 12, height: 12))
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.35).cgColor)
        ctx.fillEllipse(in: CGRect(x: p.x - 3, y: cy - 2, width: 5, height: 5))
        ctx.setStrokeColor(Theme.gold.withAlphaComponent(magnetizing ? 0.9 : 0.5).cgColor)
        ctx.setLineWidth(magnetizing ? 2 : 1)
        let ring = magnetizing ? 12.0 : 9.0
        ctx.strokeEllipse(in: CGRect(x: p.x - ring, y: cy - ring, width: ring * 2, height: ring * 2))
    }

    private static func drawProximityHints(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        if engine.onTradeLane {
            drawBanner(ctx: ctx, bounds: bounds,
                       text: "TRADE LANE — Hold S / F to exit  ·  Pirate hits or disrupted rings dump you!")
            return
        }
        let pos = engine.player.position
        if let freighter = engine.npcs.first(where: {
            $0.isCargo && $0.enginesDisabled && $0.cargoPodsRemaining > 0
                && distance($0.position, pos) < $0.radius + 55
        }) {
            drawBanner(ctx: ctx, bounds: bounds,
                       text: "Press F to loot cargo pods from \(freighter.name) (\(freighter.cargoPodsRemaining) left)")
            return
        }
        if let hit = engine.nearbyTradeRing() {
            let offline = hit.lane.isRingDisrupted(hit.index) ? " [OFFLINE]" : ""
            drawBanner(ctx: ctx, bounds: bounds,
                       text: "Press F to enter trade lane — \(hit.lane.name)\(offline)")
            return
        }
        for st in engine.currentSystem.stations {
            if distance(pos, st.position) < st.dockRadius {
                drawBanner(ctx: ctx, bounds: bounds, text: "Press F / E to dock at \(st.name)")
                return
            }
        }
        for gate in engine.currentSystem.gates {
            if distance(pos, gate.position) < gate.radius + 30 {
                drawBanner(ctx: ctx, bounds: bounds, text: "Press F / E to jump — \(gate.name)")
                return
            }
        }
        for wreck in engine.currentSystem.wrecks {
            if distance(pos, wreck.position) < wreck.mineRadius {
                let bp = wreck.blueprint != nil ? " · blueprint signal" : ""
                drawBanner(ctx: ctx, bounds: bounds,
                           text: "Press R or F to salvage \(wreck.name) (Scrap \(wreck.scrap)\(bp))")
                return
            }
        }
        for ast in engine.currentSystem.asteroids {
            if distance(pos, ast.position) < ast.radius + 50 {
                drawBanner(ctx: ctx, bounds: bounds, text: "Press R or F to mine Ore (\(ast.ore) left)")
                return
            }
        }
    }

    private static func drawBanner(ctx: CGContext, bounds: CGRect, text: String) {
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Theme.accent]
        let size = (text as NSString).size(withAttributes: attr)
        let pad: CGFloat = 14
        let rect = CGRect(x: (bounds.width - size.width) / 2 - pad,
                          y: 90, width: size.width + pad * 2, height: size.height + 10)
        Theme.panelBg.setFill()
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        path.fill()
        Theme.panelBorder.setStroke()
        path.lineWidth = 1
        path.stroke()
        (text as NSString).draw(at: CGPoint(x: rect.minX + pad, y: rect.minY + 5), withAttributes: attr)
    }

    // MARK: - HUD

    private static func drawHUD(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        let p = engine.player
        let margin: CGFloat = 16
        let panelW: CGFloat = 230
        let panelH: CGFloat = engine.player.isWanted ? 168 : 152
        let panel = CGRect(x: margin, y: bounds.height - panelH - margin, width: panelW, height: panelH)
        drawPanel(ctx: ctx, rect: panel)

        var y = panel.maxY - 20
        drawText(engine.currentSystem.displayName, at: CGPoint(x: panel.minX + 12, y: y),
                 font: .systemFont(ofSize: 13, weight: .bold), color: Theme.systemTint(engine.currentSystemName))
        y -= 16
        drawText("\(p.credits) cr  ·  \(p.shipClass.shortName)", at: CGPoint(x: panel.minX + 12, y: y),
                 font: .monospacedDigitSystemFont(ofSize: 11, weight: .semibold), color: Theme.gold)

        y -= 14
        if p.isWanted {
            let stars = String(repeating: "★", count: p.wantedLevel)
            drawText("WANTED \(stars) \(p.rep.wantedLabel)", at: CGPoint(x: panel.minX + 12, y: y),
                     font: .systemFont(ofSize: 10, weight: .bold), color: Theme.danger)
            y -= 12
        }

        y -= 2
        drawLabeledBar(ctx: ctx, x: panel.minX + 12, y: y, width: panelW - 24, label: "HULL",
                       frac: CGFloat(p.hull / p.stats.maxHull), color: Theme.hull,
                       text: "\(Int(p.hull))/\(Int(p.stats.maxHull))")
        y -= 14
        drawLabeledBar(ctx: ctx, x: panel.minX + 12, y: y, width: panelW - 24, label: "SHLD",
                       frac: CGFloat(p.shield / p.stats.maxShield), color: Theme.shield,
                       text: "\(Int(p.shield))/\(Int(p.stats.maxShield))")
        y -= 14
        drawLabeledBar(ctx: ctx, x: panel.minX + 12, y: y, width: panelW - 24, label: "ENRG",
                       frac: CGFloat(p.energy / max(1, p.stats.maxEnergy)), color: Theme.energy,
                       text: "\(Int(p.energy))/\(Int(p.stats.maxEnergy))")
        y -= 14
        drawLabeledBar(ctx: ctx, x: panel.minX + 12, y: y, width: panelW - 24, label: "HOLD",
                       frac: CGFloat(p.cargoUsed / max(1, p.stats.cargoCapacity)), color: Theme.accent,
                       text: String(format: "%.0f/%.0f", p.cargoUsed, p.stats.cargoCapacity))
        y -= 14
        let hangarGun = p.hangarPrimaryWeapon
        let wCol: NSColor = {
            if let hex = hangarGun?.colorHex, let c = NSColor(hex: hex) { return c }
            switch hangarGun?.weaponType {
            case .plasma: return Theme.plasma
            case .rail, .cannon: return Theme.rail
            case .beam: return Theme.danger
            default: return Theme.laser
            }
        }()
        let lockHint: String = {
            if let tid = engine.targetID, let t = engine.npcs.first(where: { $0.id == tid }),
               t.isHostile, distance(t.position, p.position) <= GameEngine.missileLockRange {
                return "LOCK"
            }
            return "—"
        }()
        let gunLabel = hangarGun?.name ?? "Unarmed"
        let secLabel: String = {
            switch p.bKeyMode {
            case .classicMissiles:
                return "B:MSL \(p.missiles)/\(Player.maxMissiles)"
            case .hangarSecondary:
                if let sec = p.hangarSecondaryWeapon {
                    return "B:\(sec.name)"
                }
                return "B:HANGAR?"
            }
        }()
        var ordnance = "\(gunLabel)  ·  \(secLabel)  ·  MN \(p.mineStock)  CM \(p.cmStock) \(lockHint)"
        if p.freelaneBoostActive {
            ordnance += "  ·  LANE BOOST \(Int(p.freelaneBoostSeconds ?? 0))s"
        } else if p.hasAncientLaneCore {
            ordnance += "  ·  CORE"
        }
        drawText(ordnance,
                 at: CGPoint(x: panel.minX + 12, y: y),
                 font: .systemFont(ofSize: 9, weight: .semibold),
                 color: p.freelaneBoostActive ? Theme.gold : wCol)

        // Combat target panel (top-right)
        if let tid = engine.targetID, let t = engine.npcs.first(where: { $0.id == tid }) {
            let tall = t.scannedByPlayer || engine.scanProgress > 0.05
            let tpH: CGFloat = tall ? 118 : 90
            let tp = CGRect(x: bounds.width - 220 - margin, y: bounds.height - tpH - margin, width: 220, height: tpH)
            drawPanel(ctx: ctx, rect: tp)
            drawText("TARGET", at: CGPoint(x: tp.minX + 12, y: tp.maxY - 18),
                     font: .systemFont(ofSize: 10, weight: .bold), color: Theme.danger)
            drawText("\(t.name)  [\(t.hullType.classLabel)]", at: CGPoint(x: tp.minX + 12, y: tp.maxY - 34),
                     font: .systemFont(ofSize: 12, weight: .semibold), color: Theme.textPrimary)
            let dist = Int(distance(t.position, engine.player.position))
            let inLock = t.isHostile && Float(dist) <= GameEngine.missileLockRange
            drawText("Range \(dist)m\(inLock ? "  ·  MSL LOCK" : "")", at: CGPoint(x: tp.minX + 12, y: tp.maxY - 50),
                     font: .systemFont(ofSize: 11), color: inLock ? Theme.missile : Theme.textSecondary)
            if t.scannedByPlayer {
                let want = t.isWanted ? " · WANTED" : ""
                drawText("\(t.faction.displayName)\(want)", at: CGPoint(x: tp.minX + 12, y: tp.maxY - 66),
                         font: .systemFont(ofSize: 10, weight: .semibold),
                         color: t.isWanted ? Theme.warning : Theme.accent)
                let cargoBits = t.manifest.sorted { $0.key.rawValue < $1.key.rawValue }.prefix(2)
                    .map { "\($0.key.rawValue)×\($0.value)" }.joined(separator: " ")
                drawText(cargoBits.isEmpty ? "Manifest: empty" : cargoBits,
                         at: CGPoint(x: tp.minX + 12, y: tp.maxY - 80),
                         font: .systemFont(ofSize: 10), color: Theme.textSecondary)
            } else if engine.scanProgress > 0.02 {
                drawLabeledBar(ctx: ctx, x: tp.minX + 12, y: tp.maxY - 72, width: 196, label: "SCAN",
                               frac: CGFloat(engine.scanProgress), color: Theme.accent, text: "")
            } else {
                drawText("Hold I to identify", at: CGPoint(x: tp.minX + 12, y: tp.maxY - 66),
                         font: .systemFont(ofSize: 10), color: Theme.textMuted)
            }
            drawLabeledBar(ctx: ctx, x: tp.minX + 12, y: tp.minY + 16, width: 196, label: "HULL",
                           frac: CGFloat(t.hull / t.maxHull), color: Theme.hull, text: "")
        }

        // Pinned trade route strip
        if let route = engine.player.pinnedRoute {
            let strip = CGRect(x: margin, y: bounds.height - panelH - margin - 36, width: min(340, bounds.width * 0.4), height: 28)
            drawPanel(ctx: ctx, rect: strip)
            drawText("ROUTE  \(route.shortLabel)  ·  U clear",
                     at: CGPoint(x: strip.minX + 10, y: strip.midY - 6),
                     font: .systemFont(ofSize: 10, weight: .semibold), color: Theme.gold)
        }

        // Nav waypoint panel (under status — left side)
        drawNavPanel(ctx: ctx, bounds: bounds, engine: engine, margin: margin)

        // Off-screen nav edge marker
        drawNavEdgeMarker(ctx: ctx, bounds: bounds, engine: engine)

        // Minimap
        drawMinimap(ctx: ctx, bounds: bounds, engine: engine)

        // ── Top-center stack (top → bottom, no overlap) ─────────────────
        // Story/missions → race → weather → compass → autopilot badge.
        // Each band consumes vertical space so bars never cover each other.
        var stackTop = bounds.height - margin  // next free Y (top edge of next bar)

        stackTop = drawStoryMissionStrip(ctx: ctx, bounds: bounds, engine: engine,
                                         margin: margin, stackTop: stackTop)

        // Freelane time trial / result banner
        if engine.raceActive {
            let t = GameEngine.formatRaceTime(engine.raceTimer)
            var line = "TIME TRIAL  \(t)"
            if let pb = engine.racePBTime {
                let delta = engine.raceTimer - pb
                let sign = delta >= 0 ? "+" : "−"
                let dAbs = GameEngine.formatRaceTime(abs(delta))
                let colHint = delta <= 0 ? "▲" : "▼"
                line += "  ·  PB \(GameEngine.formatRaceTime(pb))  \(colHint)\(sign)\(dAbs)"
            } else {
                line += "  ·  no PB yet"
            }
            if !engine.raceGhostSamples.isEmpty {
                line += "  ·  GHOST"
            }
            let barH: CGFloat = 28
            let gap: CGFloat = 6
            let barW = min(bounds.width - 40, 520)
            let bar = CGRect(x: (bounds.width - barW) / 2, y: stackTop - gap - barH,
                             width: barW, height: barH)
            Theme.gold.withAlphaComponent(0.28).setFill()
            let path = NSBezierPath(roundedRect: bar, xRadius: 8, yRadius: 8)
            path.fill()
            Theme.gold.setStroke()
            path.lineWidth = 2
            path.stroke()
            let ahead = (engine.racePBTime.map { engine.raceTimer <= $0 } ?? true)
            drawText(line, at: CGPoint(x: bar.midX, y: bar.midY - 7),
                     font: .monospacedDigitSystemFont(ofSize: 13, weight: .heavy),
                     color: ahead ? Theme.gold : Theme.warning, align: .center)
            stackTop = bar.minY
        } else if !engine.raceResultBanner.isEmpty {
            let barH: CGFloat = 28
            let gap: CGFloat = 6
            let barW = min(bounds.width - 40, 480)
            let bar = CGRect(x: (bounds.width - barW) / 2, y: stackTop - gap - barH,
                             width: barW, height: barH)
            Theme.accent.withAlphaComponent(0.3).setFill()
            let path = NSBezierPath(roundedRect: bar, xRadius: 8, yRadius: 8)
            path.fill()
            Theme.accent.setStroke()
            path.lineWidth = 2
            path.stroke()
            drawText(engine.raceResultBanner, at: CGPoint(x: bar.midX, y: bar.midY - 7),
                     font: .systemFont(ofSize: 13, weight: .heavy),
                     color: Theme.textPrimary, align: .center)
            stackTop = bar.minY
        }

        // Environment / space weather HUD (no screen-edge vignette)
        let env = engine.environmentEffects
        if !env.labels.isEmpty {
            let hazard = env.isHazardous
            let text = env.labels.joined(separator: " · ")
            let detail: String = {
                if env.damagePerSec > 1 {
                    return String(format: "  ·  −%.0f SHLD/s", env.damagePerSec)
                }
                if env.sensorsBlind { return "  ·  SCANNERS DEAD" }
                if env.energyDrainPerSec > 5 {
                    return String(format: "  ·  −%.0f ENRG/s", env.energyDrainPerSec)
                }
                if env.thrustMult < 0.9 {
                    return String(format: "  ·  THRUST %.0f%%", env.thrustMult * 100)
                }
                if env.turnMult < 0.9 {
                    return String(format: "  ·  TURN %.0f%%", env.turnMult * 100)
                }
                if env.scanMult < 0.85 {
                    return String(format: "  ·  SCAN %.0f%%", env.scanMult * 100)
                }
                return ""
            }()
            let barH: CGFloat = 28
            let gap: CGFloat = 6
            let barW = min(bounds.width - 40, 480)
            let bar = CGRect(x: (bounds.width - barW) / 2, y: stackTop - gap - barH,
                             width: barW, height: barH)
            (hazard ? Theme.danger : Theme.accent).withAlphaComponent(0.35).setFill()
            let path = NSBezierPath(roundedRect: bar, xRadius: 8, yRadius: 8)
            path.fill()
            (hazard ? Theme.danger : Theme.accent).setStroke()
            path.lineWidth = 2
            path.stroke()
            drawText(text + detail, at: CGPoint(x: bar.midX, y: bar.midY - 7),
                     font: .systemFont(ofSize: 13, weight: .heavy),
                     color: Theme.textPrimary, align: .center)
            stackTop = bar.minY
        }

        // Compass strip (under stacked banners)
        stackTop = drawCompass(ctx: ctx, bounds: bounds, engine: engine, stackTop: stackTop)

        // Autopilot badge under compass
        if engine.autopilotWasActive || engine.autopilotHeld {
            let gap: CGFloat = 8
            drawText("AP HOLD H", at: CGPoint(x: bounds.midX, y: stackTop - gap - 12),
                     font: .systemFont(ofSize: 10, weight: .bold),
                     color: engine.autopilotHeld ? Theme.hull : Theme.textMuted, align: .center)
        }

        // Radio chatter (above NEWS) — compact centered strip, not full-width
        if !engine.radioLine.isEmpty {
            let font = NSFont.systemFont(ofSize: 11, weight: .medium)
            let label = "RADIO  \(engine.radioLine)"
            let bar = Self.bottomTickerBar(bounds: bounds, y: 62, text: label, font: font, maxWidth: 480)
            Theme.panelBg.withAlphaComponent(0.9).setFill()
            NSBezierPath(roundedRect: bar, xRadius: 6, yRadius: 6).fill()
            Theme.accent.withAlphaComponent(0.45).setStroke()
            let bp = NSBezierPath(roundedRect: bar, xRadius: 6, yRadius: 6)
            bp.lineWidth = 1
            bp.stroke()
            let shown = Self.truncateToWidth(label, font: font, maxWidth: bar.width - 20)
            drawText(shown, at: CGPoint(x: bar.minX + 10, y: bar.minY + 4),
                     font: font, color: Theme.accent)
        }

        // News ticker (bottom) — compact centered strip sized to the headline
        if !engine.newsLine.isEmpty {
            let font = NSFont.systemFont(ofSize: 11, weight: .medium)
            let label = "NEWS  \(engine.newsLine)"
            let bar = Self.bottomTickerBar(bounds: bounds, y: 36, text: label, font: font, maxWidth: 520)
            Theme.panelBg.setFill()
            NSBezierPath(roundedRect: bar, xRadius: 6, yRadius: 6).fill()
            Theme.panelBorder.setStroke()
            let bp = NSBezierPath(roundedRect: bar, xRadius: 6, yRadius: 6)
            bp.lineWidth = 1
            bp.stroke()
            let shown = Self.truncateToWidth(label, font: font, maxWidth: bar.width - 20)
            drawText(shown, at: CGPoint(x: bar.minX + 10, y: bar.minY + 4),
                     font: font, color: Theme.gold)
        }

        // Controls hint
        drawText("WASD fly  ·  H autopilot  ·  Y photo  ·  Space fire  ·  B missile  ·  V nav  ·  F dock  ·  P pause",
                 at: CGPoint(x: bounds.midX, y: 14),
                 font: .systemFont(ofSize: 10), color: Theme.textMuted, align: .center)
    }

    private static func drawPhotoOverlay(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        // Corner brackets (viewfinder)
        let m: CGFloat = 28
        let len: CGFloat = 36
        ctx.setStrokeColor(Theme.accent.withAlphaComponent(0.7).cgColor)
        ctx.setLineWidth(2)
        // TL
        ctx.move(to: CGPoint(x: m, y: bounds.height - m - len))
        ctx.addLine(to: CGPoint(x: m, y: bounds.height - m))
        ctx.addLine(to: CGPoint(x: m + len, y: bounds.height - m))
        // TR
        ctx.move(to: CGPoint(x: bounds.width - m - len, y: bounds.height - m))
        ctx.addLine(to: CGPoint(x: bounds.width - m, y: bounds.height - m))
        ctx.addLine(to: CGPoint(x: bounds.width - m, y: bounds.height - m - len))
        // BL
        ctx.move(to: CGPoint(x: m, y: m + len))
        ctx.addLine(to: CGPoint(x: m, y: m))
        ctx.addLine(to: CGPoint(x: m + len, y: m))
        // BR
        ctx.move(to: CGPoint(x: bounds.width - m - len, y: m))
        ctx.addLine(to: CGPoint(x: bounds.width - m, y: m))
        ctx.addLine(to: CGPoint(x: bounds.width - m, y: m + len))
        ctx.strokePath()

        drawText("PHOTO MODE", at: CGPoint(x: bounds.midX, y: bounds.height - 36),
                 font: .systemFont(ofSize: 14, weight: .bold), color: Theme.accent, align: .center)
        drawText("WASD pan  ·  −/+ camera speed (\(Int(engine.freeCameraSpeed)))  ·  Esc / Y exit",
                 at: CGPoint(x: bounds.midX, y: 28),
                 font: .systemFont(ofSize: 12), color: Theme.textSecondary, align: .center)
        drawText(engine.currentSystem.displayName,
                 at: CGPoint(x: bounds.midX, y: 48),
                 font: .systemFont(ofSize: 11), color: Theme.textMuted, align: .center)
    }

    /// Top-center campaign / mission lines. Returns updated stackTop (bottom of strip).
    @discardableResult
    private static func drawStoryMissionStrip(
        ctx: CGContext, bounds: CGRect, engine: GameEngine, margin: CGFloat, stackTop: CGFloat
    ) -> CGFloat {
        let lines: [(String, NSColor, NSFont)] = {
            var out: [(String, NSColor, NSFont)] = []
            out.append((
                engine.storyHUDLine,
                engine.player.ironmanMode ? Theme.danger : Theme.accent,
                .systemFont(ofSize: 11, weight: .semibold)
            ))
            if engine.player.ironmanMode {
                out.append(("IRONMAN", Theme.danger, .systemFont(ofSize: 10, weight: .bold)))
            }
            for m in engine.activeMissions.prefix(2) {
                out.append((
                    "▪ \(m.title)  (\(m.progress)/\(m.target))",
                    Theme.gold.withAlphaComponent(0.9),
                    .systemFont(ofSize: 11, weight: .regular)
                ))
            }
            return out
        }()
        guard !lines.isEmpty else { return stackTop }

        let lineH: CGFloat = 16
        let padX: CGFloat = 16
        let padY: CGFloat = 8
        var maxW: CGFloat = 120
        for (text, _, font) in lines {
            let w = (text as NSString).size(withAttributes: [.font: font]).width
            maxW = max(maxW, w)
        }
        let panelW = min(bounds.width - 280, maxW + padX * 2)
        let panelH = CGFloat(lines.count) * lineH + padY * 2
        // Cap width so we don't collide with left status / right target panels
        let panel = CGRect(
            x: (bounds.width - panelW) / 2,
            y: stackTop - panelH,
            width: panelW,
            height: panelH
        )
        Theme.panelBg.withAlphaComponent(0.88).setFill()
        let path = NSBezierPath(roundedRect: panel, xRadius: 8, yRadius: 8)
        path.fill()
        Theme.panelBorder.withAlphaComponent(0.7).setStroke()
        path.lineWidth = 1
        path.stroke()

        var y = panel.maxY - padY - 12
        let mx = panel.midX
        for (text, color, font) in lines {
            drawText(text, at: CGPoint(x: mx, y: y), font: font, color: color, align: .center)
            y -= lineH
        }
        return panel.minY
    }

    private static func drawNavPanel(ctx: CGContext, bounds: CGRect, engine: GameEngine, margin: CGFloat) {
        let panelW: CGFloat = 250
        let panelH: CGFloat = 72
        // Place below top-left status if possible; else mid-left
        let statusH: CGFloat = engine.player.isWanted ? 168 : 152
        let panel = CGRect(x: margin, y: bounds.height - statusH - margin - panelH - 8,
                           width: panelW, height: panelH)
        drawPanel(ctx: ctx, rect: panel)

        guard let nav = engine.resolveNav(), let m = engine.navMetrics() else {
            drawText("NAV", at: CGPoint(x: panel.minX + 12, y: panel.maxY - 18),
                     font: .systemFont(ofSize: 10, weight: .bold), color: Theme.accentDim)
            drawText("No waypoint — press V", at: CGPoint(x: panel.minX + 12, y: panel.maxY - 38),
                     font: .systemFont(ofSize: 12), color: Theme.textMuted)
            drawText("Stations · gates · missions", at: CGPoint(x: panel.minX + 12, y: panel.minY + 12),
                     font: .systemFont(ofSize: 10), color: Theme.textMuted)
            return
        }

        let col: NSColor = {
            switch nav.colorHint {
            case "gate": return Theme.gate
            case "escort": return Theme.gold
            case "mission": return Theme.warning
            default: return Theme.station
            }
        }()

        drawText("NAV", at: CGPoint(x: panel.minX + 12, y: panel.maxY - 18),
                 font: .systemFont(ofSize: 10, weight: .bold), color: col)
        drawText(nav.label, at: CGPoint(x: panel.minX + 48, y: panel.maxY - 18),
                 font: .systemFont(ofSize: 13, weight: .bold), color: Theme.textPrimary)

        let distStr = GameEngine.formatNavDistance(m.distance)
        let turn = Int(m.turnDeg.rounded())
        let turnStr: String
        if abs(turn) <= 8 {
            turnStr = "▲ nose-on"
        } else if turn > 0 {
            turnStr = "◀ port \(turn)°"
        } else {
            turnStr = "starboard \(abs(turn))° ▶"
        }
        drawText("\(distStr)   \(turnStr)", at: CGPoint(x: panel.minX + 12, y: panel.maxY - 40),
                 font: .monospacedDigitSystemFont(ofSize: 12, weight: .semibold), color: Theme.gold)
        drawText(nav.detail, at: CGPoint(x: panel.minX + 12, y: panel.minY + 12),
                 font: .systemFont(ofSize: 10), color: Theme.textSecondary)

        // Mini heading dial
        let dialC = CGPoint(x: panel.maxX - 28, y: panel.midY)
        ctx.setStrokeColor(Theme.panelBorder.cgColor)
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: dialC.x - 16, y: dialC.y - 16, width: 32, height: 32))
        // Nose marker (up = player heading relative)
        let turnRad = CGFloat(m.turnDeg) * .pi / 180
        // Screen: up is +y in our coords for dial; turnDeg positive = port = left = +CCW from nose
        let needle = CGPoint(x: dialC.x + sin(-turnRad) * 12, y: dialC.y + cos(-turnRad) * 12)
        ctx.setStrokeColor(col.cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: dialC)
        ctx.addLine(to: needle)
        ctx.strokePath()
        ctx.setFillColor(Theme.player.cgColor)
        ctx.fillEllipse(in: CGRect(x: dialC.x - 2.5, y: dialC.y - 2.5, width: 5, height: 5))
    }

    /// Compass strip under the top-center stack. Returns updated stackTop (bottom of bar).
    @discardableResult
    private static func drawCompass(
        ctx: CGContext, bounds: CGRect, engine: GameEngine, stackTop: CGFloat
    ) -> CGFloat {
        let barW = min(420, bounds.width * 0.45)
        let barH: CGFloat = 28
        let gap: CGFloat = 6
        let bar = CGRect(x: (bounds.width - barW) / 2, y: stackTop - gap - barH,
                         width: barW, height: barH)
        Theme.panelBg.withAlphaComponent(0.85).setFill()
        NSBezierPath(roundedRect: bar, xRadius: 6, yRadius: 6).fill()
        Theme.panelBorder.setStroke()
        let bp = NSBezierPath(roundedRect: bar, xRadius: 6, yRadius: 6)
        bp.lineWidth = 1
        bp.stroke()

        // FOV: ±90° from player heading across bar
        let halfFOV: Float = .pi / 2 // 90° each side
        let playerAng = engine.player.angle
        let cx = bar.midX
        let cy = bar.midY

        // Center tick (nose)
        ctx.setStrokeColor(Theme.player.cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: cx, y: bar.minY + 4))
        ctx.addLine(to: CGPoint(x: cx, y: bar.maxY - 4))
        ctx.strokePath()
        drawText("▲", at: CGPoint(x: cx, y: bar.minY + 2),
                 font: .systemFont(ofSize: 8), color: Theme.player, align: .center)

        func place(_ worldPos: SIMD2<Float>, label: String, color: NSColor, important: Bool) {
            let bearing = angleToward(engine.player.position, worldPos)
            let delta = wrapAngle(bearing - playerAng)
            guard abs(delta) <= halfFOV * 1.05 else { return }
            let t = CGFloat(delta / halfFOV) // -1...1
            let x = cx + t * (barW * 0.5 - 14)
            let r: CGFloat = important ? 4 : 3
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: CGRect(x: x - r, y: cy - r, width: r * 2, height: r * 2))
            if important || abs(delta) < 0.35 {
                drawText(label, at: CGPoint(x: x, y: bar.maxY - 11),
                         font: .systemFont(ofSize: 8, weight: important ? .bold : .regular),
                         color: color, align: .center)
            }
        }

        let sys = engine.currentSystem
        let nav = engine.resolveNav()
        for st in sys.stations {
            let isNav = nav.map { distance($0.position, st.position) < 5 } ?? false
            let stCol = st.isEnemyBase ? Theme.pirate : Theme.station
            place(st.position, label: shortName(st.name), color: isNav ? Theme.gold : stCol, important: isNav || st.isEnemyBase)
        }
        for g in sys.gates {
            let isNav = nav.map { distance($0.position, g.position) < 5 } ?? false
            place(g.position, label: shortName(g.destinationSystem), color: isNav ? Theme.gold : Theme.gate, important: isNav)
        }
        if let star = sys.star {
            place(star.position, label: "★", color: Theme.gold, important: false)
        }
        if let eid = engine.escortShipID, let h = engine.npcs.first(where: { $0.id == eid }) {
            place(h.position, label: "ESC", color: Theme.gold, important: true)
        }
        return bar.minY
    }

    private static func shortName(_ s: String) -> String {
        if s.count <= 8 { return s }
        // Prefer first word
        let first = s.split(separator: " ").first.map(String.init) ?? s
        if first.count <= 8 { return first }
        return String(s.prefix(7)) + "…"
    }

    private static func drawNavEdgeMarker(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        guard let nav = engine.resolveNav() else { return }
        let cam = engine.camera
        let screen = worldToScreen(nav.position, camera: cam, bounds: bounds)
        let pad: CGFloat = 36
        let inset = bounds.insetBy(dx: pad, dy: pad)
        // On screen? skip edge marker (label already there)
        if inset.contains(screen) { return }

        let cx = bounds.midX
        let cy = bounds.midY
        var dx = screen.x - cx
        var dy = screen.y - cy
        // Intersect with inset rectangle from center
        let hw = inset.width / 2
        let hh = inset.height / 2
        let scaleX = dx == 0 ? .greatestFiniteMagnitude : hw / abs(dx)
        let scaleY = dy == 0 ? .greatestFiniteMagnitude : hh / abs(dy)
        let scale = min(scaleX, scaleY)
        let edge = CGPoint(x: cx + dx * scale, y: cy + dy * scale)

        let col: NSColor = {
            switch nav.colorHint {
            case "gate": return Theme.gate
            case "escort": return Theme.gold
            case "mission": return Theme.warning
            default: return Theme.station
            }
        }()

        // Diamond
        let s: CGFloat = 10
        let path = CGMutablePath()
        path.move(to: CGPoint(x: edge.x, y: edge.y + s))
        path.addLine(to: CGPoint(x: edge.x + s, y: edge.y))
        path.addLine(to: CGPoint(x: edge.x, y: edge.y - s))
        path.addLine(to: CGPoint(x: edge.x - s, y: edge.y))
        path.closeSubpath()
        ctx.setFillColor(col.withAlphaComponent(0.9).cgColor)
        ctx.addPath(path)
        ctx.fillPath()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(1)
        ctx.addPath(path)
        ctx.strokePath()

        if let m = engine.navMetrics() {
            let distStr = GameEngine.formatNavDistance(m.distance)
            // Place label inside from edge
            let labelOffset = normalizeSafe(SIMD2(Float(cx - edge.x), Float(cy - edge.y)))
            let lx = edge.x + CGFloat(labelOffset.x) * 28
            let ly = edge.y + CGFloat(labelOffset.y) * 28
            drawText("\(nav.label) \(distStr)", at: CGPoint(x: lx, y: ly),
                     font: .systemFont(ofSize: 11, weight: .semibold), color: col, align: .center)
        }
    }

    private static func drawMinimap(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        let size: CGFloat = 188
        let margin: CGFloat = 16
        let rect = CGRect(x: bounds.width - size - margin, y: margin, width: size, height: size)
        drawPanel(ctx: ctx, rect: rect)

        let sys = engine.currentSystem
        let pad: CGFloat = 22
        let scale = (size - pad * 2) / CGFloat(sys.bounds * 2)
        let cx = rect.midX
        let cy = rect.midY

        func map(_ w: SIMD2<Float>) -> CGPoint {
            CGPoint(x: cx + CGFloat(w.x) * scale, y: cy + CGFloat(w.y) * scale)
        }

        // Clip to panel interior
        ctx.saveGState()
        ctx.clip(to: rect.insetBy(dx: 4, dy: 4))

        // Trade lanes
        ctx.setStrokeColor(Theme.accent.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(1.2)
        for lane in sys.tradeLanes {
            guard lane.points.count >= 2 else { continue }
            let a = map(lane.points[0])
            ctx.move(to: a)
            for pt in lane.points.dropFirst() {
                ctx.addLine(to: map(pt))
            }
            ctx.strokePath()
        }
        // Planets
        for planet in sys.planets {
            let p = map(planet.position)
            let known = engine.player.discoveredPlanets.contains("\(engine.currentSystemName)/\(planet.name)")
            let pr = max(3, CGFloat(planet.radius) * scale * 0.35)
            let a: CGFloat = known ? 0.95 : 0.4
            ctx.setFillColor(CGColor(red: CGFloat(planet.color.0), green: CGFloat(planet.color.1),
                                     blue: CGFloat(planet.color.2), alpha: a))
            ctx.fillEllipse(in: CGRect(x: p.x - pr, y: p.y - pr, width: pr * 2, height: pr * 2))
        }
        // Discovered wrecks
        for wreck in sys.wrecks {
            let key = "\(engine.currentSystemName)/\(wreck.name)"
            guard engine.player.discoveredWrecks.contains(key) else { continue }
            let p = map(wreck.position)
            ctx.setFillColor(Theme.warning.cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5))
        }
        // Star
        if let star = sys.star {
            let p = map(star.position)
            ctx.setFillColor(Theme.gold.cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
        }
        // Stations + labels
        let nav = engine.resolveNav()
        for st in sys.stations {
            let p = map(st.position)
            let isNav = nav.map { distance($0.position, st.position) < 5 } ?? false
            let baseCol = st.isEnemyBase ? Theme.pirate : Theme.station
            ctx.setFillColor((isNav ? Theme.gold : baseCol).cgColor)
            let r: CGFloat = isNav ? 4.5 : (st.isEnemyBase ? 4 : 3.5)
            ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            drawText(shortName(st.name), at: CGPoint(x: p.x, y: p.y - 11),
                     font: .systemFont(ofSize: 8, weight: isNav || st.isEnemyBase ? .bold : .medium),
                     color: isNav ? Theme.gold : baseCol.withAlphaComponent(0.9), align: .center)
        }
        // Gates + dest labels
        for g in sys.gates {
            let p = map(g.position)
            let isNav = nav.map { distance($0.position, g.position) < 5 } ?? false
            ctx.setFillColor((isNav ? Theme.gold : Theme.gate).cgColor)
            // Diamond
            let s: CGFloat = isNav ? 5 : 4
            let path = CGMutablePath()
            path.move(to: CGPoint(x: p.x, y: p.y + s))
            path.addLine(to: CGPoint(x: p.x + s, y: p.y))
            path.addLine(to: CGPoint(x: p.x, y: p.y - s))
            path.addLine(to: CGPoint(x: p.x - s, y: p.y))
            path.closeSubpath()
            ctx.addPath(path)
            ctx.fillPath()
            drawText(shortName(g.destinationSystem), at: CGPoint(x: p.x, y: p.y + 8),
                     font: .systemFont(ofSize: 8, weight: isNav ? .bold : .medium),
                     color: isNav ? Theme.gold : Theme.gate, align: .center)
        }
        // NPCs (small)
        for ship in engine.npcs {
            let p = map(ship.position)
            ctx.setFillColor(factionColor(ship.faction).withAlphaComponent(0.85).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3))
        }
        // Nav line from player to waypoint
        if let nav {
            let pp = map(engine.player.position)
            let np = map(nav.position)
            ctx.setStrokeColor(Theme.gold.withAlphaComponent(0.55).cgColor)
            ctx.setLineWidth(1)
            ctx.setLineDash(phase: 0, lengths: [3, 3])
            ctx.move(to: pp)
            ctx.addLine(to: np)
            ctx.strokePath()
            ctx.setLineDash(phase: 0, lengths: [])
        }
        // Player with heading wedge
        let pp = map(engine.player.position)
        let ang = CGFloat(engine.player.angle)
        let nose = CGPoint(x: pp.x + cos(ang) * 9, y: pp.y + sin(ang) * 9)
        let left = CGPoint(x: pp.x + cos(ang + 2.5) * 6, y: pp.y + sin(ang + 2.5) * 6)
        let right = CGPoint(x: pp.x + cos(ang - 2.5) * 6, y: pp.y + sin(ang - 2.5) * 6)
        let wedge = CGMutablePath()
        wedge.move(to: nose)
        wedge.addLine(to: left)
        wedge.addLine(to: right)
        wedge.closeSubpath()
        ctx.setFillColor(Theme.player.withAlphaComponent(0.9).cgColor)
        ctx.addPath(wedge)
        ctx.fillPath()
        ctx.setFillColor(Theme.player.cgColor)
        ctx.fillEllipse(in: CGRect(x: pp.x - 3, y: pp.y - 3, width: 6, height: 6))

        ctx.restoreGState()

        drawText("SYSTEM MAP", at: CGPoint(x: rect.minX + 8, y: rect.maxY - 14),
                 font: .systemFont(ofSize: 9, weight: .bold), color: Theme.accentDim)
        drawText("Z expand · click", at: CGPoint(x: rect.maxX - 8, y: rect.maxY - 14),
                 font: .systemFont(ofSize: 8), color: Theme.textMuted, align: .right)
    }

    // MARK: - Expanded system map

    private static func drawSystemMap(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        let layout = GameEngine.systemMapLayout(bounds: bounds, worldBounds: engine.currentSystem.bounds)
        let chart = layout.chart
        let list = layout.listPanel
        let sys = engine.currentSystem
        let entries = engine.systemMapEntries()
        let sel = min(engine.systemMapSelectIndex, max(0, entries.count - 1))
        let selected = entries.indices.contains(sel) ? entries[sel] : nil
        let activeNav = engine.resolveNav()

        drawText("SYSTEM MAP — \(sys.displayName)", at: CGPoint(x: bounds.midX, y: bounds.height - 22),
                 font: .systemFont(ofSize: 18, weight: .bold), color: Theme.accent, align: .center)
        drawText("↑↓ select  ·  Enter set destination & fly  ·  V set nav  ·  click marker  ·  Z/Esc close  ·  G galaxy",
                 at: CGPoint(x: bounds.midX, y: 14),
                 font: .systemFont(ofSize: 11), color: Theme.textMuted, align: .center)

        // Chart panel
        drawPanel(ctx: ctx, rect: chart.insetBy(dx: -6, dy: -6), radius: 12)
        ctx.saveGState()
        ctx.clip(to: chart)

        // Soft grid
        ctx.setStrokeColor(Theme.panelBorder.withAlphaComponent(0.25).cgColor)
        ctx.setLineWidth(1)
        let gridStep = max(80 * layout.scale, 40)
        var gx = chart.minX
        while gx < chart.maxX {
            ctx.move(to: CGPoint(x: gx, y: chart.minY))
            ctx.addLine(to: CGPoint(x: gx, y: chart.maxY))
            gx += gridStep
        }
        var gy = chart.minY
        while gy < chart.maxY {
            ctx.move(to: CGPoint(x: chart.minX, y: gy))
            ctx.addLine(to: CGPoint(x: chart.maxX, y: gy))
            gy += gridStep
        }
        ctx.strokePath()

        // Trade lanes
        ctx.setStrokeColor(Theme.accent.withAlphaComponent(0.45).cgColor)
        ctx.setLineWidth(2)
        for lane in sys.tradeLanes {
            guard lane.points.count >= 2 else { continue }
            let a = layout.worldToScreen(lane.points[0])
            ctx.move(to: a)
            for pt in lane.points.dropFirst() {
                ctx.addLine(to: layout.worldToScreen(pt))
            }
            ctx.strokePath()
            // Lane name at midpoint
            let midIdx = lane.points.count / 2
            if midIdx < lane.points.count {
                let mp = layout.worldToScreen(lane.points[midIdx])
                drawText(lane.name, at: CGPoint(x: mp.x, y: mp.y + 6),
                         font: .systemFont(ofSize: 9), color: Theme.accent.withAlphaComponent(0.7), align: .center)
            }
        }

        // Environment zones (strong map fill + border)
        for zone in sys.environmentZones {
            let p = layout.worldToScreen(zone.position)
            let zr = max(10, CGFloat(zone.radius) * layout.scale)
            let col: NSColor = {
                switch zone.kind {
                case .nebula: return NSColor(calibratedRed: 0.7, green: 0.3, blue: 1.0, alpha: 0.35)
                case .radiation: return Theme.danger.withAlphaComponent(0.38)
                case .ionStorm: return Theme.accent.withAlphaComponent(0.35)
                case .dust: return Theme.warning.withAlphaComponent(0.35)
                case .ice: return Theme.shield.withAlphaComponent(0.35)
                case .gravSheer: return Theme.gate.withAlphaComponent(0.35)
                case .emBlackout: return NSColor.black.withAlphaComponent(0.45)
                }
            }()
            ctx.setFillColor(col.cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - zr, y: p.y - zr, width: zr * 2, height: zr * 2))
            ctx.setStrokeColor(col.withAlphaComponent(0.95).cgColor)
            ctx.setLineWidth(2)
            ctx.strokeEllipse(in: CGRect(x: p.x - zr, y: p.y - zr, width: zr * 2, height: zr * 2))
            if zr > 14 {
                drawText(zone.kind.shortAlert, at: CGPoint(x: p.x, y: p.y + 4),
                         font: .systemFont(ofSize: 9, weight: .heavy),
                         color: Theme.textPrimary, align: .center)
                drawText(zone.name, at: CGPoint(x: p.x, y: p.y - 10),
                         font: .systemFont(ofSize: 8, weight: .medium),
                         color: Theme.textSecondary, align: .center)
            }
        }

        // Planets
        for planet in sys.planets {
            let p = layout.worldToScreen(planet.position)
            let pr = max(6, CGFloat(planet.radius) * layout.scale * 0.4)
            ctx.setFillColor(CGColor(red: CGFloat(planet.color.0), green: CGFloat(planet.color.1),
                                     blue: CGFloat(planet.color.2), alpha: 0.9))
            ctx.fillEllipse(in: CGRect(x: p.x - pr, y: p.y - pr, width: pr * 2, height: pr * 2))
        }

        // Star
        if let star = sys.star {
            let p = layout.worldToScreen(star.position)
            ctx.setFillColor(Theme.gold.cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16))
            drawText(star.name, at: CGPoint(x: p.x, y: p.y - 18),
                     font: .systemFont(ofSize: 10, weight: .medium), color: Theme.gold, align: .center)
        }

        // Wrecks
        for wreck in sys.wrecks {
            let key = "\(engine.currentSystemName)/\(wreck.name)"
            guard engine.player.discoveredWrecks.contains(key) else { continue }
            let p = layout.worldToScreen(wreck.position)
            ctx.setFillColor(Theme.warning.cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
        }

        // Stations
        for st in sys.stations {
            let p = layout.worldToScreen(st.position)
            let isSel = selected.map { distance($0.position, st.position) < 1 } ?? false
            let isNav = activeNav.map { distance($0.position, st.position) < 5 } ?? false
            let baseCol = st.isEnemyBase ? Theme.pirate : Theme.station
            let col = isSel || isNav ? Theme.gold : baseCol
            let r: CGFloat = isSel ? 9 : (st.isEnemyBase ? 8 : 7)
            ctx.setFillColor(col.cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            if isSel {
                ctx.setStrokeColor(Theme.gold.cgColor)
                ctx.setLineWidth(2)
                ctx.strokeEllipse(in: CGRect(x: p.x - r - 5, y: p.y - r - 5, width: (r + 5) * 2, height: (r + 5) * 2))
            } else if st.isEnemyBase {
                ctx.setStrokeColor(Theme.pirate.withAlphaComponent(0.6).cgColor)
                ctx.setLineWidth(1.5)
                ctx.strokeEllipse(in: CGRect(x: p.x - r - 4, y: p.y - r - 4, width: (r + 4) * 2, height: (r + 4) * 2))
            }
            let label = st.isEnemyBase ? "☠ \(st.name)" : st.name
            drawText(label, at: CGPoint(x: p.x, y: p.y - r - 14),
                     font: .systemFont(ofSize: isSel ? 12 : 11, weight: isSel ? .bold : .semibold),
                     color: col, align: .center)
            let d = GameEngine.formatNavDistance(distance(engine.player.position, st.position))
            let sub = st.isEnemyBase ? "\(d) · ENEMY BASE" : d
            drawText(sub, at: CGPoint(x: p.x, y: p.y - r - 28),
                     font: .monospacedDigitSystemFont(ofSize: 10, weight: .regular),
                     color: st.isEnemyBase ? Theme.pirate.withAlphaComponent(0.85) : Theme.textSecondary,
                     align: .center)
        }

        // Gates
        for g in sys.gates {
            let p = layout.worldToScreen(g.position)
            let isSel = selected.map { distance($0.position, g.position) < 1 } ?? false
            let isNav = activeNav.map { distance($0.position, g.position) < 5 } ?? false
            let col = isSel || isNav ? Theme.gold : Theme.gate
            let s: CGFloat = isSel ? 10 : 8
            let path = CGMutablePath()
            path.move(to: CGPoint(x: p.x, y: p.y + s))
            path.addLine(to: CGPoint(x: p.x + s, y: p.y))
            path.addLine(to: CGPoint(x: p.x, y: p.y - s))
            path.addLine(to: CGPoint(x: p.x - s, y: p.y))
            path.closeSubpath()
            ctx.setFillColor(col.cgColor)
            ctx.addPath(path)
            ctx.fillPath()
            if isSel {
                ctx.setStrokeColor(Theme.gold.cgColor)
                ctx.setLineWidth(2)
                ctx.strokeEllipse(in: CGRect(x: p.x - s - 6, y: p.y - s - 6, width: (s + 6) * 2, height: (s + 6) * 2))
            }
            drawText("→ \(g.destinationSystem)", at: CGPoint(x: p.x, y: p.y - s - 14),
                     font: .systemFont(ofSize: 11, weight: .semibold), color: col, align: .center)
        }

        // Escort
        if let eid = engine.escortShipID, let h = engine.npcs.first(where: { $0.id == eid }) {
            let p = layout.worldToScreen(h.position)
            ctx.setFillColor(Theme.gold.cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10))
            drawText("ESCORT", at: CGPoint(x: p.x, y: p.y + 10),
                     font: .systemFont(ofSize: 10, weight: .bold), color: Theme.gold, align: .center)
        }

        // Nav line + player
        let pp = layout.worldToScreen(engine.player.position)
        if let nav = activeNav {
            let np = layout.worldToScreen(nav.position)
            ctx.setStrokeColor(Theme.gold.withAlphaComponent(0.65).cgColor)
            ctx.setLineWidth(1.5)
            ctx.setLineDash(phase: 0, lengths: [5, 4])
            ctx.move(to: pp)
            ctx.addLine(to: np)
            ctx.strokePath()
            ctx.setLineDash(phase: 0, lengths: [])
        }
        // Also line to selection preview
        if let sel = selected, sel.waypoint != nil {
            let sp = layout.worldToScreen(sel.position)
            ctx.setStrokeColor(Theme.accent.withAlphaComponent(0.4).cgColor)
            ctx.setLineWidth(1)
            ctx.setLineDash(phase: 0, lengths: [2, 3])
            ctx.move(to: pp)
            ctx.addLine(to: sp)
            ctx.strokePath()
            ctx.setLineDash(phase: 0, lengths: [])
        }

        // Player wedge
        let ang = CGFloat(engine.player.angle)
        let nose = CGPoint(x: pp.x + cos(ang) * 14, y: pp.y + sin(ang) * 14)
        let left = CGPoint(x: pp.x + cos(ang + 2.4) * 10, y: pp.y + sin(ang + 2.4) * 10)
        let right = CGPoint(x: pp.x + cos(ang - 2.4) * 10, y: pp.y + sin(ang - 2.4) * 10)
        let wedge = CGMutablePath()
        wedge.move(to: nose)
        wedge.addLine(to: left)
        wedge.addLine(to: right)
        wedge.closeSubpath()
        ctx.setFillColor(Theme.player.cgColor)
        ctx.addPath(wedge)
        ctx.fillPath()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(1)
        ctx.strokeEllipse(in: CGRect(x: pp.x - 5, y: pp.y - 5, width: 10, height: 10))
        drawText("YOU", at: CGPoint(x: pp.x, y: pp.y + 16),
                 font: .systemFont(ofSize: 10, weight: .bold), color: Theme.player, align: .center)

        ctx.restoreGState()

        // List panel
        drawPanel(ctx: ctx, rect: list, radius: 12)
        var y = list.maxY - 22
        drawText("DESTINATIONS", at: CGPoint(x: list.minX + 14, y: y),
                 font: .systemFont(ofSize: 12, weight: .bold), color: Theme.accentDim)
        y -= 8
        drawText("Click or ↑↓ · Enter to travel", at: CGPoint(x: list.minX + 14, y: y - 12),
                 font: .systemFont(ofSize: 10), color: Theme.textMuted)
        y -= 36

        let rowH: CGFloat = 36
        for (i, e) in entries.enumerated() {
            if y < list.minY + 90 { break }
            let selectedRow = i == sel
            if selectedRow {
                Theme.accent.withAlphaComponent(0.15).setFill()
                NSBezierPath(roundedRect: CGRect(x: list.minX + 8, y: y - 22, width: list.width - 16, height: 34),
                             xRadius: 6, yRadius: 6).fill()
            }
            let kindColor: NSColor = {
                switch e.kind {
                case .station: return Theme.station
                case .gate: return Theme.gate
                case .escort: return Theme.gold
                case .planet: return Theme.textSecondary
                case .wreck: return Theme.warning
                case .anomaly: return Theme.accent
                }
            }()
            let icon: String = {
                switch e.kind {
                case .station: return "◎"
                case .gate: return "◇"
                case .escort: return "◆"
                case .planet: return "○"
                case .wreck: return "×"
                case .anomaly: return "✦"
                }
            }()
            let travelable = e.waypoint != nil
            drawText("\(icon) \(e.title)", at: CGPoint(x: list.minX + 16, y: y),
                     font: .systemFont(ofSize: 12, weight: selectedRow ? .bold : .medium),
                     color: selectedRow ? Theme.gold : (travelable ? Theme.textPrimary : Theme.textMuted))
            drawText(e.subtitle, at: CGPoint(x: list.minX + 16, y: y - 14),
                     font: .systemFont(ofSize: 10), color: kindColor.withAlphaComponent(0.9))
            y -= rowH
        }

        // Selection detail footer
        let foot = CGRect(x: list.minX + 10, y: list.minY + 12, width: list.width - 20, height: 70)
        Theme.panelBg.blended(withFraction: 0.3, of: .black)?.setFill()
        NSBezierPath(roundedRect: foot, xRadius: 8, yRadius: 8).fill()
        if let e = selected {
            drawText(e.title, at: CGPoint(x: foot.minX + 10, y: foot.maxY - 20),
                     font: .systemFont(ofSize: 13, weight: .bold), color: Theme.textPrimary)
            drawText(e.subtitle, at: CGPoint(x: foot.minX + 10, y: foot.maxY - 38),
                     font: .systemFont(ofSize: 11), color: Theme.textSecondary)
            if e.waypoint != nil {
                drawText("Enter — set destination & close", at: CGPoint(x: foot.minX + 10, y: foot.minY + 12),
                         font: .systemFont(ofSize: 11, weight: .semibold), color: Theme.gold)
            } else {
                drawText("Landmark only — not a travel target", at: CGPoint(x: foot.minX + 10, y: foot.minY + 12),
                         font: .systemFont(ofSize: 11), color: Theme.textMuted)
            }
        } else {
            drawText("No selection", at: CGPoint(x: foot.minX + 10, y: foot.midY - 6),
                     font: .systemFont(ofSize: 12), color: Theme.textMuted)
        }
    }

    // MARK: - Station UI

    private static func drawStationUI(ctx: CGContext, bounds: CGRect, engine: GameEngine, dimmed: Bool) {
        // Deeper vignette so dock panel reads as a station bay
        if dimmed {
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.42).cgColor)
            ctx.fill(bounds)
        } else {
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.52).cgColor)
            ctx.fill(bounds)
        }

        guard let st = engine.dockedStation else { return }
        let panelW = min(760, bounds.width - 60)
        let panelH = min(640, bounds.height - 48)
        let panel = CGRect(x: (bounds.width - panelW) / 2, y: (bounds.height - panelH) / 2,
                           width: panelW, height: panelH)

        let headerCol = st.isEnemyBase ? Theme.pirate : Theme.station
        let railCol = st.isEnemyBase ? Theme.pirate : Theme.systemTint(engine.currentSystemName)

        // Soft outer glow behind panel
        ctx.setFillColor(railCol.withAlphaComponent(0.08).cgColor)
        ctx.fill(panel.insetBy(dx: -6, dy: -6))

        drawPanel(ctx: ctx, rect: panel, radius: 12, accent: railCol)

        // Faction-tinted header bar
        let headerH: CGFloat = 64
        let headerRect = CGRect(x: panel.minX, y: panel.maxY - headerH, width: panel.width, height: headerH)
        ctx.saveGState()
        let clip = NSBezierPath(roundedRect: panel, xRadius: 12, yRadius: 12)
        clip.addClip()
        let headerColors = [
            headerCol.withAlphaComponent(0.28).cgColor,
            headerCol.withAlphaComponent(0.06).cgColor,
            Theme.panelBg.cgColor,
        ] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: headerColors, locations: [0, 0.55, 1]) {
            ctx.drawLinearGradient(g,
                                   start: CGPoint(x: headerRect.midX, y: headerRect.maxY),
                                   end: CGPoint(x: headerRect.midX, y: headerRect.minY - 8),
                                   options: [])
        }
        // Top accent line
        ctx.setStrokeColor(headerCol.withAlphaComponent(0.75).cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: panel.minX + 12, y: panel.maxY - 2))
        ctx.addLine(to: CGPoint(x: panel.maxX - 12, y: panel.maxY - 2))
        ctx.strokePath()
        ctx.restoreGState()

        // Side rails
        ctx.setStrokeColor(railCol.withAlphaComponent(0.45).cgColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: panel.minX + 3, y: panel.minY + 18))
        ctx.addLine(to: CGPoint(x: panel.minX + 3, y: panel.maxY - 18))
        ctx.move(to: CGPoint(x: panel.maxX - 3, y: panel.minY + 18))
        ctx.addLine(to: CGPoint(x: panel.maxX - 3, y: panel.maxY - 18))
        ctx.strokePath()

        let headerName = st.isEnemyBase ? "☠ \(st.name)" : st.name
        drawText(headerName, at: CGPoint(x: panel.minX + 24, y: panel.maxY - 32),
                 font: .systemFont(ofSize: 20, weight: .bold), color: headerCol)
        let subDesc = st.isEnemyBase
            ? "\(st.faction) den · \(st.description)"
            : st.description
        drawText(subDesc, at: CGPoint(x: panel.minX + 24, y: panel.maxY - 52),
                 font: .systemFont(ofSize: 11), color: st.isEnemyBase ? Theme.danger.withAlphaComponent(0.85) : Theme.textSecondary)
        drawText("\(engine.player.credits) cr   ·   Hold \(String(format: "%.0f", engine.player.cargoUsed))/\(String(format: "%.0f", engine.player.stats.cargoCapacity))",
                 at: CGPoint(x: panel.maxX - 24, y: panel.maxY - 32),
                 font: .monospacedDigitSystemFont(ofSize: 12, weight: .medium), color: Theme.gold, align: .right)

        // Tabs (Warehouse only at Freeport 7)
        let tabs = engine.availableStationTabs
        let tabY = panel.maxY - 96
        let tabW = (panelW - 48) / CGFloat(max(1, tabs.count))
        for (i, tab) in tabs.enumerated() {
            let selected = tab == engine.stationTab
            let tx = panel.minX + 24 + CGFloat(i) * tabW
            let tr = CGRect(x: tx, y: tabY, width: tabW - 6, height: 28)
            if selected {
                railCol.withAlphaComponent(0.22).setFill()
                NSBezierPath(roundedRect: tr, xRadius: 6, yRadius: 6).fill()
                railCol.setStroke()
                let bp = NSBezierPath(roundedRect: tr, xRadius: 6, yRadius: 6)
                bp.lineWidth = 1.2
                bp.stroke()
            }
            let label = "\(i + 1) \(tab.title)"
            drawText(label, at: CGPoint(x: tr.midX, y: tr.midY - 7),
                     font: .systemFont(ofSize: 11, weight: selected ? .bold : .regular),
                     color: selected ? Theme.accent : Theme.textSecondary, align: .center)
        }

        let content = CGRect(x: panel.minX + 24, y: panel.minY + 24,
                             width: panelW - 48, height: tabY - panel.minY - 36)

        switch engine.stationTab {
        case .status: drawStatusTab(content: content, engine: engine, station: st)
        case .trade: drawTradeTab(content: content, engine: engine, station: st)
        case .warehouse: drawWarehouseTab(content: content, engine: engine)
        case .missions: drawMissionsTab(content: content, engine: engine)
        case .outfit: drawOutfitTab(content: content, engine: engine, station: st)
        case .undock: drawUndockTab(content: content, engine: engine)
        }

        let footer: String
        if engine.stationTab == .warehouse {
            footer = "↑/↓ commodity  ·  −/+ qty  ·  Enter deposit/rent  ·  F withdraw  ·  Esc pause"
        } else {
            footer = "←/→ tabs  ·  ↑/↓ select  ·  Enter confirm  ·  F sell/shields  ·  Esc pause"
        }
        drawText(footer, at: CGPoint(x: panel.midX, y: panel.minY + 8),
                 font: .systemFont(ofSize: 10), color: Theme.textMuted, align: .center)
    }

    private static func drawWarehouseTab(content: CGRect, engine: GameEngine) {
        let bay = engine.player.warehouse
        var y = content.maxY - 10
        drawText("Freeport 7 — Private Warehouse Bay", at: CGPoint(x: content.minX, y: y),
                 font: .systemFont(ofSize: 14, weight: .semibold), color: Theme.gold)
        y -= 22

        if bay?.rented != true {
            drawText("Lease a secure bay to store cargo between trade runs.",
                     at: CGPoint(x: content.minX, y: y), font: .systemFont(ofSize: 12), color: Theme.textSecondary)
            y -= 20
            drawText("Cost: \(PlayerWarehouse.rentCost) cr  ·  Capacity: \(Int(PlayerWarehouse.bayCapacity)) mass",
                     at: CGPoint(x: content.minX, y: y), font: .systemFont(ofSize: 12), color: Theme.textPrimary)
            y -= 20
            drawText("Requires: not wanted  ·  Police rep ≥ \(PlayerWarehouse.minPoliceRep)",
                     at: CGPoint(x: content.minX, y: y), font: .systemFont(ofSize: 12), color: Theme.textSecondary)
            y -= 28
            let canRent = !engine.player.isWanted
                && engine.player.rep.repPolice >= PlayerWarehouse.minPoliceRep
                && engine.player.credits >= PlayerWarehouse.rentCost
            drawText(canRent
                     ? "Enter: rent bay (−\(PlayerWarehouse.rentCost) cr)"
                     : "Enter: attempt lease (check credits / standing)",
                     at: CGPoint(x: content.minX, y: y),
                     font: .systemFont(ofSize: 13, weight: .semibold),
                     color: canRent ? Theme.accent : Theme.warning)
            y -= 36
            drawText("Tip: buy cheap in Solara, store here, free hold space for other runs,",
                     at: CGPoint(x: content.minX, y: y), font: .systemFont(ofSize: 11), color: Theme.textMuted)
            y -= 16
            drawText("then withdraw and freelane to sell high.",
                     at: CGPoint(x: content.minX, y: y), font: .systemFont(ofSize: 11), color: Theme.textMuted)
            return
        }

        let used = bay?.usedMass ?? 0
        drawText("Bay \(String(format: "%.0f", used))/\(Int(PlayerWarehouse.bayCapacity)) mass  ·  Qty: \(engine.tradeAmount)  (−/+)",
                 at: CGPoint(x: content.minX, y: y),
                 font: .systemFont(ofSize: 12, weight: .medium), color: Theme.textPrimary)
        y -= 18
        drawText("Enter: deposit from ship  ·  F: withdraw to ship",
                 at: CGPoint(x: content.minX, y: y),
                 font: .systemFont(ofSize: 12, weight: .semibold), color: Theme.accent)
        y -= 24

        let cols: [(String, CGFloat)] = [
            ("Commodity", content.minX),
            ("Ship", content.minX + 180),
            ("Bay", content.minX + 280),
            ("Mass/u", content.minX + 380),
        ]
        for (label, x) in cols {
            drawText(label, at: CGPoint(x: x, y: y),
                     font: .systemFont(ofSize: 10, weight: .bold), color: Theme.accentDim)
        }
        y -= 8
        ctxStrokeLine(from: CGPoint(x: content.minX, y: y), to: CGPoint(x: content.maxX, y: y), color: Theme.panelBorder)
        y -= 18

        for (i, c) in Commodity.allCases.enumerated() {
            let selected = i == engine.tradeCommodityIndex
            if selected {
                Theme.accent.withAlphaComponent(0.12).setFill()
                NSBezierPath(rect: CGRect(x: content.minX - 4, y: y - 4, width: content.width + 8, height: 20)).fill()
            }
            let col = selected ? Theme.accent : Theme.textPrimary
            let shipHave = engine.player.cargo[c, default: 0]
            let bayHave = bay?.cargo[c, default: 0] ?? 0
            drawText(c.rawValue, at: CGPoint(x: content.minX, y: y),
                     font: .systemFont(ofSize: 12, weight: selected ? .bold : .regular), color: col)
            drawText("\(shipHave)", at: CGPoint(x: content.minX + 180, y: y),
                     font: .monospacedDigitSystemFont(ofSize: 12, weight: .regular), color: col)
            drawText("\(bayHave)", at: CGPoint(x: content.minX + 280, y: y),
                     font: .monospacedDigitSystemFont(ofSize: 12, weight: .regular),
                     color: bayHave > 0 ? Theme.gold : Theme.textSecondary)
            drawText(String(format: "%.1f", c.unitMass), at: CGPoint(x: content.minX + 380, y: y),
                     font: .monospacedDigitSystemFont(ofSize: 12, weight: .regular), color: Theme.textMuted)
            y -= 20
        }
    }

    private static func drawStatusTab(content: CGRect, engine: GameEngine, station: Station) {
        let p = engine.player
        var y = content.maxY - 10
        let statusTitle = station.isEnemyBase
            ? "Ship Status — \(station.faction) ☠ ENEMY BASE"
            : "Ship Status — \(station.faction)"
        drawText(statusTitle, at: CGPoint(x: content.minX, y: y),
                 font: .systemFont(ofSize: 14, weight: .semibold),
                 color: station.isEnemyBase ? Theme.pirate : Theme.textPrimary)
        y -= 28
        let planets = p.discoveredPlanets.count
        let wrecks = p.discoveredWrecks.count
        let mods = p.unlockedBlueprints.isEmpty
            ? "none"
            : p.unlockedBlueprints.map(\.displayName).sorted().joined(separator: ", ")
        let rep = p.rep
        let inv = p.investment(system: engine.currentSystemName, station: station.name)
        let investLine: String
        if let inv {
            let disc = Int((inv.buyDiscount * 100).rounded())
            let bonus = Int((inv.sellBonus * 100).rounded())
            investLine = "Stake: \(inv.tierLabel) (Lv\(inv.level)) · −\(disc)% buy / +\(bonus)% sell"
        } else {
            investLine = "Stake: none · invest for permanent trade rates + berth"
        }
        let berthLine = inv.map { "Berth: \($0.berthName)" } ?? "Berth: public docking only"
        let hidden = p.hiddenCargoUsed
        let loanLine = p.loanOutstanding > 0
            ? "Loan: \(p.loanOutstanding) cr owed (\(Player.loanPaymentPerDock)/dock)"
            : "Loan: none"
        let insLine = p.insured ? "Insurance: ACTIVE (respawn last dock)" : "Insurance: none — buy at Outfitter"
        let protLine: String = {
            if let s = p.pirateProtectionSeconds, s > 0 {
                return "Protection: \(Int(s))s remaining"
            }
            return "Protection: none (Umbra / dens / black markets)"
        }()
        let gunName = p.hangarPrimaryWeapon?.name ?? "Unarmed"
        let lines = [
            "Hull role / career: \(p.shipClass.displayName)",
            "Hull: \(Int(p.hull))/\(Int(p.stats.maxHull))   Shields: \(Int(p.shield))/\(Int(p.stats.maxShield))",
            "Cargo: \(String(format: "%.0f", p.cargoUsed))/\(String(format: "%.0f", p.stats.cargoCapacity))  ·  Hidden: \(String(format: "%.0f", hidden))/\(String(format: "%.0f", Player.hiddenCargoCapacity))",
            "Wanted: \(rep.wantedLabel) (\(rep.wantedLevel)/5)   Dirty: \(p.isDirty ? "yes" : "no")",
            "Rep  Police \(rep.repPolice)  ·  Militia \(rep.repMilitia)  ·  Pirate \(rep.repPirate)",
            investLine,
            berthLine,
            insLine,
            loanLine,
            protLine,
            "Kills: \(p.kills)   Missions: \(p.missionsCompleted)   Discoveries: +\(p.discoveryCreditsEarned) cr",
            "Mk amps: Gun \(p.weaponLevel)  Drive \(p.engineLevel)  Shd \(p.shieldLevel)  Pwr \(p.energyLevel)  Hold \(p.cargoLevel)",
            "Primary: \(gunName)  ·  Energy \(Int(p.energy))/\(Int(p.stats.maxEnergy))  ·  MSL \(p.missiles)/\(Player.maxMissiles)",
            "Blueprints: \(mods)",
        ]
        for line in lines {
            let isInvest = line.hasPrefix("Stake:") || line.hasPrefix("Berth:")
            drawText(line, at: CGPoint(x: content.minX, y: y),
                     font: .systemFont(ofSize: 12),
                     color: isInvest ? Theme.gold : Theme.textSecondary)
            y -= 17
        }
        y -= 6
        if p.isWanted, station.faction == "Militia" {
            drawText("Enter: pay fine (\(rep.fineCost()) cr) to clear warrants",
                     at: CGPoint(x: content.minX, y: y),
                     font: .systemFont(ofSize: 12, weight: .medium), color: Theme.warning)
        } else if p.hull < p.stats.maxHull {
            drawText("Enter: repair hull",
                     at: CGPoint(x: content.minX, y: y),
                     font: .systemFont(ofSize: 12, weight: .medium), color: Theme.accent)
        } else if let cost = engine.nextInvestmentCost {
            let lvl = inv?.level ?? 0
            let next = lvl == 0 ? "Shareholder" : (lvl == 1 ? "Partner" : "Patron")
            drawText("Enter: invest → \(next) (\(cost) cr)  ·  F shields  ·  wingman if full",
                     at: CGPoint(x: content.minX, y: y),
                     font: .systemFont(ofSize: 11, weight: .medium), color: Theme.gold)
        } else {
            drawText("Enter: recharge / hire wingman (\(GameEngine.wingmanHireCost) cr)  ·  Patron maxed",
                     at: CGPoint(x: content.minX, y: y),
                     font: .systemFont(ofSize: 12, weight: .medium), color: Theme.accent)
        }
        y -= 18
        drawText(engine.hasWingman ? "Wingman: ACTIVE" : "Wingman: none",
                 at: CGPoint(x: content.minX, y: y),
                 font: .systemFont(ofSize: 11), color: engine.hasWingman ? Theme.hull : Theme.textMuted)
        if let eid = engine.escortShipID, let h = engine.npcs.first(where: { $0.id == eid }) {
            y -= 16
            drawText("Escort: \(h.name) nearby", at: CGPoint(x: content.minX, y: y),
                     font: .systemFont(ofSize: 11), color: Theme.gold)
        }

        // Cargo list
        y -= 36
        drawText("Cargo Manifest", at: CGPoint(x: content.minX, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: Theme.textPrimary)
        y -= 22
        if p.cargo.isEmpty {
            drawText("Empty hold.", at: CGPoint(x: content.minX, y: y),
                     font: .systemFont(ofSize: 12), color: Theme.textMuted)
        } else {
            for (c, n) in p.cargo.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                drawText("\(c.rawValue): \(n)", at: CGPoint(x: content.minX, y: y),
                         font: .systemFont(ofSize: 12), color: Theme.textSecondary)
                y -= 18
            }
        }
        if !p.smuggleHold.isEmpty {
            y -= 14
            drawText("Hidden hold", at: CGPoint(x: content.minX, y: y),
                     font: .systemFont(ofSize: 12, weight: .semibold), color: Theme.warning)
            y -= 16
            for (c, n) in p.smuggleHold.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                drawText("\(c.rawValue): \(n)", at: CGPoint(x: content.minX, y: y),
                         font: .systemFont(ofSize: 12), color: Theme.warning)
                y -= 16
            }
        }
    }

    private static func drawTradeTab(content: CGRect, engine: GameEngine, station: Station) {
        let inv = engine.player.investment(system: engine.currentSystemName, station: station.name)
        let invNote = inv.map { " · Investor \($0.tierLabel)" } ?? ""
        drawText("Commodity Exchange  ·  Qty: \(engine.tradeAmount)  (−/+)\(invNote)",
                 at: CGPoint(x: content.minX, y: content.maxY - 10),
                 font: .systemFont(ofSize: 13, weight: .semibold),
                 color: inv != nil ? Theme.gold : Theme.textPrimary)

        // Header
        var y = content.maxY - 40
        let cols: [(String, CGFloat)] = [
            ("Commodity", content.minX),
            ("You have", content.minX + 160),
            ("Buy (you pay)", content.minX + 250),
            ("Sell (they pay)", content.minX + 380),
            ("Stock", content.minX + 520),
        ]
        for (label, x) in cols {
            drawText(label, at: CGPoint(x: x, y: y),
                     font: .systemFont(ofSize: 10, weight: .bold), color: Theme.accentDim)
        }
        y -= 8
        ctxStrokeLine(from: CGPoint(x: content.minX, y: y), to: CGPoint(x: content.maxX, y: y), color: Theme.panelBorder)

        y -= 20
        for (i, c) in Commodity.allCases.enumerated() {
            let selected = i == engine.tradeCommodityIndex
            let offer = station.market[c]
            let have = engine.player.cargo[c, default: 0]
            if selected {
                Theme.accent.withAlphaComponent(0.12).setFill()
                NSBezierPath(rect: CGRect(x: content.minX - 4, y: y - 4, width: content.width + 8, height: 20)).fill()
            }
            let col = selected ? Theme.accent : Theme.textPrimary
            let prices: (playerPays: Int, stationPays: Int) = {
                guard let o = offer else { return (0, 0) }
                return engine.effectiveTradePrice(offer: o, station: station)
            }()
            drawText(c.rawValue, at: CGPoint(x: content.minX, y: y), font: .systemFont(ofSize: 12, weight: selected ? .bold : .regular), color: col)
            drawText("\(have)", at: CGPoint(x: content.minX + 160, y: y), font: .monospacedDigitSystemFont(ofSize: 12, weight: .regular), color: col)
            drawText("\(prices.playerPays) cr", at: CGPoint(x: content.minX + 250, y: y), font: .monospacedDigitSystemFont(ofSize: 12, weight: .regular), color: Theme.warning)
            drawText("\(prices.stationPays) cr", at: CGPoint(x: content.minX + 380, y: y), font: .monospacedDigitSystemFont(ofSize: 12, weight: .regular), color: Theme.hull)
            drawText("\(offer?.stock ?? 0)", at: CGPoint(x: content.minX + 520, y: y), font: .monospacedDigitSystemFont(ofSize: 12, weight: .regular), color: Theme.textSecondary)
            y -= 22
        }

        drawText("Enter = BUY   ·   F = SELL\(inv != nil ? "   ·   rates include your stake" : "")",
                 at: CGPoint(x: content.minX, y: content.minY + 8),
                 font: .systemFont(ofSize: 12, weight: .medium), color: Theme.accent)
    }

    private static func drawMissionsTab(content: CGRect, engine: GameEngine) {
        var y = content.maxY - 10
        drawText("Mission Board", at: CGPoint(x: content.minX, y: y),
                 font: .systemFont(ofSize: 14, weight: .semibold), color: Theme.textPrimary)
        y -= 28

        var idx = 0
        drawText("AVAILABLE", at: CGPoint(x: content.minX, y: y),
                 font: .systemFont(ofSize: 10, weight: .bold), color: Theme.accentDim)
        y -= 20
        if engine.stationMissions.isEmpty {
            drawText("No new contracts.", at: CGPoint(x: content.minX, y: y),
                     font: .systemFont(ofSize: 12), color: Theme.textMuted)
            y -= 22
        }
        for m in engine.stationMissions {
            let selected = idx == engine.missionSelectIndex
            drawMissionRow(m, at: y, content: content, selected: selected, tag: "Accept")
            y -= 48
            idx += 1
        }

        y -= 8
        drawText("ACTIVE", at: CGPoint(x: content.minX, y: y),
                 font: .systemFont(ofSize: 10, weight: .bold), color: Theme.accentDim)
        y -= 20
        if engine.activeMissions.isEmpty {
            drawText("No active missions.", at: CGPoint(x: content.minX, y: y),
                     font: .systemFont(ofSize: 12), color: Theme.textMuted)
        }
        for m in engine.activeMissions {
            let selected = idx == engine.missionSelectIndex
            let ready = m.progress >= m.target || {
                if case .delivery = m.kind { return false }
                if case .explore = m.kind { return m.progress >= 1 }
                if case .escort = m.kind { return m.progress >= 1 }
                return false
            }()
            // delivery readiness checked on turn-in
            drawMissionRow(m, at: y, content: content, selected: selected,
                           tag: ready ? "Turn in" : "\(m.progress)/\(m.target)")
            y -= 48
            idx += 1
        }

        drawText("Enter to accept or turn in selected mission", at: CGPoint(x: content.minX, y: content.minY + 8),
                 font: .systemFont(ofSize: 11), color: Theme.accent)
    }

    private static func drawMissionRow(_ m: Mission, at y: CGFloat, content: CGRect, selected: Bool, tag: String) {
        if selected {
            Theme.accent.withAlphaComponent(0.12).setFill()
            NSBezierPath(roundedRect: CGRect(x: content.minX - 4, y: y - 28, width: content.width + 8, height: 44),
                         xRadius: 6, yRadius: 6).fill()
        }
        let col = selected ? Theme.accent : Theme.textPrimary
        var title = m.title
        if m.isSmuggle == true { title = "🔒 " + title }
        if m.isDirty == true { title = "⚠ " + title }
        if m.timeLimit != nil || m.timeRemaining != nil { title = "⏱ " + title }
        drawText(title, at: CGPoint(x: content.minX, y: y),
                 font: .systemFont(ofSize: 12, weight: .semibold), color: col)
        drawText("\(m.reward) cr", at: CGPoint(x: content.maxX, y: y),
                 font: .monospacedDigitSystemFont(ofSize: 12, weight: .bold), color: Theme.gold, align: .right)
        var desc = m.description
        if let rem = m.timeRemaining {
            let sec = max(0, Int(rem.rounded()))
            desc = "⏱ \(sec / 60):\(String(format: "%02d", sec % 60)) left · " + desc
        } else if let lim = m.timeLimit {
            desc = "⏱ \(Int(lim))s limit · " + desc
        }
        drawText(desc, at: CGPoint(x: content.minX, y: y - 16),
                 font: .systemFont(ofSize: 11), color: Theme.textSecondary)
        drawText(tag, at: CGPoint(x: content.maxX, y: y - 16),
                 font: .systemFont(ofSize: 10, weight: .medium), color: Theme.warning, align: .right)
    }

    private static func drawOutfitTab(content: CGRect, engine: GameEngine, station: Station) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let p = engine.player
        // Career / hull role browse is outfit index 7 (modular hangar Hull is separate)
        let previewHull = engine.outfitSelectIndex == 7 ? engine.shipClassPreview : p.shipClass
        let hullOwned = p.rep.ownedShips.contains(previewHull) || previewHull == .hybrid
        let hullTitle = engine.outfitSelectIndex == 7
            ? "Hull Role / Career: \(previewHull.displayName)"
            : "Hull Role / Career: \(p.shipClass.displayName)"
        let hullSub: String
        if engine.outfitSelectIndex == 7 {
            if hullOwned {
                hullSub = previewHull == p.shipClass
                    ? "\(previewHull.blurb) · active role · hangar parts re-fit after swap"
                    : "Owned · Enter swap · Mk kept · re-fit hangar parts after swap"
            } else {
                hullSub = "\(previewHull.blurb) · \(previewHull.purchaseCost) cr · Enter buy · Mk kept · re-fit hangar after"
            }
        } else {
            hullSub = "\(p.shipClass.blurb) · −/+ Hybrid · Freighter · Interceptor (not hangar Hull)"
        }
        let fine = p.rep.fineCost()
        let fineSub: String
        if !p.isWanted {
            fineSub = "No warrants on file"
        } else if station.faction == "Militia" {
            fineSub = "Clear wanted \(p.rep.wantedLabel) for \(fine) cr"
        } else {
            fineSub = "Dock at a Militia station (e.g. Fort Kestrel, Border Watch)"
        }
        // Paint/livery is hangar-only. Outfit = Mk amps, services, ammo; Hangar = modules + guns.
        let engSub = p.engineLevel >= 5
            ? "MAX — drive amp stacks on hangar Engines"
            : "Drive amp (stacks hangar Engines) → Mk\(p.engineLevel + 1)  (\(1000 * p.engineLevel) cr)"
        let shdSub = p.shieldLevel >= 5
            ? "MAX — shield amp stacks on hangar Shields"
            : "Shield amp (stacks hangar Shields) → Mk\(p.shieldLevel + 1)  (\(1100 * p.shieldLevel) cr)"
        let enrSub = p.energyLevel >= 5
            ? "MAX — power amp for hangar guns & regen"
            : "Power amp (stacks hangar reactor/hull)  (\(1150 * p.energyLevel) cr)"
        let mslFullSub = "Full · B classic missiles (key 5 toggles hangar secondary)"
        let mslBuySub = "+\(min(Player.missilePackSize, Player.maxMissiles - p.missiles)) · \(Player.missilePackCost) cr · B classic / hangar Seekers"
        let mineFullSub = "Full · J classic drop · hangar Mines use B-mode secondary"
        let mineBuySub = "+\(min(Player.minePackSize, p.maxMinesForClass - p.mineStock)) · \(Player.minePackCost) cr · J drop (classic)"
        var items: [(String, String, Int, Bool)] = [
            ("Gun Amplifiers Mk\(p.weaponLevel)",
             p.weaponLevel >= 5 ? "MAX — scales hangar primary DPS"
                : "Scales hangar primary damage → Mk\(p.weaponLevel + 1)  (\(1200 * p.weaponLevel) cr)", 0, false),
            ("Drive Amplifiers Mk\(p.engineLevel)", engSub, 1, false),
            ("Shield Amplifiers Mk\(p.shieldLevel)", shdSub, 2, false),
            ("Power Amplifiers Mk\(p.energyLevel)", enrSub, 3, false),
            ("Cargo Hold Mk\(p.cargoLevel)", p.cargoLevel >= 5 ? "MAX — no hangar equivalent"
                : "Hold size only (hangar has no cargo slot) → Mk\(p.cargoLevel + 1)  (\(900 * p.cargoLevel) cr)", 4, false),
            ("Full Repair", "Service: restore hull (\(Int(ceil(p.stats.maxHull - p.hull)) * station.repairCostPerHull) cr)", 5, false),
            ("Wingman: \(engine.wingmanRolePreview.displayName)", engine.hasWingman
                ? "\(engine.activeWingmanName()) active · −/+ browse next hire"
                : "\(engine.wingmanRolePreview.blurb) · \(engine.wingmanHireCostCurrent()) cr · −/+ role", 6, false),
            (hullTitle, hullSub, 7, false),
            ("Clear Wanted", fineSub, 8, false),
            ("Missiles \(p.missiles)/\(Player.maxMissiles)",
             p.missiles >= Player.maxMissiles ? mslFullSub : mslBuySub, 9, false),
            ("Hull Insurance", p.ironmanMode
                ? "Unavailable on Ironman"
                : (p.insured ? "ACTIVE — respawn at last dock on death" : "\(Player.insurancePremium) cr · respawn last dock (−fee)"), 10, false),
            ("Freighter Loan", p.loanOutstanding > 0
                ? "Owed \(p.loanOutstanding) cr · Enter pay · \(Player.loanPaymentPerDock)/dock auto"
                : (p.rep.ownedShips.contains(.freighter)
                    ? "You already own a freighter"
                    : "Down \(Player.freighterLoanDownPayment) cr · owe \(Player.freighterLoanAmount)"), 11, false),
            ("Pirate Protection", {
                if let s = p.pirateProtectionSeconds, s > 0 {
                    return "Active \(Int(s))s · Enter extend \(Player.pirateProtectionFee) cr"
                }
                return "Umbra/dens/black market · \(Player.pirateProtectionFee) cr · pirates stand down"
            }(), 12, false),
            ("Mines \(p.mineStock)/\(p.maxMinesForClass)",
             p.mineStock >= p.maxMinesForClass ? mineFullSub : mineBuySub, 13, false),
            ("Chaff \(p.cmStock)/\(p.maxCMForClass)",
             p.cmStock >= p.maxCMForClass ? "Racks full · K breaks missile locks"
                : "+\(min(Player.cmPackSize, p.maxCMForClass - p.cmStock)) · \(Player.cmPackCost) cr · K deploy · no hangar slot", 14, false),
            ("Ship Hangar", "Hull · Wings · Engines · Primary · Secondary · Shields · Utility · Livery · Enter open", 15, false),
        ]
        if engine.isAlienOutfitter {
            for (i, tech) in Blueprint.alienTech.enumerated() {
                let owned = p.unlockedBlueprints.contains(tech)
                let sub = owned ? "INSTALLED · \(tech.blurb)" : "\(tech.blurb) · \(tech.alienPurchaseCost) cr"
                items.append(("✦ \(tech.displayName)", sub, GameEngine.outfitBaseRowCount + i, true))
            }
        }

        let header = engine.isAlienOutfitter ? "Outfitter · VAEL TECH" : "Outfitter & Services"
        drawText(header, at: CGPoint(x: content.minX, y: content.maxY - 4),
                 font: .systemFont(ofSize: 14, weight: .semibold),
                 color: engine.isAlienOutfitter ? Theme.alien : Theme.textPrimary)

        // Scrollable list viewport (CG y ↑). Leave a clear band under the header so the
        // first row title (Weapons) is never clipped when firstVisible == 0.
        let rowH: CGFloat = 40
        let listTopY = content.maxY - 34   // top edge of viewport (below header)
        let listBotY = content.minY + 18   // bottom edge (above ▼ hint)
        let viewportH = max(rowH, listTopY - listBotY)
        let visibleRows = max(1, Int(floor(viewportH / rowH)))
        let selectedPos = items.firstIndex(where: { $0.2 == engine.outfitSelectIndex }) ?? 0

        // Keep the selected row fully inside the viewport.
        let maxFirst = max(0, items.count - visibleRows)
        var firstVisible = 0
        if selectedPos >= visibleRows {
            firstVisible = selectedPos - visibleRows + 1
        }
        firstVisible = min(max(0, firstVisible), maxFirst)

        let clipRect = CGRect(
            x: content.minX - 6,
            y: listBotY,
            width: content.width + 12,
            height: viewportH
        )
        ctx.saveGState()
        ctx.clip(to: clipRect)

        for (i, item) in items.enumerated() {
            let (title, subtitle, idx, isAlien) = item
            let slot = i - firstVisible
            // Full row band from top of viewport downward
            let rowTop = listTopY - CGFloat(slot) * rowH
            let rowBot = rowTop - rowH
            // Skip rows fully outside the viewport
            guard rowBot < listTopY && rowTop > listBotY else { continue }

            // Title baseline sits inside the row with room for glyphs above;
            // subtitle sits under the title. (NSString.draw origin = bottom-left of text.)
            let titleY = rowTop - 18
            let subY = titleY - 14

            let selected = idx == engine.outfitSelectIndex
            if selected {
                (isAlien ? Theme.alien : Theme.accent).withAlphaComponent(0.18).setFill()
                NSBezierPath(
                    roundedRect: CGRect(x: content.minX - 4, y: rowBot + 3,
                                        width: content.width + 8, height: rowH - 6),
                    xRadius: 6, yRadius: 6
                ).fill()
            }
            let titleCol = selected
                ? (isAlien ? Theme.alien : Theme.accent)
                : (isAlien ? Theme.alien : Theme.textPrimary)
            drawText(title, at: CGPoint(x: content.minX, y: titleY),
                     font: .systemFont(ofSize: 12, weight: selected ? .bold : .medium),
                     color: titleCol)
            drawText(subtitle, at: CGPoint(x: content.minX, y: subY),
                     font: .systemFont(ofSize: 10), color: Theme.textSecondary)
        }
        ctx.restoreGState()

        // Scroll hints (outside clip so they stay readable)
        if firstVisible > 0 {
            drawText("▲ more · ↑", at: CGPoint(x: content.maxX, y: content.maxY - 20),
                     font: .systemFont(ofSize: 9, weight: .semibold), color: Theme.accent, align: .right)
        }
        if firstVisible + visibleRows < items.count {
            drawText("▼ more · ↓", at: CGPoint(x: content.maxX, y: content.minY + 4),
                     font: .systemFont(ofSize: 9, weight: .semibold), color: Theme.accent, align: .right)
        }
    }

    private static func drawUndockTab(content: CGRect, engine: GameEngine) {
        drawText("Ready to launch?", at: CGPoint(x: content.midX, y: content.midY + 20),
                 font: .systemFont(ofSize: 18, weight: .bold), color: Theme.textPrimary, align: .center)
        drawText("Press Enter or F to undock into \(engine.currentSystem.displayName).",
                 at: CGPoint(x: content.midX, y: content.midY - 10),
                 font: .systemFont(ofSize: 13), color: Theme.accent, align: .center)
        drawText("Safe flying, pilot.", at: CGPoint(x: content.midX, y: content.midY - 36),
                 font: .systemFont(ofSize: 12), color: Theme.textSecondary, align: .center)
    }

    // MARK: - Ship Hangar (Spacecraft Builder)

    private static func drawHangar(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        let panelW = min(920, bounds.width - 48)
        let panelH = min(620, bounds.height - 40)
        let panel = CGRect(x: (bounds.width - panelW) / 2, y: (bounds.height - panelH) / 2,
                           width: panelW, height: panelH)
        drawPanel(ctx: ctx, rect: panel, radius: 14)

        drawText("SHIP HANGAR", at: CGPoint(x: panel.minX + 28, y: panel.maxY - 36),
                 font: .systemFont(ofSize: 22, weight: .bold), color: Theme.accent)
        let stName = engine.dockedStation?.name ?? "Station"
        drawText("\(stName) · \(engine.hangarDraft.name) · \(engine.player.credits) cr",
                 at: CGPoint(x: panel.minX + 28, y: panel.maxY - 58),
                 font: .systemFont(ofSize: 12), color: Theme.gold)
        drawText("Modules + weapons + livery · Outfit Mk amps / ammo / services stack on top",
                 at: CGPoint(x: panel.minX + 28, y: panel.maxY - 74),
                 font: .systemFont(ofSize: 10), color: Theme.textMuted)

        // Slot chips (top strip) — leave room for subtitle under station line
        let slots = PartSlot.allCases
        let chipW = (panelW - 56) / CGFloat(slots.count)
        var chipX = panel.minX + 28
        let chipY = panel.maxY - 112
        for slot in slots {
            let active = slot == engine.hangarSlot
            let chip = CGRect(x: chipX, y: chipY, width: chipW - 6, height: 28)
            if active {
                Theme.accent.withAlphaComponent(0.22).setFill()
                NSBezierPath(roundedRect: chip, xRadius: 6, yRadius: 6).fill()
                Theme.accent.setStroke()
                let bp = NSBezierPath(roundedRect: chip, xRadius: 6, yRadius: 6)
                bp.lineWidth = 1.5
                bp.stroke()
            }
            drawText(slot.shortLabel, at: CGPoint(x: chip.midX, y: chip.midY - 6),
                     font: .systemFont(ofSize: 10, weight: active ? .bold : .medium),
                     color: active ? Theme.accent : Theme.textMuted, align: .center)
            chipX += chipW
        }

        // Left: part list
        let listX = panel.minX + 28
        let listTop = chipY - 20
        let listBottom = panel.minY + 48
        let parts = PartsCatalog.parts(for: engine.hangarSlot)
        let rowH: CGFloat = 36
        let visible = max(1, Int((listTop - listBottom) / rowH))
        var first = 0
        if engine.hangarPartIndex >= visible {
            first = engine.hangarPartIndex - visible + 1
        }
        first = min(max(0, first), max(0, parts.count - visible))

        drawText(engine.hangarSlot.label.uppercased(),
                 at: CGPoint(x: listX, y: listTop + 4),
                 font: .systemFont(ofSize: 11, weight: .bold), color: Theme.gold)

        for (i, part) in parts.enumerated() {
            let slotIdx = i - first
            guard slotIdx >= 0, slotIdx < visible else { continue }
            let y = listTop - 18 - CGFloat(slotIdx) * rowH
            let selected = i == engine.hangarPartIndex
            if selected {
                Theme.accent.withAlphaComponent(0.16).setFill()
                NSBezierPath(roundedRect: CGRect(x: listX - 4, y: y - 10, width: panelW * 0.42, height: 32),
                             xRadius: 6, yRadius: 6).fill()
            }
            let equipped = engine.hangarDraft.loadout[part.slot] == part.id
            let owned = engine.player.ownedShipParts?.contains(part.id) == true
            let cost = engine.hangarInstallCost(for: part)
            let isPremiumGun = ShipDesign.purchasablePrimaryWeaponIDs.contains(part.id)
            let titleCol = selected ? Theme.accent : (equipped ? Theme.gold : Theme.textPrimary)
            let mark = equipped ? "● " : (owned ? "○ " : (isPremiumGun ? "🔒 " : "  "))
            let price: String
            if equipped {
                price = "fitted"
            } else if owned || cost == 0 {
                price = owned ? "owned · Enter fit" : "free"
            } else {
                price = "\(cost) cr · Enter buy"
            }
            drawText(mark + part.name, at: CGPoint(x: listX, y: y + 2),
                     font: .systemFont(ofSize: 12, weight: selected ? .bold : .medium), color: titleCol)
            drawText("\(part.desc)  ·  \(price)", at: CGPoint(x: listX, y: y - 12),
                     font: .systemFont(ofSize: 10),
                     color: cost > 0 && !owned && !equipped ? Theme.warning : Theme.textMuted)
        }

        // Center: live ship preview
        let previewC = CGPoint(x: panel.midX + 40, y: panel.midY + 10)
        ctx.saveGState()
        ctx.translateBy(x: previewC.x, y: previewC.y)
        ctx.rotate(by: CGFloat(engine.time * 0.35))
        let stats = engine.hangarDraft.computeStats()
        ShipDrawing.draw(
            ctx: ctx,
            stats: stats,
            options: ShipDrawing.Options(
                scale: 3.2,
                thrustGlow: 0.55 + 0.25 * CGFloat(0.5 + 0.5 * sin(engine.time * 10)),
                shieldPulse: stats.maxShield > 0 ? 0.7 : 0,
                damaged: 0,
                rotateToPlusX: true
            )
        )
        ctx.restoreGState()
        // Soft ring under ship
        ctx.setStrokeColor(Theme.accent.withAlphaComponent(0.15).cgColor)
        ctx.setLineWidth(1)
        ctx.strokeEllipse(in: CGRect(x: previewC.x - 70, y: previewC.y - 70, width: 140, height: 140))

        // Right: combat-effective stats (Mk + hangar frame bonuses)
        let sx = panel.maxX - 210
        var sy = panel.maxY - 140
        let combat = engine.player.stats
        drawText("IN FLIGHT (Mk + hangar)", at: CGPoint(x: sx, y: sy),
                 font: .systemFont(ofSize: 11, weight: .bold), color: Theme.gold)
        sy -= 20
        let combatLines = [
            "Hull max  \(Int(combat.maxHull))",
            "Shield max  \(Int(combat.maxShield))",
            "Thrust  \(Int(combat.thrust))",
            "Speed  \(Int(combat.maxSpeed))",
            "Turn  \(String(format: "%.2f", combat.turnRate))",
            "Energy  \(Int(combat.maxEnergy)) · regen \(Int(combat.energyRegen))",
            "Gun Mk  \(engine.player.weaponLevel)",
        ]
        for line in combatLines {
            drawText(line, at: CGPoint(x: sx, y: sy),
                     font: .monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                     color: Theme.textSecondary)
            sy -= 16
        }
        sy -= 8
        drawText("HANGAR FRAME", at: CGPoint(x: sx, y: sy),
                 font: .systemFont(ofSize: 11, weight: .bold), color: Theme.gold)
        sy -= 18
        let frameLines = [
            "Armor  \(Int(stats.armor))  ·  Shd \(Int(stats.maxShield))",
            "Frame thrust  \(Int(stats.thrust))",
            stats.primary.map { "Primary  \($0.name)" } ?? "Primary  —",
            stats.secondary.map { "Secondary  \($0.name)" } ?? "Secondary  —",
            String(format: "Hangar DPS  %.0f", stats.dps),
        ]
        for line in frameLines {
            drawText(line, at: CGPoint(x: sx, y: sy),
                     font: .monospacedDigitSystemFont(ofSize: 10, weight: .regular),
                     color: Theme.textMuted)
            sy -= 15
        }

        drawText("←/→ slots  ·  ↑/↓ browse  ·  Enter buy/fit  ·  R randomize  ·  Esc finish (docked only)",
                 at: CGPoint(x: panel.midX, y: panel.minY + 16),
                 font: .systemFont(ofSize: 11), color: Theme.textMuted, align: .center)
    }

    // MARK: - Menus

    private static func drawTitle(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        // Decorative gate ring + hero ship
        let cx = bounds.midX
        let cy = bounds.midY + 90
        for i in 0..<4 {
            let r = 70 + CGFloat(i) * 30
            ctx.setStrokeColor(Theme.accent.withAlphaComponent(0.12 + CGFloat(i) * 0.05).cgColor)
            ctx.setLineWidth(2)
            ctx.strokeEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        }
        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.rotate(by: CGFloat(engine.time * 0.15))
        ShipArt.draw(ctx: ctx, style: Self.playerArtStyle(engine.player.shipClass), scale: 42,
                     accent: engine.player.paintJob.accent,
                     time: engine.time, paint: engine.player.paintJob,
                     modularDesign: engine.player.shipDesign, thrustGlow: 0.55)
        ctx.restoreGState()

        drawText("STARLANE", at: CGPoint(x: cx, y: bounds.height * 0.72),
                 font: .systemFont(ofSize: 52, weight: .heavy), color: Theme.accent, align: .center)
        let ver = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.31"
        drawText("v\(ver)  ·  Freelance the frontier. Trade. Fight. Survive.",
                 at: CGPoint(x: cx, y: bounds.height * 0.72 - 36),
                 font: .systemFont(ofSize: 14), color: Theme.textSecondary, align: .center)

        let items = engine.titleItems
        var y = bounds.height * 0.42
        for (i, item) in items.enumerated() {
            let selected = i == engine.titleMenuIndex
            let prefix = selected ? "▸ " : "  "
            drawText(prefix + item, at: CGPoint(x: cx, y: y),
                     font: .systemFont(ofSize: selected ? 18 : 15, weight: selected ? .bold : .regular),
                     color: selected ? Theme.gold : Theme.textSecondary, align: .center)
            y -= 32
        }

        if let info = engine.saveInfo {
            drawText("Save: \(info)", at: CGPoint(x: cx, y: 48),
                     font: .systemFont(ofSize: 11), color: Theme.textMuted, align: .center)
        }
        drawText("↑↓ select  ·  Enter confirm  ·  M mute", at: CGPoint(x: cx, y: 28),
                 font: .systemFont(ofSize: 11), color: Theme.textMuted, align: .center)
    }

    private static func drawHowToPlay(ctx: CGContext, bounds: CGRect) {
        let panelW = min(640, bounds.width - 80)
        let panelH = min(520, bounds.height - 80)
        let panel = CGRect(x: (bounds.width - panelW) / 2, y: (bounds.height - panelH) / 2,
                           width: panelW, height: panelH)
        drawPanel(ctx: ctx, rect: panel, radius: 12)
        drawText("How to Play", at: CGPoint(x: panel.minX + 24, y: panel.maxY - 36),
                 font: .systemFont(ofSize: 20, weight: .bold), color: Theme.accent)

        let lines = [
            "FLIGHT",
            "  A/D turn · W/S thrust · Space fire hangar primary gun",
            "  Q / 1–4  Cycle owned hangar guns (Pulse Laser free)",
            "  B secondary/missiles · T target · J mines · K chaff",
            "",
            "INTERACT",
            "  F dock / freelane / jump · R mine / survey",
            "",
            "STATIONS (docked)",
            "  Outfit: Mk amps, cargo, ammo, services · Hangar: modules & guns",
            "  Drive/Shield/Power Mk stack on hangar Engines/Shields/Utility",
            "  Gun Amplifiers Mk scale hangar primary damage",
            "  B classic missiles (Outfit ammo) · 5 toggles hangar secondary",
            "  J mines / K chaff = Outfit ammo · hangar Mines also on B",
            "",
            "REPUTATION",
            "  Kill traders → heat; kill pirates → law likes you",
            "  Wanted? Pay fine at Militia stations",
            "",
            "Press Esc or Enter to return",
        ]
        var y = panel.maxY - 70
        for line in lines {
            let isHeader = line == line.uppercased() && !line.isEmpty && !line.hasPrefix(" ")
            drawText(line, at: CGPoint(x: panel.minX + 28, y: y),
                     font: .systemFont(ofSize: isHeader ? 12 : 12, weight: isHeader ? .bold : .regular),
                     color: isHeader ? Theme.gold : Theme.textSecondary)
            y -= 20
        }
    }

    private static func drawSettings(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        if engine.settingsShowControls {
            drawControlsReference(ctx: ctx, bounds: bounds)
            return
        }

        let panelW: CGFloat = 420
        let panelH: CGFloat = 300
        let panel = CGRect(x: (bounds.width - panelW) / 2, y: (bounds.height - panelH) / 2,
                           width: panelW, height: panelH)
        drawPanel(ctx: ctx, rect: panel, radius: 12)
        drawText("Settings", at: CGPoint(x: panel.midX, y: panel.maxY - 36),
                 font: .systemFont(ofSize: 20, weight: .bold), color: Theme.accent, align: .center)

        let audio = AudioManager.shared
        let items = [
            "Mute All: \(audio.muted ? "ON" : "OFF")",
            "Music: \(audio.musicEnabled ? "ON" : "OFF")",
            "Sound FX: \(audio.sfxEnabled ? "ON" : "OFF")",
            "Controls…",
        ]
        var y = panel.midY + 48
        for (i, item) in items.enumerated() {
            let selected = i == engine.settingsMenuIndex
            let prefix = selected ? "▸ " : "  "
            drawText(prefix + item, at: CGPoint(x: panel.midX, y: y),
                     font: .systemFont(ofSize: 15, weight: selected ? .bold : .regular),
                     color: selected ? Theme.gold : Theme.textSecondary, align: .center)
            y -= 36
        }
        drawText("↑↓ select  ·  Space / Enter  ·  Esc back", at: CGPoint(x: panel.midX, y: panel.minY + 24),
                 font: .systemFont(ofSize: 11), color: Theme.textMuted, align: .center)
    }

    private static func drawControlsReference(ctx: CGContext, bounds: CGRect) {
        let panelW = min(640, bounds.width - 60)
        let panelH = min(560, bounds.height - 50)
        let panel = CGRect(x: (bounds.width - panelW) / 2, y: (bounds.height - panelH) / 2,
                           width: panelW, height: panelH)
        drawPanel(ctx: ctx, rect: panel, radius: 12)
        drawText("CONTROLS", at: CGPoint(x: panel.midX, y: panel.maxY - 32),
                 font: .systemFont(ofSize: 20, weight: .bold), color: Theme.accent, align: .center)

        let colL = panel.minX + 28
        let colR = panel.midX + 12
        var yL = panel.maxY - 68
        var yR = panel.maxY - 68

        func section(_ title: String, left: Bool) {
            let x = left ? colL : colR
            var y = left ? yL : yR
            drawText(title, at: CGPoint(x: x, y: y),
                     font: .systemFont(ofSize: 12, weight: .bold), color: Theme.gold)
            y -= 20
            if left { yL = y } else { yR = y }
        }
        func row(_ key: String, _ action: String, left: Bool) {
            let x = left ? colL : colR
            var y = left ? yL : yR
            drawText(key, at: CGPoint(x: x, y: y),
                     font: .monospacedSystemFont(ofSize: 12, weight: .semibold), color: Theme.accent)
            drawText(action, at: CGPoint(x: x + 118, y: y),
                     font: .systemFont(ofSize: 12), color: Theme.textSecondary)
            y -= 18
            if left { yL = y } else { yR = y }
        }

        section("FLIGHT", left: true)
        row("W / ↑", "Thrust", left: true)
        row("S / ↓", "Brake / reverse", left: true)
        row("A/D · ←/→", "Turn", left: true)
        row("S (lane)", "Exit freelane", left: true)

        section("COMBAT", left: true)
        row("Space", "Fire hangar primary gun", left: true)
        row("Q", "Cycle owned hangar guns", left: true)
        row("1–4", "Quick-select owned guns", left: true)
        row("B", "Fire B-mode (missiles or hangar)", left: true)
        row("5", "Toggle B: classic MSL ↔ hangar", left: true)
        row("J", "Drop proximity mine", left: true)
        row("K", "Countermeasures (chaff)", left: true)
        row("L", "Ancient freelane boost", left: true)
        row("T / Tab", "Cycle targets", left: true)
        row("I", "Hold to scan / identify", left: true)

        section("INTERACT", left: false)
        row("F / E", "Dock · jump · freelane", left: false)
        row("R", "Mine asteroid / wreck", left: false)
        row("V / N", "Cycle nav waypoint", left: false)
        row("C", "Clear nav", left: false)
        row("H", "Hold autopilot to NAV", left: false)
        row("U", "Pin/clear trade route", left: false)
        row("Z / X", "System map", left: false)
        row("G", "Galaxy map (+ U pin)", left: false)
        row("Y / O", "Photo / free camera", left: false)

        section("MENUS", left: false)
        row("P / Esc", "Pause", left: false)
        row("M", "Mute audio", left: false)
        row("⌘S / ⌘L", "Save / Load slots", left: false)
        row("⌘N", "New game", left: false)
        row("⌘Q", "Quit", left: false)

        section("DOCKED", left: false)
        row("1–6 · ←/→", "Station tabs", left: false)
        row("↑/↓", "Select item", left: false)
        row("− / +", "Trade qty · wingman role · hull career", left: false)
        row("Outfit Hangar", "Modules, guns, secondaries, livery", left: false)
        row("Enter", "Buy / accept / upgrade", left: false)
        row("F", "Sell (Trade) / shields", left: false)

        drawText("Esc or Enter — back to Settings", at: CGPoint(x: panel.midX, y: panel.minY + 20),
                 font: .systemFont(ofSize: 11), color: Theme.textMuted, align: .center)
    }

    private static func drawPause(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.55).cgColor)
        ctx.fill(bounds)
        let items = ["Resume", "Save Game", "Load Game", "Galaxy Map", "System Map", "Logbook", "Settings", "Title Menu", "Quit"]
        drawText("PAUSED", at: CGPoint(x: bounds.midX, y: bounds.midY + 130),
                 font: .systemFont(ofSize: 28, weight: .bold), color: Theme.accent, align: .center)
        var y = bounds.midY + 65
        for (i, item) in items.enumerated() {
            let selected = i == engine.pauseMenuIndex
            drawText((selected ? "▸ " : "  ") + item, at: CGPoint(x: bounds.midX, y: y),
                     font: .systemFont(ofSize: selected ? 16 : 13, weight: selected ? .bold : .regular),
                     color: selected ? Theme.gold : Theme.textSecondary, align: .center)
            y -= 26
        }
    }

    private static func drawLogbook(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        let panelW = min(640, bounds.width - 80)
        let panelH = min(520, bounds.height - 80)
        let panel = CGRect(x: (bounds.width - panelW) / 2, y: (bounds.height - panelH) / 2,
                           width: panelW, height: panelH)
        drawPanel(ctx: ctx, rect: panel, radius: 12)
        let p = engine.player
        drawText("PILOT LOGBOOK", at: CGPoint(x: panel.midX, y: panel.maxY - 32),
                 font: .systemFont(ofSize: 20, weight: .bold), color: Theme.accent, align: .center)
        if p.ironmanMode {
            drawText(p.ironmanFailed ? "IRONMAN — FAILED" : "IRONMAN — LIVE",
                     at: CGPoint(x: panel.midX, y: panel.maxY - 54),
                     font: .systemFont(ofSize: 12, weight: .bold),
                     color: p.ironmanFailed ? Theme.danger : Theme.warning, align: .center)
        }

        var y = panel.maxY - 80
        drawText("STORY", at: CGPoint(x: panel.minX + 24, y: y),
                 font: .systemFont(ofSize: 11, weight: .bold), color: Theme.gold)
        y -= 18
        for stage in 0..<StoryBeat.count {
            let done = p.storyStage > stage
            let current = p.storyStage == stage
            let mark = done ? "✓" : (current ? "▸" : "·")
            let col = done ? Theme.hull : (current ? Theme.accent : Theme.textMuted)
            drawText("\(mark) \(StoryBeat.title(stage))", at: CGPoint(x: panel.minX + 28, y: y),
                     font: .systemFont(ofSize: 12, weight: current ? .semibold : .regular), color: col)
            y -= 16
            if current {
                drawText("   \(StoryBeat.description(stage))", at: CGPoint(x: panel.minX + 28, y: y),
                         font: .systemFont(ofSize: 10), color: Theme.textSecondary)
                y -= 16
            }
        }
        if p.storyStage >= StoryBeat.count {
            drawText("✓ Campaign complete — Frontier Ace", at: CGPoint(x: panel.minX + 28, y: y),
                     font: .systemFont(ofSize: 12, weight: .semibold), color: Theme.hull)
            y -= 18
        }

        y -= 8
        drawText("STATISTICS", at: CGPoint(x: panel.minX + 24, y: y),
                 font: .systemFont(ofSize: 11, weight: .bold), color: Theme.gold)
        y -= 18
        let stats = [
            "Systems charted: \(p.systemsVisited.count)  ·  Aliens down: \(p.aliensDestroyed)",
            "Planets surveyed: \(p.discoveredPlanets.count) · Wrecks: \(p.discoveredWrecks.count)",
            "Pirates destroyed: \(p.log.piratesDestroyed) · Capitals: \(p.log.capitalsDestroyed)",
            "Freighters saved: \(p.log.freightersSaved) · Station assists: \(p.log.stationKillsAssisted)",
            "Freelanes ridden: \(p.log.freelanesRidden) · Docks: \(p.log.docks)",
            "Lifetime credits earned: \(p.log.lifetimeCreditsEarned) · Cargo pods looted: \(p.log.cargoPodsLooted)",
            "Discovery bonuses: \(p.discoveryCreditsEarned) cr · Missions done: \(p.missionsCompleted)",
        ]
        for line in stats {
            drawText(line, at: CGPoint(x: panel.minX + 28, y: y),
                     font: .systemFont(ofSize: 11), color: Theme.textSecondary)
            y -= 15
        }

        y -= 8
        drawText("ACHIEVEMENTS (\(p.log.unlocked.count)/\(Achievement.allCases.count))",
                 at: CGPoint(x: panel.minX + 24, y: y),
                 font: .systemFont(ofSize: 11, weight: .bold), color: Theme.gold)
        y -= 18
        for ach in Achievement.allCases {
            let got = p.log.unlocked.contains(ach.rawValue)
            let mark = got ? "★" : "☆"
            drawText("\(mark) \(ach.title) — \(ach.detail)", at: CGPoint(x: panel.minX + 28, y: y),
                     font: .systemFont(ofSize: 10),
                     color: got ? Theme.gold : Theme.textMuted)
            y -= 14
            if y < panel.minY + 36 { break }
        }

        drawText("Esc / Enter close", at: CGPoint(x: panel.midX, y: panel.minY + 16),
                 font: .systemFont(ofSize: 11), color: Theme.textMuted, align: .center)
    }

    private static func drawSlotPicker(ctx: CGContext, bounds: CGRect, engine: GameEngine, loading: Bool) {
        let panelW: CGFloat = min(560, bounds.width - 80)
        let panelH: CGFloat = 340
        let panel = CGRect(x: (bounds.width - panelW) / 2, y: (bounds.height - panelH) / 2,
                           width: panelW, height: panelH)
        drawPanel(ctx: ctx, rect: panel, radius: 12)
        drawText(loading ? "Load Flight Log" : "Save Flight Log",
                 at: CGPoint(x: panel.midX, y: panel.maxY - 36),
                 font: .systemFont(ofSize: 20, weight: .bold), color: Theme.accent, align: .center)
        drawText(loading
                 ? "Choose autosave or a manual slot"
                 : "Choose a slot (autosave is written automatically on dock)",
                 at: CGPoint(x: panel.midX, y: panel.maxY - 58),
                 font: .systemFont(ofSize: 11), color: Theme.textSecondary, align: .center)

        let labels = loading ? engine.loadSlotLabels : engine.saveSlotLabels
        var y = panel.maxY - 100
        for (i, label) in labels.enumerated() {
            let selected = i == engine.slotMenuIndex
            if selected {
                Theme.accent.withAlphaComponent(0.12).setFill()
                NSBezierPath(roundedRect: CGRect(x: panel.minX + 20, y: y - 6, width: panelW - 40, height: 28),
                             xRadius: 6, yRadius: 6).fill()
            }
            let empty = label.contains("empty")
            drawText((selected ? "▸ " : "  ") + label,
                     at: CGPoint(x: panel.minX + 32, y: y),
                     font: .systemFont(ofSize: selected ? 13 : 12, weight: selected ? .semibold : .regular),
                     color: empty ? Theme.textMuted : (selected ? Theme.gold : Theme.textPrimary))
            y -= 36
        }

        drawText("↑/↓ select  ·  Enter confirm  ·  Esc back",
                 at: CGPoint(x: panel.midX, y: panel.minY + 20),
                 font: .systemFont(ofSize: 11), color: Theme.textMuted, align: .center)
    }

    // MARK: - Galaxy map

    /// Fixed chart positions (normalized 0...1 then scaled). Voidreach is off the rim.
    private static let galaxyLayout: [String: CGPoint] = [
        "Solara": CGPoint(x: 0.42, y: 0.48),
        "Vesper": CGPoint(x: 0.62, y: 0.38),
        "Ironreach": CGPoint(x: 0.28, y: 0.62),
        "Cinder": CGPoint(x: 0.55, y: 0.68),
        "Azurel": CGPoint(x: 0.72, y: 0.28),
        "Nyx": CGPoint(x: 0.78, y: 0.52),
        "Helion": CGPoint(x: 0.48, y: 0.22),
        "Drift": CGPoint(x: 0.22, y: 0.40),
        "Kestrel": CGPoint(x: 0.18, y: 0.72),
        "Umbra": CGPoint(x: 0.68, y: 0.78),
        "Voidreach": CGPoint(x: 0.92, y: 0.18),
    ]

    private static func drawGalaxyMap(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        let margin: CGFloat = 40
        let chart = CGRect(x: margin, y: margin + 30, width: bounds.width * 0.58, height: bounds.height - margin * 2 - 40)
        drawPanel(ctx: ctx, rect: chart.insetBy(dx: -8, dy: -8), radius: 12)

        drawText("GALAXY MAP", at: CGPoint(x: chart.midX, y: bounds.height - 36),
                 font: .systemFont(ofSize: 18, weight: .bold), color: Theme.accent, align: .center)
        drawText("←/→ system  ·  ↑/↓ station intel  ·  G / Esc close",
                 at: CGPoint(x: chart.midX, y: 22),
                 font: .systemFont(ofSize: 11), color: Theme.textMuted, align: .center)

        func nodePoint(_ name: String) -> CGPoint {
            let n = galaxyLayout[name] ?? CGPoint(x: 0.5, y: 0.5)
            return CGPoint(x: chart.minX + n.x * chart.width, y: chart.minY + n.y * chart.height)
        }

        // Gate links (hide wormhole links until discovered / Voidreach visited)
        var drawn = Set<String>()
        for (sysName, sys) in engine.systems {
            let a = nodePoint(sysName)
            for gate in sys.gates {
                if gate.isWormhole {
                    let known = engine.player.discoveredWormholes.contains(gate.wormholeKey)
                        || engine.player.systemsVisited.contains("Voidreach")
                    guard known else { continue }
                    let pair = [sysName, gate.destinationSystem].sorted().joined(separator: "|WH")
                    guard !drawn.contains(pair) else { continue }
                    drawn.insert(pair)
                    let b = nodePoint(gate.destinationSystem)
                    ctx.setStrokeColor(Theme.wormhole.withAlphaComponent(0.55).cgColor)
                    ctx.setLineWidth(2)
                    ctx.setLineDash(phase: 0, lengths: [5, 4])
                    ctx.move(to: a)
                    ctx.addLine(to: b)
                    ctx.strokePath()
                    ctx.setLineDash(phase: 0, lengths: [])
                } else {
                    let pair = [sysName, gate.destinationSystem].sorted().joined(separator: "|")
                    guard !drawn.contains(pair) else { continue }
                    drawn.insert(pair)
                    let b = nodePoint(gate.destinationSystem)
                    ctx.setStrokeColor(Theme.gate.withAlphaComponent(0.35).cgColor)
                    ctx.setLineWidth(1.5)
                    ctx.move(to: a)
                    ctx.addLine(to: b)
                    ctx.strokePath()
                }
            }
        }

        // System nodes — frontier always; Voidreach only if charted
        var mapNames = GalaxyBuilder.systemNames
        if engine.player.systemsVisited.contains("Voidreach")
            || engine.player.discoveredWormholes.contains(where: { $0.contains("Voidreach") }) {
            mapNames.append("Voidreach")
        }
        for name in mapNames {
            let p = nodePoint(name)
            let visited = engine.player.systemsVisited.contains(name)
            let selected = name == engine.mapSelectedSystem
            let here = name == engine.currentSystemName
            let tint = Theme.systemTint(name)
            let r: CGFloat = selected ? 16 : (name == "Voidreach" ? 14 : 12)
            ctx.setFillColor(tint.withAlphaComponent(visited ? 0.95 : 0.35).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            if selected {
                ctx.setStrokeColor(Theme.gold.cgColor)
                ctx.setLineWidth(2.5)
                ctx.strokeEllipse(in: CGRect(x: p.x - r - 4, y: p.y - r - 4, width: (r + 4) * 2, height: (r + 4) * 2))
            }
            if here {
                ctx.setStrokeColor(Theme.player.cgColor)
                ctx.setLineWidth(2)
                ctx.strokeEllipse(in: CGRect(x: p.x - r - 1, y: p.y - r - 1, width: (r + 1) * 2, height: (r + 1) * 2))
            }
            let label = name == "Voidreach" ? "Voidreach ✦" : name
            drawText(label, at: CGPoint(x: p.x, y: p.y - r - 14),
                     font: .systemFont(ofSize: selected ? 12 : 10, weight: selected ? .bold : .medium),
                     color: visited ? Theme.textPrimary : Theme.textMuted, align: .center)
        }

        // Detail panel
        let panel = CGRect(x: chart.maxX + 24, y: margin + 30,
                           width: bounds.width - chart.maxX - margin - 24,
                           height: bounds.height - margin * 2 - 40)
        drawPanel(ctx: ctx, rect: panel, radius: 12)
        let sysName = engine.mapSelectedSystem
        let sys = engine.systems[sysName]
        var y = panel.maxY - 28
        drawText(sys?.displayName ?? sysName, at: CGPoint(x: panel.minX + 16, y: y),
                 font: .systemFont(ofSize: 16, weight: .bold), color: Theme.systemTint(sysName))
        y -= 22
        drawText(sys?.blurb ?? "", at: CGPoint(x: panel.minX + 16, y: y),
                 font: .systemFont(ofSize: 11), color: Theme.textSecondary)
        y -= 28

        let visited = engine.player.systemsVisited.contains(sysName)
        drawText(visited ? "Status: CHARTED" : "Status: UNVISITED",
                 at: CGPoint(x: panel.minX + 16, y: y),
                 font: .systemFont(ofSize: 11, weight: .semibold),
                 color: visited ? Theme.hull : Theme.warning)
        y -= 20
        if let sys {
            let gates = sys.gates.map(\.destinationSystem).joined(separator: ", ")
            drawText("Gates: \(gates)", at: CGPoint(x: panel.minX + 16, y: y),
                     font: .systemFont(ofSize: 11), color: Theme.gate)
            y -= 24
            drawText("STATIONS & MARKET INTEL", at: CGPoint(x: panel.minX + 16, y: y),
                     font: .systemFont(ofSize: 10, weight: .bold), color: Theme.accentDim)
            y -= 18

            for (i, st) in sys.stations.enumerated() {
                let selected = i == engine.mapSelectedStationIndex
                if selected {
                    Theme.accent.withAlphaComponent(0.12).setFill()
                    NSBezierPath(rect: CGRect(x: panel.minX + 10, y: y - 4, width: panel.width - 20, height: 18)).fill()
                }
                drawText((selected ? "▸ " : "  ") + st.name,
                         at: CGPoint(x: panel.minX + 16, y: y),
                         font: .systemFont(ofSize: 12, weight: selected ? .bold : .regular),
                         color: selected ? Theme.gold : Theme.textPrimary)
                y -= 18
            }

            y -= 10
            let stIdx = min(engine.mapSelectedStationIndex, max(0, sys.stations.count - 1))
            if let st = sys.stations.indices.contains(stIdx) ? sys.stations[stIdx] : sys.stations.first {
                let key = "\(sysName)/\(st.name)"
                drawText("Last known prices — \(st.name)", at: CGPoint(x: panel.minX + 16, y: y),
                         font: .systemFont(ofSize: 11, weight: .semibold), color: Theme.station)
                y -= 18
                if let intel = engine.player.marketIntel[key] {
                    for c in Commodity.allCases.prefix(8) {
                        let buy = intel.buyPrices[c] ?? 0
                        let sell = intel.sellPrices[c] ?? 0
                        let hint = engine.marketHint(for: c, intel: intel)
                        let hintStr = hint.map { "  \($0)" } ?? ""
                        let hintCol: NSColor = {
                            guard let h = hint else { return Theme.textSecondary }
                            if h.contains("BUY") || h.contains("cheaper") { return Theme.hull }
                            if h.contains("SELL") || h.contains("pays") { return Theme.gold }
                            return Theme.textSecondary
                        }()
                        drawText("\(c.rawValue): buy \(buy) / sell \(sell)\(hintStr)",
                                 at: CGPoint(x: panel.minX + 20, y: y),
                                 font: .monospacedDigitSystemFont(ofSize: 10, weight: .regular),
                                 color: hintCol)
                        y -= 14
                        if y < panel.minY + 80 { break }
                    }
                    if let n = intel.samples, n > 1 {
                        y -= 4
                        drawText("Price history: \(n) dock samples (rolling avg)",
                                 at: CGPoint(x: panel.minX + 16, y: y),
                                 font: .systemFont(ofSize: 10), color: Theme.textMuted)
                        y -= 14
                    }
                } else {
                    drawText(visited
                             ? "No dock data yet — visit and dock to log prices."
                             : "Jump here and dock to gather market intel.",
                             at: CGPoint(x: panel.minX + 16, y: y),
                             font: .systemFont(ofSize: 11), color: Theme.textMuted)
                    y -= 18
                }
            }

            // Route planner from known intel
            let routes = engine.tradeRouteHints(limit: 3)
            if !routes.isEmpty, y > panel.minY + 50 {
                y -= 6
                drawText("ROUTE PLANNER (buy low → sell high)", at: CGPoint(x: panel.minX + 16, y: y),
                         font: .systemFont(ofSize: 10, weight: .bold), color: Theme.accentDim)
                y -= 16
                for r in routes {
                    let buyShort = r.buyAt.split(separator: "/").last.map(String.init) ?? r.buyAt
                    let sellShort = r.sellAt.split(separator: "/").last.map(String.init) ?? r.sellAt
                    let buySys = r.buyAt.split(separator: "/").first.map(String.init) ?? ""
                    let sellSys = r.sellAt.split(separator: "/").first.map(String.init) ?? ""
                    drawText("\(r.commodity.rawValue): \(buySys)/\(buyShort) → \(sellSys)/\(sellShort) (+\(r.margin))",
                             at: CGPoint(x: panel.minX + 16, y: y),
                             font: .systemFont(ofSize: 10), color: Theme.gold)
                    y -= 14
                    if y < panel.minY + 20 { break }
                }
            }
        }
    }

    private static func playerArtStyle(_ shipClass: PlayerShipClass) -> ShipArt.Style {
        switch shipClass {
        case .hybrid: return .player
        case .freighter: return .freighter
        case .interceptor: return .interceptor
        }
    }

    private static func drawDeath(ctx: CGContext, bounds: CGRect, engine: GameEngine) {
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.65).cgColor)
        ctx.fill(bounds)
        drawText(engine.player.ironmanMode ? "IRONMAN RUN ENDED" : "SHIP DESTROYED",
                 at: CGPoint(x: bounds.midX, y: bounds.midY + 50),
                 font: .systemFont(ofSize: 32, weight: .heavy), color: Theme.danger, align: .center)
        drawText("Kills \(engine.player.kills)  ·  Credits \(engine.player.credits)  ·  Story \(min(engine.player.storyStage, StoryBeat.count))/\(StoryBeat.count)",
                 at: CGPoint(x: bounds.midX, y: bounds.midY + 8),
                 font: .systemFont(ofSize: 14), color: Theme.textSecondary, align: .center)
        let prompt: String
        if engine.player.ironmanMode {
            prompt = "Ironman saves wiped. Press Enter for title."
        } else if engine.canInsuranceRespawn {
            let dock = engine.player.lastDockStation ?? "last dock"
            prompt = "Insured — Enter to respawn at \(dock). Cargo lost. Or load a save."
        } else {
            prompt = "No insurance. Load a save/autosave, or Enter for title. Outfitter sells policies."
        }
        drawText(prompt,
                 at: CGPoint(x: bounds.midX, y: bounds.midY - 28),
                 font: .systemFont(ofSize: 13), color: Theme.accent, align: .center)
    }

    /// Toast above the NEWS bar / controls — never over the top story/mission panel.
    private static func drawMessage(ctx: CGContext, bounds: CGRect, text: String) {
        let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let attr: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (text as NSString).size(withAttributes: attr)
        let padX: CGFloat = 18
        let padY: CGFloat = 10
        let panelW = min(bounds.width - 48, textSize.width + padX * 2)
        let panelH = textSize.height + padY * 2
        // Above NEWS (y≈36) and control hints (y≈14); clear of top HUD strip
        let panel = CGRect(
            x: (bounds.width - panelW) / 2,
            y: 68,
            width: panelW,
            height: panelH
        )
        Theme.panelBg.withAlphaComponent(0.94).setFill()
        let path = NSBezierPath(roundedRect: panel, xRadius: 8, yRadius: 8)
        path.fill()
        Theme.gold.withAlphaComponent(0.55).setStroke()
        path.lineWidth = 1.5
        path.stroke()
        drawText(text, at: CGPoint(x: panel.midX, y: panel.midY - 6),
                 font: font, color: Theme.gold, align: .center)
    }

    // MARK: - Drawing helpers

    private static func worldToScreen(_ w: SIMD2<Float>, camera: SIMD2<Float>, bounds: CGRect) -> CGPoint {
        CGPoint(
            x: bounds.midX + CGFloat(w.x - camera.x),
            y: bounds.midY + CGFloat(w.y - camera.y)
        )
    }

    private static func factionColor(_ f: Faction) -> NSColor {
        switch f {
        case .pirate: return Theme.pirate
        case .trader: return Theme.trader
        case .police: return Theme.police
        case .militia: return Theme.militia
        case .alien: return Theme.alien
        }
    }

    private static func hullColor(_ ship: NPCShip) -> NSColor {
        if ship.isWingman { return Theme.hull }
        if ship.isCapital { return NSColor(calibratedRed: 0.85, green: 0.15, blue: 0.2, alpha: 1) }
        switch ship.hullType {
        case .freighter: return Theme.trader
        case .bulkHauler: return NSColor(calibratedRed: 0.45, green: 0.72, blue: 0.40, alpha: 1)
        case .tanker: return NSColor(calibratedRed: 0.65, green: 0.75, blue: 0.45, alpha: 1)
        case .containerShip: return NSColor(calibratedRed: 0.50, green: 0.80, blue: 0.55, alpha: 1)
        case .oreBarge: return NSColor(calibratedRed: 0.70, green: 0.55, blue: 0.35, alpha: 1)
        case .courier: return NSColor(calibratedRed: 0.55, green: 0.90, blue: 0.75, alpha: 1)
        case .pirateRaider, .pirateGunship, .pirateBomber: return Theme.pirate
        case .patrol, .interceptor, .policeEnforcer: return Theme.police
        case .militiaCutter, .militiaFrigate: return Theme.militia
        case .alienSkimmer, .alienWarden, .alienStalker: return Theme.alien
        }
    }

    private static func drawPanel(ctx: CGContext, rect: CGRect, radius: CGFloat = 10, accent: NSColor? = nil) {
        Theme.panelBg.setFill()
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        path.fill()
        (accent ?? Theme.panelBorder).withAlphaComponent(accent == nil ? 1 : 0.85).setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }

    private static func drawBar(ctx: CGContext, rect: CGRect, frac: CGFloat, color: NSColor) {
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.4).cgColor)
        ctx.fill(rect)
        let f = max(0, min(1, frac))
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width * f, height: rect.height))
    }

    /// Compact bottom ticker (NEWS / RADIO): sized to text, capped width, centered.
    private static func bottomTickerBar(
        bounds: CGRect, y: CGFloat, text: String, font: NSFont, maxWidth: CGFloat
    ) -> CGRect {
        let padX: CGFloat = 20
        let textW = (text as NSString).size(withAttributes: [.font: font]).width
        let cap = min(maxWidth, bounds.width - 80)
        let w = min(cap, max(160, textW + padX * 2))
        return CGRect(x: (bounds.width - w) / 2, y: y, width: w, height: 22)
    }

    /// Ellipsize string so it fits `maxWidth` in the given font.
    private static func truncateToWidth(_ text: String, font: NSFont, maxWidth: CGFloat) -> String {
        let attr: [NSAttributedString.Key: Any] = [.font: font]
        if (text as NSString).size(withAttributes: attr).width <= maxWidth { return text }
        var s = text
        while s.count > 4 {
            s = String(s.dropLast())
            let trial = s + "…"
            if (trial as NSString).size(withAttributes: attr).width <= maxWidth { return trial }
        }
        return "…"
    }

    private static func drawLabeledBar(
        ctx: CGContext, x: CGFloat, y: CGFloat, width: CGFloat,
        label: String, frac: CGFloat, color: NSColor, text: String
    ) {
        drawText(label, at: CGPoint(x: x, y: y), font: .systemFont(ofSize: 9, weight: .bold), color: Theme.textMuted)
        let barX = x + 36
        let barW = width - 36 - (text.isEmpty ? 0 : 50)
        drawBar(ctx: ctx, rect: CGRect(x: barX, y: y + 2, width: barW, height: 8), frac: frac, color: color)
        if !text.isEmpty {
            drawText(text, at: CGPoint(x: x + width, y: y),
                     font: .monospacedDigitSystemFont(ofSize: 9, weight: .regular),
                     color: Theme.textSecondary, align: .right)
        }
    }

    private static func drawText(
        _ string: String, at point: CGPoint,
        font: NSFont, color: NSColor, align: NSTextAlignment = .left
    ) {
        let para = NSMutableParagraphStyle()
        para.alignment = align
        let attr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: para,
        ]
        let ns = string as NSString
        if align == .center {
            let size = ns.size(withAttributes: attr)
            ns.draw(at: CGPoint(x: point.x - size.width / 2, y: point.y), withAttributes: attr)
        } else if align == .right {
            let size = ns.size(withAttributes: attr)
            ns.draw(at: CGPoint(x: point.x - size.width, y: point.y), withAttributes: attr)
        } else {
            ns.draw(at: point, withAttributes: attr)
        }
    }

    private static func drawCenteredText(_ string: String, in rect: CGRect, font: NSFont, color: NSColor) {
        drawText(string, at: CGPoint(x: rect.midX, y: rect.midY - 8), font: font, color: color, align: .center)
    }

    private static func ctxStrokeLine(from: CGPoint, to: CGPoint, color: NSColor) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: from)
        ctx.addLine(to: to)
        ctx.strokePath()
    }
}

// Simple deterministic RNG for starfields
struct SeededRNG {
    private var state: UInt64
    init(seed: Int) { state = UInt64(bitPattern: Int64(seed == 0 ? 1 : seed)) }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func nextFloat(_ range: ClosedRange<Float>) -> Float {
        let u = Float(next() % 10_000) / 10_000
        return range.lowerBound + (range.upperBound - range.lowerBound) * u
    }
}
