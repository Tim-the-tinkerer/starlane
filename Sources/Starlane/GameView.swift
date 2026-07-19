import AppKit
import QuartzCore

@MainActor
final class GameView: NSView {
    weak var engine: GameEngine?
    private var timer: Timer?
    private var lastTime: CFTimeInterval = 0
    private var trackingArea: NSTrackingArea?
    /// Balanced NSCursor hide/unhide (refcount).
    private var cursorHidden = false

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    /// True when the hosting window is in macOS full screen.
    var isWindowFullScreen: Bool {
        window?.styleMask.contains(.fullScreen) == true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        startLoop()
        window?.makeFirstResponder(self)
        updateTrackingAreas()
        refreshCursorVisibility()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if superview == nil {
            showCursorIfNeeded()
        }
    }

    override func removeFromSuperview() {
        timer?.invalidate()
        timer = nil
        showCursorIfNeeded()
        super.removeFromSuperview()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [
            .activeInKeyWindow,
            .mouseEnteredAndExited,
            .inVisibleRect,
            .cursorUpdate,
        ]
        let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        refreshCursorVisibility()
    }

    override func mouseExited(with event: NSEvent) {
        showCursorIfNeeded()
    }

    override func cursorUpdate(with event: NSEvent) {
        // Push empty cursor while over the view in full screen (survives OS resets).
        if isWindowFullScreen {
            NSCursor.setHiddenUntilMouseMoves(false)
            hideCursorIfNeeded()
        } else {
            showCursorIfNeeded()
            NSCursor.arrow.set()
        }
    }

    /// Call when full-screen / key-window state changes.
    func refreshCursorVisibility() {
        // Hide only while this game window is key and full screen.
        if isWindowFullScreen, window?.isKeyWindow == true {
            hideCursorIfNeeded()
        } else {
            showCursorIfNeeded()
        }
    }

    private func hideCursorIfNeeded() {
        guard !cursorHidden else { return }
        NSCursor.hide()
        cursorHidden = true
    }

    private func showCursorIfNeeded() {
        guard cursorHidden else { return }
        NSCursor.unhide()
        cursorHidden = false
    }

    private func startLoop() {
        timer?.invalidate()
        lastTime = CACurrentMediaTime()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let engine = self.engine else { return }
                let now = CACurrentMediaTime()
                let dt = Float(min(now - self.lastTime, 0.05))
                self.lastTime = now
                if dt > 0 {
                    engine.update(dt: dt)
                }
                self.needsDisplay = true
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, let engine else {
            NSColor.black.setFill()
            dirtyRect.fill()
            return
        }
        Renderer.draw(ctx: ctx, bounds: bounds, engine: engine)
    }

    override func keyDown(with event: NSEvent) {
        if !event.isARepeat {
            engine?.keyDown(event.keyCode)
        }
    }

    override func keyUp(with event: NSEvent) {
        engine?.keyUp(event.keyCode)
    }

    override func mouseDown(with event: NSEvent) {
        // View is not flipped — matches CGContext (origin bottom-left).
        let p = convert(event.locationInWindow, from: nil)
        engine?.mouseDown(at: p, in: bounds)
    }

    override func rightMouseDown(with event: NSEvent) {
        // Right-click closes expanded system map
        if engine?.phase == .systemMap {
            engine?.keyDown(GameEngine.keyEscape)
        }
    }
}
