import AppKit
import Observation
import SwiftUI

@MainActor @Observable
final class MascotCompanionController {
    var enabled = UserDefaults.standard.object(forKey: "mascot.enabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "mascot.enabled")
            updateVisibility()
        }
    }
    var animationsEnabled = UserDefaults.standard.object(forKey: "mascot.animate") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(animationsEnabled, forKey: "mascot.animate")
            updateAnimation()
        }
    }
    var size: Double = {
        let saved = UserDefaults.standard.double(forKey: "mascot.size")
        return saved == 0 ? 176 : min(240, max(112, saved))
    }()
    {
        didSet {
            UserDefaults.standard.set(size, forKey: "mascot.size")
            resize()
        }
    }
    @ObservationIgnored private var panel: MascotCompanionPanel?
    @ObservationIgnored private var mascot: MascotMetalView?
    @ObservationIgnored private var popover: NSPopover?
    @ObservationIgnored private var screenObserver: NSObjectProtocol?
    @ObservationIgnored private var accessibilityObserver: NSObjectProtocol?
    @ObservationIgnored private weak var store: AppStore?
    @ObservationIgnored private weak var island: SessionIslandController?

    func start(store: AppStore, island: SessionIslandController) {
        guard panel == nil else { return }
        self.store = store
        self.island = island
        let panel = MascotCompanionPanel(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Companheiro Fronda"
        panel.identifier = NSUserInterfaceItemIdentifier("mascot.companion")
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        let mascot = MascotMetalView()
        mascot.interactive = true
        mascot.frame = panel.contentView?.bounds ?? .zero
        mascot.autoresizingMask = [.width, .height]
        mascot.toolTip = "Clique para ver tarefas e ações. Arraste para mover."
        mascot.setAccessibilityElement(true)
        mascot.setAccessibilityRole(.button)
        mascot.setAccessibilityLabel("Companheiro Fronda")
        mascot.setAccessibilityIdentifier("mascot.open")
        mascot.setAccessibilityHelp("Clique para abrir tarefas. Use as setas para mover quando estiver em foco.")
        mascot.onActivate = { [weak self] in self?.togglePopover() }
        mascot.onMove = { [weak self] delta in self?.move(by: delta) }
        mascot.onMoveEnd = { [weak self] in self?.savePosition() }
        mascot.onHide = { [weak self] in self?.enabled = false }
        mascot.onDismiss = { [weak self] in self?.popover?.close() }
        panel.onEscape = { [weak self] in self?.popover?.close() }
        panel.contentView = mascot
        self.panel = panel
        self.mascot = mascot
        restorePosition()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.fitOnScreen()
                self?.savePosition()
            }
        }
        accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.updateAnimation() } }
        updateVisibility()
        observeSessions()
    }

    func toggle() { enabled.toggle() }

    private func observeSessions() {
        guard let store else { return }
        withObservationTracking {
            _ = store.mascotActivities
            _ = store.firstTaskJourney.isActive
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateAnimation()
                self?.observeSessions()
            }
        }
    }

    func updateAnimation() {
        guard let store else { return }
        let activity = store.mascotActivities.first
        let teaching = store.firstTaskJourney.isActive && (activity?.priority ?? 6) >= 3
        let state: MascotState = teaching ? .guide : activity?.state ?? .idle
        mascot?.setAccessibilityValue(activity?.detail ?? "Tudo tranquilo")
        mascot?.toolTip = (activity?.action ?? "Ver tarefas e ações") + ". Arraste para mover."
        mascot?.configure(
            state: state.rawValue,
            reduced: !animationsEnabled || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            suspended: !enabled)
    }

    func showActions() {
        enabled = true
        panel?.makeKey()
        if let mascot { panel?.makeFirstResponder(mascot) }
        if popover?.isShown != true { togglePopover() }
    }

    func open(_ route: String? = nil) {
        popover?.close()
        guard let store else { return }
        island?.openHarness(route: route, store: store)
    }

    func newTask() {
        guard let store else { return }
        open()
        store.showComposer = true
    }

    func openActivity(_ activity: MascotActivity) {
        guard let store else { return }
        switch activity.destination {
        case .run(let id, let section):
            open()
            store.navigation.visit(WorkspaceLocation(route: "run:" + id, section: section))
        case .decision(let id):
            store.decisionRunID = id
            open("decisions")
        case .external(let id):
            guard let url = URL(string: "codex://threads/" + id) else { return }
            popover?.close()
            NSWorkspace.shared.open(url)
        case .sessions: showSessions()
        }
    }

    func startJourney() {
        guard let store else { return }
        open()
        store.openFirstTaskJourney()
    }

    func showSessions() {
        popover?.close()
        island?.enabled = true
        island?.expand(focus: true)
    }

    func resetPosition() {
        guard let panel, let screen = NSScreen.main else { return }
        panel.setFrameOrigin(defaultOrigin(screen))
        savePosition()
    }

    private func updateVisibility() {
        if enabled {
            fitOnScreen()
            panel?.orderFrontRegardless()
        } else {
            popover?.close()
            panel?.orderOut(nil)
        }
        updateAnimation()
    }

    private func togglePopover() {
        guard let store, let mascot, enabled else { return }
        if let popover, popover.isShown {
            popover.close()
            return
        }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.contentViewController = NSHostingController(
            rootView: MascotCompanionPopover(store: store, companion: self))
        self.popover = popover
        popover.show(
            relativeTo: mascot.bounds.insetBy(dx: size * 0.12, dy: size * 0.12), of: mascot, preferredEdge: .minX)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func resize() {
        guard let panel else { return }
        let center = CGPoint(x: panel.frame.midX, y: panel.frame.midY)
        panel.setFrame(NSRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size), display: true)
        fitOnScreen()
        savePosition()
    }

    private func move(by delta: CGPoint) {
        guard let panel else { return }
        popover?.close()
        let frame = panel.frame.offsetBy(dx: delta.x, dy: delta.y)
        let screen =
            NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? panel.screen ?? NSScreen.main
        panel.setFrameOrigin(clamped(frame.origin, to: screen))
    }

    private func clamped(_ point: CGPoint, to screen: NSScreen?) -> CGPoint {
        guard let bounds = screen?.visibleFrame.insetBy(dx: 4, dy: 4) else { return point }
        return CGPoint(
            x: min(max(point.x, bounds.minX), max(bounds.minX, bounds.maxX - size)),
            y: min(max(point.y, bounds.minY), max(bounds.minY, bounds.maxY - size)))
    }

    private func defaultOrigin(_ screen: NSScreen) -> CGPoint {
        CGPoint(x: screen.visibleFrame.maxX - size - 28, y: screen.visibleFrame.minY + 28)
    }

    private func restorePosition() {
        guard let panel, let screen = NSScreen.main else { return }
        let defaults = UserDefaults.standard
        let position: CGPoint
        if defaults.object(forKey: "mascot.x") != nil {
            position = CGPoint(x: defaults.double(forKey: "mascot.x"), y: defaults.double(forKey: "mascot.y"))
        } else {
            position = defaultOrigin(screen)
        }
        panel.setFrameOrigin(position)
        fitOnScreen()
    }

    private func fitOnScreen() {
        guard let panel else { return }
        let screen =
            NSScreen.screens.max {
                let left = $0.visibleFrame.intersection(panel.frame)
                let right = $1.visibleFrame.intersection(panel.frame)
                return (left.isNull ? 0 : left.width * left.height) < (right.isNull ? 0 : right.width * right.height)
            } ?? NSScreen.main
        panel.setFrameOrigin(clamped(panel.frame.origin, to: screen))
    }

    private func savePosition() {
        guard let panel else { return }
        UserDefaults.standard.set(panel.frame.minX, forKey: "mascot.x")
        UserDefaults.standard.set(panel.frame.minY, forKey: "mascot.y")
    }
}

private final class MascotCompanionPanel: NSPanel {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
}
