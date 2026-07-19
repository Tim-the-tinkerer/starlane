import AppKit

@MainActor
final class GameWindowController: NSWindowController, NSWindowDelegate {
    let engine = GameEngine()
    private let gameView = GameView()
    private var eventMonitor: Any?
    private var didEnterFullScreen = false

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Starlane"
        window.minSize = NSSize(width: 900, height: 600)
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.titlebarAppearsTransparent = true
        window.backgroundColor = Theme.void
        if let screen = NSScreen.main {
            window.setFrame(screen.visibleFrame, display: true)
        } else {
            window.center()
        }

        gameView.frame = window.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        gameView.autoresizingMask = [.width, .height]
        gameView.engine = engine
        window.contentView = gameView

        super.init(window: window)
        window.delegate = self
        installInputMonitor()
    }

    // MARK: - Full screen cursor

    func windowDidEnterFullScreen(_ notification: Notification) {
        gameView.refreshCursorVisibility()
        window?.makeFirstResponder(gameView)
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        gameView.refreshCursorVisibility()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        gameView.refreshCursorVisibility()
    }

    func windowDidResignKey(_ notification: Notification) {
        // Restore system cursor when leaving the game (Cmd-Tab, etc.)
        gameView.refreshCursorVisibility()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeFirstResponder(gameView)
        enterFullScreenIfNeeded()
    }

    func enterFullScreenIfNeeded() {
        guard let window, !didEnterFullScreen else { return }
        didEnterFullScreen = true
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            if !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
            window.makeFirstResponder(self.gameView)
            self.gameView.refreshCursorVisibility()
        }
    }

    private func installInputMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            return self.handleKey(event)
        }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        if event.modifierFlags.contains(.command) {
            return event
        }

        switch event.type {
        case .keyDown:
            if event.isARepeat {
                let code = event.keyCode
                let movement: Set<UInt16> = [13, 0, 1, 2, 126, 125, 123, 124]
                if engine.phase == .playing, movement.contains(code) {
                    engine.keysDown.insert(code)
                    return nil
                }
                return nil
            }
            // F while docked: sell / withdraw / shields
            if engine.phase == .docked, event.keyCode == GameEngine.keyF {
                if engine.stationTab == .trade {
                    engine.sellCommodity()
                    return nil
                }
                if engine.stationTab == .warehouse || engine.stationTab == .status {
                    engine.dockedSecondaryAction()
                    return nil
                }
            }
            engine.keyDown(event.keyCode)
            return nil
        case .keyUp:
            engine.keyUp(event.keyCode)
            return nil
        default:
            return event
        }
    }
}
