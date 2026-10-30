import AppKit
import HarnessDomain
import SwiftUI
import UserNotifications

@main
struct HarnessApp: App {
    @NSApplicationDelegateAdaptor(HarnessAppDelegate.self) private var delegate
    @State private var store = AppStore()
    @State private var island = SessionIslandController()
    @State private var companion = MascotCompanionController()
    var body: some Scene {
        Window("Fronda", id: "main") {
            ContentView(store: store)
                .background(
                    SessionIslandLifecycle(store: store, controller: island, companion: companion, delegate: delegate)
                )
                .preferredColorScheme(store.colorScheme)
                .task { await store.connect() }
                .onOpenURL { url in
                    if ["fronda", "harness"].contains(url.scheme ?? "") {
                        store.route = "run:" + url.lastPathComponent
                    }
                }
        }
        .defaultSize(width: 1380, height: 900)
        .defaultWindowPlacement { _, context in
            let bounds = context.defaultDisplay.visibleRect
            let size = CGSize(width: min(1380, bounds.width - 48), height: min(900, bounds.height - 48))
            return WindowPlacement(.center, size: size)
        }
        .windowToolbarStyle(.unifiedCompact)
        .commands { FrondaCommands(store: store, island: island, companion: companion) }
        WindowGroup("Workspace da run", id: "run", for: String.self) { $id in
            if let id {
                RunWindowView(store: store, runID: id)
                    .frame(minWidth: 960, minHeight: 650)
                    .preferredColorScheme(store.colorScheme)
                    .focusedSceneValue(\.frondaRunID, id)
                    .navigationTitle(store.snapshot.runs.first { $0.id == id }?.title ?? "Workspace da run")
            }
        }
        .defaultSize(width: 1280, height: 850)
        .defaultLaunchBehavior(.suppressed)
        .windowToolbarStyle(.unified)
        Settings {
            SettingsView(store: store, island: island, companion: companion).preferredColorScheme(store.colorScheme)
        }
        .defaultSize(width: 1000, height: 760)
        MenuBarExtra {
            MenuBarView(store: store, island: island, companion: companion)
        } label: {
            Label {
                Text("\(store.activeRuns.count)")
            } icon: {
                Image(nsImage: FrondaMenuBarIcon.image).renderingMode(.template)
            }
            .accessibilityLabel("Fronda, \(store.activeRuns.count) execuções ativas")
        }
        .menuBarExtraStyle(.window)
    }
}

private struct SessionIslandLifecycle: View {
    let store: AppStore
    let controller: SessionIslandController
    let companion: MascotCompanionController
    let delegate: HarnessAppDelegate
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        SessionIslandWindowReader(controller: controller).frame(width: 0, height: 0).onAppear {
            controller.start(store: store) { openWindow(id: "main") }
            companion.start(store: store, island: controller)
            delegate.reopenMainWindow = {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

private struct SessionIslandWindowReader: NSViewRepresentable {
    let controller: SessionIslandController
    func makeNSView(context: Context) -> WindowReaderView {
        let view = WindowReaderView()
        view.onWindow = { [weak controller] window in controller?.registerMainWindow(window) }
        return view
    }
    func updateNSView(_ nsView: WindowReaderView, context: Context) {}

    final class WindowReaderView: NSView {
        var onWindow: ((NSWindow) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { onWindow?(window) }
        }
    }
}

final class HarnessAppDelegate: NSObject, NSApplicationDelegate {
    private let notificationRouter = NotificationRouter()
    var reopenMainWindow: (() -> Void)?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let iconURL = Bundle.main.url(forResource: "Fronda", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
        {
            NSApp.applicationIconImage = icon
        }
        NSApp.activate(ignoringOtherApps: true)
        UNUserNotificationCenter.current().delegate = notificationRouter
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        reopenMainWindow?()
        return reopenMainWindow == nil
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
