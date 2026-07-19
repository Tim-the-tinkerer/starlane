import AppKit

@main
enum StarlaneMain {
    @MainActor
    static func main() {
        // Debug: `Starlane --probe-saves` prints decode errors and exits.
        if CommandLine.arguments.contains("--probe-saves") {
            probeSavesAndExit()
            return
        }
        let app = NSApplication.shared
        let delegate = StarlaneAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)
        app.run()
    }

    private static func probeSavesAndExit() {
        let dir = SaveGame.directory
        print("Save directory: \(dir.path)")
        print("hasAnySave: \(SaveGame.hasAnySave)")
        let migrate = CommandLine.arguments.contains("--migrate-saves")
        for s in 1...SaveGame.manualSlotCount {
            do {
                var snap = try SaveGame.load(slot: s)
                snap.player.normalizeSaveDefaults()
                if snap.ironmanMode == nil { snap.ironmanMode = snap.player.ironmanMode }
                print("Slot \(s): OK — \(snap.currentSystemName), \(snap.player.credits) cr, mines=\(snap.player.mineStock), investments=\(snap.player.investments.count)")
                if migrate {
                    try SaveGame.save(snap, slot: s)
                    print("  → rewritten Slot \(s)")
                }
            } catch {
                print("Slot \(s): FAIL — \(error)")
            }
        }
        do {
            var snap = try SaveGame.loadAutosave()
            snap.player.normalizeSaveDefaults()
            if snap.ironmanMode == nil { snap.ironmanMode = snap.player.ironmanMode }
            print("Autosave: OK — \(snap.currentSystemName), \(snap.player.credits) cr, mines=\(snap.player.mineStock)")
            if migrate {
                try SaveGame.autosave(snap)
                print("  → rewritten Autosave")
            }
        } catch {
            print("Autosave: FAIL — \(error)")
        }
        do {
            let snap = try SaveGame.loadMostRecent()
            print("Most recent: OK — \(snap.currentSystemName)")
        } catch {
            print("Most recent: FAIL — \(error)")
        }
        exit(0)
    }
}

@MainActor
final class StarlaneAppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: GameWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        windowController = GameWindowController()
        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func setupMainMenu() {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Starlane"
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: appName)
        appMenuItem.submenu = appMenu

        let about = NSMenuItem(title: "About \(appName)", action: #selector(showAbout(_:)), keyEquivalent: "")
        about.target = self
        appMenu.addItem(about)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
            .keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let gameMenuItem = NSMenuItem()
        mainMenu.addItem(gameMenuItem)
        let gameMenu = NSMenu(title: "Game")
        gameMenuItem.submenu = gameMenu

        let newGame = NSMenuItem(title: "New Game", action: #selector(startNewGame(_:)), keyEquivalent: "n")
        newGame.target = self
        gameMenu.addItem(newGame)

        let loadGame = NSMenuItem(title: "Load Game", action: #selector(loadGame(_:)), keyEquivalent: "l")
        loadGame.target = self
        gameMenu.addItem(loadGame)

        let saveGame = NSMenuItem(title: "Save Game", action: #selector(saveGame(_:)), keyEquivalent: "s")
        saveGame.target = self
        gameMenu.addItem(saveGame)

        gameMenu.addItem(.separator())

        let mute = NSMenuItem(title: "Toggle Mute", action: #selector(toggleMute(_:)), keyEquivalent: "m")
        mute.target = self
        gameMenu.addItem(mute)

        let title = NSMenuItem(title: "Return to Title Menu", action: #selector(returnToTitle(_:)), keyEquivalent: "")
        title.target = self
        gameMenu.addItem(title)

        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "Help")
        helpMenuItem.submenu = helpMenu

        let help = NSMenuItem(title: "\(appName) Help", action: #selector(showHelp(_:)), keyEquivalent: "?")
        help.target = self
        helpMenu.addItem(help)
    }

    @objc private func startNewGame(_ sender: Any?) {
        windowController?.engine.newGame()
    }

    @objc private func loadGame(_ sender: Any?) {
        guard let engine = windowController?.engine else { return }
        if engine.phase == .title || engine.phase == .paused || engine.phase == .playing || engine.phase == .docked {
            engine.openLoadSlots(from: engine.phase == .title ? .title : engine.phase)
        } else {
            _ = engine.loadGame()
        }
    }

    @objc private func saveGame(_ sender: Any?) {
        guard let engine = windowController?.engine else { return }
        if engine.phase == .playing || engine.phase == .docked || engine.phase == .paused {
            engine.openSaveSlots(from: engine.phase)
        } else {
            _ = engine.saveGame()
        }
    }

    @objc private func returnToTitle(_ sender: Any?) {
        windowController?.engine.returnToTitle()
    }

    @objc private func toggleMute(_ sender: Any?) {
        AudioManager.shared.muted.toggle()
    }

    @objc private func showHelp(_ sender: Any?) {
        HelpWindowController.show()
    }

    @objc private func showAbout(_ sender: Any?) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        let credits = NSMutableAttributedString()
        credits.append(NSAttributedString(
            string: "A Freelancer-style space adventure.\nTrade the lanes. Fight pirates. Dock, outfit, freelane.\n\n",
            attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)]
        ))
        credits.append(NSAttributedString(
            string: "WASD fly · Space fire · F dock/jump · T target\nR mine · P pause · M mute · ⌘Q quit",
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        ))

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Starlane",
            .applicationVersion: version,
            .version: "Build \(build)",
            .credits: credits,
        ])
    }
}
