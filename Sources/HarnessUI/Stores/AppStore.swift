import AppKit
import HarnessDomain
import HarnessIPC
import HarnessInfrastructure
import Observation
import SwiftUI
import UserNotifications

@MainActor @Observable
final class AppStore {
    var snapshot = Snapshot()
    var loading = true
    var connected = false
    var error: String?
    var notice: String?
    let workspace = WorkspaceSession()
    var navigation: WorkspaceNavigation { workspace.navigation }
    var route: String {
        get { navigation.location.route }
        set { navigation.visit(newValue) }
    }
    var settingsSection = "Geral"
    var guideTopic = "start"
    let firstTaskJourney = FirstTaskJourney()
    var decisionRunID: String?
    var showComposer = false
    var showPalette = false
    var showStopConfirmation = false
    var composerText = ""
    var composerSource: SourceIntent?
    var composerProjectID = ""
    var composerRunbookID = ""
    var events = [String: [RunEvent]]()
    var busy = Set<String>()
    var externalSessions = [ExternalSession]()
    var externalSessionError: String?
    @ObservationIgnored private var externalSessionBridge = ExternalSessionBridge()
    private var client: CoordinatorClient?
    private var polling: Task<Void, Never>?
    private var previousStates = [String: RunState]()
    var activeRuns: [Run] { snapshot.runs.filter { $0.state.active } }
    var pendingDecisions: Int {
        snapshot.runs.reduce(0) {
            $0 + $1.approvals.filter { $0.state == "PREPARED" }.count
                + ($1.state == .waitingUser ? 1 : 0)
        }
    }
    var colorScheme: ColorScheme? {
        snapshot.preferences.appearance == "Escuro" ? .dark : snapshot.preferences.appearance == "Claro" ? .light : nil
    }
    func connect() async {
        guard polling == nil else { return }
        do {
            let args = CommandLine.arguments
            let root = args.firstIndex(where: { ["--fronda-data-root", "--harness-data-root"].contains($0) }).flatMap {
                args.indices.contains($0 + 1) ? URL(fileURLWithPath: args[$0 + 1]) : nil
            }
            client = try CoordinatorClient(root: root)
            externalSessionBridge = ExternalSessionBridge(root: root)
            await refresh()
            polling = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    guard let self else { return }
                    await self.refresh(silent: true)
                }
            }
        } catch {
            self.error = error.localizedDescription
            loading = false
        }
    }
    func refresh(silent: Bool = false) async {
        let bridge = externalSessionBridge
        do {
            externalSessions = try await Task.detached(priority: .utility) { try bridge.sessions() }.value
            externalSessionError = nil
        } catch {
            externalSessionError = "Não foi possível atualizar as sessões externas."
        }
        do {
            let response = try await send(RPCRequest("snapshot"))
            if let value = response.snapshot {
                if snapshot.preferences.notifications { notifyChanges(value.runs) }
                snapshot = value
                connected = true
                previousStates = Dictionary(uniqueKeysWithValues: value.runs.map { ($0.id, $0.state) })
            }
        } catch {
            connected = false
            if !silent { self.error = error.localizedDescription }
        }
        loading = false
    }
    func send(_ request: RPCRequest) async throws -> RPCResponse {
        guard let client else { throw HarnessError("Conectando ao coordenador…") }
        let response = try await client.send(request)
        if let error = response.error { throw HarnessError(error) }
        return response
    }
    func perform(_ action: String, id: String = "", configure: ((inout RPCRequest) -> Void)? = nil) {
        var request = RPCRequest(action)
        request.id = id
        configure?(&request)
        let command = request
        Task {
            busy.insert(id.isEmpty ? action : id)
            defer { busy.remove(id.isEmpty ? action : id) }
            do {
                let response = try await send(command)
                if !response.path.isEmpty {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: response.path)])
                    notice = "Exportação concluída"
                }
                if action == "run.fork", !response.id.isEmpty { route = "run:" + response.id }
                await refresh()
                if !id.isEmpty { await loadEvents(id) }
            } catch { self.error = error.localizedDescription }
        }
    }
    func loadEvents(_ id: String, before: Int = 0) async {
        do {
            var request = RPCRequest("events")
            request.id = id
            request.number = before
            let incoming = try await send(request).events ?? []
            events[id] = Dictionary(
                (events[id, default: []] + incoming).map { ($0.id, $0) }, uniquingKeysWith: { _, new in new }
            ).values.sorted { $0.sequence < $1.sequence }
        } catch { self.error = error.localizedDescription }
    }
    func addProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Adicionar projeto"
        panel.message = "Escolha um repositório Git. Scripts de instalação não serão executados."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            var project = Project()
            project.bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            perform("project.add") {
                $0.path = url.path
                $0.project = project
            }
        } catch { self.error = error.localizedDescription }
    }
    func renewProjectAccess(_ id: String) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Renovar acesso"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            var project = Project()
            project.bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            perform("project.reauthorize", id: id) {
                $0.path = url.path
                $0.project = project
            }
        } catch { self.error = error.localizedDescription }
    }
    func draft(title: String, source: SourceIntent, projectID: String, runbook: String) {
        composerText = title
        composerSource = source
        composerProjectID = projectID
        composerRunbookID = snapshot.runbooks.first(where: { $0.name == runbook })?.id ?? ""
        showComposer = true
    }
    func savePreferences(_ value: AppPreferences) { perform("preferences.save") { $0.preferences = value } }
    func reveal(_ path: String) {
        guard !path.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
    func openFile(_ path: String) {
        guard !path.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
    func requestNotifications() {
        Task {
            do {
                let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [
                    .alert, .sound, .badge,
                ])
                var prefs = snapshot.preferences
                prefs.notifications = allowed
                savePreferences(prefs)
            } catch { self.error = error.localizedDescription }
        }
    }
    private func notifyChanges(_ runs: [Run]) {
        for run in runs
        where previousStates[run.id] != nil && previousStates[run.id] != run.state
            && [.ready, .partial, .failed, .blocked, .waitingUser].contains(run.state)
        {
            let content = UNMutableNotificationContent()
            content.title = run.state.label
            content.body = run.title
            content.threadIdentifier = run.id
            content.userInfo = ["runID": run.id]
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: run.id + run.state.rawValue, content: content, trigger: nil))
        }
    }
}
