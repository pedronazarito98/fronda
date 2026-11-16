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
    var chatID = makeID()
    var hasSelectedChat = false
    var pendingRunID: String?
    var graph: ChatRunReference?
    var runDetail: ChatRunDetail?
    var chatDrafts = [String: ChatComposerDraft]()
    var settingsSection = "Geral"
    var events = [String: [RunEvent]]()
    var busy = Set<String>()
    var externalSessions = [ExternalSession]()
    var externalSessionError: String?
    @ObservationIgnored private var externalSessionBridge = ExternalSessionBridge()
    private var client: CoordinatorClient?
    private var polling: Task<Void, Never>?
    private var refreshSequence = 0
    private var requestedUpgrade = false
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
        refreshSequence += 1
        let sequence = refreshSequence
        let bridge = externalSessionBridge
        do {
            externalSessions = try await Task.detached(priority: .utility) { try bridge.sessions() }.value
            externalSessionError = nil
        } catch {
            externalSessionError = "Não foi possível atualizar as sessões externas."
        }
        do {
            var response = try await send(RPCRequest("snapshot"))
            guard sequence == refreshSequence else { return }
            if response.snapshot?.conversations == nil {
                if !requestedUpgrade {
                    // A bundle update at the installed path can leave the previous coordinator in memory.
                    // Its graceful shutdown refuses to interrupt work already in progress.
                    requestedUpgrade = true
                    do {
                        _ = try await send(RPCRequest("service.shutdown"))
                        try await Task.sleep(for: .seconds(1))
                        response = try await send(RPCRequest("snapshot"))
                    } catch {
                        requestedUpgrade = false
                        throw error
                    }
                }
                guard response.snapshot?.conversations != nil else {
                    throw HarnessError(
                        "Esta versão do coordenador não oferece conversas. Reabra a versão atual do Fronda.")
                }
            }
            guard sequence == refreshSequence else { return }
            if let value = response.snapshot {
                if snapshot.preferences.notifications { notifyChanges(value.runs) }
                snapshot = value
                resolvePendingChat()
                connected = true
                previousStates = Dictionary(uniqueKeysWithValues: value.runs.map { ($0.id, $0.state) })
            }
        } catch {
            guard sequence == refreshSequence else { return }
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
                }
                if action == "run.fork", !response.id.isEmpty { openChat(forRun: response.id) }
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
    func addChatProject() async throws -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Usar projeto"
        panel.message = "Escolha o repositório Git em que o Fronda vai trabalhar."
        guard await panel.begin() == .OK, let url = panel.url else { return nil }
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        if let known = snapshot.projects.first(where: { $0.path == path }) { return known.id }
        var project = Project()
        project.bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        var request = RPCRequest("project.add")
        request.path = path
        request.project = project
        let id = try await send(request).id
        await refresh(silent: true)
        return id
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
    func savePreferences(_ value: AppPreferences) { perform("preferences.save") { $0.preferences = value } }
    func reveal(_ path: String) {
        guard !path.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
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
            content.title = run.pauseAwareStateLabel
            content.body = run.title
            content.threadIdentifier = run.id
            content.userInfo = ["runID": run.id]
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: run.id + run.state.rawValue, content: content, trigger: nil))
        }
    }
}
