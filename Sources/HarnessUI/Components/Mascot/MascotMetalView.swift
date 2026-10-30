import AppKit
import MetalKit
import QuartzCore

@MainActor
final class MascotMetalView: MTKView, MTKViewDelegate {
    var onActivate: (() -> Void)?
    var onMove: ((CGPoint) -> Void)?
    var onMoveEnd: (() -> Void)?
    var onHide: (() -> Void)?
    var onDismiss: (() -> Void)?
    var interactive = false
    private let graphics = MascotResources.graphics
    private let motion = MascotMotionEngine()
    private var animationState = "idle"
    private var reduced = false
    private var suspended = false
    private var screenAsleep = false
    private var pointer = CGPoint.zero
    private var velocity = CGPoint.zero
    private var hover = -1
    private var lastFrame: [Float] = []
    private var lastTime = CACurrentMediaTime()
    private var pointerDown: CGPoint?
    private var previousPointer: CGPoint?
    private var moved = false
    private var tracking: NSTrackingArea?
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var fallback: NSImageView?

    init() {
        super.init(frame: .zero, device: MascotResources.graphics?.device)
        wantsLayer = true
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColorMake(0, 0, 0, 0)
        layer?.isOpaque = false
        framebufferOnly = true
        delegate = self
        isPaused = true
        enableSetNeedsDisplay = true
        setAccessibilityElement(false)
        if graphics == nil || motion == nil { showFallback() }
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { interactive }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        refreshPlayback()
        if window != nil && bounds.width > 0 && bounds.height > 0 && !suspended { needsDisplay = true }
    }

