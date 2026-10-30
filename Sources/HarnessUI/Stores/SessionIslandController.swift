import AppKit
import Observation
import SwiftUI

@MainActor @Observable
final class SessionIslandController {
    enum Presentation { case compact, peek, expanded }

    var enabled = UserDefaults.standard.object(forKey: "island.enabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "island.enabled")
            updatePlacement()
        }
    }
    var expandOnHover = UserDefaults.standard.object(forKey: "island.hover") as? Bool ?? true {
        didSet { UserDefaults.standard.set(expandOnHover, forKey: "island.hover") }
    }
    private(set) var presentation = Presentation.compact
    var expanded: Bool { presentation == .expanded }
    var revealed: Bool { presentation != .compact }
    private(set) var pinned = false
    private(set) var cameraHeight: CGFloat = 0
    private(set) var cameraWidth: CGFloat = 0
    var crownHeight: CGFloat { max(28, cameraHeight) }
    private(set) var width: CGFloat = 180
    private(set) var height: CGFloat = 32
    private(set) var canvasWidth: CGFloat = 180
    private(set) var canvasHeight: CGFloat = 32
    @ObservationIgnored private var panel: SessionIslandPanel?
    @ObservationIgnored private var hoverTask: Task<Void, Never>?
    @ObservationIgnored private var settleTask: Task<Void, Never>?
    @ObservationIgnored private var attentionTask: Task<Void, Never>?
    @ObservationIgnored private var screenObserver: NSObjectProtocol?
    @ObservationIgnored private var openMain: (() -> Void)?
    @ObservationIgnored private var sessionCount = 0
    @ObservationIgnored private var activityCount = 0
    @ObservationIgnored private var attentionCount = 0
    @ObservationIgnored private var pointerInside = false
    @ObservationIgnored private weak var mainWindow: NSWindow?

    func registerMainWindow(_ window: NSWindow) { mainWindow = window }

    func resize(sessionCount: Int, activityCount: Int, attentionCount: Int) {
        let needsAttention = attentionCount > self.attentionCount
        guard
            self.sessionCount != sessionCount || self.activityCount != activityCount
                || self.attentionCount != attentionCount
        else { return }
        self.sessionCount = sessionCount
        self.activityCount = activityCount
        self.attentionCount = attentionCount
        if needsAttention && enabled && presentation == .compact {
            presentation = .peek
            attentionTask?.cancel()
            attentionTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, let self, !self.pointerInside, !self.pinned,
                    self.presentation == .peek
                else { return }
                self.collapse()
            }
        }
        updatePlacement(animated: true)
    }

    func start(store: AppStore, openMain: @escaping () -> Void) {
        self.openMain = openMain
        guard panel == nil else { return }
        let panel = SessionIslandPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Central de sessões Fronda"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.autorecalculatesKeyViewLoop = true
        let content = NSHostingView(rootView: SessionIslandView(store: store, controller: self))
        content.sizingOptions = []
        panel.contentView = content
        panel.onEscape = { [weak self] in self?.collapse() }
        self.panel = panel
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updatePlacement() }
        }
        updatePlacement()
    }

    func toggle() {
        if !enabled { enabled = true }
        if expanded { collapse() } else { expand(focus: true) }
    }

    func expand(focus: Bool = false) {
        hoverTask?.cancel()
        attentionTask?.cancel()
        presentation = .expanded
        updatePlacement(animated: true)
        if focus { panel?.makeKey() }
    }

    func collapse() {
        hoverTask?.cancel()
        attentionTask?.cancel()
        pinned = false
        presentation = .compact
        panel?.resignKey()
        updatePlacement(animated: true)
    }

    func togglePin() { pinned.toggle() }

    func hover(_ inside: Bool) {
        pointerInside = inside
        hoverTask?.cancel()
        guard !pinned else { return }
        // Closing still works when hover-to-preview is disabled.
        guard !inside || expandOnHover else { return }
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(inside ? 180 : 500))
            guard !Task.isCancelled, let self else { return }
            if inside {
                guard self.presentation == .compact else { return }
                self.presentation = .peek
                self.updatePlacement(animated: true)
            } else {
                self.collapse()
            }
        }
    }

    func openHarness(route: String? = nil, store: AppStore) {
        collapse()
        if let route { store.route = route }
        if let mainWindow, mainWindow.isVisible || mainWindow.isMiniaturized {
            mainWindow.deminiaturize(nil)
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            openMain?()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updatePlacement(animated: Bool = false) {
        guard let panel else { return }
        settleTask?.cancel()
        guard enabled else {
            hoverTask?.cancel()
            attentionTask?.cancel()
            presentation = .compact
            pinned = false
            pointerInside = false
            panel.orderOut(nil)
            return
        }
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else {
            panel.orderOut(nil)
            return
        }
        cameraHeight = screen.safeAreaInsets.top
        let left = screen.auxiliaryTopLeftArea
        let right = screen.auxiliaryTopRightArea
        cameraWidth = left.flatMap { l in right.map { max(0, $0.minX - l.maxX) } } ?? 0
        let hasActivity = activityCount > 0 || attentionCount > 0
        switch presentation {
        case .compact:
            width = cameraWidth > 0 ? cameraWidth + (hasActivity ? 104 : 16) : (hasActivity ? 148 : 88)
            height = crownHeight + (cameraHeight > 0 ? 2 : 0)
        case .peek:
            width = max(360, cameraWidth + 120)
            height = crownHeight + 84
        case .expanded:
            width = max(420, cameraWidth + 140)
            height = crownHeight + (sessionCount == 0 ? 148 : 112 + CGFloat(min(4, sessionCount)) * 88)
        }
        width = min(width, screen.frame.width - 40)
        height = min(height, screen.visibleFrame.height - 24)
        // A notchless display gets a floating pill below the menu bar.
        let top = cameraHeight > 0 ? screen.frame.maxY : screen.visibleFrame.maxY - 8
        let shouldAnimate = animated && panel.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if shouldAnimate {
            // Reserve spring overshoot, releasing transparent hit regions after settling.
            canvasWidth = max(canvasWidth, width + 32)
            canvasHeight = max(canvasHeight, height + 24)
        } else {
            canvasWidth = width + (revealed ? 32 : 0)
            canvasHeight = height + (revealed ? 24 : 0)
        }
        placePanel(centerX: screen.frame.midX, top: top)
        panel.orderFrontRegardless()
        if shouldAnimate {
            let centerX = screen.frame.midX
            settleTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(IslandMotion.settleMilliseconds))
                guard !Task.isCancelled, let self else { return }
                self.canvasWidth = self.width + (self.revealed ? 32 : 0)
                self.canvasHeight = self.height + (self.revealed ? 24 : 0)
                self.placePanel(centerX: centerX, top: top)
            }
        }
    }

    private func placePanel(centerX: CGFloat, top: CGFloat) {
        panel?.setFrame(
            NSRect(x: centerX - canvasWidth / 2, y: top - canvasHeight, width: canvasWidth, height: canvasHeight),
            display: true)
    }
}

private final class SessionIslandPanel: NSPanel {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
}
