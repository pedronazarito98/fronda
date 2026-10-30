import Foundation
import Observation

@MainActor @Observable
final class FirstTaskJourney {
    enum Status: String, Codable { case new, active, paused, completed }
    private struct Progress: Codable {
        var step = FirstTaskStep.project
        var status = Status.new
        var skipped = Set<FirstTaskStep>()
        var runID: String?
        var draft: NewRunDraft?
    }
    private static let storageKey = "fronda.guide.first-task.v1"
    private var progress: Progress

    init() {
        let saved = UserDefaults.standard.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode(Progress.self, from: $0) }
        progress = saved ?? Progress()
        // Restore at the user's request; never reopen a sheet during app launch.
        if progress.status == .active { progress.status = .paused }
    }

    var step: FirstTaskStep { progress.step }
    var status: Status { progress.status }
    var isActive: Bool { status == .active }
    var isComposing: Bool { isActive && progress.runID == nil }
    var runID: String? { progress.runID }
    var savedDraft: NewRunDraft? { progress.draft }
    var skippedCount: Int { progress.skipped.count }
    var entryTitle: String {
        switch status {
        case .new: "Preparar minha primeira tarefa"
        case .active: "Continuar com o mascote"
        case .paused: "Retomar minha jornada"
        case .completed: "Fazer a jornada novamente"
        }
    }

    func begin() {
        if status == .new || status == .completed { progress = Progress() }
        progress.status = .active
        persist()
    }

    func checkpoint(_ draft: NewRunDraft) {
        guard [.active, .paused].contains(status), progress.runID == nil else { return }
        progress.draft = draft
        persist()
    }

    func advance() {
        guard isComposing, step != .prepare && step != .context,
            let next = FirstTaskStep.allCases.dropFirst(step.number).first
        else { return }
        progress.step = next
        persist()
    }

    func skip() {
        guard isActive else { return }
        if step == .prepare || step == .context {
            pause()
        } else {
            progress.skipped.insert(step)
            advance()
        }
    }

    func pause() {
        guard isActive else { return }
        progress.status = .paused
        persist()
    }

    func createdRun(_ id: String) {
        guard [.active, .paused].contains(status), runID == nil, !id.isEmpty else { return }
        progress.runID = id
        progress.draft = nil
        progress.step = .context
        persist()
    }

    func complete() {
        guard isActive, runID != nil, step == .context else { return }
        progress.status = .completed
        progress.draft = nil
        persist()
    }

    func resumeDraftAfterMissingRun() {
        progress = Progress()
        progress.status = .active
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

extension AppStore {
    func openFirstTaskJourney() {
        firstTaskJourney.begin()
        if let id = firstTaskJourney.runID {
            guard snapshot.runs.contains(where: { $0.id == id && $0.state != .archived }) else {
                firstTaskJourney.resumeDraftAfterMissingRun()
                showComposer = true
                notice = "A tarefa anterior não está disponível. Vamos preparar uma nova."
                return
            }
            navigation.visit(WorkspaceLocation(route: "run:" + id, section: .context))
        } else {
            showComposer = true
        }
    }
}