    func configure(state: String = "idle", reduced: Bool, suspended: Bool = false) {
        let changed = animationState != state || self.reduced != reduced || self.suspended != suspended
        animationState = state
        self.reduced = reduced
        self.suspended = suspended
        refreshPlayback()
        if changed && !suspended { needsDisplay = true }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeObservers()
        guard window != nil else {
            isPaused = true
            return
        }
        let center = NotificationCenter.default
        for name in [
            NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification, NSWindow.didChangeBackingPropertiesNotification,
        ] {
            observers.append(
                center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.refreshPlayback() }
                })
        }
        for name in [
            .NSProcessInfoPowerStateDidChange, NSApplication.didHideNotification,
            NSApplication.didUnhideNotification,
        ] {
            observers.append(
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.refreshPlayback() }
                })
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification] {
            workspaceObservers.append(
                workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    let asleep = note.name == NSWorkspace.screensDidSleepNotification
                    Task { @MainActor in
                        self?.screenAsleep = asleep
                        self?.refreshPlayback()
                    }
                })
        }
        refreshPlayback()
    }

    override func viewDidHide() {
        super.viewDidHide()
        refreshPlayback()
    }
    override func viewDidUnhide() {
        super.viewDidUnhide()
        refreshPlayback()
    }

    func stop() {
        isPaused = true
        suspended = true
        removeObservers()
        delegate = nil
    }

    private func removeObservers() {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
        workspaceObservers.removeAll()
    }

    private func refreshPlayback() {
        let visibleWindow = window?.sheetParent ?? window
        let visible =
            window?.isVisible == true && visibleWindow?.occlusionState.contains(.visible) == true
            && !isHiddenOrHasHiddenAncestor && !NSApp.isHidden
        preferredFramesPerSecond = ProcessInfo.processInfo.isLowPowerModeEnabled ? 15 : 30
        let pause = reduced || suspended || screenAsleep || !visible || fallback != nil
        if isPaused != pause { lastTime = CACurrentMediaTime() }
        enableSetNeedsDisplay = pause
        isPaused = pause
        if visible && !suspended && !screenAsleep && reduced { needsDisplay = true }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard !suspended, !screenAsleep, let graphics, let motion, fallback == nil,
            let pass = currentRenderPassDescriptor, let drawable = currentDrawable,
            let command = graphics.queue.makeCommandBuffer()
        else { return }
        let now = CACurrentMediaTime()
        let dt = min(0.08, max(0.001, now - lastTime))
        lastTime = now
        guard
            let values = motion.frame(
                delta: dt, state: animationState, reduced: reduced, pointer: pointer, hover: hover,
                velocity: velocity, dragging: pointerDown != nil && moved)
        else {
            showFallback()
            return
        }
        lastFrame = values
        velocity.x *= 0.75
        velocity.y *= 0.75
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.setRenderPipelineState(graphics.pipeline)
        encoder.setVertexBuffer(graphics.vertices, offset: 0, index: 0)
        values.withUnsafeBytes { bytes in
            if let address = bytes.baseAddress {
                encoder.setVertexBytes(address, length: bytes.count, index: 1)
                encoder.setFragmentBytes(address, length: bytes.count, index: 1)
            }
        }
        encoder.setFragmentTexture(graphics.texture, index: 0)
        encoder.drawIndexedPrimitives(
            type: .triangle, indexCount: graphics.indexCount, indexType: .uint16,
            indexBuffer: graphics.indices, indexBufferOffset: 0)
        encoder.endEncoding()
        command.present(drawable)
        command.commit()
    }

    private func showFallback() {
        guard fallback == nil else { return }
        isPaused = true
        let image = NSImageView(frame: bounds)
        image.image = MascotResources.image ?? FrondaAssets.mascot
        image.imageScaling = .scaleProportionallyUpOrDown
        image.autoresizingMask = [.width, .height]
        image.setAccessibilityElement(false)
        addSubview(image)
        fallback = image
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let x = point.x / max(1, bounds.width)
        let y = 1 - point.y / max(1, bounds.height)
        pointer = CGPoint(x: min(1, max(-1, (x - 0.5) * 3)), y: min(1, max(-1, (y - 0.5) * 3)))
        hover = MascotHitRegions.branch(at: CGPoint(x: x, y: y), frame: lastFrame)
        if interactive { NSCursor.openHand.set() }
    }
    override func mouseExited(with event: NSEvent) {
        pointer = .zero
        hover = -1
        NSCursor.arrow.set()
    }
    override func mouseDown(with event: NSEvent) {
        guard interactive else { return }
        pointerDown = NSEvent.mouseLocation
        previousPointer = pointerDown
        moved = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard interactive, let start = pointerDown, let previous = previousPointer else { return }
        let current = NSEvent.mouseLocation
        if hypot(current.x - start.x, current.y - start.y) > 3 { moved = true }
        if moved {
            let delta = CGPoint(x: current.x - previous.x, y: current.y - previous.y)
            onMove?(delta)
            velocity = CGPoint(x: min(2, max(-2, delta.x / 14)), y: min(2, max(-2, -delta.y / 14)))
            NSCursor.closedHand.set()
        }
        previousPointer = current
    }
    override func mouseUp(with event: NSEvent) {
        guard pointerDown != nil else { return }
        pointerDown = nil
        previousPointer = nil
        if moved {
            onMoveEnd?()
        } else {
            motion?.touch(branch: max(0, hover))
            onActivate?()
        }
        NSCursor.openHand.set()
    }
    override func rightMouseDown(with event: NSEvent) {
        guard interactive else { return }
        let menu = NSMenu()
        let item = NSMenuItem(title: "Ocultar companheiro", action: #selector(hideCompanion), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    @objc private func hideCompanion() { onHide?() }
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onDismiss?()
        case 36, 49: onActivate?()
        case 123:
            onMove?(CGPoint(x: -12, y: 0))
            onMoveEnd?()
        case 124:
            onMove?(CGPoint(x: 12, y: 0))
            onMoveEnd?()
        case 125:
            onMove?(CGPoint(x: 0, y: -12))
            onMoveEnd?()
        case 126:
            onMove?(CGPoint(x: 0, y: 12))
            onMoveEnd?()
        default: super.keyDown(with: event)
        }
    }
    override func accessibilityPerformPress() -> Bool {
        onActivate?()
        return interactive
    }
}
