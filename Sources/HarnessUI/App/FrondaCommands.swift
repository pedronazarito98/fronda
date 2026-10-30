import AppKit
import HarnessDomain
import SwiftUI

private struct FrondaRunIDKey: FocusedValueKey {
    typealias Value = String
}

extension FocusedValues {
    var frondaRunID: String? {
        get { self[FrondaRunIDKey.self] }
        set { self[FrondaRunIDKey.self] = newValue }
    }
}

struct FrondaCommands: Commands {
    let store: AppStore
    let island: SessionIslandController
    let companion: MascotCompanionController
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.frondaRunID) private var focusedRunID
    @FocusedValue(\.workspaceNavigation) private var navigation
    @FocusedValue(\.workspaceSession) private var workspace

    var body: some Commands {
        SidebarCommands()
        CommandGroup(replacing: .help) {
            Button("Guia Fronda") { navigate("guide") }.keyboardShortcut("?", modifiers: .command)
            Button(store.firstTaskJourney.entryTitle) {
                openMain()
                store.openFirstTaskJourney()
            }.disabled(!store.connected || store.showComposer || store.showPalette)
            Button("Como escolher modelos e esforço") {
                store.guideTopic = "models"
                navigate("guide")
            }
            Button("Como importar skills e regras") {
                store.guideTopic = "context"
                navigate("guide")
            }
        }
        CommandGroup(replacing: .newItem) {
            Button("Nova aba") { workspace?.openTab() }
                .keyboardShortcut("t").disabled(workspace == nil)
            Button("Fechar aba") { if let workspace { workspace.closeTab(workspace.selectedID) } }
                .keyboardShortcut("w", modifiers: [.command, .shift]).disabled(workspace == nil)
            Button("Reabrir última aba") { workspace?.reopen() }
                .keyboardShortcut("t", modifiers: [.command, .shift]).disabled(workspace?.canReopen != true)
            Divider()
            Button("Nova tarefa…") {
                openMain()
                store.showComposer = true
            }.keyboardShortcut("n").disabled(store.showComposer || store.showPalette)
            Button("Adicionar projeto…") {
                openMain()
                store.addProject()
            }.keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(store.showComposer || store.showPalette)
            Menu("Abrir tarefa recente") {
                ForEach(recentRuns) { run in
                    Button(run.title) { openRun(run.id) }
                }
            }.disabled(recentRuns.isEmpty)
        }
        CommandMenu("Navegar") {
            Button("Próxima aba") { workspace?.cycle(1) }
                .keyboardShortcut(.tab, modifiers: .control).disabled(workspace == nil)
            Button("Aba anterior") { workspace?.cycle(-1) }
                .keyboardShortcut(.tab, modifiers: [.control, .shift]).disabled(workspace == nil)
            Button("Alternar painel em foco") {
                if let tab = workspace?.selected { tab.secondaryFocused.toggle() }
            }.keyboardShortcut("`", modifiers: [.control, .option])
                .disabled(workspace?.selected.secondary == nil)
            Divider()
            Button("Voltar") { navigation?.goBack() }
                .keyboardShortcut("[").disabled(navigation?.canGoBack != true)
            Button("Avançar") { navigation?.goForward() }
                .keyboardShortcut("]").disabled(navigation?.canGoForward != true)
            Divider()
            Button("Buscar e executar comando…") {
                openMain()
                store.showPalette = true
            }.keyboardShortcut("k").disabled(store.showComposer || store.showPalette)
            Divider()
            Button("Visão geral") { navigate("center") }.keyboardShortcut("1")
            Button("Tarefas") { navigate("runs") }.keyboardShortcut("2")
            Button("Projetos") { navigate("projects") }.keyboardShortcut("3")
            Button("Decisões") { navigate("decisions") }.keyboardShortcut("4")
            Button("Fluxos") { navigate("runbooks") }.keyboardShortcut("5")
            Button("Diário") { navigate("diary") }.keyboardShortcut("6")
            Divider()
            Button("Atualizar") { Task { await store.refresh(silent: true) } }.keyboardShortcut("r")
                .disabled(!store.connected)
        }
        CommandMenu("Execução") {
            Button("Abrir tarefa em janela") {
                if let run = focusedRun { openRun(run.id) }
            }.keyboardShortcut(.return, modifiers: [.command, .option])
                .disabled(focusedRun == nil)
            Button("Mostrar worktree no Finder") {
                if let run = focusedRun { store.reveal(run.workspace) }
            }.keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(focusedRun?.workspace.isEmpty != false)
            Divider()
            Button(companion.enabled ? "Ocultar companheiro" : "Mostrar companheiro") { companion.toggle() }
                .keyboardShortcut("m", modifiers: [.command, .option, .control])
            Button("Tarefas do companheiro") { companion.showActions() }
            Button("Central de sessões") { island.toggle() }.keyboardShortcut("i", modifiers: [.command, .option])
            Button(store.snapshot.preferences.queuePaused ? "Retomar fila" : "Pausar fila") {
                store.perform("queue.toggle")
            }
            Button("Verificar providers") { store.perform("providers.probe") }
            Divider()
            Button("Sair e parar runs…") {
                openMain()
                store.showStopConfirmation = true
            }
        }
    }

    private var focusedRun: Run? {
        guard let focusedRunID else { return nil }
        return store.snapshot.runs.first { $0.id == focusedRunID }
    }

    private var recentRuns: [Run] {
        Array(store.snapshot.runs.sorted { $0.updatedAt > $1.updatedAt }.prefix(8))
    }

    private func navigate(_ route: String) {
        store.route = route
        openMain()
    }

    private func openMain() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openRun(_ id: String) {
        openWindow(id: "run", value: id)
        NSApp.activate(ignoringOtherApps: true)
    }
}
