import AppKit
import HarnessDomain
import SwiftUI
import UserNotifications

@main
struct HarnessApp: App {
    @NSApplicationDelegateAdaptor(HarnessAppDelegate.self) private var delegate
    @State private var store = AppStore()
    var body: some Scene {
        WindowGroup("Harness", id: "main") {
            ContentView(store: store)
                .preferredColorScheme(store.colorScheme)
                .task { await store.connect() }
                .onOpenURL { url in if url.scheme == "harness" { store.route = "run:" + url.lastPathComponent } }
        }
        .defaultSize(width: 1380, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nova run…") { store.showComposer = true }.keyboardShortcut("n")
            }
            CommandGroup(after: .textEditing) {
                Button("Buscar e executar comando…") { store.showPalette = true }.keyboardShortcut("k")
                Button("Command Center") { store.route = "center" }.keyboardShortcut("1")
                Button("Runs") { store.route = "runs" }.keyboardShortcut("2")
                Button("Projetos") { store.route = "projects" }.keyboardShortcut("3")
                Button("Decisões") { store.route = "decisions" }.keyboardShortcut("4")
            }
            CommandMenu("Execução") {
                Button(store.snapshot.preferences.queuePaused ? "Retomar fila" : "Pausar fila") {
                    store.perform("queue.toggle")
                }
                Button("Verificar providers") { store.perform("providers.probe") }
                Divider()
                Button("Sair e parar runs…") { store.showStopConfirmation = true }
            }
        }
        WindowGroup("Workspace da run", id: "run", for: String.self) { $id in
            if let id {
                RunWorkspace(store: store, runID: id).frame(minWidth: 960, minHeight: 650).preferredColorScheme(
                    store.colorScheme)
            }
        }.defaultSize(width: 1280, height: 850)
        Settings { SettingsView(store: store).preferredColorScheme(store.colorScheme) }
        MenuBarExtra {
            MenuBarView(store: store)
        } label: {
            Label("\(store.activeRuns.count)", systemImage: "square.stack.3d.up")
        }
        .menuBarExtraStyle(.window)
    }
}

final class HarnessAppDelegate: NSObject, NSApplicationDelegate {
    private let notificationRouter = NotificationRouter()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        UNUserNotificationCenter.current().delegate = notificationRouter
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
